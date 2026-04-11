//! Legacy **`/api/general/getSingleProject`** and **`updateProject`** as versioned **`POST`**.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    routing::post,
    Json as JsonResponse, Router,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{parse_optional_text_field, FieldPatch};
use crate::projects::ProjectRow;
use crate::state::AppState;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct GetSingleProjectBody {
    id: i32,
}

#[derive(Debug, Serialize)]
struct GetSingleProjectResponse {
    data: Vec<ProjectRow>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct LegacyUpdateProjectBody {
    id: i32,
    #[serde(default, rename = "type")]
    legacy_type: Option<Value>,
    #[serde(default)]
    intro: Option<Value>,
    #[serde(default)]
    art_style: Option<Value>,
    #[serde(default)]
    video_ratio: Option<Value>,
    #[serde(default)]
    project_type: Option<Value>,
}

#[derive(Debug, Serialize)]
struct LegacyUpdateProjectResponse {
    message: &'static str,
}

fn merge_opt(current: &Option<String>, patch: FieldPatch<String>) -> Option<String> {
    match patch {
        FieldPatch::Absent => current.clone(),
        FieldPatch::Set(v) => v,
    }
}

async fn post_get_single_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GetSingleProjectBody>,
) -> Result<JsonResponse<GetSingleProjectResponse>, ApiError> {
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
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(body.id)
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(GetSingleProjectResponse { data: rows }))
}

async fn post_update_project(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<LegacyUpdateProjectBody>,
) -> Result<JsonResponse<LegacyUpdateProjectResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    let intro_patch = parse_optional_text_field(body.intro, "intro")?;
    let mode_patch = parse_optional_text_field(body.legacy_type, "type")?;
    let art_style_patch = parse_optional_text_field(body.art_style, "artStyle")?;
    let video_ratio_patch = parse_optional_text_field(body.video_ratio, "videoRatio")?;
    let project_type_patch = parse_optional_text_field(body.project_type, "projectType")?;

    let patches = [
        &intro_patch,
        &mode_patch,
        &art_style_patch,
        &video_ratio_patch,
        &project_type_patch,
    ];
    if !patches.iter().any(|p| !matches!(**p, FieldPatch::Absent)) {
        return Err(ApiError::BadRequest(
            "expected at least one of intro, type, artStyle, videoRatio, projectType".into(),
        ));
    }

    let pool = state
        .pool
        .as_ref()
        .ok_or_else(|| ApiError::DatabaseError("DATABASE_URL not configured".into()))?;

    let current = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, legacy_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms
        FROM app_project
        WHERE legacy_id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(body.id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let new_intro = merge_opt(&current.intro, intro_patch);
    let new_mode = merge_opt(&current.mode, mode_patch);
    let new_art_style = merge_opt(&current.art_style, art_style_patch);
    let new_video_ratio = merge_opt(&current.video_ratio, video_ratio_patch);
    let new_project_type = merge_opt(&current.project_type, project_type_patch);

    sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET intro = $1, mode = $2, art_style = $3, video_ratio = $4, project_type = $5,
            updated_at = NOW()
        WHERE id = $6 AND owner_user_id = $7
        RETURNING id, legacy_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms
        "#,
    )
    .bind(&new_intro)
    .bind(&new_mode)
    .bind(&new_art_style)
    .bind(&new_video_ratio)
    .bind(&new_project_type)
    .bind(current.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(JsonResponse(LegacyUpdateProjectResponse {
        message: "修改成功",
    }))
}

pub fn router() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/general/get-single-project",
            post(post_get_single_project),
        )
        .route("/api/v1/general/update-project", post(post_update_project))
}
