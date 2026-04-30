//! Quality review to agent memory feedback loop.
//!
//! Severe storyboard/output review failures are converted into the existing
//! `rejected_video_negative_memory` chain so the next generation can directly
//! reuse them without extra LLM calls. Non-video targets still fall back to a
//! compact generic summary memory.
#![allow(dead_code)]

use std::collections::BTreeSet;

use serde::Serialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::production::{
    build_selected_video_memory, clear_rejected_video_negative_memory,
    infer_negative_fragments_from_comments, map_bad_case_category_with_comments,
    optimize_scoped_video_memory, persist_rejected_video_negative_memory,
    persist_selected_video_memory, refresh_project_video_style_memory,
    refresh_script_video_style_memory, StoryboardPromptSeedRow,
};
use crate::settings::agent_memory::replace_named_summary_memory;

use super::types::QualityReview;

const QUALITY_FEEDBACK_MEMORY_NAME: &str = "quality_feedback_memory";
const LOW_SCORE_THRESHOLD: i16 = 6;
const SEVERE_SCORE_THRESHOLD: i16 = 4;
const SELECTED_MEMORY_PROMOTION_SCORE_THRESHOLD: i16 = 8;

fn fit_i32(value: usize) -> i32 {
    i32::try_from(value).unwrap_or(i32::MAX)
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityFeedbackMemoryOutcome {
    pub action: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub agent_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub storyboard_id: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub memory_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cleared_memory_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub removed_rows: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub removed_chars: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub removed_visual_rows: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub removed_duplicate_rows: Option<i32>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub focus_tags: Vec<String>,
}

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

async fn promote_quality_review_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    review: &QualityReview,
) -> Result<QualityFeedbackMemoryOutcome, String> {
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
            focus_tags: infer_quality_feedback_focus_tags(review, true),
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
            focus_tags: infer_quality_feedback_focus_tags(review, true),
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
            focus_tags: infer_quality_feedback_focus_tags(review, true),
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
        focus_tags: infer_quality_feedback_focus_tags(review, true),
    })
}

fn should_promote_quality_review_selected_video_memory(review: &QualityReview) -> bool {
    quality_review_storyboard_target_id(review).is_some()
        && !review.is_bad_case
        && review.passed == Some(true)
        && review
            .overall_score
            .is_some_and(|score| score >= SELECTED_MEMORY_PROMOTION_SCORE_THRESHOLD)
}

fn quality_review_storyboard_target_id(review: &QualityReview) -> Option<i32> {
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

fn infer_quality_feedback_focus_tags(
    review: &QualityReview,
    positive_outcome: bool,
) -> Vec<String> {
    let comment = review
        .comments
        .as_deref()
        .map(str::to_lowercase)
        .unwrap_or_default();
    let category = review
        .bad_case_category
        .as_deref()
        .map(str::to_lowercase)
        .unwrap_or_default();
    let mut tags = BTreeSet::new();

    let dialogue_good = review.dialogue_naturalness.is_some_and(|score| score >= 8);
    let dialogue_bad = review.dialogue_naturalness.is_some_and(|score| score <= 7);
    let identity_good = review.character_consistency.is_some_and(|score| score >= 8);
    let identity_bad = review.character_consistency.is_some_and(|score| score <= 6);
    let visual_good = review.visual_quality.is_some_and(|score| score >= 8);
    let visual_bad = review.visual_quality.is_some_and(|score| score <= 6);

    if (positive_outcome
        && (dialogue_good
            || contains_any(
                &comment,
                &[
                    "情绪递进",
                    "口型自然",
                    "台词自然",
                    "不生硬",
                    "有起伏",
                    "会呼吸",
                ],
            )))
        || (!positive_outcome
            && (dialogue_bad
                || contains_any(
                    &comment,
                    &[
                        "读文章",
                        "生硬",
                        "没情绪",
                        "单一状态",
                        "平平淡淡",
                        "干念",
                        "口型",
                    ],
                )
                || contains_any(&category, &["dialogue", "delivery", "lip", "voice"])))
    {
        tags.insert("delivery_realism".to_string());
    }

    if (positive_outcome
        && contains_any(&comment, &["情绪递进", "情绪层次", "自然流动", "表演细腻"]))
        || (!positive_outcome
            && (contains_any(
                &comment,
                &[
                    "没情绪",
                    "情绪平",
                    "木",
                    "僵",
                    "没有起伏",
                    "blank expression",
                    "emotionless",
                ],
            ) || contains_any(&category, &["emotion", "performance"])))
    {
        tags.insert("emotion_arc".to_string());
    }

    if (positive_outcome
        && (identity_good || contains_any(&comment, &["人物稳定", "角色一致", "脸稳", "造型稳定"])))
        || (!positive_outcome
            && (identity_bad
                || contains_any(
                    &comment,
                    &[
                        "穿帮",
                        "串脸",
                        "脸崩",
                        "角色不一致",
                        "服装不一致",
                        "五官不一致",
                    ],
                )
                || contains_any(&category, &["identity", "character", "consistency", "face"])))
    {
        tags.insert("identity_continuity".to_string());
    }

    if (positive_outcome
        && (visual_good
            || contains_any(&comment, &["真实自然", "光影自然", "反光真实", "质感稳定"])))
        || (!positive_outcome
            && (visual_bad
                || contains_any(
                    &comment,
                    &[
                        "不自然",
                        "很假",
                        "假脸",
                        "ai感",
                        "像ai",
                        "出戏",
                        "闪烁",
                        "塑料",
                        "光影假",
                    ],
                )
                || contains_any(&category, &["visual", "lighting", "continuity", "motion"])))
    {
        tags.insert("lighting_realism".to_string());
    }

    tags.into_iter().collect()
}

fn contains_any(value: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| value.contains(needle))
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
        infer_quality_feedback_focus_tags, should_promote_quality_review_selected_video_memory,
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

    #[test]
    fn successful_storyboard_review_qualifies_for_selected_video_memory_promotion() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(9);
        review.comments = Some("人物状态自然，情绪和镜头都稳定".into());

        assert!(should_promote_quality_review_selected_video_memory(&review));
    }

    #[test]
    fn failed_or_low_score_storyboard_review_does_not_promote_selected_video_memory() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(7);
        assert!(!should_promote_quality_review_selected_video_memory(
            &review
        ));

        review.overall_score = Some(9);
        review.passed = Some(false);
        assert!(!should_promote_quality_review_selected_video_memory(
            &review
        ));
    }

    #[test]
    fn negative_feedback_focus_tags_capture_delivery_identity_and_lighting() {
        let tags = infer_quality_feedback_focus_tags(&sample_review(), false);

        assert_eq!(
            tags,
            vec![
                "delivery_realism".to_string(),
                "identity_continuity".to_string(),
                "lighting_realism".to_string(),
            ]
        );
    }

    #[test]
    fn positive_feedback_focus_tags_capture_emotion_and_identity() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(9);
        review.dialogue_naturalness = Some(9);
        review.character_consistency = Some(9);
        review.visual_quality = Some(8);
        review.comments = Some("情绪递进自然，角色一致，光影真实自然".into());

        let tags = infer_quality_feedback_focus_tags(&review, true);

        assert_eq!(
            tags,
            vec![
                "delivery_realism".to_string(),
                "emotion_arc".to_string(),
                "identity_continuity".to_string(),
                "lighting_realism".to_string(),
            ]
        );
    }
}
