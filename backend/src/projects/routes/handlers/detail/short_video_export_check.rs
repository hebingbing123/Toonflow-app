//! **导出前检查** + 质量摘要（D2），与 D1 装配 SQL 对齐。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::production::{
    export_duration_warning_code, resolve_shot_script_source, resolve_shot_voiceover_ready,
};
use crate::state::AppState;

use super::super::super::types::{
    ProjectShortVideoExportCheckResponse, ShortVideoExportCheckIssue, ShortVideoExportCheckSummary,
};
use super::assembly_query::{
    assembly_selected_media_kind, fetch_project_assembly_flat_rows, fetch_project_assembly_header,
};

fn issue(
    severity: &'static str,
    code: &'static str,
    detail: String,
    row: &super::assembly_query::AssemblyFlatRow,
) -> ShortVideoExportCheckIssue {
    ShortVideoExportCheckIssue {
        severity: severity.to_string(),
        code: code.to_string(),
        detail,
        script_numeric_id: row.script_numeric_id,
        storyboard_id: row.storyboard_id,
        storyboard_numeric_id: row.storyboard_numeric_id,
        sb_index: row.sb_index,
    }
}

fn evaluate_row(row: &super::assembly_query::AssemblyFlatRow) -> Vec<ShortVideoExportCheckIssue> {
    let mut out = Vec::new();
    let media_kind = assembly_selected_media_kind(row.file_path.as_deref());
    let subtitle_src = resolve_shot_script_source(row.video_desc.as_deref(), row.prompt.as_deref());
    let vo_script_ready =
        resolve_shot_voiceover_ready(row.video_desc.as_deref(), row.prompt.as_deref());
    let vo_asset_ready = row.voiceover_state.as_deref() == Some("completed")
        && row
            .voiceover_audio_url
            .as_deref()
            .is_some_and(|u| !u.trim().is_empty());

    if row.candidate_status.as_deref() == Some("pending") {
        out.push(issue(
            "blocking",
            "candidate_pending",
            "Storyboard shortVideo.candidateStatus is pending; confirm before export.".into(),
            row,
        ));
    }

    match media_kind {
        "none" => {
            out.push(issue(
                "blocking",
                "missing_selected_media",
                "No file_path / selected media for this storyboard.".into(),
                row,
            ));
        }
        "video" => {}
        _ => {
            out.push(issue(
                "blocking",
                "selected_media_not_video",
                "Video export expects an mp4/mov/webm/mkv current selection; found image or other URL.".into(),
                row,
            ));
        }
    }

    if subtitle_src == "placeholder" {
        out.push(issue(
            "blocking",
            "subtitle_placeholder",
            "No subtitle/narration text (video_desc empty and prompt empty).".into(),
            row,
        ));
    }

    let vo_failed = row.voiceover_state.as_deref() == Some("failed")
        || row
            .voiceover_error
            .as_deref()
            .is_some_and(|e| !e.trim().is_empty());
    if vo_failed {
        out.push(issue(
            "warning",
            "voiceover_failed",
            "Voiceover pipeline reported failure or error metadata.".into(),
            row,
        ));
    }

    if vo_script_ready && !vo_asset_ready && !vo_failed {
        out.push(issue(
            "warning",
            "voiceover_audio_missing",
            "Narration text exists but completed voiceover audio URL is absent.".into(),
            row,
        ));
    }

    if let Some(code) = export_duration_warning_code(row.duration.as_deref()) {
        let detail = match code {
            "duration_not_explicit" => {
                "Duration field empty; exporter defaults timeline to 5s.".to_string()
            }
            "duration_unparsable" => format!(
                "Duration {:?} is not a positive integer seconds value.",
                row.duration.as_deref().unwrap_or("")
            ),
            _ => "Duration anomaly.".to_string(),
        };
        out.push(issue("warning", code, detail, row));
    }

    if media_kind == "video" {
        let st = row.state.as_deref().map(str::trim).unwrap_or("");
        if st != "已完成" {
            out.push(issue(
                "warning",
                "completion_uncertain",
                format!(
                    "Video selected but storyboard state is {:?}, not 已完成.",
                    row.state.as_deref().unwrap_or("")
                ),
                row,
            ));
        }
    }

    out
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/short-video-export-check",
    operation_id = "getProjectShortVideoExportCheckByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectShortVideoExportCheckResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_export_check_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectShortVideoExportCheckResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let header = fetch_project_assembly_header(pool, project_id, uid)
        .await?
        .ok_or(ApiError::NotFound)?;

    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;

    let storyboard_count = flat.len() as i64;
    let mut issues = Vec::new();
    for row in &flat {
        issues.extend(evaluate_row(row));
    }

    let blocking_issue_count = issues.iter().filter(|i| i.severity == "blocking").count() as i64;
    let warning_issue_count = issues.iter().filter(|i| i.severity == "warning").count() as i64;
    let export_ready = blocking_issue_count == 0;

    Ok(Json(ProjectShortVideoExportCheckResponse {
        schema_version: 1,
        export_ready,
        summary: ShortVideoExportCheckSummary {
            storyboard_count,
            blocking_issue_count,
            warning_issue_count,
        },
        issues,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn sample_row(
        file_path: Option<&str>,
        video_desc: Option<&str>,
        prompt: Option<&str>,
        state: Option<&str>,
        candidate: Option<&str>,
        duration: Option<&str>,
    ) -> super::super::assembly_query::AssemblyFlatRow {
        super::super::assembly_query::AssemblyFlatRow {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: 1,
            script_numeric_id: 9,
            script_name: None,
            sb_index: Some(1),
            file_path: file_path.map(str::to_string),
            duration: duration.map(str::to_string),
            state: state.map(str::to_string),
            track_id: None,
            prompt: prompt.map(str::to_string),
            video_desc: video_desc.map(str::to_string),
            voiceover_state: None,
            voiceover_audio_url: None,
            voiceover_error: None,
            candidate_status: candidate.map(str::to_string),
        }
    }

    #[test]
    fn export_ready_when_video_completed_and_text_present() {
        let row = sample_row(
            Some("https://x/a.mp4"),
            Some("hello"),
            None,
            Some("已完成"),
            None,
            Some("8"),
        );
        let issues = evaluate_row(&row);
        assert!(issues.iter().all(|i| i.severity != "blocking"));
    }

    #[test]
    fn blocking_when_pending_candidate_or_no_video() {
        let pending = sample_row(
            Some("https://x/a.mp4"),
            Some("t"),
            None,
            Some("已完成"),
            Some("pending"),
            Some("5"),
        );
        assert!(evaluate_row(&pending)
            .iter()
            .any(|i| i.code == "candidate_pending"));

        let no_media = sample_row(None, Some("t"), None, None, None, Some("5"));
        assert!(evaluate_row(&no_media)
            .iter()
            .any(|i| i.code == "missing_selected_media"));
    }
}
