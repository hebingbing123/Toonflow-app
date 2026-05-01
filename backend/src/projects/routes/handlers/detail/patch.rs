//! 项目字段 PATCH。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::http_kit::json_patch::{parse_optional_text_field, FieldPatch};
use crate::state::AppState;

use super::super::super::common::merge_text_patch;
use super::super::super::types::{PatchProjectBody, ProjectRow};

pub(crate) async fn patch_project_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<PatchProjectBody>,
) -> Result<Json<ProjectRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

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

    let art_style_pack_patch = parse_optional_text_field(body.art_style_pack, "art_style_pack")?;
    let story_style_pack_patch =
        parse_optional_text_field(body.story_style_pack, "story_style_pack")?;

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
        &art_style_pack_patch,
        &story_style_pack_patch,
    ];
    if !patches.iter().any(|p| !matches!(**p, FieldPatch::Absent)) {
        return Err(ApiError::BadRequest(
            "expected at least one patchable field (name, intro, project_type, image_model, image_quality, video_model, art_style, director_manual, mode, video_ratio, art_style_pack, story_style_pack)".into(),
        ));
    }

    let current = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
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
    let new_art_style_pack = merge_text_patch(&current.art_style_pack, art_style_pack_patch);
    let new_story_style_pack = merge_text_patch(&current.story_style_pack, story_style_pack_patch);

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET name = $1, intro = $2, project_type = $3,
            image_model = $4, image_quality = $5, video_model = $6,
            art_style = $7, director_manual = $8, mode = $9, video_ratio = $10,
            art_style_pack = $11, story_style_pack = $12,
            updated_at = NOW()
        WHERE id = $13 AND owner_user_id = $14
        RETURNING id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms,
                  art_style_pack, story_style_pack
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
    .bind(&new_art_style_pack)
    .bind(&new_story_style_pack)
    .bind(current.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}
