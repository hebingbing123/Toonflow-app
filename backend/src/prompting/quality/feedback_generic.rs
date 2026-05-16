//! Generic quality feedback helpers: focus tag inference, content building, fragment scoring.

use std::collections::BTreeSet;

use crate::prompting::quality::types::QualityReview;
use serde::Serialize;

pub(super) const LOW_SCORE_THRESHOLD: i16 = 6;
pub(super) const SEVERE_SCORE_THRESHOLD: i16 = 4;
pub(super) const SELECTED_MEMORY_PROMOTION_SCORE_THRESHOLD: i16 = 8;
pub(super) const QUALITY_FEEDBACK_NEGATIVE_FRAGMENT_LIMIT: usize = 2;

pub(super) fn fit_i32(value: usize) -> i32 {
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

pub(super) fn contains_any(value: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| value.contains(needle))
}

pub(super) fn infer_quality_feedback_focus_tags(
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

pub(super) fn collect_negative_fragments(review: &QualityReview) -> Vec<String> {
    use crate::production::{
        infer_negative_fragments_from_comments, map_bad_case_category_with_comments,
    };
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

pub(super) fn compact_quality_review_negative_fragments(
    fragments: Vec<String>,
    focus_tags: &[String],
) -> Vec<String> {
    if fragments.len() <= QUALITY_FEEDBACK_NEGATIVE_FRAGMENT_LIMIT {
        return fragments;
    }
    let mut scored = fragments
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            (
                score_quality_review_negative_fragment_for_focus(&fragment, focus_tags),
                idx,
                fragment,
            )
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    scored
        .into_iter()
        .map(|(_, _, fragment)| fragment)
        .take(QUALITY_FEEDBACK_NEGATIVE_FRAGMENT_LIMIT)
        .collect()
}

fn score_quality_review_negative_fragment_for_focus(fragment: &str, focus_tags: &[String]) -> i32 {
    let normalized = fragment.to_ascii_lowercase();
    let mut score = 0;
    for tag in focus_tags {
        match tag.as_str() {
            "delivery_realism"
                if normalized.contains("lip-sync")
                    || normalized.contains("delivery")
                    || normalized.contains("expression")
                    || normalized.contains("monotone") =>
            {
                score += 40;
            }
            "emotion_arc"
                if normalized.contains("expression")
                    || normalized.contains("emotion")
                    || normalized.contains("mood")
                    || normalized.contains("frantic")
                    || normalized.contains("oppressive") =>
            {
                score += 34;
            }
            "identity_continuity"
                if normalized.contains("face")
                    || normalized.contains("identity")
                    || normalized.contains("costume")
                    || normalized.contains("character") =>
            {
                score += 38;
            }
            "lighting_realism"
                if normalized.contains("light")
                    || normalized.contains("backlight")
                    || normalized.contains("silhouette")
                    || normalized.contains("neon")
                    || normalized.contains("reflection") =>
            {
                score += 36;
            }
            _ => {}
        }
    }
    if normalized.contains("lip-sync")
        || normalized.contains("delivery")
        || normalized.contains("expression")
        || normalized.contains("face")
        || normalized.contains("identity")
        || normalized.contains("light")
    {
        score += 8;
    }
    score - normalized.chars().count() as i32 / 12
}

pub(super) fn infer_risk_tags(fragments: &[String]) -> Vec<&'static str> {
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

pub(super) fn build_generic_quality_feedback_content(review: &QualityReview) -> String {
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
