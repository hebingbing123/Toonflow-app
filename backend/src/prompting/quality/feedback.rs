//! Quality review to agent memory feedback loop.
//!
//! Severe storyboard/output review failures are converted into the existing
//! `rejected_video_negative_memory` chain so the next generation can directly
//! reuse them without extra LLM calls. Non-video targets still fall back to a
//! compact generic summary memory.
#![allow(dead_code)]

use std::collections::BTreeSet;

use sqlx::PgPool;
use uuid::Uuid;

use crate::production::{
    infer_negative_fragments_from_comments, map_bad_case_category_with_comments,
    persist_rejected_video_negative_memory, refresh_project_video_style_memory,
    refresh_script_video_style_memory,
};
use crate::settings::agent_memory::replace_named_summary_memory;

use super::types::QualityReview;

const QUALITY_FEEDBACK_MEMORY_NAME: &str = "quality_feedback_memory";
const LOW_SCORE_THRESHOLD: i16 = 6;
const SEVERE_SCORE_THRESHOLD: i16 = 4;

/// Automatically write quality feedback to agent memory if the review indicates issues.
pub async fn maybe_write_quality_feedback_to_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    review: &QualityReview,
) -> Result<(), String> {
    let should_write = review.is_bad_case
        || review
            .overall_score
            .map(|s| s < LOW_SCORE_THRESHOLD)
            .unwrap_or(false)
        || review.passed == Some(false);
    if !should_write {
        return Ok(());
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
        return Ok(());
    }

    let feedback_content = build_generic_quality_feedback_content(review);
    if feedback_content.is_empty() {
        return Ok(());
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

    Ok(())
}

fn build_quality_review_rejected_video_memory(review: &QualityReview) -> Option<String> {
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

    let fragments = collect_negative_fragments(review);
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

fn collect_negative_fragments(review: &QualityReview) -> Vec<String> {
    let mut seen: BTreeSet<&'static str> = BTreeSet::new();
    let mut fragments = Vec::new();

    if let Some(category) = review.bad_case_category.as_deref() {
        if let Some(fragment) =
            map_bad_case_category_with_comments(category, review.comments.as_deref())
        {
            if seen.insert(fragment) {
                fragments.push(fragment.to_string());
            }
        }
    }

    if let Some(comments) = review.comments.as_deref() {
        for fragment in infer_negative_fragments_from_comments(comments) {
            if seen.insert(fragment) {
                fragments.push(fragment.to_string());
            }
        }
    }

    fragments
}

fn infer_risk_tags(fragments: &[String]) -> Vec<&'static str> {
    let joined = fragments.join(" ").to_ascii_lowercase();
    let mut tags = Vec::new();

    if joined.contains("face")
        || joined.contains("identity")
        || joined.contains("costume")
        || joined.contains("character")
    {
        tags.push("identity");
    }
    if joined.contains("lip-sync")
        || joined.contains("delivery")
        || joined.contains("expression")
        || joined.contains("dialogue")
    {
        tags.push("dialogue");
    }
    if joined.contains("flicker")
        || joined.contains("jitter")
        || joined.contains("rushed motion")
        || joined.contains("shot changes")
    {
        tags.push("motion");
    }
    if joined.contains("backlight") || joined.contains("lighting") || joined.contains("reflection")
    {
        tags.push("lighting");
    }
    if joined.contains("camera angle") || joined.contains("close-up") || joined.contains("framing")
    {
        tags.push("framing");
    }

    tags
}

fn build_generic_quality_feedback_content(review: &QualityReview) -> String {
    let mut parts = Vec::new();

    if let Some(target_id) = &review.target_id {
        parts.push(format!("target={target_id}"));
    }

    if review.is_bad_case {
        if let Some(cat) = &review.bad_case_category {
            parts.push(format!("issue={cat}"));
        } else {
            parts.push("issue=bad_case".to_string());
        }
    }

    let mut score_parts = Vec::new();
    if let Some(score) = review
        .plot_coherence
        .filter(|score| *score < LOW_SCORE_THRESHOLD)
    {
        score_parts.push((score, format!("plot_coherence:{score}")));
    }
    if let Some(score) = review
        .character_consistency
        .filter(|score| *score < LOW_SCORE_THRESHOLD)
    {
        score_parts.push((score, format!("character_consistency:{score}")));
    }
    if let Some(score) = review
        .dialogue_naturalness
        .filter(|score| *score < LOW_SCORE_THRESHOLD)
    {
        score_parts.push((score, format!("dialogue_naturalness:{score}")));
    }
    if let Some(score) = review.pacing.filter(|score| *score < LOW_SCORE_THRESHOLD) {
        score_parts.push((score, format!("pacing:{score}")));
    }
    if let Some(score) = review
        .faithfulness
        .filter(|score| *score < LOW_SCORE_THRESHOLD)
    {
        score_parts.push((score, format!("faithfulness:{score}")));
    }
    if let Some(score) = review
        .visual_quality
        .filter(|score| *score < LOW_SCORE_THRESHOLD)
    {
        score_parts.push((score, format!("visual_quality:{score}")));
    }
    if !score_parts.is_empty() {
        score_parts.sort_by_key(|(score, label)| (*score, label.clone()));
        parts.push(format!(
            "low_scores=[{}]",
            score_parts
                .into_iter()
                .take(2)
                .map(|(_, label)| label)
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }

    if let Some(comments) = &review.comments {
        let compact = comments.split_whitespace().collect::<Vec<_>>().join(" ");
        let truncated = if compact.len() > 120 {
            format!("{}...", &compact[..120])
        } else {
            compact
        };
        parts.push(format!("notes={truncated}"));
    }

    parts.join(" | ")
}

#[cfg(test)]
mod tests {
    use super::{
        build_generic_quality_feedback_content, build_quality_review_rejected_video_memory,
        QUALITY_FEEDBACK_MEMORY_NAME,
    };
    use crate::prompting::quality::types::QualityReview;
    use serde_json::json;
    use uuid::Uuid;

    fn sample_review() -> QualityReview {
        QualityReview {
            id: Uuid::nil(),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            user_id: Uuid::nil(),
            project_id: Some(1),
            script_id: Some(2),
            job_id: None,
            target_type: "storyboard".into(),
            target_id: Some("12".into()),
            source: "manual".into(),
            plot_coherence: None,
            character_consistency: Some(5),
            dialogue_naturalness: Some(4),
            pacing: None,
            faithfulness: None,
            visual_quality: Some(4),
            overall_score: Some(4),
            passed: Some(false),
            comments: Some("表情太平像读稿，嘴型也有点对不上，逆光太硬".into()),
            skill_version: None,
            model_name: Some("demo-model".into()),
            model_params: Some(json!({})),
            memory_delivery_priority_applied: Some(true),
            reviewer_id: None,
            is_bad_case: true,
            bad_case_category: Some("dialogue_issue".into()),
        }
    }

    #[test]
    fn severe_storyboard_review_builds_rejected_video_memory() {
        let content = build_quality_review_rejected_video_memory(&sample_review())
            .expect("rejected video memory");

        assert!(content.contains("storyboardIds=12"), "{content}");
        assert!(content.contains("rejectionCount=2"), "{content}");
        assert!(content.contains("riskTags=dialogue/lighting"), "{content}");
        assert!(
            content.contains("avoid=avoid lip-sync mismatch"),
            "{content}"
        );
        assert!(
            content.contains("avoid blank expression or monotone delivery"),
            "{content}"
        );
        assert!(
            content.contains("avoid harsh backlight silhouette"),
            "{content}"
        );
    }

    #[test]
    fn non_severe_review_stays_as_observation_strength_memory() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(5);
        review.comments = Some("情绪太平，像读稿".into());

        let content =
            build_quality_review_rejected_video_memory(&review).expect("rejected video memory");
        assert!(content.contains("rejectionCount=1"), "{content}");
        assert!(
            content.contains("avoid blank expression or monotone delivery"),
            "{content}"
        );
    }

    #[test]
    fn generic_feedback_content_truncates_long_comments() {
        let mut review = sample_review();
        review.target_type = "script".into();
        review.target_id = Some("script-9".into());
        review.comments = Some("a".repeat(240));

        let content = build_generic_quality_feedback_content(&review);
        assert!(content.contains("target=script-9"), "{content}");
        assert!(content.contains("low_scores=["), "{content}");
        assert!(content.contains("notes="), "{content}");
        assert!(!content.contains("model=demo-model"), "{content}");
    }

    #[test]
    fn generic_feedback_content_keeps_only_two_lowest_scores() {
        let mut review = sample_review();
        review.plot_coherence = Some(3);
        review.pacing = Some(2);
        review.faithfulness = Some(5);

        let content = build_generic_quality_feedback_content(&review);
        assert!(
            content.contains("low_scores=[pacing:2, plot_coherence:3]"),
            "{content}"
        );
        assert!(!content.contains("faithfulness:5"), "{content}");
    }

    #[test]
    fn generic_feedback_summary_memory_stays_named_for_scope_replacement() {
        assert_eq!(QUALITY_FEEDBACK_MEMORY_NAME, "quality_feedback_memory");
    }
}
