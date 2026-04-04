use axum::{
    extract::{Path, State},
    http::HeaderMap,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::json_patch::{parse_optional_text_field, FieldPatch};
use crate::state::AppState;

#[derive(Debug, FromRow, Serialize)]
pub struct ProjectRow {
    pub id: Uuid,
    pub legacy_id: i32,
    pub name: Option<String>,
    pub intro: Option<String>,
    pub project_type: Option<String>,
    pub create_time_ms: Option<i64>,
}

#[derive(Debug, FromRow, Serialize)]
struct ScriptBrief {
    legacy_id: i32,
    name: Option<String>,
    extract_state: Option<i32>,
}

#[derive(Serialize)]
struct ProjectDetailResponse {
    project: ProjectRow,
    scripts: Vec<ScriptBrief>,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchProjectBody {
    #[serde(default)]
    name: Option<Value>,
    #[serde(default)]
    intro: Option<Value>,
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/projects", get(list_projects))
        .route(
            "/api/v1/projects/legacy/{legacy_id}",
            get(get_project_by_legacy).patch(patch_project_by_legacy),
        )
}

async fn list_projects(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<ProjectRow>>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;
    let rows = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, legacy_id, name, intro, project_type, create_time_ms
        FROM app_project
        WHERE owner_user_id = $1
        ORDER BY create_time_ms DESC NULLS LAST, legacy_id DESC
        "#,
    )
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(rows))
}

async fn get_project_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ProjectDetailResponse>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let project = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, legacy_id, name, intro, project_type, create_time_ms
        FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let scripts = sqlx::query_as::<_, ScriptBrief>(
        r#"
        SELECT legacy_id, name, extract_state
        FROM app_script
        WHERE project_id = $1
        ORDER BY legacy_id ASC
        "#,
    )
    .bind(project.id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectDetailResponse { project, scripts }))
}

async fn patch_project_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
    Json(body): Json<PatchProjectBody>,
) -> Result<Json<ProjectRow>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let name_patch = parse_optional_text_field(body.name, "name")?;
    let intro_patch = parse_optional_text_field(body.intro, "intro")?;
    if matches!(name_patch, FieldPatch::Absent) && matches!(intro_patch, FieldPatch::Absent) {
        return Err(ApiError::BadRequest(
            "expected at least one of: name, intro".into(),
        ));
    }

    let current = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, legacy_id, name, intro, project_type, create_time_ms
        FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_name = match name_patch {
        FieldPatch::Absent => current.name.clone(),
        FieldPatch::Set(v) => v,
    };
    let new_intro = match intro_patch {
        FieldPatch::Absent => current.intro.clone(),
        FieldPatch::Set(v) => v,
    };

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET name = $1, intro = $2, updated_at = NOW()
        WHERE id = $3 AND owner_user_id = $4
        RETURNING id, legacy_id, name, intro, project_type, create_time_ms
        "#,
    )
    .bind(&new_name)
    .bind(&new_intro)
    .bind(current.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}
