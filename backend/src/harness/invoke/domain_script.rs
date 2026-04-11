//! 脚本域 Harness 工具：get_planData、get_script_content、get_novel_text、get_novel_events。

use serde::Serialize;
use serde_json::Value;
use sqlx::types::Json;

use super::{
    project_numeric_from_ctx, require_pool, script_numeric_id_from_args_or_ctx, InvokeError,
};
use crate::harness::HarnessContext;

// ── Row types ────────────────────────────────────────────────────────────────

#[derive(sqlx::FromRow, Serialize)]
pub(super) struct HarnessScriptRow {
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: Option<String>,
    pub content: Option<String>,
    pub extract_state: Option<i32>,
}

#[derive(sqlx::FromRow, Serialize)]
pub(super) struct HarnessNovelRow {
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub chapter_index: i32,
    pub chapter: String,
    pub chapter_data: String,
    pub event_state: i32,
}

#[derive(sqlx::FromRow, Serialize)]
pub(super) struct HarnessNovelEventRow {
    #[sqlx(rename = "numeric_id")]
    pub numeric_id: i32,
    pub name: String,
    pub detail: String,
}

#[derive(sqlx::FromRow)]
pub(super) struct OwnedScriptScope {
    pub project_id: uuid::Uuid,
    pub script_id: uuid::Uuid,
}

// ── Helpers ──────────────────────────────────────────────────────────────────

pub(super) async fn require_owned_script_scope(
    ctx: &HarnessContext,
    script_numeric_id: i32,
) -> Result<OwnedScriptScope, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    sqlx::query_as::<_, OwnedScriptScope>(
        r#"
        SELECT p.id AS project_id, s.id AS script_id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND s.numeric_id = $3
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| InvokeError::MissingContext("script not found in attached project".into()))
}

// ── Tool implementations ─────────────────────────────────────────────────────

pub(super) async fn invoke_get_plan_data(ctx: &HarnessContext) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;

    let project_uuid: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT id FROM app_project
        WHERE numeric_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_numeric_id)
    .bind(ctx.user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext("attached project is not owned or missing".into())
    })?;

    let plan_row: Option<(i64, Json<Value>)> = sqlx::query_as(
        r#"
        SELECT id, plan_data
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
        SELECT s.numeric_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1 AND p.numeric_id = $2
        ORDER BY s.numeric_id
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let mut data = plan_row
        .as_ref()
        .map(|(_, j)| j.0.clone())
        .unwrap_or_else(|| Value::Object(Default::default()));
    if let Some(obj) = data.as_object_mut() {
        obj.insert(
            "script".into(),
            serde_json::to_value(&scripts)
                .map_err(|_| InvokeError::DatabaseError("failed to serialize scripts".into()))?,
        );
    }

    let mut body = serde_json::json!({
        "projectId": project_numeric_id,
        "agentType": "scriptAgent",
        "data": data,
    });
    if let Some((plan_id, _)) = plan_row {
        body.as_object_mut()
            .expect("get_planData body must be an object")
            .insert("planId".to_string(), serde_json::json!(plan_id));
    }
    Ok(body)
}

pub(super) async fn invoke_get_script_content(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;

    let row: HarnessScriptRow = sqlx::query_as(
        r#"
        SELECT s.numeric_id, s.name, s.content, s.extract_state
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND s.numeric_id = $3
        "#,
    )
    .bind(ctx.user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| InvokeError::MissingContext("script not found in attached project".into()))?;

    serde_json::to_value(row)
        .map_err(|_| InvokeError::DatabaseError("failed to serialize script".into()))
}

pub(super) async fn invoke_get_novel_text(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let novel_numeric_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let rows: Vec<HarnessNovelRow> = if let Some(novel_id) = novel_numeric_id {
        sqlx::query_as(
            r#"
            SELECT n.numeric_id, n.chapter_index, n.chapter, n.chapter_data, n.event_state
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
              AND n.numeric_id = $3
            ORDER BY n.chapter_index ASC, n.numeric_id ASC
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(novel_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as(
            r#"
            SELECT n.numeric_id, n.chapter_index, n.chapter, n.chapter_data, n.event_state
            FROM app_novel n
            INNER JOIN app_project p ON p.id = n.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
            ORDER BY n.chapter_index ASC, n.numeric_id ASC
            LIMIT 200
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    let total = rows.len();
    Ok(serde_json::json!({
        "projectId": project_numeric_id,
        "items": rows,
        "total": total,
    }))
}

pub(super) async fn invoke_get_novel_events(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let novel_numeric_id = arguments
        .get("novelId")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let rows: Vec<HarnessNovelEventRow> = if let Some(novel_id) = novel_numeric_id {
        sqlx::query_as(
            r#"
            SELECT e.numeric_id, e.name, e.detail
            FROM app_novel_event e
            INNER JOIN app_project p ON p.id = e.project_id
            INNER JOIN app_novel_event_chapter ec ON ec.event_id = e.id
            INNER JOIN app_novel n ON n.id = ec.novel_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
              AND n.numeric_id = $3
            ORDER BY e.numeric_id ASC
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .bind(novel_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    } else {
        sqlx::query_as(
            r#"
            SELECT e.numeric_id, e.name, e.detail
            FROM app_novel_event e
            INNER JOIN app_project p ON p.id = e.project_id
            WHERE p.owner_user_id = $1
              AND p.numeric_id = $2
            ORDER BY e.numeric_id ASC
            LIMIT 200
            "#,
        )
        .bind(ctx.user_id)
        .bind(project_numeric_id)
        .fetch_all(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    };

    let total = rows.len();
    Ok(serde_json::json!({
        "projectId": project_numeric_id,
        "items": rows,
        "total": total,
    }))
}
