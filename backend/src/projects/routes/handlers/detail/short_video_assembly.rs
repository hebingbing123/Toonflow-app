//! 项目级 **成片装配** 只读聚合（D1）：当前选中媒体、字幕文案来源、旁白状态与音频 URL、项目默认声线/字幕/BGM。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use std::collections::hash_map::Entry;
use std::collections::HashMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::production::{resolve_shot_script_source, resolve_shot_voiceover_ready};
use crate::state::AppState;

use super::super::super::types::{
    ProjectShortVideoAssemblyResponse, ShortVideoAssemblyEffectiveDefaults,
    ShortVideoAssemblyProjectDefaults, ShortVideoAssemblyScriptGroup, ShortVideoAssemblyShot,
    ShortVideoCandidateQualitySummary, ShortVideoQualityStageBucket,
};
use super::assembly_query::{
    assembly_selected_media_kind, fetch_assembly_candidate_quality_summary,
    fetch_project_assembly_flat_rows, fetch_project_assembly_header,
};
use crate::short_video::defaults::resolve_tts_voice;

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/short-video-assembly",
    operation_id = "getProjectShortVideoAssemblyByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectShortVideoAssemblyResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_assembly_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectShortVideoAssemblyResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let header = fetch_project_assembly_header(pool, project_id, uid)
        .await?
        .ok_or(ApiError::NotFound)?;

    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;

    let storyboard_numeric_ids: Vec<i32> = flat.iter().map(|r| r.storyboard_numeric_id).collect();
    let (quality_scalars, quality_stage_rows) =
        fetch_assembly_candidate_quality_summary(pool, uid, header.id, &storyboard_numeric_ids)
            .await?;
    let bad_cases_by_stage: Vec<ShortVideoQualityStageBucket> = quality_stage_rows
        .into_iter()
        .map(|r| ShortVideoQualityStageBucket {
            stage: r.stage,
            bad_case_count: r.bad_case_count,
        })
        .collect();
    let candidate_quality_summary = ShortVideoCandidateQualitySummary {
        schema_version: 1,
        project_bad_case_total: quality_scalars.project_bad_case_total,
        assembly_shot_review_total: quality_scalars.assembly_shot_review_total,
        assembly_shot_bad_case_count: quality_scalars.assembly_shot_bad_case_count,
        assembly_shots_with_bad_case: quality_scalars.assembly_shots_with_bad_case,
        assembly_late_stage_bad_case_count: quality_scalars.assembly_late_stage_bad_case_count,
        bad_cases_by_stage,
    };

    let mut script_order: Vec<i32> = Vec::new();
    let mut script_meta: HashMap<i32, Option<String>> = HashMap::new();
    let mut grouped: HashMap<i32, Vec<ShortVideoAssemblyShot>> = HashMap::new();

    for r in flat {
        match script_meta.entry(r.script_numeric_id) {
            Entry::Vacant(slot) => {
                script_order.push(r.script_numeric_id);
                slot.insert(r.script_name.clone());
            }
            Entry::Occupied(mut existing) => {
                if existing.get().is_none() {
                    *existing.get_mut() = r.script_name.clone();
                }
            }
        }

        let subtitle_source =
            resolve_shot_script_source(r.video_desc.as_deref(), r.prompt.as_deref()).to_string();
        let voiceover_script_ready =
            resolve_shot_voiceover_ready(r.video_desc.as_deref(), r.prompt.as_deref());
        let voiceover_asset_ready = r.voiceover_state.as_deref() == Some("completed")
            && r.voiceover_audio_url
                .as_deref()
                .is_some_and(|u| !u.trim().is_empty());

        let shot = ShortVideoAssemblyShot {
            storyboard_id: r.storyboard_id,
            storyboard_numeric_id: r.storyboard_numeric_id,
            sb_index: r.sb_index,
            selected_media_url: r.file_path.clone(),
            selected_media_kind: assembly_selected_media_kind(r.file_path.as_deref()).to_string(),
            duration: r.duration,
            state: r.state,
            track_id: r.track_id,
            subtitle_text: r.video_desc,
            subtitle_source,
            voiceover_script_ready,
            voiceover_state: r.voiceover_state,
            voiceover_audio_url: r.voiceover_audio_url,
            voiceover_error: r.voiceover_error,
            voiceover_asset_ready,
        };

        grouped.entry(r.script_numeric_id).or_default().push(shot);
    }

    let scripts: Vec<ShortVideoAssemblyScriptGroup> = script_order
        .into_iter()
        .map(|sid| ShortVideoAssemblyScriptGroup {
            script_numeric_id: sid,
            script_name: script_meta.get(&sid).cloned().flatten(),
            shots: grouped.remove(&sid).unwrap_or_default(),
        })
        .collect();

    let effective_tts_voice = resolve_tts_voice(None, header.voice_profile.as_deref());
    Ok(Json(ProjectShortVideoAssemblyResponse {
        schema_version: 1,
        project_defaults: ShortVideoAssemblyProjectDefaults {
            voice_profile: header.voice_profile.clone(),
            subtitle_style: header.subtitle_style.clone(),
            bgm_strategy: header.bgm_strategy.clone(),
        },
        effective_short_video_defaults: ShortVideoAssemblyEffectiveDefaults {
            tts_voice: effective_tts_voice,
            subtitle_style: header.subtitle_style.clone(),
            bgm_strategy: header.bgm_strategy.clone(),
        },
        candidate_quality_summary,
        scripts,
    }))
}
