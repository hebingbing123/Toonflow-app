use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::Serialize;
use sqlx::{FromRow, PgPool};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::error::ApiError;
use crate::internal_ops::{
    expected_internal_ops_token, request_internal_ops_token, INTERNAL_OPS_TOKEN_ENV,
};
use crate::state::AppState;

#[derive(Debug, Clone, Serialize, ToSchema, FromRow)]
pub struct WorkspaceStatsResponse {
    pub workspace_id: Uuid,
    pub workspace_member_count: i64,
    pub workspace_project_count: i64,
    pub workspace_active_job_count: i64,
}

pub(crate) fn router() -> Router<AppState> {
    Router::new().route(
        "/api/v1/workspaces/{workspace_id}/stats",
        get(get_workspace_stats),
    )
}

fn internal_ops_token_expected() -> Option<String> {
    expected_internal_ops_token()
}

fn require_internal_ops_token(headers: &HeaderMap) -> Result<(), ApiError> {
    let Some(expected) = internal_ops_token_expected() else {
        return Err(ApiError::Forbidden(format!(
            "workspace stats HTTP disabled (set {})",
            INTERNAL_OPS_TOKEN_ENV
        )));
    };
    let got = request_internal_ops_token(headers).unwrap_or_default();
    if got != expected.as_str() {
        return Err(ApiError::Unauthorized);
    }
    Ok(())
}

async fn fetch_workspace_stats(
    pool: &PgPool,
    workspace_id: Uuid,
) -> Result<WorkspaceStatsResponse, ApiError> {
    sqlx::query_as(
        r#"
        SELECT
          w.id AS workspace_id,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_workspace_member m
            WHERE m.workspace_id = w.id
          ) AS workspace_member_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_project p
            WHERE p.workspace_id = w.id
              AND p.archived_at IS NULL
          ) AS workspace_project_count,
          (
            SELECT COUNT(*)::bigint
            FROM public.app_generation_job j
            WHERE j.status IN ('queued', 'running')
              AND EXISTS (
                SELECT 1
                FROM public.app_project p
                WHERE p.workspace_id = w.id
                  AND p.archived_at IS NULL
                  AND (
                    (j.payload->>'project_uuid') = p.id::text
                    OR (
                      (j.payload->>'project_uuid') IS NULL
                      AND (j.payload->>'project_numeric_id') ~ '^[0-9]+$'
                      AND p.numeric_id = (j.payload->>'project_numeric_id')::int
                    )
                  )
              )
          ) AS workspace_active_job_count
        FROM public.app_workspace w
        WHERE w.id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

#[utoipa::path(
    get,
    path = "/api/v1/workspaces/{workspace_id}/stats",
    operation_id = "getWorkspaceStatsV1",
    tag = "workspaces",
    params(
        ("workspace_id" = Uuid, Path, description = "Workspace UUID")
    ),
    responses(
        (status = 200, description = "OK", body = WorkspaceStatsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    )
)]
pub(crate) async fn get_workspace_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(workspace_id): Path<Uuid>,
) -> Result<Json<WorkspaceStatsResponse>, ApiError> {
    require_internal_ops_token(&headers)?;
    let pool = state.require_pool()?;
    let stats = fetch_workspace_stats(pool, workspace_id).await?;
    Ok(Json(stats))
}

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(get_workspace_stats),
    components(schemas(WorkspaceStatsResponse, crate::error::ErrorBody)),
    tags((name = "workspaces", description = "Workspace lifecycle (personal + enterprise)"))
)]
pub struct WorkspaceOpsStatsOpenApi;
