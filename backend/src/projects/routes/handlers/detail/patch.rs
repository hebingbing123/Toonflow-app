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
use crate::projects::routes::audit::{
    append_project_audit, project_field_change_details, AppendProjectAudit,
};
use crate::state::AppState;
use serde_json::Value;

use super::super::super::common::{merge_text_patch, require_project_write_scope, trim_opt};
use super::super::super::types::{BrandBible, PatchProjectBody, ProjectBrief, ProjectRow};
use super::super::super::validation::{
    validate_duration_strategy, validate_mode, validate_quality_gate_strategy,
    validate_target_market, validate_target_platforms,
};

#[derive(sqlx::FromRow)]
struct ProjectPatchRow {
    id: Uuid,
    #[allow(dead_code)]
    workspace_id: Option<Uuid>,
    #[allow(dead_code)]
    numeric_id: i32,
    name: Option<String>,
    intro: Option<String>,
    project_type: Option<String>,
    image_model: Option<String>,
    image_quality: Option<String>,
    video_model: Option<String>,
    art_style: Option<String>,
    director_manual: Option<String>,
    mode: Option<String>,
    video_ratio: Option<String>,
    #[allow(dead_code)]
    create_time_ms: Option<i64>,
    art_style_pack: Option<String>,
    story_style_pack: Option<String>,
    target_market: Option<String>,
    target_platforms: Option<Vec<String>>,
    duration_strategy: Option<String>,
    voice_profile: Option<String>,
    subtitle_style: Option<String>,
    bgm_strategy: Option<String>,
    quality_gate_strategy: Option<String>,
    project_brief: Option<Value>,
    brand_bible: Option<Value>,
}

fn trim_text_patch(patch: FieldPatch<String>) -> FieldPatch<String> {
    match patch {
        FieldPatch::Absent => FieldPatch::Absent,
        FieldPatch::Set(v) => FieldPatch::Set(trim_opt(v)),
    }
}

fn parse_json_object_patch<T: serde::de::DeserializeOwned>(
    value: Option<Value>,
    field: &str,
) -> Result<FieldPatch<Value>, ApiError> {
    match value {
        None => Ok(FieldPatch::Absent),
        Some(Value::Null) => Ok(FieldPatch::Set(None)),
        Some(raw @ Value::Object(_)) => {
            serde_json::from_value::<T>(raw.clone()).map_err(|e| {
                ApiError::BadRequest(format!("{field} must be a valid object: {e}"))
            })?;
            Ok(FieldPatch::Set(Some(raw)))
        }
        Some(_) => Err(ApiError::BadRequest(format!(
            "{field} must be an object or null"
        ))),
    }
}

#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}",
    operation_id = "patchProjectByIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = PatchProjectBody,
    responses(
        (status = 200, description = "OK", body = ProjectRow),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_project_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<PatchProjectBody>,
) -> Result<Json<ProjectRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_write_scope(&state, uid, project_id).await?;

    let name_patch = trim_text_patch(parse_optional_text_field(body.name, "name")?);
    let intro_patch = trim_text_patch(parse_optional_text_field(body.intro, "intro")?);
    let project_type_patch = trim_text_patch(parse_optional_text_field(
        body.project_type,
        "project_type",
    )?);
    let image_model_patch =
        trim_text_patch(parse_optional_text_field(body.image_model, "image_model")?);
    let image_quality_patch = trim_text_patch(parse_optional_text_field(
        body.image_quality,
        "image_quality",
    )?);
    let video_model_patch =
        trim_text_patch(parse_optional_text_field(body.video_model, "video_model")?);
    let art_style_patch = trim_text_patch(parse_optional_text_field(body.art_style, "art_style")?);
    let director_manual_patch = trim_text_patch(parse_optional_text_field(
        body.director_manual,
        "director_manual",
    )?);
    let mode_patch = trim_text_patch(parse_optional_text_field(body.mode, "mode")?);
    let video_ratio_patch =
        trim_text_patch(parse_optional_text_field(body.video_ratio, "video_ratio")?);

    let art_style_pack_patch = trim_text_patch(parse_optional_text_field(
        body.art_style_pack,
        "art_style_pack",
    )?);
    let story_style_pack_patch = trim_text_patch(parse_optional_text_field(
        body.story_style_pack,
        "story_style_pack",
    )?);

    let target_market_patch = trim_text_patch(parse_optional_text_field(
        body.target_market,
        "target_market",
    )?);
    let duration_strategy_patch = trim_text_patch(parse_optional_text_field(
        body.duration_strategy,
        "duration_strategy",
    )?);
    let voice_profile_patch = trim_text_patch(parse_optional_text_field(
        body.voice_profile,
        "voice_profile",
    )?);
    let subtitle_style_patch = trim_text_patch(parse_optional_text_field(
        body.subtitle_style,
        "subtitle_style",
    )?);
    let bgm_strategy_patch = trim_text_patch(parse_optional_text_field(
        body.bgm_strategy,
        "bgm_strategy",
    )?);
    let quality_gate_strategy_patch = trim_text_patch(parse_optional_text_field(
        body.quality_gate_strategy,
        "quality_gate_strategy",
    )?);
    let project_brief_patch =
        parse_json_object_patch::<ProjectBrief>(body.project_brief, "projectBrief")?;
    let brand_bible_patch = parse_json_object_patch::<BrandBible>(body.brand_bible, "brandBible")?;

    // Parse target_platforms array field
    let target_platforms_patch = match body.target_platforms {
        None => FieldPatch::Absent,
        Some(serde_json::Value::Null) => FieldPatch::Set(None),
        Some(serde_json::Value::Array(arr)) => {
            let platforms: Result<Vec<String>, _> = arr
                .into_iter()
                .map(|v| {
                    v.as_str().map(|s| s.to_string()).ok_or_else(|| {
                        crate::error::bad_request_i18n(
                            "target_platforms must be array of strings",
                            "target_platforms 必须是字符串数组",
                        )
                    })
                })
                .collect();
            let platforms = platforms?
                .into_iter()
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect::<Vec<_>>();

            validate_target_platforms(&platforms)?;

            FieldPatch::Set(Some(platforms))
        }
        Some(_) => {
            return Err(ApiError::BadRequest(
                "target_platforms must be array or null".into(),
            ))
        }
    };

    // Validate enum fields if they are being set
    if let FieldPatch::Set(Some(ref mode_val)) = mode_patch {
        validate_mode(mode_val)?;
    }
    if let FieldPatch::Set(Some(ref market_val)) = target_market_patch {
        validate_target_market(market_val)?;
    }
    if let FieldPatch::Set(Some(ref strategy_val)) = duration_strategy_patch {
        validate_duration_strategy(strategy_val)?;
    }
    if let FieldPatch::Set(Some(ref gate_strategy_val)) = quality_gate_strategy_patch {
        validate_quality_gate_strategy(gate_strategy_val)?;
    }

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
        &quality_gate_strategy_patch,
    ];
    if !patches.iter().any(|p| !matches!(**p, FieldPatch::Absent))
        && matches!(target_platforms_patch, FieldPatch::Absent)
        && matches!(project_brief_patch, FieldPatch::Absent)
        && matches!(brand_bible_patch, FieldPatch::Absent)
    {
        return Err(ApiError::BadRequest(
            "expected at least one patchable field (name, intro, project_type, image_model, image_quality, video_model, art_style, director_manual, mode, video_ratio, art_style_pack, story_style_pack, target_market, target_platforms, duration_strategy, voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy, projectBrief, brandBible)".into(),
        ));
    }

    let current = sqlx::query_as::<_, ProjectPatchRow>(
        r#"
        SELECT id, workspace_id, numeric_id, name, intro, project_type,
               image_model, image_quality, video_model, art_style,
               director_manual, mode, video_ratio, create_time_ms,
               art_style_pack, story_style_pack,
               target_market, target_platforms, duration_strategy,
               voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy,
               project_brief, brand_bible
        FROM app_project p
        WHERE p.id = $1
        "#,
    )
    .bind(scope.id)
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
    let new_quality_gate_strategy =
        merge_text_patch(&current.quality_gate_strategy, quality_gate_strategy_patch);
    let new_project_brief = match project_brief_patch {
        FieldPatch::Absent => current.project_brief.clone(),
        FieldPatch::Set(v) => v,
    };
    let new_brand_bible = match brand_bible_patch {
        FieldPatch::Absent => current.brand_bible.clone(),
        FieldPatch::Set(v) => v,
    };

    let new_target_platforms = match target_platforms_patch {
        FieldPatch::Absent => current.target_platforms.clone(),
        FieldPatch::Set(v) => v,
    };

    let mut changed_fields = Vec::new();
    if current.name != new_name {
        changed_fields.push("name");
    }
    if current.intro != new_intro {
        changed_fields.push("intro");
    }
    if current.project_type != new_project_type {
        changed_fields.push("project_type");
    }
    if current.image_model != new_image_model {
        changed_fields.push("image_model");
    }
    if current.image_quality != new_image_quality {
        changed_fields.push("image_quality");
    }
    if current.video_model != new_video_model {
        changed_fields.push("video_model");
    }
    if current.art_style != new_art_style {
        changed_fields.push("art_style");
    }
    if current.director_manual != new_director_manual {
        changed_fields.push("director_manual");
    }
    if current.mode != new_mode {
        changed_fields.push("mode");
    }
    if current.video_ratio != new_video_ratio {
        changed_fields.push("video_ratio");
    }
    if current.art_style_pack != new_art_style_pack {
        changed_fields.push("art_style_pack");
    }
    if current.story_style_pack != new_story_style_pack {
        changed_fields.push("story_style_pack");
    }
    if current.target_market != new_target_market {
        changed_fields.push("target_market");
    }
    if current.target_platforms != new_target_platforms {
        changed_fields.push("target_platforms");
    }
    if current.duration_strategy != new_duration_strategy {
        changed_fields.push("duration_strategy");
    }
    if current.voice_profile != new_voice_profile {
        changed_fields.push("voice_profile");
    }
    if current.subtitle_style != new_subtitle_style {
        changed_fields.push("subtitle_style");
    }
    if current.bgm_strategy != new_bgm_strategy {
        changed_fields.push("bgm_strategy");
    }
    if current.quality_gate_strategy != new_quality_gate_strategy {
        changed_fields.push("quality_gate_strategy");
    }
    if current.project_brief != new_project_brief {
        changed_fields.push("project_brief");
    }
    if current.brand_bible != new_brand_bible {
        changed_fields.push("brand_bible");
    }

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET name = $1, intro = $2, project_type = $3,
            image_model = $4, image_quality = $5, video_model = $6,
            art_style = $7, director_manual = $8, mode = $9, video_ratio = $10,
            art_style_pack = $11, story_style_pack = $12,
            target_market = $13, target_platforms = $14, duration_strategy = $15,
            voice_profile = $16, subtitle_style = $17, bgm_strategy = $18,
            quality_gate_strategy = $19, project_brief = $20, brand_bible = $21,
            updated_at = NOW()
        WHERE id = $22
        RETURNING id, workspace_id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms,
                  art_style_pack, story_style_pack,
                  target_market, target_platforms, duration_strategy,
                  voice_profile, subtitle_style, bgm_strategy, quality_gate_strategy,
                  $23 AS project_access_mode,
                  $24 AS project_access_role
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
    .bind(&new_quality_gate_strategy)
    .bind(&new_project_brief)
    .bind(&new_brand_bible)
    .bind(current.id)
    .bind(scope.access_mode_label())
    .bind(scope.access_role_label())
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    append_project_audit(
        pool,
        AppendProjectAudit {
            project_id: scope.id,
            workspace_id: scope.workspace_id,
            project_numeric_id: Some(current.numeric_id),
            actor_user_id: uid,
            action: "project_updated",
            target_user_id: None,
            details: project_field_change_details(
                &changed_fields,
                current.name.as_deref(),
                row.name.as_deref(),
            ),
        },
    )
    .await?;

    Ok(Json(row))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::http_kit::json_patch::FieldPatch;
    use serde_json::json;

    #[test]
    fn parse_json_object_patch_accepts_null_and_object() {
        assert!(matches!(
            parse_json_object_patch::<ProjectBrief>(Some(Value::Null), "projectBrief").unwrap(),
            FieldPatch::Set(None)
        ));

        let patch = parse_json_object_patch::<ProjectBrief>(
            Some(json!({"premise":"复仇"})),
            "projectBrief",
        )
        .unwrap();
        assert!(matches!(patch, FieldPatch::Set(Some(Value::Object(_)))));
    }

    #[test]
    fn parse_json_object_patch_rejects_non_object() {
        let err =
            parse_json_object_patch::<BrandBible>(Some(json!("bad")), "brandBible").unwrap_err();
        match err {
            ApiError::BadRequest(message) => {
                assert!(message.contains("brandBible must be an object or null"));
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }
}
