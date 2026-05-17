//! Shared short-video storyboard readiness predicates (**MP-W3 / Space consistency**).
//!
//! Used by **`GET …/short-video-readiness`** and production generation guards so gates stay aligned.

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{conflict_with_details_i18n, ApiError};

#[derive(Debug, Clone, sqlx::FromRow)]
pub(crate) struct StoryboardReadinessRow {
    pub(crate) storyboard_numeric_id: i32,
    pub(crate) is_live_action_mode: bool,
    pub(crate) has_basic_slot: bool,
    pub(crate) has_prompt_context: bool,
    pub(crate) has_reference_visual: bool,
    pub(crate) has_live_action_reference_shots: bool,
    pub(crate) has_live_action_performance_notes: bool,
    pub(crate) candidate_cleared: bool,
    pub(crate) no_blocking_job: bool,
}

/// Text from Postgres **`COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')`**.
#[must_use]
#[allow(dead_code)] // Referenced from `projects` readiness unit tests (`#[cfg(test)]` only).
pub(crate) fn candidate_cleared_from_coalesced_metadata_text(coalesced: &str) -> bool {
    coalesced.trim() != "pending"
}

#[must_use]
pub(crate) fn blocking_reason_codes(row: &StoryboardReadinessRow) -> Vec<&'static str> {
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

#[derive(Debug, Clone)]
pub(crate) struct StoryboardReadinessEval {
    pub(crate) storyboard_numeric_id: i32,
    pub(crate) blocking_reasons: Vec<String>,
}

impl StoryboardReadinessEval {
    #[must_use]
    pub(crate) fn ready_for_generation(&self) -> bool {
        self.blocking_reasons.is_empty()
    }
}

#[must_use]
pub(crate) fn eval_from_row(row: &StoryboardReadinessRow) -> StoryboardReadinessEval {
    StoryboardReadinessEval {
        storyboard_numeric_id: row.storyboard_numeric_id,
        blocking_reasons: blocking_reason_codes(row)
            .into_iter()
            .map(str::to_string)
            .collect(),
    }
}

/// Load readiness rows for one script; optionally restrict to **`storyboard_numeric_ids`**.
pub(crate) async fn load_script_storyboard_readiness(
    pool: &PgPool,
    project_id: Uuid,
    owner_user_id: Uuid,
    script_numeric_id: i32,
    storyboard_numeric_ids: Option<&[i32]>,
) -> Result<Vec<StoryboardReadinessRow>, ApiError> {
    let ids_filter: Option<Vec<i32>> = storyboard_numeric_ids
        .map(|ids| ids.iter().copied().filter(|id| *id > 0).collect::<Vec<_>>());
    let rows = if let Some(ref ids) = ids_filter {
        if ids.is_empty() {
            return Ok(Vec::new());
        }
        sqlx::query_as::<_, StoryboardReadinessRow>(
            r#"
            SELECT
              sb.numeric_id AS storyboard_numeric_id,
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
                TRIM(COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')) <> 'pending'
              ) AS candidate_cleared,
              NOT EXISTS (
                SELECT 1
                FROM app_generation_job j
                WHERE j.owner_user_id = $3
                  AND j.status IN ('queued', 'running')
                  AND j.payload ? 'storyboard_numeric_id'
                  AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
                  AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
              ) AS no_blocking_job
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project ap ON ap.id = sc.project_id
            WHERE sc.project_id = $1
              AND sc.numeric_id = $2
              AND sb.numeric_id = ANY($4::int4[])
            ORDER BY sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
            "#,
        )
        .bind(project_id)
        .bind(script_numeric_id)
        .bind(owner_user_id)
        .bind(ids)
        .fetch_all(pool)
        .await
    } else {
        sqlx::query_as::<_, StoryboardReadinessRow>(
            r#"
            SELECT
              sb.numeric_id AS storyboard_numeric_id,
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
                TRIM(COALESCE(sb.metadata #>> '{shortVideo,candidateStatus}', '')) <> 'pending'
              ) AS candidate_cleared,
              NOT EXISTS (
                SELECT 1
                FROM app_generation_job j
                WHERE j.owner_user_id = $3
                  AND j.status IN ('queued', 'running')
                  AND j.payload ? 'storyboard_numeric_id'
                  AND (j.payload->>'storyboard_numeric_id') ~ '^[0-9]+$'
                  AND (j.payload->>'storyboard_numeric_id')::int = sb.numeric_id
              ) AS no_blocking_job
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project ap ON ap.id = sc.project_id
            WHERE sc.project_id = $1
              AND sc.numeric_id = $2
            ORDER BY sb.sb_index ASC NULLS LAST, sb.numeric_id ASC
            "#,
        )
        .bind(project_id)
        .bind(script_numeric_id)
        .bind(owner_user_id)
        .fetch_all(pool)
        .await
    }
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows)
}

/// Returns **409** when any evaluated storyboard is not ready for generation.
pub(crate) fn enforce_storyboards_ready_for_generation(
    evaluations: &[StoryboardReadinessEval],
) -> Result<(), ApiError> {
    let blocked: Vec<_> = evaluations
        .iter()
        .filter(|e| !e.ready_for_generation())
        .map(|e| {
            serde_json::json!({
                "storyboardNumericId": e.storyboard_numeric_id,
                "blockingReasons": e.blocking_reasons,
            })
        })
        .collect();
    if blocked.is_empty() {
        return Ok(());
    }
    Err(conflict_with_details_i18n(
        "One or more storyboards are not ready for video generation",
        "部分分镜尚未满足短视频生成就绪条件",
        serde_json::json!({ "blockedStoryboards": blocked }),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn candidate_cleared_rejects_pending_and_whitespace_padding() {
        assert!(!candidate_cleared_from_coalesced_metadata_text("pending"));
        assert!(!candidate_cleared_from_coalesced_metadata_text(" pending "));
        assert!(candidate_cleared_from_coalesced_metadata_text("confirmed"));
        assert!(candidate_cleared_from_coalesced_metadata_text(""));
    }

    #[test]
    fn blocking_reasons_include_candidate_pending() {
        let row = StoryboardReadinessRow {
            storyboard_numeric_id: 1,
            is_live_action_mode: false,
            has_basic_slot: true,
            has_prompt_context: true,
            has_reference_visual: true,
            has_live_action_reference_shots: false,
            has_live_action_performance_notes: false,
            candidate_cleared: false,
            no_blocking_job: true,
        };
        assert!(
            blocking_reason_codes(&row).contains(&"candidate_pending"),
            "pending candidate must block generation"
        );
    }
}
