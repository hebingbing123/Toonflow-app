use serde_json::{json, Value};

use crate::harness::HarnessContext;
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};

use super::super::domain_script::require_owned_script_scope;
use super::super::{
    map_api_error, parse_ids_required, project_numeric_from_ctx, require_pool,
    script_numeric_id_from_args_or_ctx, InvokeError,
};

#[derive(sqlx::FromRow)]
struct StoryboardGenerateRow {
    #[sqlx(rename = "numeric_id")]
    numeric_id: i32,
    prompt: Option<String>,
}

pub(crate) async fn invoke_generate_derive_asset(
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
    for asset_id in &valid_ids {
        let payload = json!({
            "source": "production.assets.batch-generate",
            "project_numeric_id": project_numeric_id,
            "script_id": script_numeric_id,
            "asset_id": asset_id,
            "model": model,
            "resolution": resolution,
        });
        let row = enqueue_generation_job(
            pool,
            ctx.user_id,
            JOB_KIND_ASSET_GENERATE_BATCH,
            payload,
            None,
        )
        .await
        .map_err(|e| map_api_error(e, "failed to enqueue derived-asset generation job"))?;
        enqueued.push(row);
    }

    let total = enqueued.len();
    Ok(json!({ "enqueued": enqueued, "total": total, "assetIds": valid_ids }))
}

pub(crate) async fn invoke_generate_storyboard(
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

    let storyboard_ids: Vec<i32> = rows.iter().map(|row| row.numeric_id).collect();
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
        let item = enqueue_generation_job(
            pool,
            ctx.user_id,
            JOB_KIND_ASSET_GENERATE_BATCH,
            payload,
            None,
        )
        .await
        .map_err(|e| map_api_error(e, "failed to enqueue storyboard generation job"))?;
        enqueued.push(item);
    }

    let total = enqueued.len();
    Ok(json!({ "enqueued": enqueued, "total": total, "storyboardIds": storyboard_ids }))
}
