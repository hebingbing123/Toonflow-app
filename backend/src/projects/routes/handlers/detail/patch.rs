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

    let target_market_patch = parse_optional_text_field(body.target_market, "target_market")?;
    let duration_strategy_patch =
        parse_optional_text_field(body.duration_strategy, "duration_strategy")?;
    let voice_profile_patch = parse_optional_text_field(body.voice_profile, "voice_profile")?;
    let subtitle_style_patch = parse_optional_text_field(body.subtitle_style, "subtitle_style")?;
    let bgm_strategy_patch = parse_optional_text_field(body.bgm_strategy, "bgm_strategy")?;

    // Parse target_platforms array field
    let target_platforms_patch = match body.target_platforms {
        None => FieldPatch::Absent,
        Some(serde_json::Value::Null) => FieldPatch::Set(None),
        Some(serde_json::Value::Array(arr)) => {
            let platforms: Result<Vec<String>, _> = arr
                .into_iter()
                .map(|v| {
                    v.as_str().map(|s| s.to_string()).ok_or_else(|| {
                        ApiError::BadRequest("target_platforms must be array of strings".into())
                    })
                })
                .collect();
            FieldPatch::Set(Some(platforms?))
        }
        Some(_) => {
            return Err(ApiError::BadRequest(
                "target_platforms must be array or null".into(),
            ))
        }
    };

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
        &target_market_patch,
        &duration_strategy_patch,
        &voice_profile_patch,
        &subtitle_style_patch,
        &bgm_strategy_patch,
    ];
    if !patches.iter().any(|p| !matches!(**p, FieldPatch::Absent))
        && matches!(target_platforms_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one patchable field (name, intro, project_type, image_model, image_quality, video_model, art_style, director_manual, mode, video_ratio, art_style_pack, story_style_pack, target_market, target_platforms, duration_strategy, voice_profile, subtitle_style, bgm_strategy)".into(),
        ));
    }

    let current = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack,
               target_market, target_platforms, duration_strategy,
               voice_profile, subtitle_style, bgm_strategy
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
    let new_target_market = merge_text_patch(&current.target_market, target_market_patch);
    let new_duration_strategy =
        merge_text_patch(&current.duration_strategy, duration_strategy_patch);
    let new_voice_profile = merge_text_patch(&current.voice_profile, voice_profile_patch);
    let new_subtitle_style = merge_text_patch(&current.subtitle_style, subtitle_style_patch);
    let new_bgm_strategy = merge_text_patch(&current.bgm_strategy, bgm_strategy_patch);

    let new_target_platforms = match target_platforms_patch {
        FieldPatch::Absent => current.target_platforms.clone(),
        FieldPatch::Set(v) => v,
    };

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET name = $1, intro = $2, project_type = $3,
            image_model = $4, image_quality = $5, video_model = $6,
            art_style = $7, director_manual = $8, mode = $9, video_ratio = $10,
            art_style_pack = $11, story_style_pack = $12,
            target_market = $13, target_platforms = $14, duration_strategy = $15,
            voice_profile = $16, subtitle_style = $17, bgm_strategy = $18,
            updated_at = NOW()
        WHERE id = $19 AND owner_user_id = $20
        RETURNING id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms,
                  art_style_pack, story_style_pack,
                  target_market, target_platforms, duration_strategy,
                  voice_profile, subtitle_style, bgm_strategy
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
    .bind(&new_target_market)
    .bind(&new_target_platforms)
    .bind(&new_duration_strategy)
    .bind(&new_voice_profile)
    .bind(&new_subtitle_style)
    .bind(&new_bgm_strategy)
    .bind(current.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}
