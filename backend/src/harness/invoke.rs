//! Synchronous Harness tool execution (MVP). WebSocket and future agent loop call into here.

use std::collections::BTreeSet;

use serde::Serialize;
use serde_json::{json, Value};
use sqlx::types::Json;

use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::skills::SkillReadError;

use super::observe;
use super::permissions;
use super::HarnessContext;

#[derive(Debug)]
pub enum InvokeError {
    UnknownTool(String),
    NotImplemented {
        tool: String,
        hint: String,
    },
    /// Tool-specific argument validation (maps to `invalid_payload` over WS).
    InvalidArgs(String),
    SkillNotFound,
    SkillBadRequest(String),
    SkillUnavailable,
    /// Child process / IPC failure for process-isolated tools (`isolated.echo`).
    IsolationFailed(String),
    /// WASM interpreter failure (`wasm.probe`).
    WasmFailed(String),
    /// Postgres-backed domain tools require a configured pool.
    DatabaseUnavailable,
    /// Domain tools require project/script context and/or arguments.
    MissingContext(String),
    DatabaseError(String),
}

impl From<SkillReadError> for InvokeError {
    fn from(e: SkillReadError) -> Self {
        match e {
            SkillReadError::BadPath(m) => InvokeError::SkillBadRequest(m),
            SkillReadError::SkillsDirMissing => InvokeError::SkillUnavailable,
            SkillReadError::NotFound => InvokeError::SkillNotFound,
            SkillReadError::TooLarge | SkillReadError::TooLargeBinary => {
                InvokeError::SkillBadRequest("skill file exceeds maximum allowed size".into())
            }
            SkillReadError::Io(m) => InvokeError::SkillBadRequest(m),
        }
    }
}

impl InvokeError {
    #[must_use]
    pub fn code(&self) -> &'static str {
        match self {
            InvokeError::UnknownTool(_) => "unknown_tool",
            InvokeError::NotImplemented { .. } => "tool_not_implemented",
            InvokeError::InvalidArgs(_) => "invalid_payload",
            InvokeError::SkillNotFound => "not_found",
            InvokeError::SkillBadRequest(_) => "invalid_payload",
            InvokeError::SkillUnavailable => "skill_unavailable",
            InvokeError::IsolationFailed(_) => "isolation_failed",
            InvokeError::WasmFailed(_) => "wasm_failed",
            InvokeError::DatabaseUnavailable => "database_error",
            InvokeError::MissingContext(_) => "invalid_state",
            InvokeError::DatabaseError(_) => "database_error",
        }
    }

    #[must_use]
    pub fn message(&self) -> String {
        match self {
            InvokeError::UnknownTool(n) => format!("unknown or unregistered tool: {n}"),
            InvokeError::NotImplemented { tool, hint } => format!("{tool}: {hint}"),
            InvokeError::InvalidArgs(m) => m.clone(),
            InvokeError::SkillNotFound => "skill file not found".into(),
            InvokeError::SkillBadRequest(m) => m.clone(),
            InvokeError::SkillUnavailable => {
                "skills directory is not available on this server".into()
            }
            InvokeError::IsolationFailed(m) => m.clone(),
            InvokeError::WasmFailed(m) => m.clone(),
            InvokeError::DatabaseUnavailable => "DATABASE_URL not configured".into(),
            InvokeError::MissingContext(m) => m.clone(),
            InvokeError::DatabaseError(m) => m.clone(),
        }
    }
}

#[derive(sqlx::FromRow, Serialize)]
struct HarnessScriptRow {
    legacy_id: i32,
    name: Option<String>,
    content: Option<String>,
    extract_state: Option<i32>,
}

#[derive(sqlx::FromRow, Serialize)]
struct HarnessNovelRow {
    legacy_id: i32,
    chapter_index: i32,
    chapter: String,
    chapter_data: String,
    event_state: i32,
}

#[derive(sqlx::FromRow, Serialize)]
struct HarnessNovelEventRow {
    legacy_id: i32,
    name: String,
    detail: String,
}

#[derive(sqlx::FromRow)]
struct OwnedScriptScope {
    project_id: uuid::Uuid,
    script_id: uuid::Uuid,
}

#[derive(sqlx::FromRow)]
struct ParentAssetRow {
    asset_type: String,
}

#[derive(sqlx::FromRow)]
struct StoryboardGenerateRow {
    legacy_id: i32,
    prompt: Option<String>,
}

fn require_pool(ctx: &HarnessContext) -> Result<&sqlx::PgPool, InvokeError> {
    ctx.pool.as_ref().ok_or(InvokeError::DatabaseUnavailable)
}

fn map_api_error(err: crate::error::ApiError, fallback: &'static str) -> InvokeError {
    match err {
        crate::error::ApiError::NotFound => {
            InvokeError::MissingContext("resource not found".into())
        }
        crate::error::ApiError::BadRequest(msg) => InvokeError::InvalidArgs(msg),
        crate::error::ApiError::DatabaseError(msg) => InvokeError::DatabaseError(msg),
        _ => InvokeError::DatabaseError(fallback.into()),
    }
}

fn project_legacy_from_ctx(ctx: &HarnessContext) -> Result<i32, InvokeError> {
    ctx.project_legacy_id
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::MissingContext("project context not attached".into()))
}

async fn invoke_get_plan_data(ctx: &HarnessContext) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;

    let project_uuid: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_legacy_id)
    .bind(ctx.user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext("attached project is not owned or missing".into())
    })?;

    let plan_data: Option<Json<Value>> = sqlx::query_scalar(
        r#"
        SELECT plan_data
        FROM app_script_agent_plan
        WHERE project_id = $1 AND owner_user_id = $2 AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(project_uuid)
    .bind(ctx.user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let scripts: Vec<HarnessScriptRow> = sqlx::query_as(
        r#"
        SELECT s.legacy_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1 AND p.legacy_id = $2
        ORDER BY s.legacy_id
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_legacy_id)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let mut data = plan_data.map_or_else(|| Value::Object(Default::default()), |j| j.0);
    if let Some(obj) = data.as_object_mut() {
        obj.insert(
            "script".into(),
            serde_json::to_value(&scripts)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize scripts".into()))?,
        );
    }

    Ok(serde_json::json!({
        "projectId": project_legacy_id,
        "agentType": "scriptAgent",
        "data": data,
    }))
}

fn script_legacy_id_from_args_or_ctx(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<i32, InvokeError> {
    let from_args = arguments
        .get("scriptId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);
    from_args.or(ctx.script_legacy_id).ok_or_else(|| {
        InvokeError::MissingContext("scriptId is required (arg or attach context)".into())
    })
}

fn parse_i32_required(arguments: &Value, key: &str) -> Result<i32, InvokeError> {
    arguments
        .get(key)
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0)
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a positive integer")))
}

fn parse_ids_required(arguments: &Value, key: &str) -> Result<Vec<i32>, InvokeError> {
    let values = arguments
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| InvokeError::InvalidArgs(format!("{key} must be a non-empty array")))?;
    if values.is_empty() {
        return Err(InvokeError::InvalidArgs(format!(
            "{key} must be a non-empty array"
        )));
    }
    let mut uniq = BTreeSet::new();
    for value in values {
        let id = value
            .as_i64()
            .and_then(|v| i32::try_from(v).ok())
            .filter(|v| *v > 0)
            .ok_or_else(|| {
                InvokeError::InvalidArgs(format!("{key} must contain positive integers"))
            })?;
        uniq.insert(id);
    }
    Ok(uniq.into_iter().collect())
}

async fn require_owned_script_scope(
    ctx: &HarnessContext,
    script_legacy_id: i32,
) -> Result<OwnedScriptScope, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    sqlx::query_as::<_, OwnedScriptScope>(
        r#"
        SELECT p.id AS project_id, s.id AS script_id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_legacy_id)
    .bind(script_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| InvokeError::MissingContext("script not found in attached project".into()))
}

async fn invoke_get_script_content(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;

    let row: HarnessScriptRow = sqlx::query_as(
        r#"
        SELECT s.legacy_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.legacy_id = $2
          AND s.legacy_id = $3
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_legacy_id)
    .bind(script_legacy_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| InvokeError::MissingContext("script not found in attached project".into()))?;

    serde_json::to_value(row)
        .map_err(|_| InvokeError::DatabaseError("failed to serialize script".into()))
}

async fn invoke_get_novel_text(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let novel_legacy_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let rows: Vec<HarnessNovelRow> = if let Some(novel_id) = novel_legacy_id {
        sqlx::query_as(
            r#"
            SELECT n.legacy_id, n.chapter_index, n.chapter, n.chapter_data, n.event_state
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
              AND n.legacy_id = $3
            ORDER BY n.chapter_index ASC, n.legacy_id ASC
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_legacy_id)
        .bind(novel_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as(
            r#"
            SELECT n.legacy_id, n.chapter_index, n.chapter, n.chapter_data, n.event_state
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
            ORDER BY n.chapter_index ASC, n.legacy_id ASC
            LIMIT 200
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_legacy_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    Ok(serde_json::json!({
        "projectId": project_legacy_id,
        "items": rows,
        "total": rows.len(),
    }))
}

async fn invoke_get_novel_events(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let novel_legacy_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let rows: Vec<HarnessNovelEventRow> = if let Some(novel_id) = novel_legacy_id {
        sqlx::query_as(
            r#"
            SELECT e.legacy_id, e.name, e.detail
            FROM app_novel_event e
            INNER JOIN app_project p ON p.id = e.project_id
            INNER JOIN app_novel_event_chapter ec ON ec.event_id = e.id
            INNER JOIN app_novel n ON n.id = ec.novel_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
              AND n.legacy_id = $3
            ORDER BY e.legacy_id ASC
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_legacy_id)
        .bind(novel_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as(
            r#"
            SELECT e.legacy_id, e.name, e.detail
            FROM app_novel_event e
            INNER JOIN app_project p ON p.id = e.project_id
            WHERE p.owner_user_id = $1
              AND p.legacy_id = $2
            ORDER BY e.legacy_id ASC
            LIMIT 200
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_legacy_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    Ok(serde_json::json!({
        "projectId": project_legacy_id,
        "items": rows,
        "total": rows.len(),
    }))
}

async fn invoke_get_flow_data(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let key = arguments
        .get("key")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| InvokeError::InvalidArgs("key must be a non-empty string".into()))?;
    let mapped_key = if key == "stoaryTable" {
        "storyboardTable"
    } else {
        key
    };
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;

    let flow = crate::production_legacy::load_owned_production_flow_json(
        pool,
        ctx.user_id,
        project_legacy_id,
        script_legacy_id,
    )
    .await
    .map_err(|e| map_api_error(e, "failed to read production flow data"))?;

    flow.get(mapped_key)
        .cloned()
        .ok_or_else(|| InvokeError::InvalidArgs(format!("unsupported flow key: {key}")))
}

async fn invoke_add_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_legacy_id).await?;
    let assets_id = parse_i32_required(arguments, "assetsId")?;
    let name = arguments
        .get("name")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| InvokeError::InvalidArgs("name must be a non-empty string".into()))?;
    let desc = arguments
        .get("desc")
        .and_then(Value::as_str)
        .map(str::trim)
        .ok_or_else(|| InvokeError::InvalidArgs("desc must be a string".into()))?;
    let maybe_legacy_id = arguments
        .get("id")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let parent = sqlx::query_as::<_, ParentAssetRow>(
        r#"
        SELECT a.asset_type
        FROM app_asset a
        WHERE a.project_id = $1
          AND a.legacy_id = $2
        "#,
    )
    .bind(scope.project_id)
    .bind(assets_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| InvokeError::MissingContext("parent asset not found".into()))?;

    if let Some(legacy_id) = maybe_legacy_id {
        let updated = sqlx::query(
            r#"
            UPDATE app_asset
            SET name = $4,
                description = $5,
                updated_at = NOW()
            WHERE project_id = $1
              AND legacy_id = $2
              AND COALESCE((metadata ->> 'assetsId')::int, 0) = $3
            "#,
        )
        .bind(scope.project_id)
        .bind(legacy_id)
        .bind(assets_id)
        .bind(name)
        .bind(desc)
        .execute(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

        if updated.rows_affected() == 0 {
            return Err(InvokeError::MissingContext(
                "derived asset not found under the specified parent".into(),
            ));
        }

        return Ok(json!({
            "id": legacy_id,
            "assetsId": assets_id,
            "name": name,
            "desc": desc,
            "projectId": project_legacy_id,
            "scriptId": script_legacy_id,
            "operation": "updated",
        }));
    }

    let next_legacy_id: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(a.legacy_id), 0) + 1
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.owner_user_id = $1
        "#,
    )
    .bind(ctx.user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let new_id = uuid::Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO app_asset (
            id,
            project_id,
            legacy_id,
            name,
            asset_type,
            description,
            metadata
        )
        VALUES (
            $1,
            $2,
            $3,
            $4,
            $5,
            $6,
            jsonb_build_object('assetsId', $7, 'state', '未生成')
        )
        "#,
    )
    .bind(new_id)
    .bind(scope.project_id)
    .bind(next_legacy_id)
    .bind(name)
    .bind(parent.asset_type)
    .bind(desc)
    .bind(assets_id)
    .execute(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_script_asset (script_id, asset_id)
        VALUES ($1, $2)
        ON CONFLICT DO NOTHING
        "#,
    )
    .bind(scope.script_id)
    .bind(new_id)
    .execute(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    Ok(json!({
        "id": next_legacy_id,
        "assetsId": assets_id,
        "name": name,
        "desc": desc,
        "projectId": project_legacy_id,
        "scriptId": script_legacy_id,
        "operation": "created",
    }))
}

async fn invoke_del_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_legacy_id).await?;
    let assets_id = parse_i32_required(arguments, "assetsId")?;
    let derive_id = parse_i32_required(arguments, "id")?;

    let derive_uuid: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
          AND a.legacy_id = $3
          AND COALESCE((a.metadata ->> 'assetsId')::int, 0) = $4
        "#,
    )
    .bind(scope.project_id)
    .bind(scope.script_id)
    .bind(derive_id)
    .bind(assets_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext("derived asset not found under the specified parent".into())
    })?;

    sqlx::query(
        r#"
        DELETE FROM app_asset
        WHERE id = $1
        "#,
    )
    .bind(derive_uuid)
    .execute(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    Ok(json!({
        "id": derive_id,
        "assetsId": assets_id,
        "projectId": project_legacy_id,
        "scriptId": script_legacy_id,
        "deleted": true,
    }))
}

async fn invoke_generate_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_legacy_id).await?;
    let ids = parse_ids_required(arguments, "ids")?;
    let model = arguments
        .get("model")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("dall-e-3");
    let resolution = arguments
        .get("resolution")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("1024x1024");

    let valid_ids: Vec<i32> = sqlx::query_scalar(
        r#"
        SELECT a.legacy_id
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
          AND a.legacy_id = ANY($3::int4[])
          AND a.metadata ? 'assetsId'
        ORDER BY a.legacy_id
        "#,
    )
    .bind(scope.project_id)
    .bind(scope.script_id)
    .bind(&ids)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    if valid_ids.len() != ids.len() {
        return Err(InvokeError::MissingContext(
            "some derived assets are missing or outside attached scope".into(),
        ));
    }

    let mut enqueued = Vec::with_capacity(valid_ids.len());
    for asset_id in valid_ids {
        let payload = json!({
            "source": "production.assets.batch-generate",
            "project_legacy_id": project_legacy_id,
            "script_id": script_legacy_id,
            "asset_id": asset_id,
            "model": model,
            "resolution": resolution,
        });
        let row = enqueue_generation_job(pool, ctx.user_id, JOB_KIND_ASSET_GENERATE_BATCH, payload)
            .await
            .map_err(|e| map_api_error(e, "failed to enqueue derived-asset generation job"))?;
        enqueued.push(row);
    }

    Ok(json!({
        "enqueued": enqueued,
        "total": enqueued.len(),
    }))
}

async fn invoke_generate_storyboard(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let ids = parse_ids_required(arguments, "ids")?;
    let pool = require_pool(ctx)?;
    let project_legacy_id = project_legacy_from_ctx(ctx)?;
    let script_legacy_id = script_legacy_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_legacy_id).await?;
    let model = arguments
        .get("model")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("dall-e-3");
    let resolution = arguments
        .get("resolution")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .unwrap_or("1024x1024");

    let rows: Vec<StoryboardGenerateRow> = sqlx::query_as(
        r#"
        SELECT sb.legacy_id, sb.prompt
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.legacy_id = ANY($2::int4[])
        ORDER BY sb.legacy_id
        "#,
    )
    .bind(scope.script_id)
    .bind(&ids)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    if rows.len() != ids.len() {
        return Err(InvokeError::MissingContext(
            "some storyboard ids are missing or outside attached scope".into(),
        ));
    }

    let mut enqueued = Vec::with_capacity(rows.len());
    for row in rows {
        let payload = json!({
            "source": "production.storyboard.batch-generate-image",
            "project_legacy_id": project_legacy_id,
            "script_id": script_legacy_id,
            "storyboard_id": row.legacy_id,
            "prompt": row.prompt.unwrap_or_default(),
            "model": model,
            "resolution": resolution,
        });
        let item =
            enqueue_generation_job(pool, ctx.user_id, JOB_KIND_ASSET_GENERATE_BATCH, payload)
                .await
                .map_err(|e| map_api_error(e, "failed to enqueue storyboard generation job"))?;
        enqueued.push(item);
    }

    Ok(json!({
        "enqueued": enqueued,
        "total": enqueued.len(),
    }))
}

fn dispatch_in_process(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    match name {
        "echo" => Ok(arguments.clone()),
        "wasm.probe" => super::wasm_runtime::invoke_probe().map_err(InvokeError::WasmFailed),
        "skills.read" => {
            let path = arguments
                .get("path")
                .and_then(Value::as_str)
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .ok_or_else(|| {
                    InvokeError::InvalidArgs(
                        "skills.read requires arguments.path (non-empty string)".into(),
                    )
                })?;
            let doc = crate::skills::read_skill_markdown(path).map_err(InvokeError::from)?;
            serde_json::to_value(&doc).map_err(|_| {
                InvokeError::SkillBadRequest("failed to serialize skill content".into())
            })
        }
        "get_planData" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_planData requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_plan_data(ctx))
        }
        "get_script_content" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_script_content requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_script_content(ctx, arguments))
        }
        "get_novel_text" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_novel_text requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_novel_text(ctx, arguments))
        }
        "get_novel_events" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_novel_events requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_novel_events(ctx, arguments))
        }
        "get_flowData" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "get_flowData requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_get_flow_data(ctx, arguments))
        }
        "add_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "add_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_add_derive_asset(ctx, arguments))
        }
        "del_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "del_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_del_derive_asset(ctx, arguments))
        }
        "generate_deriveAsset" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "generate_deriveAsset requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_generate_derive_asset(ctx, arguments))
        }
        "generate_storyboard" => {
            let handle = tokio::runtime::Handle::try_current().map_err(|_| {
                InvokeError::DatabaseError(
                    "generate_storyboard requires async runtime (WebSocket invoke path)".into(),
                )
            })?;
            handle.block_on(invoke_generate_storyboard(ctx, arguments))
        }
        _ => Err(InvokeError::NotImplemented {
            tool: name.to_string(),
            hint: "registered in catalog but execution is not wired yet".to_string(),
        }),
    }
}

/// Run a catalog tool by name. Returns JSON suitable for `harness.tool.result.payload.result`.
/// WebSocket uses [`invoke_tool_async`] (process-isolated tools); this remains for tests and a future sync caller.
#[allow(dead_code)]
pub fn invoke_tool(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    if !permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    observe::harness_tool_invoke(ctx, name);

    dispatch_in_process(ctx, name, arguments)
}

/// Like [`invoke_tool`], but routes process-isolated tools to async handlers (WebSocket path).
pub async fn invoke_tool_async(
    ctx: &HarnessContext,
    name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    if !permissions::tool_invocation_allowed(ctx.user_id, name) {
        return Err(InvokeError::UnknownTool(name.to_string()));
    }

    observe::harness_tool_invoke(ctx, name);

    match name {
        "isolated.echo" => super::isolate::isolated_echo(arguments).await,
        "get_planData" => invoke_get_plan_data(ctx).await,
        "get_script_content" => invoke_get_script_content(ctx, arguments).await,
        "get_novel_text" => invoke_get_novel_text(ctx, arguments).await,
        "get_novel_events" => invoke_get_novel_events(ctx, arguments).await,
        "get_flowData" => invoke_get_flow_data(ctx, arguments).await,
        "add_deriveAsset" => invoke_add_derive_asset(ctx, arguments).await,
        "del_deriveAsset" => invoke_del_derive_asset(ctx, arguments).await,
        "generate_deriveAsset" => invoke_generate_derive_asset(ctx, arguments).await,
        "generate_storyboard" => invoke_generate_storyboard(ctx, arguments).await,
        "wasm.probe" => {
            let r = tokio::task::spawn_blocking(super::wasm_runtime::invoke_probe)
                .await
                .map_err(|e| InvokeError::WasmFailed(format!("join: {e}")))?;
            r.map_err(InvokeError::WasmFailed)
        }
        _ => dispatch_in_process(ctx, name, arguments),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use uuid::Uuid;

    fn ctx() -> HarnessContext {
        HarnessContext::with_scope(Uuid::nil(), None, None, None)
    }

    #[test]
    fn echo_returns_arguments() {
        let args = json!({ "a": 1, "b": "x" });
        let out = invoke_tool(&ctx(), "echo", &args).unwrap();
        assert_eq!(out, args);
    }

    #[test]
    fn unknown_tool_not_in_catalog() {
        let err = invoke_tool(&ctx(), "no_such_tool", &json!({})).unwrap_err();
        assert_eq!(err.code(), "unknown_tool");
    }

    #[test]
    fn skills_read_requires_path() {
        let err = invoke_tool(&ctx(), "skills.read", &json!({})).unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }

    #[test]
    fn skills_read_loads_known_file() {
        let out = invoke_tool(
            &ctx(),
            "skills.read",
            &json!({ "path": "script_execution_script.md" }),
        )
        .unwrap();
        let path = out.get("path").and_then(Value::as_str).unwrap();
        assert!(
            path.ends_with("script_execution_script.md"),
            "unexpected path: {path}"
        );
        let content = out.get("content").and_then(Value::as_str).unwrap();
        assert!(!content.is_empty());
    }

    #[test]
    fn wasm_probe_returns_42() {
        let out = invoke_tool(&ctx(), "wasm.probe", &json!({})).unwrap();
        assert_eq!(out.get("value").and_then(Value::as_i64), Some(42));
    }

    #[tokio::test]
    async fn get_script_content_requires_context() {
        let err = invoke_tool_async(&ctx(), "get_script_content", &json!({}))
            .await
            .unwrap_err();
        assert_eq!(err.code(), "database_error");
    }

    #[tokio::test]
    async fn get_flow_data_requires_key() {
        let err = invoke_tool_async(&ctx(), "get_flowData", &json!({}))
            .await
            .unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }

    #[tokio::test]
    async fn generate_storyboard_ids_require_positive_ints() {
        let err = invoke_tool_async(&ctx(), "generate_storyboard", &json!({ "ids": [0] }))
            .await
            .unwrap_err();
        assert_eq!(err.code(), "invalid_payload");
    }
}
