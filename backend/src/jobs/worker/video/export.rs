use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;

use crate::jobs::worker::JobRunError;
use crate::jobs::JobRow;
use crate::state::AppState;
use crate::vendor::video::{VideoExportRequest, VideoProviderClient};

pub(crate) async fn run_video_export(
    _state: &AppState,
    _pool: &PgPool,
    _job_id: Uuid,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let p = &row.payload;

    let source_url = p
        .get("source_url")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing source_url".into()))?;

    let format = p.get("format").and_then(|x| x.as_str()).unwrap_or("mp4");
    let target_resolution = p.get("target_resolution").and_then(|x| x.as_str());
    let include_audio = p
        .get("include_audio")
        .and_then(|x| x.as_bool())
        .unwrap_or(true);

    tracing::info!(
        job_id = %row.id,
        kind = %row.kind,
        source_url = %source_url,
        format = %format,
        "video export: processing"
    );

    let client = VideoProviderClient::new();
    let export_req = VideoExportRequest {
        source_url: source_url.to_string(),
        format: format.to_string(),
        target_resolution: target_resolution.map(String::from),
        include_audio,
    };

    let export_resp = client
        .export_video(&export_req)
        .await
        .map_err(|e| JobRunError::Failed(format!("export failed: {e}")))?;

    let export_url = export_resp
        .export_url
        .ok_or_else(|| JobRunError::Failed("no export URL in response".to_string()))?;

    Ok(json!({
        "source": "video.export",
        "task_id": export_resp.task_id,
        "status": export_resp.status.as_str(),
        "export_url": export_url,
        "format": format,
        "include_audio": include_audio,
    }))
}
