//! **POST …/short-video-pre-assembly** — enqueue batch rough-cut manifest job (MP-W6).

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde::Deserialize;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_SHORT_VIDEO_PRE_ASSEMBLY};
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::short_video::defaults::resolve_tts_voice;
use crate::short_video::export_gaps::ExportGapRowInput;
use crate::short_video::pre_assembly::{build_pre_assembly_manifest, PreAssemblyBuildInput};
use crate::state::AppState;

use super::super::super::types::{
    ShortVideoPreAssemblyEnqueueResponse, ShortVideoPreAssemblySummary,
};
use super::assembly_query::{fetch_project_assembly_flat_rows, fetch_project_assembly_header};

#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct ShortVideoPreAssemblyBody {
    /// Optional filter: only shots under this script **`numeric_id`**.
    #[serde(default)]
    pub script_numeric_id: Option<i32>,
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/short-video-pre-assembly",
    operation_id = "postProjectShortVideoPreAssemblyByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = ShortVideoPreAssemblyBody,
    responses(
        (status = 200, description = "OK", body = ShortVideoPreAssemblyEnqueueResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_pre_assembly_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ShortVideoPreAssemblyBody>,
) -> Result<Json<ShortVideoPreAssemblyEnqueueResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let resolved_project_id = scope.id;

    let header = fetch_project_assembly_header(pool, resolved_project_id)
        .await?
        .ok_or(ApiError::NotFound)?;

    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;
    let gap_rows: Vec<ExportGapRowInput> = flat
        .iter()
        .filter(|r| {
            body.script_numeric_id
                .is_none_or(|sid| sid == r.script_numeric_id)
        })
        .map(|r| ExportGapRowInput {
            storyboard_id: r.storyboard_id,
            storyboard_numeric_id: r.storyboard_numeric_id,
            script_numeric_id: r.script_numeric_id,
            sb_index: r.sb_index,
            file_path: r.file_path.clone(),
            duration: r.duration.clone(),
            state: r.state.clone(),
            prompt: r.prompt.clone(),
            video_desc: r.video_desc.clone(),
            voiceover_state: r.voiceover_state.clone(),
            voiceover_audio_url: r.voiceover_audio_url.clone(),
            voiceover_error: r.voiceover_error.clone(),
            candidate_status: r.candidate_status.clone(),
        })
        .collect();

    if gap_rows.is_empty() {
        return Err(crate::error::bad_request_i18n(
            "no storyboards available for pre-assembly",
            "没有可用于预组装的镜头",
        ));
    }

    let effective_tts_voice = resolve_tts_voice(None, header.voice_profile.as_deref());
    let preview = build_pre_assembly_manifest(PreAssemblyBuildInput {
        project_uuid: header.id,
        voice_profile: header.voice_profile.as_deref(),
        subtitle_style: header.subtitle_style.as_deref(),
        bgm_strategy: header.bgm_strategy.as_deref(),
        tts_voice: effective_tts_voice.clone(),
        rows: &gap_rows,
    });

    if preview.blocking_shot_count > 0 {
        return Err(crate::error::bad_request_i18n(
            &format!(
                "pre-assembly blocked: {} shot(s) have blocking export gaps",
                preview.blocking_shot_count
            ),
            &format!(
                "预组装被阻断：{} 个镜头存在阻断性导出缺口",
                preview.blocking_shot_count
            ),
        ));
    }

    let project_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT numeric_id FROM app_project WHERE id = $1"#)
            .bind(header.id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let payload = serde_json::json!({
        "source": "short_video_space.pre_assembly",
        "project_uuid": header.id,
        "project_numeric_id": project_numeric_id,
        "script_numeric_id": body.script_numeric_id,
        "voice_profile": header.voice_profile,
        "subtitle_style": header.subtitle_style,
        "bgm_strategy": header.bgm_strategy,
        "effective_tts_voice": effective_tts_voice,
        "shot_count": preview.shot_count,
        "blocking_shot_count": preview.blocking_shot_count,
    });

    let job: JobRow = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_SHORT_VIDEO_PRE_ASSEMBLY,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;

    Ok(Json(ShortVideoPreAssemblyEnqueueResponse {
        schema_version: 1,
        job_id: job.id,
        summary: ShortVideoPreAssemblySummary {
            shot_count: preview.shot_count as i64,
            blocking_shot_count: preview.blocking_shot_count as i64,
            ready_video_count: preview.ready_video_count as i64,
            ready_voiceover_count: preview.ready_voiceover_count as i64,
            total_duration_seconds: preview.total_duration_seconds,
        },
    }))
}
