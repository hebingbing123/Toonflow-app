//! 制作域 Harness 工具：get_flowData、add/del/generate_deriveAsset、generate_storyboard。

use serde_json::{json, Value};

use super::{
    map_api_error, parse_i32_required, parse_ids_required, project_numeric_from_ctx, require_pool,
    script_numeric_id_from_args_or_ctx, InvokeError,
};
use crate::assets::ADV_LOCK_ASSET_NUMERIC;
use crate::harness::HarnessContext;
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};

use super::domain_script::require_owned_script_scope;

// ── Row types ────────────────────────────────────────────────────────────────

#[derive(sqlx::FromRow)]
struct ParentAssetRow {
    asset_type: String,
}

#[derive(sqlx::FromRow)]
struct StoryboardGenerateRow {
    #[sqlx(rename = "numeric_id")]
    numeric_id: i32,
    prompt: Option<String>,
}

// ── Tool implementations ─────────────────────────────────────────────────────

pub(super) async fn invoke_get_flow_data(
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
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;

    let flow = crate::production_flow::load_owned_production_flow_json(
        pool,
        ctx.user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await
    .map_err(|e| map_api_error(e, "failed to read production flow data"))?;

    flow.get(mapped_key)
        .cloned()
        .ok_or_else(|| InvokeError::InvalidArgs(format!("unsupported flow key: {key}")))
}

pub(super) async fn invoke_add_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_numeric_id).await?;
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
    let maybe_numeric_id = arguments
        .get("id")
        .and_then(Value::as_i64)
        .and_then(|v| i32::try_from(v).ok())
        .filter(|v| *v > 0);

    let parent = sqlx::query_as::<_, ParentAssetRow>(
        r#"
        SELECT a.asset_type
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
        WHERE a.project_id = $1
          AND a.numeric_id = $2
        "#,
    )
    .bind(scope.project_id)
    .bind(assets_id)
    .bind(scope.script_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        InvokeError::MissingContext(
            "parent asset not found or not linked to this script (app_script_asset)".into(),
        )
    })?;

    if let Some(numeric_id) = maybe_numeric_id {
        let updated = sqlx::query(
            r#"
            UPDATE app_asset a
            SET name = $4,
                description = $5,
                updated_at = NOW()
            FROM app_script_asset sa
            WHERE a.id = sa.asset_id
              AND sa.script_id = $6
              AND a.project_id = $1
              AND a.numeric_id = $2
              AND COALESCE((a.metadata ->> 'assetsId')::int, 0) = $3
            "#,
        )
        .bind(scope.project_id)
        .bind(numeric_id)
        .bind(assets_id)
        .bind(name)
        .bind(desc)
        .bind(scope.script_id)
        .execute(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

        if updated.rows_affected() == 0 {
            return Err(InvokeError::MissingContext(
                "derived asset not found under the specified parent".into(),
            ));
        }

        return Ok(json!({
            "id": numeric_id,
            "assetsId": assets_id,
            "name": name,
            "desc": desc,
            "projectId": project_numeric_id,
            "scriptId": script_numeric_id,
            "operation": "updated",
        }));
    }

    // Wrap SELECT MAX + INSERT in a transaction to prevent duplicate numeric_id
    // under concurrent add_deriveAsset calls for the same user.
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_ASSET_NUMERIC)
        .execute(&mut *tx)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let next_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_asset"#)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let new_id = uuid::Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO app_asset (
            id, project_id, numeric_id, name, asset_type, description, metadata
        )
        VALUES (
            $1, $2, $3, $4, $5, $6,
            jsonb_build_object('assetsId', $7, 'state', '未生成')
        )
        "#,
    )
    .bind(new_id)
    .bind(scope.project_id)
    .bind(next_numeric_id)
    .bind(name)
    .bind(parent.asset_type)
    .bind(desc)
    .bind(assets_id)
    .execute(&mut *tx)
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
    .execute(&mut *tx)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    Ok(json!({
        "id": next_numeric_id,
        "assetsId": assets_id,
        "name": name,
        "desc": desc,
        "projectId": project_numeric_id,
        "scriptId": script_numeric_id,
        "operation": "created",
    }))
}

pub(super) async fn invoke_del_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_numeric_id).await?;
    let assets_id = parse_i32_required(arguments, "assetsId")?;
    let derive_id = parse_i32_required(arguments, "id")?;

    let derive_uuid: uuid::Uuid = sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
          AND a.numeric_id = $3
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

    sqlx::query(r#"DELETE FROM app_asset WHERE id = $1"#)
        .bind(derive_uuid)
        .execute(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    Ok(json!({
        "id": derive_id,
        "assetsId": assets_id,
        "projectId": project_numeric_id,
        "scriptId": script_numeric_id,
        "deleted": true,
    }))
}

pub(super) async fn invoke_generate_derive_asset(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_numeric_id).await?;
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
        SELECT a.numeric_id
        FROM app_asset a
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        WHERE a.project_id = $1
          AND sa.script_id = $2
          AND a.numeric_id = ANY($3::int4[])
          AND a.metadata ? 'assetsId'
        ORDER BY a.numeric_id
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
            "project_numeric_id": project_numeric_id,
            "script_id": script_numeric_id,
            "asset_id": asset_id,
            "model": model,
            "resolution": resolution,
        });
        let row = enqueue_generation_job(pool, ctx.user_id, JOB_KIND_ASSET_GENERATE_BATCH, payload)
            .await
            .map_err(|e| map_api_error(e, "failed to enqueue derived-asset generation job"))?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(json!({ "enqueued": enqueued, "total": total }))
}

pub(super) async fn invoke_generate_storyboard(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let ids = parse_ids_required(arguments, "ids")?;
    let pool = require_pool(ctx)?;
    let project_numeric_id = project_numeric_from_ctx(ctx)?;
    let script_numeric_id = script_numeric_id_from_args_or_ctx(ctx, arguments)?;
    let scope = require_owned_script_scope(ctx, script_numeric_id).await?;
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
        SELECT sb.numeric_id, sb.prompt
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = ANY($2::int4[])
        ORDER BY sb.numeric_id
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
            "project_numeric_id": project_numeric_id,
            "script_id": script_numeric_id,
            "storyboard_numeric_id": row.numeric_id,
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

    let total = enqueued.len();
    Ok(json!({ "enqueued": enqueued, "total": total }))
}
