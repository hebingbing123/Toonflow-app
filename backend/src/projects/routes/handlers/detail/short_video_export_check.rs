//! **导出前检查** + 质量摘要（D2），与 D1 装配 SQL 对齐。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use std::collections::BTreeMap;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::publish::export_check_facets::load_publish_export_facet_evaluation;
use crate::short_video::export_gaps::{
    evaluate_export_gap_issues, gap_facet_flags, ExportGapRowInput,
};
use crate::state::AppState;

use super::super::super::types::{
    ProjectShortVideoExportCheckResponse, QualityGateBlockingReason, ShortVideoExportCheckIssue,
    ShortVideoExportCheckStoryboardGap, ShortVideoExportCheckSummary, ShortVideoExportQualityGate,
};
use super::assembly_query::{fetch_project_assembly_flat_rows, fetch_project_assembly_header};

fn issue_from_gap(
    issue: &crate::short_video::export_gaps::ExportGapIssue,
    row: &super::assembly_query::AssemblyFlatRow,
) -> ShortVideoExportCheckIssue {
    ShortVideoExportCheckIssue {
        severity: issue.severity.to_string(),
        code: issue.code.to_string(),
        detail: issue.detail.clone(),
        script_numeric_id: row.script_numeric_id,
        storyboard_id: row.storyboard_id,
        storyboard_numeric_id: row.storyboard_numeric_id,
        sb_index: row.sb_index,
    }
}

pub(crate) fn row_to_gap_input(row: &super::assembly_query::AssemblyFlatRow) -> ExportGapRowInput {
    ExportGapRowInput {
        storyboard_id: row.storyboard_id,
        storyboard_numeric_id: row.storyboard_numeric_id,
        script_numeric_id: row.script_numeric_id,
        sb_index: row.sb_index,
        file_path: row.file_path.clone(),
        duration: row.duration.clone(),
        state: row.state.clone(),
        prompt: row.prompt.clone(),
        video_desc: row.video_desc.clone(),
        voiceover_state: row.voiceover_state.clone(),
        voiceover_audio_url: row.voiceover_audio_url.clone(),
        voiceover_error: row.voiceover_error.clone(),
        candidate_status: row.candidate_status.clone(),
    }
}

fn build_storyboard_gaps(
    issues: &[ShortVideoExportCheckIssue],
) -> Vec<ShortVideoExportCheckStoryboardGap> {
    let mut by_storyboard: BTreeMap<Uuid, ShortVideoExportCheckStoryboardGap> = BTreeMap::new();
    for issue in issues {
        let entry = by_storyboard.entry(issue.storyboard_id).or_insert_with(|| {
            ShortVideoExportCheckStoryboardGap {
                script_numeric_id: issue.script_numeric_id,
                storyboard_id: issue.storyboard_id,
                storyboard_numeric_id: issue.storyboard_numeric_id,
                sb_index: issue.sb_index,
                gap_codes: Vec::new(),
                has_blocking: false,
                missing_selected_video: false,
                missing_subtitle: false,
                missing_voiceover: false,
                duration_anomaly: false,
            }
        });
        if !entry.gap_codes.iter().any(|c| c == &issue.code) {
            entry.gap_codes.push(issue.code.clone());
        }
        if issue.severity == "blocking" {
            entry.has_blocking = true;
        }
    }

    let mut gaps: Vec<_> = by_storyboard.into_values().collect();
    for gap in &mut gaps {
        let (mv, ms, mvo, da) = gap_facet_flags(&gap.gap_codes);
        gap.missing_selected_video = mv;
        gap.missing_subtitle = ms;
        gap.missing_voiceover = mvo;
        gap.duration_anomaly = da;
    }
    gaps.sort_by(|a, b| {
        a.script_numeric_id
            .cmp(&b.script_numeric_id)
            .then_with(|| {
                a.sb_index
                    .unwrap_or(i32::MAX)
                    .cmp(&b.sb_index.unwrap_or(i32::MAX))
            })
            .then_with(|| a.storyboard_numeric_id.cmp(&b.storyboard_numeric_id))
    });
    gaps
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
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
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
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let resolved_project_id = scope.id;

    let header = fetch_project_assembly_header(pool, resolved_project_id)
        .await?
        .ok_or(ApiError::NotFound)?;

    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;

    let storyboard_count = flat.len() as i64;
    let mut issues = Vec::new();
    for row in &flat {
        let gap_input = row_to_gap_input(row);
        for gap_issue in evaluate_export_gap_issues(&gap_input) {
            issues.push(issue_from_gap(&gap_issue, row));
        }
    }

    let publish_eval = load_publish_export_facet_evaluation(pool, resolved_project_id).await?;
    let publish_blocking_count = publish_eval
        .issues
        .iter()
        .filter(|i| i.severity == "blocking")
        .count() as i64;
    let publish_warning_count = publish_eval
        .issues
        .iter()
        .filter(|i| i.severity == "warning")
        .count() as i64;

    let blocking_issue_count =
        issues.iter().filter(|i| i.severity == "blocking").count() as i64 + publish_blocking_count;
    let warning_issue_count =
        issues.iter().filter(|i| i.severity == "warning").count() as i64 + publish_warning_count;
    let export_ready = blocking_issue_count == 0;

    let pending_review_bad_case_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_quality_review q
        WHERE q.user_id = $2
          AND q.is_bad_case = true
          AND q.project_id = (SELECT numeric_id FROM app_project WHERE id = $1)
        "#,
    )
    .bind(header.id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let quality_gate_strategy: Option<String> = sqlx::query_scalar(
        r#"
        SELECT quality_gate_strategy
        FROM app_project
        WHERE id = $1
        "#,
    )
    .bind(header.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let strategy = quality_gate_strategy.unwrap_or_else(|| "block".to_string());

    let mut blocking_reasons = Vec::new();

    if strategy == "block" {
        if pending_review_bad_case_count > 0 {
            blocking_reasons.push(QualityGateBlockingReason {
                code: "pending_bad_cases".to_string(),
                message: format!(
                    "{} bad case(s) pending review. Please review and resolve before export.",
                    pending_review_bad_case_count
                ),
                rework_route: Some("/quality-review".to_string()),
            });
        }

        let storyboard_blocking = issues.iter().filter(|i| i.severity == "blocking").count() as i64;
        if storyboard_blocking > 0 {
            blocking_reasons.push(QualityGateBlockingReason {
                code: "blocking_export_issues".to_string(),
                message: format!(
                    "{} blocking storyboard issue(s) in export check. Please resolve before export.",
                    storyboard_blocking
                ),
                rework_route: Some("/short-video-space/assembly".to_string()),
            });
        }
        if publish_blocking_count > 0 {
            blocking_reasons.push(QualityGateBlockingReason {
                code: "blocking_publish_export_issues".to_string(),
                message: format!(
                    "{} blocking publish issue(s) (cover/platform). Configure publish draft before export.",
                    publish_blocking_count
                ),
                rework_route: Some("/short-video-space/publish".to_string()),
            });
        }
    }

    let enforced = strategy == "block" && !blocking_reasons.is_empty();
    let final_export_ready = export_ready && (strategy != "block" || blocking_reasons.is_empty());

    let data_version: Option<String> = sqlx::query_scalar(
        r#"
        SELECT MAX(updated_at)::text
        FROM (
          SELECT MAX(sb.updated_at) as updated_at
          FROM app_storyboard sb
          INNER JOIN app_script sc ON sc.id = sb.script_id
          WHERE sc.project_id = $1
          UNION ALL
          SELECT MAX(vo.updated_at) as updated_at
          FROM app_voiceover vo
          INNER JOIN app_storyboard sb ON sb.id = vo.storyboard_id
          INNER JOIN app_script sc ON sc.id = sb.script_id
          WHERE sc.project_id = $1
        ) AS versions
        "#,
    )
    .bind(header.id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let storyboard_gaps = build_storyboard_gaps(&issues);

    Ok(Json(ProjectShortVideoExportCheckResponse {
        schema_version: 1,
        data_version,
        export_ready: final_export_ready,
        summary: ShortVideoExportCheckSummary {
            storyboard_count,
            blocking_issue_count,
            warning_issue_count,
        },
        issues,
        storyboard_gaps,
        publish_facets: publish_eval.facets,
        publish_issues: publish_eval.issues,
        quality_gate: ShortVideoExportQualityGate {
            schema_version: 1,
            strategy,
            enforced,
            pending_review_bad_case_count,
            blocking_reasons: if blocking_reasons.is_empty() {
                None
            } else {
                Some(blocking_reasons)
            },
        },
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
    ) -> crate::short_video::assembly_query::AssemblyFlatRow {
        crate::short_video::assembly_query::AssemblyFlatRow {
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
        let issues: Vec<_> = evaluate_export_gap_issues(&row_to_gap_input(&row))
            .into_iter()
            .map(|i| issue_from_gap(&i, &row))
            .collect();
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
        let issues: Vec<_> = evaluate_export_gap_issues(&row_to_gap_input(&pending))
            .into_iter()
            .map(|i| issue_from_gap(&i, &pending))
            .collect();
        assert!(issues.iter().any(|i| i.code == "candidate_pending"));

        let no_media = sample_row(None, Some("t"), None, None, None, Some("5"));
        let issues: Vec<_> = evaluate_export_gap_issues(&row_to_gap_input(&no_media))
            .into_iter()
            .map(|i| issue_from_gap(&i, &no_media))
            .collect();
        assert!(issues.iter().any(|i| i.code == "missing_selected_media"));
    }

    #[test]
    fn storyboard_gaps_aggregate_codes_and_facets() {
        let row = sample_row(None, None, None, None, None, None);
        let issues: Vec<_> = evaluate_export_gap_issues(&row_to_gap_input(&row))
            .into_iter()
            .map(|i| issue_from_gap(&i, &row))
            .collect();
        let gaps = build_storyboard_gaps(&issues);
        assert_eq!(gaps.len(), 1);
        assert!(gaps[0].has_blocking);
        assert!(gaps[0].missing_selected_video);
        assert!(gaps[0].missing_subtitle);
        assert!(gaps[0]
            .gap_codes
            .contains(&"missing_selected_media".to_string()));
        assert!(gaps[0]
            .gap_codes
            .contains(&"subtitle_placeholder".to_string()));
    }
}
