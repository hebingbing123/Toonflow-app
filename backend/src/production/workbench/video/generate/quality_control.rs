use super::fragment_operations::{
    merge_negative_prompt_fragment_groups, push_negative_fragment_without_budget,
};
use super::fragment_parsing::{
    canonical_negative_fragment, negative_fragment_family, negative_fragment_information_score,
};
use super::*;
use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;

#[allow(dead_code)]
pub(super) fn quality_review_row_matches_storyboard(
    row: &QualityReviewSeedRow,
    storyboard_id: i32,
) -> bool {
    quality_review_storyboard_target_id(row)
        .map(|value| value == storyboard_id)
        .unwrap_or(true)
}

pub(super) fn quality_review_storyboard_target_id(row: &QualityReviewSeedRow) -> Option<i32> {
    storyboard_target_id_parts(row.target_type.as_deref(), row.target_id.as_deref())
}

pub(super) fn recent_quality_storyboard_target_id(row: &RecentQualitySignalSeedRow) -> Option<i32> {
    storyboard_target_id_parts(row.target_type.as_deref(), row.target_id.as_deref())
}

fn storyboard_target_id_parts(target_type: Option<&str>, target_id: Option<&str>) -> Option<i32> {
    match target_type.map(str::trim) {
        Some("storyboard") => target_id.and_then(|value| value.trim().parse::<i32>().ok()),
        _ => None,
    }
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn compact_negative_review_constraints(rows: &[QualityReviewSeedRow]) -> Option<String> {
    merge_negative_prompt_fragment_groups(&[collect_negative_review_fragments(rows, 0, None)])
}

pub(super) fn collect_negative_review_fragments(
    rows: &[QualityReviewSeedRow],
    storyboard_id: i32,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<String> {
    let mut candidates = Vec::new();
    let mut order = 0usize;
    for row in rows
        .iter()
        .filter(|row| review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_scored_negative_fragment(
                &mut candidates,
                &mut order,
                map_bad_case_category_with_comments(category, row.comments.as_deref()),
                true,
                false,
                recent_quality_pressure,
            );
        }
    }
    for row in rows
        .iter()
        .filter(|row| review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_scored_negative_fragment(
                    &mut candidates,
                    &mut order,
                    Some(fragment),
                    true,
                    true,
                    recent_quality_pressure,
                );
            }
        }
    }
    for row in rows
        .iter()
        .filter(|row| !review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_scored_negative_fragment(
                &mut candidates,
                &mut order,
                map_bad_case_category_with_comments(category, row.comments.as_deref()),
                false,
                false,
                recent_quality_pressure,
            );
        }
    }
    for row in rows
        .iter()
        .filter(|row| !review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_scored_negative_fragment(
                    &mut candidates,
                    &mut order,
                    Some(fragment),
                    false,
                    true,
                    recent_quality_pressure,
                );
            }
        }
    }
    candidates.sort_by(|a, b| {
        b.score
            .cmp(&a.score)
            .then(a.order.cmp(&b.order))
            .then(a.fragment.cmp(&b.fragment))
    });

    let mut fragments = Vec::new();
    for candidate in candidates {
        push_negative_fragment_without_budget(&mut fragments, &candidate.fragment);
        if fragments.len() >= 6 {
            break;
        }
    }
    fragments
}

fn review_row_targets_storyboard(row: &QualityReviewSeedRow, storyboard_id: i32) -> bool {
    matches!(
        row.target_type.as_deref().map(str::trim),
        Some("storyboard")
    ) && row
        .target_id
        .as_deref()
        .and_then(|value| value.trim().parse::<i32>().ok())
        .is_some_and(|value| value == storyboard_id)
}

fn push_scored_negative_fragment(
    target: &mut Vec<ScoredNegativeFragment>,
    order: &mut usize,
    candidate: Option<&'static str>,
    storyboard_scoped: bool,
    from_comments: bool,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) {
    let Some(fragment) = candidate else {
        return;
    };
    target.push(ScoredNegativeFragment {
        score: score_review_negative_fragment(
            fragment,
            storyboard_scoped,
            from_comments,
            recent_quality_pressure,
        ),
        order: *order,
        fragment: fragment.to_string(),
    });
    *order += 1;
}

fn map_bad_case_category(category: &str) -> Option<&'static str> {
    match category.trim() {
        "visual_error" => Some("avoid warped anatomy, blur, flicker"),
        "storyboard_mismatch" => Some("avoid extra shot changes or wrong framing"),
        "character_break" => Some("avoid face drift or costume inconsistency"),
        "pacing_issue" => Some("avoid rushed or jerky motion"),
        "dialogue_issue" => Some("avoid lip-sync mismatch"),
        _ => None,
    }
}

pub(crate) fn map_bad_case_category_with_comments(
    category: &str,
    comments: Option<&str>,
) -> Option<&'static str> {
    let mapped = map_bad_case_category(category)?;
    let Some(comments) = comments else {
        return Some(mapped);
    };
    let comment_fragments = infer_negative_fragments_from_comments(comments);
    match category.trim() {
        "visual_error" if visual_error_category_is_redundant(&comment_fragments) => return None,
        "storyboard_mismatch" if storyboard_mismatch_category_is_redundant(&comment_fragments) => {
            return None;
        }
        "pacing_issue" if pacing_issue_category_is_redundant(&comment_fragments) => return None,
        _ => {}
    }
    Some(mapped)
}

pub(super) fn visual_error_category_is_redundant(comment_fragments: &[&'static str]) -> bool {
    let mut has_distortion = false;
    let mut has_blur = false;
    let mut has_flicker = false;
    for fragment in comment_fragments {
        match canonical_negative_fragment(fragment).as_str() {
            "avoid warped hands or limbs" | "avoid warped anatomy" => has_distortion = true,
            "avoid blur" => has_blur = true,
            "avoid flicker" | "avoid flicker or motion jitter" => has_flicker = true,
            _ => {}
        }
    }
    has_distortion && has_blur && has_flicker
}

pub(super) fn storyboard_mismatch_category_is_redundant(
    comment_fragments: &[&'static str],
) -> bool {
    let mut has_shot_change = false;
    let mut has_wrong_framing = false;
    for fragment in comment_fragments {
        match canonical_negative_fragment(fragment).as_str() {
            "avoid unnecessary shot changes" => has_shot_change = true,
            "avoid extreme camera angle"
            | "avoid overly tight close-up framing"
            | "avoid extreme camera angle or overly tight close-up framing" => {
                has_wrong_framing = true;
            }
            _ => {}
        }
    }
    has_shot_change && has_wrong_framing
}

pub(super) fn pacing_issue_category_is_redundant(comment_fragments: &[&'static str]) -> bool {
    let mut has_rushed_motion = false;
    let mut has_jerky_motion = false;
    for fragment in comment_fragments {
        match canonical_negative_fragment(fragment).as_str() {
            "avoid rushed motion" => has_rushed_motion = true,
            "avoid flicker" | "avoid flicker or motion jitter" => has_jerky_motion = true,
            _ => {}
        }
    }
    has_rushed_motion && has_jerky_motion
}

pub(crate) fn infer_negative_fragments_from_comments(comments: &str) -> Vec<&'static str> {
    let normalized = comments.trim().to_ascii_lowercase();
    let mut fragments = Vec::new();
    let keyword_groups = [
        (
            &[
                "手", "手指", "肢体", "四肢", "畸形", "变形", "anatom", "limb",
            ][..],
            "avoid warped hands or limbs",
        ),
        (
            &["脸", "面部", "五官", "表情崩", "face", "facial"][..],
            "avoid face distortion or identity drift",
        ),
        (
            &["闪烁", "跳帧", "抖动", "flicker", "jitter", "stutter"][..],
            "avoid flicker or motion jitter",
        ),
        (
            &["模糊", "发糊", "虚焦", "blur", "blurry", "soft focus"][..],
            "avoid blur",
        ),
        (
            &[
                "压迫",
                "紧张",
                "太冷",
                "冷调",
                "冷峻",
                "frantic",
                "oppressive",
                "cold mood",
            ][..],
            "avoid overly cold, oppressive, or frantic mood",
        ),
        (
            &[
                "表情僵",
                "表情木",
                "木讷",
                "木然",
                "面瘫",
                "没情绪",
                "没有情绪",
                "情绪太平",
                "语气太平",
                "台词太平",
                "台词生硬",
                "念稿",
                "读稿",
                "像读文章",
                "生硬",
                "monotone",
                "flat delivery",
                "blank expression",
                "wooden",
                "stiff performance",
            ][..],
            "avoid blank expression or monotone delivery",
        ),
        (
            &["逆光", "背光", "剪影", "backlight", "silhouette"][..],
            "avoid harsh backlight silhouette",
        ),
        (
            &[
                "冷光",
                "色温",
                "曝光死",
                "光太平",
                "flat lighting",
                "cold lighting",
            ][..],
            "avoid flat cold lighting",
        ),
        (
            &[
                "霓虹",
                "反光",
                "玻璃反射",
                "雨地反光",
                "车流反光",
                "neon reflection",
                "reflection",
            ][..],
            "avoid distracting neon reflections",
        ),
        (
            &["镜头", "构图", "机位", "切镜", "shot", "framing", "camera"][..],
            "avoid unnecessary shot changes",
        ),
        (
            &[
                "机位太歪",
                "角度太歪",
                "角度极端",
                "仰拍过头",
                "俯拍过头",
                "特写太近",
                "近景太近",
                "裁切太紧",
                "close-up too tight",
                "camera angle too extreme",
                "extreme angle",
                "tight close-up",
            ][..],
            "avoid extreme camera angle or overly tight close-up framing",
        ),
        (
            &[
                "太赶",
                "过赶",
                "过急",
                "太急",
                "过快",
                "太快",
                "节奏赶",
                "动作赶",
                "rushed",
                "too fast",
                "too quick",
                "rush",
            ][..],
            "avoid rushed motion",
        ),
        (
            &["背景", "场景", "空间", "setting", "background"][..],
            "avoid wrong setting details",
        ),
        (
            &["服装", "发型", "角色不一致", "costume", "hair", "character"][..],
            "avoid costume or character drift",
        ),
    ];

    for (keywords, fragment) in keyword_groups {
        if keywords.iter().any(|keyword| normalized.contains(keyword)) {
            fragments.push(fragment);
        }
    }
    fragments
}

fn score_review_negative_fragment(
    fragment: &str,
    storyboard_scoped: bool,
    from_comments: bool,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let source_score = if storyboard_scoped { 48 } else { 0 };
    let detail_score = if from_comments { 8 } else { 0 };
    let canonical = canonical_negative_fragment(fragment);
    let family_score = match negative_fragment_family(fragment) {
        "flicker_motion_jitter" => 36,
        "shot_change_framing" | "camera_framing" => 34,
        "performance_delivery" => 24,
        "lighting_backlight" | "lighting_reflection" => 20,
        "mood_tone" => 16,
        _ => {
            if canonical.contains("face")
                || canonical.contains("costume")
                || canonical.contains("character")
            {
                40
            } else if canonical.contains("warped")
                || canonical.contains("anatom")
                || canonical.contains("blur")
            {
                38
            } else if canonical.contains("setting") {
                18
            } else {
                14
            }
        }
    };
    let breadth_score = [
        canonical.contains("warped") || canonical.contains("anatom"),
        canonical.contains("blur"),
        canonical.contains("flicker") || canonical.contains("jitter"),
        canonical.contains("face") || canonical.contains("identity"),
        canonical.contains("costume") || canonical.contains("character"),
    ]
    .into_iter()
    .filter(|present| *present)
    .count() as i32
        * 4;
    let bias_score = score_review_negative_fragment_bias(fragment, recent_quality_pressure);
    source_score + detail_score + family_score + breadth_score + bias_score
        - negative_fragment_information_score(fragment) as i32 / 6
}

pub(super) fn score_review_negative_fragment_bias(
    fragment: &str,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let Some(pressure) = recent_quality_pressure else {
        return 0;
    };

    match negative_fragment_family(fragment) {
        "performance_delivery" | "lip_sync_mismatch" => {
            if pressure.prefer_delivery_memory_recall {
                28
            } else {
                0
            }
        }
        "character_consistency" => {
            if pressure.prefer_visual_continuity_memory_recall {
                12
            } else {
                0
            }
        }
        "lighting_backlight" | "lighting_reflection" => {
            if pressure.prefer_visual_continuity_memory_recall {
                10
            } else {
                0
            }
        }
        "flicker_motion_jitter" | "shot_change_framing" | "camera_framing" | "rushed_motion" => {
            if pressure.prefer_visual_continuity_memory_recall {
                8
            } else {
                0
            }
        }
        "mood_tone" => {
            if pressure.prefer_delivery_memory_recall {
                6
            } else {
                0
            }
        }
        _ => 0,
    }
}
