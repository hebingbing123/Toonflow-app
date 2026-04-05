use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
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
    pub image_model: Option<String>,
    pub image_quality: Option<String>,
    pub video_model: Option<String>,
    pub art_style: Option<String>,
    pub director_manual: Option<String>,
    pub mode: Option<String>,
    pub video_ratio: Option<String>,
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

/// Per-project counts for dashboards; aligns with legacy **`generalStatistics`** shape.
/// **`role_count`** counts **`app_asset`** rows with **`asset_type = 'role'`**; **`novel_count`** counts **`app_novel`** rows; **`video_count`** remains **`0`** until video rows exist in Postgres.
#[derive(Serialize)]
struct ProjectStatsResponse {
    script_count: i64,
    storyboard_count: i64,
    role_count: i64,
    novel_count: i64,
    video_count: i64,
}

/// Aggregate counts for **`owner_user_id = JWT sub`** across all owned projects (single query).
#[derive(Serialize)]
struct ProjectsSummaryResponse {
    project_count: i64,
    script_count: i64,
    storyboard_count: i64,
    novel_count: i64,
    art_style_count: i64,
    asset_count: i64,
}

#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct PatchProjectBody {
    #[serde(default)]
    name: Option<Value>,
    #[serde(default)]
    intro: Option<Value>,
    #[serde(default)]
    project_type: Option<Value>,
    #[serde(default)]
    image_model: Option<Value>,
    #[serde(default)]
    image_quality: Option<Value>,
    #[serde(default)]
    video_model: Option<Value>,
    #[serde(default)]
    art_style: Option<Value>,
    #[serde(default)]
    director_manual: Option<Value>,
    #[serde(default)]
    mode: Option<Value>,
    #[serde(default)]
    video_ratio: Option<Value>,
}

/// JSON body for `POST /api/v1/projects` (snake_case; all fields optional).
#[derive(Debug, Deserialize, Default)]
#[serde(deny_unknown_fields)]
struct CreateProjectBody {
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    intro: Option<String>,
    #[serde(default)]
    project_type: Option<String>,
    #[serde(default)]
    image_model: Option<String>,
    #[serde(default)]
    image_quality: Option<String>,
    #[serde(default)]
    video_model: Option<String>,
    #[serde(default)]
    art_style: Option<String>,
    #[serde(default)]
    director_manual: Option<String>,
    #[serde(default)]
    mode: Option<String>,
    #[serde(default)]
    video_ratio: Option<String>,
}

/// Stable key for `pg_advisory_xact_lock` when allocating `app_project.legacy_id` (global uniqueness).
const ADV_LOCK_PROJECT_LEGACY_ID: i64 = 884_422_001;

fn trim_opt(s: Option<String>) -> Option<String> {
    s.and_then(|v| {
        let t = v.trim();
        if t.is_empty() {
            None
        } else {
            Some(t.to_owned())
        }
    })
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route("/api/v1/projects/summary", get(projects_summary))
        .route("/api/v1/projects", get(list_projects).post(create_project))
        .route(
            "/api/v1/projects/legacy/{legacy_id}/stats",
            get(project_stats_by_legacy),
        )
        .route(
            "/api/v1/projects/legacy/{legacy_id}",
            get(get_project_by_legacy)
                .patch(patch_project_by_legacy)
                .delete(delete_project_by_legacy),
        )
}

async fn create_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateProjectBody>,
) -> Result<(StatusCode, Json<ProjectRow>), ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

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

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        INSERT INTO app_project (
          owner_user_id, legacy_id, name, intro, project_type,
          image_model, image_quality, video_model, art_style,
          director_manual, mode, video_ratio, create_time_ms, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, '{}'::jsonb)
        RETURNING id, legacy_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms
        "#,
    )
    .bind(uid)
    .bind(next_legacy)
    .bind(trim_opt(body.name))
    .bind(trim_opt(body.intro))
    .bind(trim_opt(body.project_type))
    .bind(trim_opt(body.image_model))
    .bind(trim_opt(body.image_quality))
    .bind(trim_opt(body.video_model))
    .bind(trim_opt(body.art_style))
    .bind(trim_opt(body.director_manual))
    .bind(trim_opt(body.mode))
    .bind(trim_opt(body.video_ratio))
    .bind(now_ms)
    .fetch_one(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok((StatusCode::CREATED, Json(row)))
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
    Ok(Json(rows))
}

async fn projects_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ProjectsSummaryResponse>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let row: (i64, i64, i64, i64, i64, i64) = sqlx::query_as(
        r#"
        SELECT
            (SELECT COUNT(*)::bigint FROM app_project WHERE owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_script s
             INNER JOIN app_project p ON s.project_id = p.id
             WHERE p.owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_storyboard sb
             INNER JOIN app_script s ON sb.script_id = s.id
             INNER JOIN app_project p ON s.project_id = p.id
             WHERE p.owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_novel n
             INNER JOIN app_project p ON p.id = n.project_id
             WHERE p.owner_user_id = $1),
            (SELECT COUNT(*)::bigint FROM app_art_style WHERE owner_user_id = $1),
            (SELECT COUNT(*)::bigint
             FROM app_asset a
             INNER JOIN app_project p ON p.id = a.project_id
             WHERE p.owner_user_id = $1)
        "#,
    )
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectsSummaryResponse {
        project_count: row.0,
        script_count: row.1,
        storyboard_count: row.2,
        novel_count: row.3,
        art_style_count: row.4,
        asset_count: row.5,
    }))
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
        SELECT id, legacy_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms
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

async fn project_stats_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<Json<ProjectStatsResponse>, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

    let project_id: Uuid = sqlx::query_scalar(
        r#"
        SELECT id
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

    let script_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_script
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script s ON sb.script_id = s.id
        WHERE s.project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let role_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset
        WHERE project_id = $1 AND asset_type = 'role'
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let novel_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_novel
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(ProjectStatsResponse {
        script_count,
        storyboard_count,
        role_count,
        novel_count,
        video_count: 0,
    }))
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
    let project_type_patch = parse_optional_text_field(body.project_type, "project_type")?;
    let image_model_patch = parse_optional_text_field(body.image_model, "image_model")?;
    let image_quality_patch = parse_optional_text_field(body.image_quality, "image_quality")?;
    let video_model_patch = parse_optional_text_field(body.video_model, "video_model")?;
    let art_style_patch = parse_optional_text_field(body.art_style, "art_style")?;
    let director_manual_patch = parse_optional_text_field(body.director_manual, "director_manual")?;
    let mode_patch = parse_optional_text_field(body.mode, "mode")?;
    let video_ratio_patch = parse_optional_text_field(body.video_ratio, "video_ratio")?;

    let patches = [
        &name_patch,
        &intro_patch,
        &project_type_patch,
        &image_model_patch,
        &image_quality_patch,
        &video_model_patch,
        &art_style_patch,
        &director_manual_patch,
        &mode_patch,
        &video_ratio_patch,
    ];
    if !patches.iter().any(|p| !matches!(**p, FieldPatch::Absent)) {
        return Err(ApiError::BadRequest(
            "expected at least one patchable field (name, intro, project_type, image_model, image_quality, video_model, art_style, director_manual, mode, video_ratio)".into(),
        ));
    }

    let current = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, legacy_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms
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

    let new_name = merge_text_patch(&current.name, name_patch);
    let new_intro = merge_text_patch(&current.intro, intro_patch);
    let new_project_type = merge_text_patch(&current.project_type, project_type_patch);
    let new_image_model = merge_text_patch(&current.image_model, image_model_patch);
    let new_image_quality = merge_text_patch(&current.image_quality, image_quality_patch);
    let new_video_model = merge_text_patch(&current.video_model, video_model_patch);
    let new_art_style = merge_text_patch(&current.art_style, art_style_patch);
    let new_director_manual = merge_text_patch(&current.director_manual, director_manual_patch);
    let new_mode = merge_text_patch(&current.mode, mode_patch);
    let new_video_ratio = merge_text_patch(&current.video_ratio, video_ratio_patch);

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET name = $1, intro = $2, project_type = $3,
            image_model = $4, image_quality = $5, video_model = $6,
            art_style = $7, director_manual = $8, mode = $9, video_ratio = $10,
            updated_at = NOW()
        WHERE id = $11 AND owner_user_id = $12
        RETURNING id, legacy_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms
        "#,
    )
    .bind(&new_name)
    .bind(&new_intro)
    .bind(&new_project_type)
    .bind(&new_image_model)
    .bind(&new_image_quality)
    .bind(&new_video_model)
    .bind(&new_art_style)
    .bind(&new_director_manual)
    .bind(&new_mode)
    .bind(&new_video_ratio)
    .bind(current.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}

async fn delete_project_by_legacy(
    State(state): State<AppState>,
    Path(legacy_id): Path<i32>,
    headers: HeaderMap,
) -> Result<StatusCode, ApiError> {
    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;
    let uid = require_user_uuid(&state, &headers)?;

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
    .bind(legacy_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let res = sqlx::query(
        r#"
        DELETE FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(legacy_id)
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

    Ok(StatusCode::NO_CONTENT)
}

fn merge_text_patch(current: &Option<String>, patch: FieldPatch<String>) -> Option<String> {
    match patch {
        FieldPatch::Absent => current.clone(),
        FieldPatch::Set(v) => v,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn patch_project_body_rejects_unknown_fields() {
        let err =
            serde_json::from_str::<PatchProjectBody>(r#"{"name":"a","extra":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }

    #[test]
    fn create_project_body_accepts_empty_object() {
        let b: CreateProjectBody = serde_json::from_str("{}").unwrap();
        assert!(b.name.is_none());
    }

    #[test]
    fn create_project_body_rejects_unknown_fields() {
        let err = serde_json::from_str::<CreateProjectBody>(r#"{"name":"a","x":1}"#).unwrap_err();
        assert!(
            err.to_string().contains("unknown field")
                || err.to_string().contains("unknown variant"),
            "{err}"
        );
    }
}
