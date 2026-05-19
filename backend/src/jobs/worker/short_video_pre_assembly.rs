//! Worker for **`short_video.pre_assembly`** — persists ordered rough-cut manifest JSON.

use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::payload_project::{
    payload_project_uuid, resolve_project_numeric_from_job_payload,
};
use crate::jobs::worker::{job_ok, JobCompletion, JobRunError};
use crate::jobs::JobRow;
use crate::short_video::assembly_query::{
    fetch_project_assembly_flat_rows, fetch_project_assembly_header,
};
use crate::short_video::export_gaps::ExportGapRowInput;
use crate::short_video::pre_assembly::{build_pre_assembly_manifest, PreAssemblyBuildInput};
use crate::state::AppState;

pub(crate) async fn run_short_video_pre_assembly(
    state: &AppState,
    pool: &PgPool,
    job_id: Uuid,
    row: &JobRow,
) -> Result<JobCompletion, JobRunError> {
    let project_uuid = payload_project_uuid(&row.payload)
        .ok_or_else(|| JobRunError::Failed("payload missing project_uuid".into()))?;
    let project_numeric_id =
        resolve_project_numeric_from_job_payload(pool, row.owner_user_id, &row.payload).await?;
    let script_filter = row
        .payload
        .get("script_numeric_id")
        .and_then(|v| v.as_i64())
        .map(|n| n as i32);

    let header = fetch_project_assembly_header(pool, project_uuid)
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?
        .ok_or_else(|| JobRunError::Failed("project not found for pre-assembly".into()))?;

    let flat = fetch_project_assembly_flat_rows(pool, header.id)
        .await
        .map_err(|e| JobRunError::Failed(format!("{e:?}")))?;

    let tts_voice = row
        .payload
        .get("effective_tts_voice")
        .and_then(|v| v.as_str())
        .map(str::to_string)
        .unwrap_or_else(|| "alloy".to_string());

    let gap_rows: Vec<ExportGapRowInput> = flat
        .iter()
        .filter(|r| script_filter.is_none_or(|sid| sid == r.script_numeric_id))
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

    let manifest = build_pre_assembly_manifest(PreAssemblyBuildInput {
        project_uuid: header.id,
        voice_profile: header.voice_profile.as_deref(),
        subtitle_style: header.subtitle_style.as_deref(),
        bgm_strategy: header.bgm_strategy.as_deref(),
        tts_voice: tts_voice.clone(),
        rows: &gap_rows,
    });

    let manifest_bytes = serde_json::to_vec_pretty(&manifest)
        .map_err(|e| JobRunError::Failed(format!("manifest serialize failed: {e}")))?;

    let root = state.local_video_export_dir.as_ref().ok_or_else(|| {
        JobRunError::Failed(
            "OPENFLOW_LOCAL_VIDEO_EXPORT_DIR is not set; cannot persist pre-assembly manifest"
                .into(),
        )
    })?;

    let user_dir = root.join(row.owner_user_id.to_string());
    tokio::fs::create_dir_all(&user_dir)
        .await
        .map_err(|e| JobRunError::Failed(format!("create pre-assembly dir failed: {e}")))?;

    let file_name = format!("{job_id}_pre_assembly.json");
    let disk_path = user_dir.join(&file_name);
    tokio::fs::write(&disk_path, &manifest_bytes)
        .await
        .map_err(|e| JobRunError::Failed(format!("write manifest failed: {e}")))?;

    let manifest_url = format!("/api/v1/jobs/{job_id}/file");

    let result = json!({
        "schema_version": 1,
        "manifest_url": manifest_url,
        "export_url": manifest_url,
        "project_uuid": header.id,
        "project_numeric_id": project_numeric_id,
        "project_defaults": {
            "voice_profile": header.voice_profile,
            "subtitle_style": header.subtitle_style,
            "bgm_strategy": header.bgm_strategy,
            "tts_voice": tts_voice,
        },
        "shot_count": manifest.shot_count,
        "blocking_shot_count": manifest.blocking_shot_count,
        "ready_video_count": manifest.ready_video_count,
        "ready_voiceover_count": manifest.ready_voiceover_count,
        "total_duration_seconds": manifest.total_duration_seconds,
        "storage": "local",
        "file_name": file_name,
        "content_type": "application/json",
        "byte_length": manifest_bytes.len(),
        "placeholder_note": "Rough-cut manifest only; mux/export is not performed in this job.",
    });

    Ok(job_ok(result))
}
