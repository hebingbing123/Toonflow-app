//! `PATCH /api/v1/projects/{project_id}/style-config` — 更新项目风格配置（需求 9.6）

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

use super::super::super::common::{merge_text_patch, trim_opt};
use super::super::super::types::{PatchStyleConfigBody, ProjectRow};

fn trim_text_patch(patch: FieldPatch<String>) -> FieldPatch<String> {
    match patch {
        FieldPatch::Absent => FieldPatch::Absent,
        FieldPatch::Set(v) => FieldPatch::Set(trim_opt(v)),
    }
}

/// `PATCH /api/v1/projects/{project_id}/style-config`
///
/// 更新项目的画风技能包（`art_style_pack`）和故事风格技能包（`story_style_pack`）配置。
/// 至少需要提供一个字段；传 `null` 可清除已有配置。
#[utoipa::path(
    patch,
    path = "/api/v1/projects/{project_id}/style-config",
    operation_id = "patchStyleConfigV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = PatchStyleConfigBody,
    responses(
        (status = 200, description = "OK", body = ProjectRow),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn patch_style_config(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<PatchStyleConfigBody>,
) -> Result<Json<ProjectRow>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    if body.art_style_pack.is_none() && body.story_style_pack.is_none() {
        return Err(ApiError::BadRequest(
            "expected at least one field: artStylePack or storyStylePack".into(),
        ));
    }
    let has_art_style_pack = body.art_style_pack.is_some();
    let has_story_style_pack = body.story_style_pack.is_some();

    let art_style_pack_patch = trim_text_patch(parse_optional_text_field(
        body.art_style_pack,
        "art_style_pack",
    )?);

    let story_style_pack_patch = trim_text_patch(parse_optional_text_field(
        body.story_style_pack,
        "story_style_pack",
    )?);

    // 先读取当前记录（确认存在且属于当前用户）
    let current = sqlx::query_as::<_, ProjectRow>(
        r#"
        SELECT id, workspace_id, numeric_id, name, intro, project_type,
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

    // 合并：body 中提供的字段覆盖当前值，未提供的字段保持不变
    let new_art_style_pack = merge_text_patch(
        &current.art_style_pack,
        if has_art_style_pack {
            art_style_pack_patch
        } else {
            FieldPatch::Absent
        },
    );
    let new_story_style_pack = merge_text_patch(
        &current.story_style_pack,
        if has_story_style_pack {
            story_style_pack_patch
        } else {
            FieldPatch::Absent
        },
    );

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET art_style_pack = $1, story_style_pack = $2, updated_at = NOW()
        WHERE id = $3 AND owner_user_id = $4
        RETURNING id, workspace_id, numeric_id, name, intro, project_type,
                  image_model, image_quality, video_model, art_style,
                  director_manual, mode, video_ratio, create_time_ms,
                  art_style_pack, story_style_pack
        "#,
    )
    .bind(&new_art_style_pack)
    .bind(&new_story_style_pack)
    .bind(current.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(row))
}
