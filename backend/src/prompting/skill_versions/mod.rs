// Feature: ai-drama-quality-optimization
//! 技能文件版本管理模块（需求 24.1, 24.2, 24.3, 24.4）
//!
//! 提供：
//! - `GET /api/v1/skill-versions?path=` — 查询某文件的版本历史
//! - `POST /api/v1/skill-versions/rollback` — 回滚到指定版本
//! - `record_skill_version` — 写入技能文件后自动记录版本（供 skills 模块调用）

pub mod models;
pub mod persist;
pub mod rollback;

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    routing::{get, post},
    Json, Router,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use models::{ListSkillVersionsQuery, RollbackRequest, RollbackResponse, SkillVersion};
use persist::list_skill_versions;
use rollback::{rollback_skill_version, RollbackError};

pub use persist::record_skill_version;
pub use persist::sha256_hex;

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/skill-versions", get(get_skill_versions))
        .route(
            "/api/v1/skill-versions/rollback",
            post(post_skill_version_rollback),
        )
}

/// `GET /api/v1/skill-versions?path=&limit=&offset=`
///
/// 查询某技能文件的版本历史（按 changed_at DESC）（需求 24.3）
#[utoipa::path(
    get,
    path = "/api/v1/skill-versions",
    operation_id = "listSkillVersionsV1",
    tag = "skills",
    params(
        ("path" = String, Query, description = "Relative file path under data/skills/"),
        ("limit" = Option<i64>, Query, description = "Max results (1-100, default 20)"),
        ("offset" = Option<i64>, Query, description = "Pagination offset"),
    ),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
async fn get_skill_versions(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(params): Query<ListSkillVersionsQuery>,
) -> Result<Json<Vec<SkillVersion>>, ApiError> {
    let _ = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if params.path.trim().is_empty() {
        return Err(ApiError::BadRequest("path must not be empty".into()));
    }

    let versions = list_skill_versions(pool, &params.path, params.limit, params.offset)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(versions))
}

/// `POST /api/v1/skill-versions/rollback`
///
/// 将技能文件回滚到指定版本（需求 24.4）
#[utoipa::path(
    post,
    path = "/api/v1/skill-versions/rollback",
    operation_id = "rollbackSkillVersionV1",
    tag = "skills",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Version not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
async fn post_skill_version_rollback(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<RollbackRequest>,
) -> Result<Json<RollbackResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if body.file_path.trim().is_empty() {
        return Err(ApiError::BadRequest("filePath must not be empty".into()));
    }

    rollback_skill_version(pool, &body, Some(uid))
        .await
        .map(Json)
        .map_err(|e| match e {
            RollbackError::VersionNotFound(_) => ApiError::NotFound,
            RollbackError::AlreadyAtTargetVersion => {
                ApiError::BadRequest("当前文件内容已与目标版本一致，无需回滚".into())
            }
            RollbackError::FilePathMismatch { .. } => ApiError::BadRequest(e.to_string()),
            RollbackError::NoContentSnapshot(_) => ApiError::BadRequest(e.to_string()),
            RollbackError::FileWrite(msg) => ApiError::BadRequest(msg),
            RollbackError::Database(e) => ApiError::DatabaseError(e.to_string()),
        })
}
