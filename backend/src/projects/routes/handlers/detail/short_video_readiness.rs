//! 短视频分镜级 readiness + 项目 rollup（impl Wave 2 / MP-W3 对齐）。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::state::AppState;

use super::super::super::types::{
    ProjectShortVideoReadinessResponse, ShortVideoReadinessReasonRollup, ShortVideoReadinessRollup,
    StoryboardShortVideoReadiness,
};

#[derive(Debug, FromRow)]
struct StoryboardReadinessRow {
    storyboard_id: Uuid,
    storyboard_numeric_id: i32,
    script_numeric_id: Option<i32>,
    sb_index: Option<i32>,
    is_live_action_mode: bool,
    has_basic_slot: bool,
    has_prompt_context: bool,
    has_reference_visual: bool,
    has_live_action_reference_shots: bool,
    has_live_action_performance_notes: bool,
    candidate_cleared: bool,
    no_blocking_job: bool,
}

/// Text from Postgres **`COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')`**.
/// **`candidate_cleared`** in `/short-video-readiness` is **`TRIM(coalesced) != 'pending'`**.
///
/// Keep this predicate aligned with the SELECT below; unit tests lock the contract for C10.
#[must_use]
#[allow(dead_code)] // Only referenced from unit tests; mirrors SQL for drift-sensitive readiness rules.
fn candidate_cleared_from_coalesced_metadata_text(coalesced: &str) -> bool {
    coalesced.trim() != "pending"
}

fn blocking_reason_codes(row: &StoryboardReadinessRow) -> Vec<&'static str> {
    let mut out = Vec::new();
    if !row.has_basic_slot {
        out.push("missing_basic_slot");
    }
    if !row.has_prompt_context {
        out.push("missing_prompt_context");
    }
    if !row.has_reference_visual {
        out.push("missing_reference_visual");
    }
    if row.is_live_action_mode && !row.has_live_action_reference_shots {
        out.push("missing_live_action_reference_shot");
    }
    if row.is_live_action_mode && !row.has_live_action_performance_notes {
        out.push("missing_live_action_performance_notes");
    }
    if !row.candidate_cleared {
        out.push("candidate_pending");
    }
    if !row.no_blocking_job {
        out.push("blocking_job");
    }
    out
}

fn rollup_reasons(rows: &[StoryboardReadinessRow]) -> Vec<ShortVideoReadinessReasonRollup> {
    use std::collections::BTreeMap;
    let mut acc: BTreeMap<&'static str, i64> = BTreeMap::new();
    for row in rows {
        for code in blocking_reason_codes(row) {
            *acc.entry(code).or_insert(0) += 1;
        }
    }
    acc.into_iter()
        .map(
            |(reason, storyboard_count)| ShortVideoReadinessReasonRollup {
                reason: reason.to_string(),
                storyboard_count,
            },
        )
        .collect()
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/short-video-readiness",
    operation_id = "getProjectShortVideoReadinessByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    responses(
        (status = 200, description = "OK", body = ProjectShortVideoReadinessResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_readiness_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectShortVideoReadinessResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let resolved_id = scope.id;

    let rows: Vec<StoryboardReadinessRow> = sqlx::query_as(
        r#"
        SELECT
          sb.id AS storyboard_id,
          sb.numeric_id AS storyboard_numeric_id,
          sc.numeric_id AS script_numeric_id,
          sb.sb_index,
          LOWER(TRIM(COALESCE(ap.mode, ''))) IN ('live_action.short_drama', '真人') AS is_live_action_mode,
          (sb.sb_index IS NOT NULL) AS has_basic_slot,
          (
            TRIM(COALESCE(sb.prompt, '')) <> ''
            OR TRIM(COALESCE(sb.video_desc, '')) <> ''
          ) AS has_prompt_context,
          (TRIM(COALESCE(sb.file_path, '')) <> '') AS has_reference_visual,
          jsonb_array_length(
            COALESCE(sb.metadata #> '{shortVideo,liveAction,referenceShotUrls}', '[]'::jsonb)
          ) > 0 AS has_live_action_reference_shots,
          TRIM(COALESCE(sb.metadata #>> '{shortVideo,liveAction,performanceNotes}', '')) <> ''
            AS has_live_action_performance_notes,
          (
            -- Must match `candidate_cleared_from_coalesced_metadata_text`
            TRIM(COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')) <> 'pending'
          ) AS candidate_cleared,
          NOT EXISTS (
            SELECT 1
            FROM app_generation_job j
            WHERE j.owner_user_id = $2
              AND j.status IN ('queued', 'running')
              AND j.payload ? 'storyboard_numeric_id'
              AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
              AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
          ) AS no_blocking_job
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project ap ON ap.id = sc.project_id
        WHERE sc.project_id = $1
        ORDER BY sc.numeric_id ASC, sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
        "#,
    )
    .bind(resolved_id)
    .bind(uid)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_storyboards = rows.len() as i64;
    let mut storyboards = Vec::with_capacity(rows.len());
    let mut ready_count: i64 = 0;

    for r in &rows {
        let blocking_reasons: Vec<String> = blocking_reason_codes(r)
            .into_iter()
            .map(std::string::ToString::to_string)
            .collect();
        let ready_for_generation = blocking_reasons.is_empty();
        if ready_for_generation {
            ready_count += 1;
        }
        storyboards.push(StoryboardShortVideoReadiness {
            storyboard_id: r.storyboard_id,
            storyboard_numeric_id: r.storyboard_numeric_id,
            script_numeric_id: r.script_numeric_id,
            sb_index: r.sb_index,
            has_basic_slot: r.has_basic_slot,
            has_prompt_context: r.has_prompt_context,
            has_reference_visual: r.has_reference_visual,
            has_live_action_reference_shots: r.has_live_action_reference_shots,
            has_live_action_performance_notes: r.has_live_action_performance_notes,
            candidate_cleared: r.candidate_cleared,
            no_blocking_job: r.no_blocking_job,
            ready_for_generation,
            blocking_reasons,
        });
    }

    let blocked_count = total_storyboards.saturating_sub(ready_count);
    let by_reason = rollup_reasons(&rows);

    Ok(Json(ProjectShortVideoReadinessResponse {
        schema_version: 1,
        rollup: ShortVideoReadinessRollup {
            total_storyboards,
            ready_count,
            blocked_count,
            by_reason,
        },
        storyboards,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn candidate_cleared_semantics_match_sql_coalesce_and_pending_gate() {
        assert!(candidate_cleared_from_coalesced_metadata_text(""));
        assert!(candidate_cleared_from_coalesced_metadata_text("linked"));
        assert!(candidate_cleared_from_coalesced_metadata_text("ignored"));
        assert!(candidate_cleared_from_coalesced_metadata_text("confirmed"));
        assert!(!candidate_cleared_from_coalesced_metadata_text("pending"));
        assert!(!candidate_cleared_from_coalesced_metadata_text(" pending "));
    }

    fn all_checks_pass_row(candidate_cleared: bool) -> StoryboardReadinessRow {
        StoryboardReadinessRow {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: 42,
            script_numeric_id: Some(7),
            sb_index: Some(1),
            is_live_action_mode: false,
            has_basic_slot: true,
            has_prompt_context: true,
            has_reference_visual: true,
            has_live_action_reference_shots: true,
            has_live_action_performance_notes: true,
            candidate_cleared,
            no_blocking_job: true,
        }
    }

    #[test]
    fn readiness_emits_candidate_pending_iff_candidate_cleared_false() {
        let cleared_row = all_checks_pass_row(candidate_cleared_from_coalesced_metadata_text(""));
        assert!(
            !blocking_reason_codes(&cleared_row).contains(&"candidate_pending"),
            "cleared shots must not block on candidate_pending"
        );

        let blocked_row =
            all_checks_pass_row(candidate_cleared_from_coalesced_metadata_text("pending"));
        assert_eq!(
            blocking_reason_codes(&blocked_row),
            vec!["candidate_pending"],
            "only pending-candidate gate should block when other checks pass"
        );
    }

    #[test]
    fn ready_for_generation_requires_candidate_cleared_among_other_checks() {
        let row_pending =
            all_checks_pass_row(candidate_cleared_from_coalesced_metadata_text("pending"));
        let reasons: Vec<String> = blocking_reason_codes(&row_pending)
            .into_iter()
            .map(str::to_string)
            .collect();
        assert!(
            reasons.iter().any(|s| s == "candidate_pending"),
            "candidate_pending must surface when metadata candidateStatus is pending"
        );

        let row_cleared = all_checks_pass_row(candidate_cleared_from_coalesced_metadata_text(""));
        let reasons_cleared: Vec<String> = blocking_reason_codes(&row_cleared)
            .into_iter()
            .map(str::to_string)
            .collect();
        assert!(
            reasons_cleared.is_empty(),
            "golden row should be ready_for_generation (empty blocking_reasons)"
        );
    }

    #[test]
    fn blocking_reason_codes_orders_expected_keys() {
        let row = StoryboardReadinessRow {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: 1,
            script_numeric_id: Some(1),
            sb_index: None,
            is_live_action_mode: false,
            has_basic_slot: false,
            has_prompt_context: false,
            has_reference_visual: false,
            has_live_action_reference_shots: false,
            has_live_action_performance_notes: false,
            candidate_cleared: false,
            no_blocking_job: false,
        };
        let codes = blocking_reason_codes(&row);
        assert_eq!(
            codes,
            vec![
                "missing_basic_slot",
                "missing_prompt_context",
                "missing_reference_visual",
                "candidate_pending",
                "blocking_job"
            ]
        );
    }

    #[test]
    fn live_action_readiness_requires_reference_shot_and_performance_notes() {
        let row = StoryboardReadinessRow {
            is_live_action_mode: true,
            has_live_action_reference_shots: false,
            has_live_action_performance_notes: false,
            ..all_checks_pass_row(true)
        };
        assert_eq!(
            blocking_reason_codes(&row),
            vec![
                "missing_live_action_reference_shot",
                "missing_live_action_performance_notes",
            ]
        );
    }
}
