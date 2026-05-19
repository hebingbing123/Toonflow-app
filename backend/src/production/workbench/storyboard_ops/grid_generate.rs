use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};

use super::common::normalize_storyboard_ids;
use super::types::{BatchGenerateImageResponse, GridGenerateAndAssignBody};
use crate::error::{bad_request_i18n, ApiError};
use crate::jobs::{enqueue_generation_job, JOB_KIND_ASSET_GENERATE_BATCH};
use crate::scope::http::require_script_write_scope_ref;
use crate::state::AppState;

const MAX_GRID_CELLS: u32 = 12;

#[utoipa::path(
    post,
    path = "/api/v1/production/storyboard/grid-generate-and-assign",
    operation_id = "postProductionStoryboardGridGenerateAndAssignV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_storyboard_grid_generate_and_assign(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GridGenerateAndAssignBody>,
) -> Result<JsonResponse<BatchGenerateImageResponse>, ApiError> {
    if body.rows == 0 || body.cols == 0 {
        return Err(bad_request_i18n(
            "rows and cols must be positive",
            "rows 与 cols 必须为正整数",
        ));
    }
    let cells = body
        .rows
        .checked_mul(body.cols)
        .ok_or_else(|| bad_request_i18n("rows * cols overflow", "rows * cols 溢出"))?;
    if cells > MAX_GRID_CELLS {
        return Err(bad_request_i18n(
            &format!("grid cannot exceed {MAX_GRID_CELLS} cells"),
            &format!("宫格不能超过 {MAX_GRID_CELLS} 格"),
        ));
    }

    let (uid, pool, scope_row) = require_script_write_scope_ref(
        &state,
        &headers,
        body.project_id,
        body.project_uuid,
        body.script_id,
    )
    .await?;

    let storyboard_ids = if body.storyboard_ids.is_empty() {
        list_script_storyboard_numeric_ids(pool, scope_row.script_id).await?
    } else {
        normalize_storyboard_ids(&body.storyboard_ids)?
    };

    if storyboard_ids.len() != cells as usize {
        return Err(bad_request_i18n(
            &format!(
                "storyboardIds length ({}) must equal rows * cols ({cells})",
                storyboard_ids.len()
            ),
            &format!(
                "storyboardIds 数量（{}）必须等于 rows * cols（{cells}）",
                storyboard_ids.len()
            ),
        ));
    }

    super::common::ensure_owned_storyboards(pool, scope_row.script_id, &storyboard_ids).await?;

    let default_model = body.model.as_deref().unwrap_or("dall-e-3");
    let default_resolution = body.resolution.as_deref().unwrap_or("1024x1024");
    let mut payload = serde_json::json!({
        "source": "production.storyboard.grid-generate-and-assign",
        "project_numeric_id": scope_row.project_numeric_id,
        "script_id": body.script_id,
        "rows": body.rows,
        "cols": body.cols,
        "storyboard_numeric_ids": storyboard_ids,
        "model": default_model,
        "resolution": default_resolution,
    });
    if let Some(project_uuid) = body.project_uuid {
        payload["project_uuid"] = serde_json::json!(project_uuid);
    }
    if let Some(base_prompt) = body
        .base_prompt
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        payload["base_prompt"] = serde_json::json!(base_prompt);
    }

    let row = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_ASSET_GENERATE_BATCH,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;

    Ok(JsonResponse(BatchGenerateImageResponse {
        enqueued: vec![row],
        total: 1,
    }))
}

async fn list_script_storyboard_numeric_ids(
    pool: &sqlx::PgPool,
    script_id: uuid::Uuid,
) -> Result<Vec<i32>, ApiError> {
    let ids = sqlx::query_scalar::<_, i32>(
        r#"
        SELECT sb.numeric_id
        FROM app_storyboard sb
        WHERE sb.script_id = $1
        ORDER BY sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
        "#,
    )
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if ids.is_empty() {
        return Err(bad_request_i18n(
            "script has no storyboards; add shots before grid generate",
            "剧本下暂无分镜，请先添加镜头再生成宫格",
        ));
    }
    Ok(ids)
}

#[cfg(test)]
mod tests {
    use super::MAX_GRID_CELLS;

    #[test]
    fn max_grid_cells_is_twelve() {
        assert_eq!(MAX_GRID_CELLS, 12);
    }
}
