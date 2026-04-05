//! Legacy **`POST /api/project/getProject`** and **`delProject`** under **`/api/v1/project/*`**.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::ProjectRow;
use crate::state::AppState;

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct LegacyEmptyBody {}

#[derive(Debug, Serialize)]
struct GetProjectListResponse {
    data: Vec<ProjectRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct DeleteProjectBody {
    /// SQLite **`o_project.id`**; maps to **`app_project.legacy_id`** in SaaS.
    id: i32,
}

#[derive(Debug, Serialize)]
struct DeleteProjectResponse {
    message: &'static str,
}

async fn post_get_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(_body): Json<LegacyEmptyBody>,
) -> Result<JsonResponse<GetProjectListResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let rows = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, legacy_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms
        FROM app_project
        WHERE owner_user_id = $1
        ORDER BY create_time_ms DESC NULLS LAST, legacy_id DESC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(GetProjectListResponse { data: rows }))
}

async fn post_delete_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteProjectBody>,
) -> Result<JsonResponse<DeleteProjectResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND legacy_project_id = $2
        "#,
    )
    .bind(uid)
    .bind(body.id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(body.id)
    .bind(uid)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        tx.rollback()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Err(ApiError::NotFound);
    }

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(DeleteProjectResponse {
        message: "删除项目成功",
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/project/get-project", post(post_get_project))
        .route("/api/v1/project/delete-project", post(post_delete_project))
}
