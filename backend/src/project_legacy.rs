//! Legacy **`POST /api/project/*`** project CRUD helpers under **`/api/v1/project/*`**
//! (**`getProject`**, **`delProject`**, **`addProject`**, **`editProject`**).

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

/// Same as [`crate::projects`] advisory lock for allocating **`legacy_id`**.
const ADV_LOCK_PROJECT_LEGACY_ID: i64 = 884_422_001;

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

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyAddProjectBody {
    project_type: String,
    name: String,
    intro: String,
    /// SQLite **`o_project.type`**; merged into PG **`mode`** with **`mode`** (see **`effective_mode`**).
    #[serde(rename = "type")]
    legacy_sqlite_type: String,
    art_style: String,
    director_manual: String,
    video_ratio: String,
    image_model: String,
    video_model: String,
    image_quality: String,
    mode: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyEditProjectBody {
    /// **`app_project.legacy_id`**
    id: i32,
    name: String,
    intro: String,
    #[serde(rename = "type")]
    legacy_sqlite_type: String,
    art_style: String,
    director_manual: String,
    video_ratio: String,
    image_model: String,
    video_model: String,
    image_quality: String,
    project_type: String,
    mode: String,
}

#[derive(Debug, Serialize)]
struct ProjectMutationResponse {
    message: &'static str,
}

fn trim_store(s: &str) -> Option<String> {
    let t = s.trim();
    if t.is_empty() {
        None
    } else {
        Some(t.to_owned())
    }
}

/// SQLite kept **`type`** and **`mode`** separate; PG has a single **`mode`** column. Prefer non-empty **`mode`**, else **`type`**.
fn effective_mode(legacy_sqlite_type: &str, mode: &str) -> Option<String> {
    trim_store(mode).or_else(|| trim_store(legacy_sqlite_type))
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

async fn post_add_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyAddProjectBody>,
) -> Result<JsonResponse<ProjectMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let mode_val = effective_mode(&body.legacy_sqlite_type, &body.mode);

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query("SELECT pg_advisory_xact_lock($1)")
        .bind(ADV_LOCK_PROJECT_LEGACY_ID)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_legacy: i32 = sqlx::query_scalar(
        r#"
        SELECT COALESCE(MAX(legacy_id), 0) + 1
        FROM app_project
        "#,
    )
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let now_ms = chrono::Utc::now().timestamp_millis();

    sqlx::query(
        r#"
        INSERT INTO app_project (
          owner_user_id, legacy_id, name, intro, project_type,
          image_model, image_quality, video_model, art_style,
          director_manual, mode, video_ratio, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '{}'::jsonb)
        "#,
    )
    .bind(uid)
    .bind(next_legacy)
    .bind(trim_store(&body.name))
    .bind(trim_store(&body.intro))
    .bind(trim_store(&body.project_type))
    .bind(trim_store(&body.image_model))
    .bind(trim_store(&body.image_quality))
    .bind(trim_store(&body.video_model))
    .bind(trim_store(&body.art_style))
    .bind(trim_store(&body.director_manual))
    .bind(mode_val)
    .bind(trim_store(&body.video_ratio))
    .bind(now_ms)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(ProjectMutationResponse {
        message: "新增项目成功",
    }))
}

async fn post_edit_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyEditProjectBody>,
) -> Result<JsonResponse<ProjectMutationResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    if body.id <= 0 {
        return Err(ApiError::BadRequest("id must be positive".into()));
    }

    let mode_val = effective_mode(&body.legacy_sqlite_type, &body.mode);

    let res = sqlx::query(
        r#"
        UPDATE app_project
        SET name = $1, intro = $2, project_type = $3,
            image_model = $4, image_quality = $5, video_model = $6,
            art_style = $7, director_manual = $8, mode = $9, video_ratio = $10,
            updated_at = NOW()
        WHERE legacy_id = $11 AND owner_user_id = $12
        "#,
    )
    .bind(trim_store(&body.name))
    .bind(trim_store(&body.intro))
    .bind(trim_store(&body.project_type))
    .bind(trim_store(&body.image_model))
    .bind(trim_store(&body.image_quality))
    .bind(trim_store(&body.video_model))
    .bind(trim_store(&body.art_style))
    .bind(trim_store(&body.director_manual))
    .bind(mode_val)
    .bind(trim_store(&body.video_ratio))
    .bind(body.id)
    .bind(uid)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(JsonResponse(ProjectMutationResponse {
        message: "编辑项目成功",
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/project/get-project", post(post_get_project))
        .route("/api/v1/project/delete-project", post(post_delete_project))
        .route("/api/v1/project/add-project", post(post_add_project))
        .route("/api/v1/project/edit-project", post(post_edit_project))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn legacy_empty_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyEmptyBody>(r#"{"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn legacy_empty_body_accepts_empty() {
        let b: LegacyEmptyBody = serde_json::from_str(r#"{}"#).unwrap();
        let _ = b;
    }

    #[test]
    fn delete_project_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<DeleteProjectBody>(r#"{"id":1,"extra":1}"#);
        assert!(err.is_err());
    }

    #[test]
    fn delete_project_body_accepts_valid() {
        let b: DeleteProjectBody = serde_json::from_str(r#"{"id":1}"#).unwrap();
        assert_eq!(b.id, 1);
    }

    #[test]
    fn legacy_add_project_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyAddProjectBody>(
            r#"{"projectType":"short","name":"Test","intro":"","type":"novel","artStyle":"","directorManual":"","videoRatio":"9:16","imageModel":"","videoModel":"","imageQuality":"","mode":"","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn legacy_add_project_body_accepts_valid() {
        let b: LegacyAddProjectBody = serde_json::from_str(
            r#"{"projectType":"short","name":"Test","intro":"Intro","type":"novel","artStyle":"style1","directorManual":"manual","videoRatio":"9:16","imageModel":"dalle","videoModel":"runway","imageQuality":"hd","mode":"creative"}"#,
        )
        .unwrap();
        assert_eq!(b.project_type, "short");
        assert_eq!(b.name, "Test");
        assert_eq!(b.legacy_sqlite_type, "novel");
        assert_eq!(b.mode, "creative");
    }

    #[test]
    fn legacy_edit_project_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<LegacyEditProjectBody>(
            r#"{"id":1,"name":"Test","intro":"","type":"novel","artStyle":"","directorManual":"","videoRatio":"","imageModel":"","videoModel":"","imageQuality":"","projectType":"","mode":"","extra":1}"#,
        );
        assert!(err.is_err());
    }

    #[test]
    fn legacy_edit_project_body_accepts_valid() {
        let b: LegacyEditProjectBody = serde_json::from_str(
            r#"{"id":1,"name":"Updated","intro":"New intro","type":"short","artStyle":"newstyle","directorManual":"newmanual","videoRatio":"16:9","imageModel":"gpt4o","videoModel":"luma","imageQuality":"ultra","projectType":"series","mode":"professional"}"#,
        )
        .unwrap();
        assert_eq!(b.id, 1);
        assert_eq!(b.name, "Updated");
        assert_eq!(b.legacy_sqlite_type, "short");
        assert_eq!(b.mode, "professional");
    }

    #[test]
    fn trim_store_returns_none_for_empty() {
        assert_eq!(trim_store(""), None);
        assert_eq!(trim_store("   "), None);
        assert_eq!(trim_store("  \n\t  "), None);
    }

    #[test]
    fn trim_store_returns_trimmed_for_non_empty() {
        assert_eq!(trim_store("hello"), Some("hello".to_string()));
        assert_eq!(trim_store("  hello  "), Some("hello".to_string()));
        assert_eq!(trim_store("hello world"), Some("hello world".to_string()));
    }

    #[test]
    fn effective_mode_prefers_mode() {
        assert_eq!(
            effective_mode("novel", "creative"),
            Some("creative".to_string())
        );
        assert_eq!(effective_mode("", "creative"), Some("creative".to_string()));
    }

    #[test]
    fn effective_mode_falls_back_to_type() {
        assert_eq!(
            effective_mode("novel", ""),
            Some("novel".to_string())
        );
        assert_eq!(effective_mode("  novel  ", ""), Some("novel".to_string()));
    }

    #[test]
    fn effective_mode_returns_none_when_both_empty() {
        assert_eq!(effective_mode("", ""), None);
        assert_eq!(effective_mode("   ", "   "), None);
    }

    #[test]
    fn delete_project_response_serialize() {
        let resp = DeleteProjectResponse {
            message: "删除成功",
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("删除成功"));
    }

    #[test]
    fn project_mutation_response_serialize() {
        let resp = ProjectMutationResponse {
            message: "操作成功",
        };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("操作成功"));
    }

    #[test]
    fn get_project_list_response_serialize() {
        let resp = GetProjectListResponse { data: vec![] };
        let json = serde_json::to_string(&resp).unwrap();
        assert!(json.contains("\"data\":[]"));
    }
}
