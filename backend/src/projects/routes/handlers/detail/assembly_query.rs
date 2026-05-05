//! Shared Postgres reads for short-video **assembly** + **export-check** (D1/D2).

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

#[derive(Debug, sqlx::FromRow)]
pub(super) struct ProjectAssemblyHeaderRow {
    pub(super) id: Uuid,
    pub(super) voice_profile: Option<String>,
    pub(super) subtitle_style: Option<String>,
    pub(super) bgm_strategy: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
pub(super) struct AssemblyFlatRow {
    pub(super) storyboard_id: Uuid,
    pub(super) storyboard_numeric_id: i32,
    pub(super) script_numeric_id: i32,
    pub(super) script_name: Option<String>,
    pub(super) sb_index: Option<i32>,
    pub(super) file_path: Option<String>,
    pub(super) duration: Option<String>,
    pub(super) state: Option<String>,
    pub(super) track_id: Option<i32>,
    pub(super) prompt: Option<String>,
    pub(super) video_desc: Option<String>,
    pub(super) voiceover_state: Option<String>,
    pub(super) voiceover_audio_url: Option<String>,
    pub(super) voiceover_error: Option<String>,
    pub(super) candidate_status: Option<String>,
}

#[must_use]
pub(super) fn assembly_selected_media_kind(url: Option<&str>) -> &'static str {
    let Some(raw) = url.map(str::trim).filter(|s| !s.is_empty()) else {
        return "none";
    };
    let path = raw
        .split('?')
        .next()
        .unwrap_or(raw)
        .split('#')
        .next()
        .unwrap_or(raw);
    let lower = path.to_ascii_lowercase();
    if lower.ends_with(".mp4")
        || lower.ends_with(".mov")
        || lower.ends_with(".webm")
        || lower.ends_with(".mkv")
    {
        return "video";
    }
    if lower.ends_with(".png")
        || lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".webp")
        || lower.ends_with(".gif")
    {
        return "image";
    }
    "other"
}

pub(super) async fn fetch_project_assembly_header(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
) -> Result<Option<ProjectAssemblyHeaderRow>, ApiError> {
    sqlx::query_as(
        r#"
        SELECT id, voice_profile, subtitle_style, bgm_strategy
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn fetch_project_assembly_flat_rows(
    pool: &PgPool,
    project_uuid: Uuid,
) -> Result<Vec<AssemblyFlatRow>, ApiError> {
    sqlx::query_as(
        r#"
        SELECT
          sb.id AS storyboard_id,
          sb.numeric_id AS storyboard_numeric_id,
          sc.numeric_id AS script_numeric_id,
          sc.name AS script_name,
          sb.sb_index,
          sb.file_path,
          sb.duration,
          sb.state,
          sb.track_id,
          sb.prompt,
          sb.video_desc,
          sb.metadata #>> '{voiceover,state}' AS voiceover_state,
          sb.metadata #>> '{voiceover,audioUrl}' AS voiceover_audio_url,
          sb.metadata #>> '{voiceover,error}' AS voiceover_error,
          sb.metadata #>> '{shortVideo,candidateStatus}' AS candidate_status
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        WHERE sc.project_id = $1
        ORDER BY sc.numeric_id ASC, sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
        "#,
    )
    .bind(project_uuid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}
