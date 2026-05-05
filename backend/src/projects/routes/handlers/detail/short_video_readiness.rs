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
    has_basic_slot: bool,
    has_prompt_context: bool,
    has_reference_visual: bool,
    candidate_cleared: bool,
    no_blocking_job: bool,
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

    let row: Option<(Uuid,)> = sqlx::query_as(
        r#"
        SELECT id
        FROM app_project
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let (resolved_id,) = row.ok_or(ApiError::NotFound)?;

    let rows: Vec<StoryboardReadinessRow> = sqlx::query_as(
        r#"
        SELECT
          sb.id AS storyboard_id,
          sb.numeric_id AS storyboard_numeric_id,
          sc.numeric_id AS script_numeric_id,
          sb.sb_index,
          (sb.sb_index IS NOT NULL) AS has_basic_slot,
          (
            TRIM(COALESCE(sb.prompt, '')) <> ''
            OR TRIM(COALESCE(sb.video_desc, '')) <> ''
          ) AS has_prompt_context,
          (TRIM(COALESCE(sb.file_path, '')) <> '') AS has_reference_visual,
          (
            COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '') <> 'pending'
          ) AS candidate_cleared,
          NOT EXISTS (
            SELECT 1
            FROM app_generation_job j
            WHERE j.owner_user_id = $2
              AND j.status IN ('queued', 'running')
              AND (j.payload->>'storyboard_numeric_id') IS NOT NULL
              AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
          ) AS no_blocking_job
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
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
    fn blocking_reason_codes_orders_expected_keys() {
        let row = StoryboardReadinessRow {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: 1,
            script_numeric_id: Some(1),
            sb_index: None,
            has_basic_slot: false,
            has_prompt_context: false,
            has_reference_visual: false,
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
}
