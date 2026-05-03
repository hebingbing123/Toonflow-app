//! Video-specific quality feedback: rejected memory building, selected memory promotion.

use sqlx::PgPool;
use uuid::Uuid;

use crate::production::{
    build_selected_video_memory, clear_rejected_video_negative_memory,
    compact_selected_video_memory_for_focus, optimize_scoped_video_memory,
    persist_selected_video_memory, refresh_project_video_style_memory,
    refresh_script_video_style_memory, selected_video_memory_is_low_signal,
    StoryboardPromptSeedRow,
};
use crate::prompting::quality::types::QualityReview;

use super::feedback_generic::{
    collect_negative_fragments, compact_quality_review_negative_fragments, fit_i32,
    infer_quality_feedback_focus_tags, infer_risk_tags, QualityFeedbackMemoryOutcome,
    SELECTED_MEMORY_PROMOTION_SCORE_THRESHOLD, SEVERE_SCORE_THRESHOLD,
};

pub(super) fn should_promote_quality_review_selected_video_memory(review: &QualityReview) -> bool {
    quality_review_storyboard_target_id(review).is_some()
        && !review.is_bad_case
        && review.passed == Some(true)
        && review
            .overall_score
            .is_some_and(|score| score >= SELECTED_MEMORY_PROMOTION_SCORE_THRESHOLD)
}

pub(super) fn quality_review_storyboard_target_id(review: &QualityReview) -> Option<i32> {
    matches!(
        review.target_type.as_str(),
        "storyboard" | "video" | "output" | "asset"
    )
    .then(|| {
        review
            .target_id
            .as_deref()
            .and_then(|value| value.parse::<i32>().ok())
            .filter(|id| *id > 0)
    })?
}

pub(super) fn build_quality_review_rejected_video_memory(review: &QualityReview) -> Option<String> {
    if !matches!(
        review.target_type.as_str(),
        "storyboard" | "video" | "output" | "asset"
    ) {
        return None;
    }
    let storyboard_numeric_id = review
        .target_id
        .as_deref()
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)?;

    let focus_tags = infer_quality_feedback_focus_tags(review, false);
    let fragments =
        compact_quality_review_negative_fragments(collect_negative_fragments(review), &focus_tags);
    if fragments.is_empty() {
        return None;
    }

    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    let rejection_count = if review.is_bad_case
        || review.passed == Some(false)
        || review
            .overall_score
            .map(|score| score <= SEVERE_SCORE_THRESHOLD)
            .unwrap_or(false)
    {
        2
    } else {
        1
    };
    parts.push(format!("rejectionCount={rejection_count}"));
    let risk_tags = infer_risk_tags(&fragments);
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

pub(super) fn prepare_selected_video_memory_for_promotion(
    memory_content: &str,
    focus_tags: &[String],
) -> Option<String> {
    let compacted = compact_selected_video_memory_for_focus(memory_content, focus_tags);
    (!selected_video_memory_is_low_signal(&compacted)).then_some(compacted)
}

pub(super) async fn promote_quality_review_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    review: &QualityReview,
) -> Result<QualityFeedbackMemoryOutcome, String> {
    let focus_tags = infer_quality_feedback_focus_tags(review, true);
    let Some(storyboard_id) = quality_review_storyboard_target_id(review) else {
        return Ok(QualityFeedbackMemoryOutcome {
            action: "promoted_selected_memory_skipped".into(),
            agent_type: Some("productionAgent".into()),
            storyboard_id: None,
            memory_name: Some("selected_video_memory".into()),
            cleared_memory_name: None,
            removed_rows: None,
            removed_chars: None,
            removed_visual_rows: None,
            removed_duplicate_rows: None,
            focus_tags: focus_tags.clone(),
        });
    };

    let prompt_seed = sqlx::query_as::<_, StoryboardPromptSeedRow>(
        r#"
        SELECT sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        JOIN app_script sc ON sc.id = sb.script_id
        JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = $4
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .bind(storyboard_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| format!("Failed to load storyboard prompt seed for quality memory: {e}"))?;

    let Some(prompt_seed) = prompt_seed else {
        return Ok(QualityFeedbackMemoryOutcome {
            action: "promoted_selected_memory_missing_prompt_seed".into(),
            agent_type: Some("productionAgent".into()),
            storyboard_id: Some(storyboard_id),
            memory_name: Some("selected_video_memory".into()),
            cleared_memory_name: None,
            removed_rows: None,
            removed_chars: None,
            removed_visual_rows: None,
            removed_duplicate_rows: None,
            focus_tags: focus_tags.clone(),
        });
    };
    let Some(memory_content) = build_selected_video_memory(storyboard_id, &prompt_seed) else {
        return Ok(QualityFeedbackMemoryOutcome {
            action: "promoted_selected_memory_empty".into(),
            agent_type: Some("productionAgent".into()),
            storyboard_id: Some(storyboard_id),
            memory_name: Some("selected_video_memory".into()),
            cleared_memory_name: None,
            removed_rows: None,
            removed_chars: None,
            removed_visual_rows: None,
            removed_duplicate_rows: None,
            focus_tags: focus_tags.clone(),
        });
    };
    let memory_content = prepare_selected_video_memory_for_promotion(&memory_content, &focus_tags);
    let Some(memory_content) = memory_content else {
        return Ok(QualityFeedbackMemoryOutcome {
            action: "promoted_selected_memory_low_signal".into(),
            agent_type: Some("productionAgent".into()),
            storyboard_id: Some(storyboard_id),
            memory_name: Some("selected_video_memory".into()),
            cleared_memory_name: None,
            removed_rows: None,
            removed_chars: None,
            removed_visual_rows: None,
            removed_duplicate_rows: None,
            focus_tags: focus_tags.clone(),
        });
    };

    clear_rejected_video_negative_memory(pool, user_id, project_id, script_id, storyboard_id)
        .await
        .map_err(|e| format!("Failed to clear stale rejected video feedback memory: {e:?}"))?;
    persist_selected_video_memory(pool, user_id, project_id, script_id, &memory_content)
        .await
        .map_err(|e| format!("Failed to persist selected video quality memory: {e:?}"))?;
    let optimization = optimize_scoped_video_memory(pool, user_id, project_id, script_id)
        .await
        .map_err(|e| format!("Failed to optimize selected video quality memory: {e:?}"))?;
    if !optimization.refreshed_script_summary {
        refresh_script_video_style_memory(pool, user_id, project_id, script_id)
            .await
            .map_err(|e| format!("Failed to refresh script selected video memory: {e:?}"))?;
    }
    if !optimization.refreshed_project_summary {
        refresh_project_video_style_memory(pool, user_id, project_id)
            .await
            .map_err(|e| format!("Failed to refresh project selected video memory: {e:?}"))?;
    }

    tracing::info!(
        review_id = %review.id,
        project_id,
        script_id,
        storyboard_id,
        optimization_removed_rows = optimization.removed_rows,
        optimization_removed_chars = optimization.removed_chars,
        optimization_removed_visual_rows = optimization.removed_visual_rows,
        optimization_removed_duplicate_rows = optimization.removed_duplicate_rows,
        "Quality feedback promoted approved storyboard/video into isolated selected memory"
    );

    Ok(QualityFeedbackMemoryOutcome {
        action: "promoted_selected_memory".into(),
        agent_type: Some("productionAgent".into()),
        storyboard_id: Some(storyboard_id),
        memory_name: Some("selected_video_memory".into()),
        cleared_memory_name: Some("rejected_video_negative_memory".into()),
        removed_rows: Some(fit_i32(optimization.removed_rows)),
        removed_chars: Some(fit_i32(optimization.removed_chars)),
        removed_visual_rows: Some(fit_i32(optimization.removed_visual_rows)),
        removed_duplicate_rows: Some(fit_i32(optimization.removed_duplicate_rows)),
        focus_tags,
    })
}
