//! Quality feedback memory entry point: writes review outcomes to agent memory.

use sqlx::PgPool;
use uuid::Uuid;

use crate::production::persist_rejected_video_negative_memory;
use crate::production::{refresh_project_video_style_memory, refresh_script_video_style_memory};
use crate::prompting::quality::types::QualityReview;
use crate::settings::agent_memory::replace_named_summary_memory;

use super::feedback_generic::{
    build_generic_quality_feedback_content, infer_quality_feedback_focus_tags,
    QualityFeedbackMemoryOutcome, LOW_SCORE_THRESHOLD,
};
use super::feedback_video::{
    build_quality_review_rejected_video_memory, promote_quality_review_selected_video_memory,
    quality_review_storyboard_target_id, should_promote_quality_review_selected_video_memory,
};

pub(super) const QUALITY_FEEDBACK_MEMORY_NAME: &str = "quality_feedback_memory";

/// Automatically write quality feedback to agent memory if the review indicates issues.
pub async fn maybe_write_quality_feedback_to_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    review: &QualityReview,
) -> Result<Option<QualityFeedbackMemoryOutcome>, String> {
    if should_promote_quality_review_selected_video_memory(review) {
        return promote_quality_review_selected_video_memory(
            pool, user_id, project_id, script_id, review,
        )
        .await
        .map(Some);
    }

    let should_write = review.is_bad_case
        || review
            .overall_score
            .map(|s| s < LOW_SCORE_THRESHOLD)
            .unwrap_or(false)
        || review.passed == Some(false);
    if !should_write {
        return Ok(None);
    }

    if let Some(content) = build_quality_review_rejected_video_memory(review) {
        persist_rejected_video_negative_memory(pool, user_id, project_id, script_id, &content)
            .await
            .map_err(|e| format!("Failed to persist rejected video feedback memory: {e:?}"))?;
        refresh_script_video_style_memory(pool, user_id, project_id, script_id)
            .await
            .map_err(|e| format!("Failed to refresh script video feedback memory: {e:?}"))?;
        refresh_project_video_style_memory(pool, user_id, project_id)
            .await
            .map_err(|e| format!("Failed to refresh project video feedback memory: {e:?}"))?;

        tracing::info!(
            review_id = %review.id,
            target_type = %review.target_type,
            target_id = ?review.target_id,
            "Quality feedback persisted into rejected video memory"
        );
        return Ok(Some(QualityFeedbackMemoryOutcome {
            action: "persisted_rejected_memory".into(),
            agent_type: Some("productionAgent".into()),
            storyboard_id: quality_review_storyboard_target_id(review),
            memory_name: Some("rejected_video_negative_memory".into()),
            cleared_memory_name: None,
            removed_rows: None,
            removed_chars: None,
            removed_visual_rows: None,
            removed_duplicate_rows: None,
            focus_tags: infer_quality_feedback_focus_tags(review, false),
        }));
    }

    let feedback_content = build_generic_quality_feedback_content(review);
    if feedback_content.is_empty() {
        return Ok(None);
    }

    let agent_type = match review.target_type.as_str() {
        "script" | "storyboard" => "scriptAgent",
        "video" | "asset" | "output" => "productionAgent",
        _ => "productionAgent",
    };

    replace_named_summary_memory(
        pool,
        user_id,
        project_id,
        Some(script_id),
        agent_type,
        "assistant",
        QUALITY_FEEDBACK_MEMORY_NAME,
        &feedback_content,
        None,
    )
    .await
    .map_err(|e| format!("Failed to write quality feedback summary memory: {e:?}"))?;

    Ok(Some(QualityFeedbackMemoryOutcome {
        action: "replaced_summary_memory".into(),
        agent_type: Some(agent_type.into()),
        storyboard_id: None,
        memory_name: Some(QUALITY_FEEDBACK_MEMORY_NAME.into()),
        cleared_memory_name: None,
        removed_rows: None,
        removed_chars: None,
        removed_visual_rows: None,
        removed_duplicate_rows: None,
        focus_tags: infer_quality_feedback_focus_tags(review, false),
    }))
}
