//! GET/PUT per-project novel crawl authentication configuration.

use axum::{
    extract::{Json, Path, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_write_scope;
use crate::state::AppState;

use super::super::crawl_auth::{get_crawl_auth_config, put_crawl_auth_config, validate_auth_mode};
use super::super::dto::{NovelCrawlAuthGetResponse, NovelCrawlAuthPutBody};

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/novels/crawl-auth",
    operation_id = "getProjectNovelCrawlAuthByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = NovelCrawlAuthGetResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_novel_crawl_auth(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
) -> Result<JsonResponse<NovelCrawlAuthGetResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_project_write_scope(&state, uid, project_id).await?;
    let pool = state.require_pool()?;
    let payload = get_crawl_auth_config(pool, project_id).await?;
    Ok(JsonResponse(payload))
}

#[utoipa::path(
    put,
    path = "/api/v1/projects/{project_id}/novels/crawl-auth",
    operation_id = "putProjectNovelCrawlAuthByProjectIdV1",
    tag = "novels",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = NovelCrawlAuthPutBody,
    responses(
        (status = 200, description = "OK", body = NovelCrawlAuthGetResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 501, description = "Not implemented", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn put_novel_crawl_auth(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(project_id): Path<Uuid>,
    Json(body): Json<NovelCrawlAuthPutBody>,
) -> Result<JsonResponse<NovelCrawlAuthGetResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    require_project_write_scope(&state, uid, project_id).await?;
    validate_auth_mode(&body.auth_mode)?;
    let pool = state.require_pool()?;
    let payload = put_crawl_auth_config(pool, project_id, body).await?;
    Ok(JsonResponse(payload))
}
