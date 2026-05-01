//! `PATCH /api/v1/projects/{project_id}/style-config` — 更新项目风格配置（需求 9.6）

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::super::types::{PatchStyleConfigBody, ProjectRow};

/// `PATCH /api/v1/projects/{project_id}/style-config`
///
/// 更新项目的画风技能包（`art_style_pack`）和故事风格技能包（`story_style_pack`）配置。
/// 至少需要提供一个字段；传 `null` 可清除已有配置。
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

    // 先读取当前记录（确认存在且属于当前用户）
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

    // 合并：body 中提供的字段覆盖当前值，未提供的字段保持不变
    let new_art_style_pack = if body.art_style_pack.is_some() {
        body.art_style_pack
    } else {
        current.art_style_pack
    };
    let new_story_style_pack = if body.story_style_pack.is_some() {
        body.story_style_pack
    } else {
        current.story_style_pack
    };

    let row = sqlx::query_as::<_, ProjectRow>(
        r#"
        UPDATE app_project
        SET art_style_pack = $1, story_style_pack = $2, updated_at = NOW()
        WHERE id = $3 AND owner_user_id = $4
        RETURNING id, numeric_id, name, intro, project_type,
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
