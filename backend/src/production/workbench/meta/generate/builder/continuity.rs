//! Continuity note helpers split from utils.rs.

use super::super::builder_parts::continuity::compact::{
    compact_continuity_fragment_wording, continuity_fragment_core,
    trim_continuity_fragment_against_storyboard_fields,
};
use super::super::builder_parts::quality_tail::continuity_tail_matches;
use super::super::*;

pub fn continuity_note_adds_specific_guidance(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "走位",
            "站位",
            "跳轴",
            "方向",
            "构图",
            "视线",
            "节奏",
            "动作",
            "位置",
            "前后景",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

pub fn continuity_fragment_is_generic_quality_tail_overlap(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || continuity_note_adds_specific_guidance(&normalized) {
        return false;
    }
    continuity_fragment_core(&normalized)
        .as_deref()
        .is_some_and(continuity_tail_matches)
}

pub fn continuity_fragment_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    if prompt_fragment_is_covered(fragment, coverage) {
        return true;
    }

    let canonical_fragment = canonical_continuity_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    coverage.iter().any(|existing| {
        let canonical_existing = canonical_continuity_fragment(existing);
        !canonical_existing.is_empty()
            && (canonical_existing == canonical_fragment
                || (canonical_fragment.chars().count() >= 4
                    && canonical_existing.contains(&canonical_fragment))
                || (canonical_existing.chars().count() >= 4
                    && canonical_fragment.contains(&canonical_existing)))
    })
}

pub fn canonical_continuity_fragment(fragment: &str) -> String {
    let mut canonical = normalize_prompt_text(fragment);
    loop {
        let mut changed = false;
        for prefix in [
            "保持上一镜头",
            "延续上一镜头",
            "保留上一镜头",
            "保持",
            "延续",
            "保留",
            "镜头",
            "情绪",
            "光影",
            "场景",
            "环境",
            "动作",
            "表演",
            "语气",
            "声场",
        ] {
            if let Some(stripped) = canonical.strip_prefix(prefix) {
                canonical = stripped
                    .trim_start_matches(|ch: char| {
                        ch.is_whitespace() || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，')
                    })
                    .to_string();
                changed = true;
                break;
            }
        }
        if !changed {
            break;
        }
    }
    canonical
}

pub fn strip_generic_director_continuity_subfragments(fragment: &str) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return normalized;
    }

    let separated = ["并且", "同时", "以及", "并", "且"]
        .into_iter()
        .fold(normalized.clone(), |acc, needle| acc.replace(needle, "，"));
    let kept = separated
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .filter(|part| !project_director_fragment_is_generic_quality_tail_overlap(part))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        normalized
    } else {
        kept.join("，")
    }
}

pub fn continuity_fragment_matches_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    let canonical = canonical_continuity_fragment(fragment);
    if canonical.is_empty() {
        return false;
    }
    canonical == fields.subject
        || canonical == fields.action
        || (!expected_camera.is_empty()
            && (canonical == expected_camera
                || canonical == fields.shot
                || canonical == fields.camera_move
                || (!fields.shot.is_empty() && canonical.contains(&fields.shot))
                || (!fields.camera_move.is_empty() && canonical.contains(&fields.camera_move))))
        || (!fields.mood.is_empty() && canonical == fields.mood)
        || (!fields.lighting.is_empty() && canonical == fields.lighting)
        || (!fields.setting.is_empty() && canonical == fields.setting)
}

pub fn select_video_prompt_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let structured_fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    let seeded_match_exists = rows.iter().any(|row| {
        row.name == "auto_scope_memory"
            && auto_scope_memory_tool_matches_video_prompt(row.content.as_str())
            && memory_storyboard_overlap_score(row.content.as_str(), storyboard_numeric_id) > 0
            && memory_prompt_seed_matches(
                row.content.as_str(),
                storyboard_numeric_id,
                current_prompt_seed,
            )
    });
    let mut scored = rows
        .iter()
        .filter_map(|row| {
            if row.name != "auto_scope_memory" {
                return None;
            }
            let content = row.content.as_str();
            if !auto_scope_memory_tool_matches_video_prompt(content) {
                return None;
            }
            if !auto_scope_memory_matches_current_prompt_seed(
                content,
                storyboard_numeric_id,
                current_prompt_seed,
                seeded_match_exists,
            ) {
                return None;
            }
            let score = memory_storyboard_overlap_score(content, storyboard_numeric_id);
            if score <= 0 {
                return None;
            }
            let note = extract_key_value(content, "summary")
                .or_else(|| extract_key_value(content, "result"))
                .and_then(|value| {
                    compact_storyboard_memory_continuity_note(&value, structured_fields.as_ref())
                })
                .and_then(|value| compact_auto_scope_continuity_summary(&value))
                .or_else(|| {
                    extract_key_value(content, "summary")
                        .or_else(|| extract_key_value(content, "result"))
                        .and_then(|value| {
                            compact_auto_scope_continuity_summary(&clip_prompt_fragment(
                                &value,
                                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                            ))
                        })
                })?;
            let continuity_score = score_continuity_note(&note, structured_fields.as_ref());
            if continuity_score <= 0 {
                return None;
            }
            if !continuity_note_matches_storyboard_risk(&note, structured_fields.as_ref()) {
                return None;
            }
            let specificity_score = score_continuity_specificity(&note);
            Some((
                score + continuity_score + specificity_score,
                specificity_score,
                continuity_score,
                note,
            ))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then(b.0.cmp(&a.0))
            .then(b.2.cmp(&a.2))
            .then(a.3.len().cmp(&b.3.len()))
            .then(a.3.cmp(&b.3))
    });

    let mut notes = Vec::new();
    for (_, _, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT {
            break;
        }
    }
    notes
}

pub fn auto_scope_memory_tool_matches_video_prompt(content: &str) -> bool {
    extract_key_value(content, "tool").is_some_and(|tool| {
        matches!(
            tool.as_str(),
            "run_sub_agent_storyboard_panel"
                | "run_sub_agent_storyboard_gen"
                | "run_sub_agent_production_supervision"
                | "run_sub_agent_director_plan"
        )
    })
}

pub fn auto_scope_memory_matches_current_prompt_seed(
    content: &str,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    seeded_match_exists: bool,
) -> bool {
    match current_prompt_seed.filter(|seed| !seed.is_empty()) {
        Some(seed) => match memory_prompt_seed_for_storyboard(content, storyboard_numeric_id) {
            Some(candidate_seed) => candidate_seed == seed,
            None => !seeded_match_exists,
        },
        None => true,
    }
}

pub fn compact_auto_scope_continuity_summary(note: &str) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }

    let fragments = split_prompt_note_fragments(&normalized)
        .map(|fragment| strip_auto_scope_continuity_scaffolding(&fragment))
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    let fragments = compact_auto_scope_continuity_fragments(fragments);
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub fn compact_auto_scope_continuity_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut kept = Vec::new();
    for fragment in fragments {
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
    }

    let has_specific_guidance = kept
        .iter()
        .any(|fragment| continuity_note_adds_specific_guidance(fragment));
    kept.iter()
        .filter(|fragment| {
            !auto_scope_continuity_fragment_is_covered(fragment, &kept, has_specific_guidance)
        })
        .cloned()
        .collect()
}

pub fn auto_scope_continuity_fragment_is_covered(
    candidate: &str,
    fragments: &[String],
    has_specific_guidance: bool,
) -> bool {
    if auto_scope_continuity_fragment_is_generic(candidate) && has_specific_guidance {
        return true;
    }

    let candidate_axis = auto_scope_continuity_axis(candidate);
    let candidate_specificity = score_continuity_specificity(candidate);
    fragments.iter().any(|other| {
        if other == candidate {
            return false;
        }
        let same_axis = candidate_axis != AutoScopeContinuityAxis::None
            && candidate_axis == auto_scope_continuity_axis(other);
        let other_is_stricter_same_axis =
            same_axis && auto_scope_continuity_fragment_prefers(other, candidate);
        same_axis
            && auto_scope_continuity_fragments_share_anchor(candidate, other)
            && (score_continuity_specificity(other) > candidate_specificity
                || other_is_stricter_same_axis)
    })
}

fn auto_scope_continuity_fragment_prefers(other: &str, candidate: &str) -> bool {
    let other = normalize_prompt_text(other);
    let candidate = normalize_prompt_text(candidate);
    (other.contains("不要跳轴") && candidate.contains("连续"))
        || (other.contains("视线方向一致") && candidate.contains("方向连续"))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AutoScopeContinuityAxis {
    None,
    Positioning,
    Rhythm,
}

pub fn auto_scope_continuity_axis(fragment: &str) -> AutoScopeContinuityAxis {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return AutoScopeContinuityAxis::None;
    }
    if [
        "跳轴",
        "视线",
        "方向",
        "构图",
        "站位",
        "走位",
        "位置",
        "前后景",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return AutoScopeContinuityAxis::Positioning;
    }
    if ["节奏", "动作"]
        .iter()
        .any(|keyword| normalized.contains(keyword))
    {
        return AutoScopeContinuityAxis::Rhythm;
    }
    AutoScopeContinuityAxis::None
}

pub fn auto_scope_continuity_fragments_share_anchor(left: &str, right: &str) -> bool {
    let left = normalize_prompt_text(left);
    let right = normalize_prompt_text(right);
    if left.is_empty() || right.is_empty() {
        return false;
    }
    [
        "跳轴",
        "视线",
        "方向",
        "构图",
        "站位",
        "走位",
        "位置",
        "前后景",
        "节奏",
        "动作",
    ]
    .iter()
    .any(|keyword| left.contains(keyword) && right.contains(keyword))
}

pub fn auto_scope_continuity_fragment_is_generic(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && !continuity_note_adds_specific_guidance(&normalized)
        && ["衔接", "连续", "统一", "一致", "延续", "保持"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

pub fn strip_auto_scope_continuity_scaffolding(fragment: &str) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for pattern in [
        "当前镜头已确认的",
        "当前分镜已确认的",
        "本镜头已确认的",
        "该镜头已确认的",
        "当前镜头已确认",
        "当前分镜已确认",
        "本镜头已确认",
        "该镜头已确认",
    ] {
        compacted = compacted.replace(pattern, "");
    }
    for pattern in ["当前镜头", "当前分镜", "本镜头", "该镜头"] {
        compacted = compacted.replace(pattern, "");
    }
    compacted = normalize_prompt_text(&compacted);
    if compacted == "已确认" || compacted == "镜头已确认" || compacted == "分镜已确认"
    {
        return String::new();
    }
    clip_prompt_fragment(&compacted, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
}

pub fn compact_storyboard_memory_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Option<String> {
    let compacted = compact_video_continuity_note(note)?;
    let Some(fields) = structured_fields else {
        return Some(compacted);
    };

    let fragments = compacted
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_continuity_fragment_against_storyboard_fields(&fragment, fields)
        })
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub fn score_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> i32 {
    let mut score = 0;
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return score;
    }
    for fragment in split_prompt_note_fragments(&normalized) {
        if fragment.is_empty() {
            continue;
        }
        if fragment.contains("上一镜头") {
            score += 24;
        }
        if [
            "走位", "站位", "方向", "构图", "衔接", "连续", "延续", "保持", "统一",
        ]
        .iter()
        .any(|keyword| fragment.contains(keyword))
        {
            score += 12;
        }
        if ["镜头", "情绪", "光影", "场景"]
            .iter()
            .any(|prefix| fragment.starts_with(prefix))
        {
            score += 2;
        }
    }

    if let Some(fields) = structured_fields {
        let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>();
        for fragment in split_prompt_note_fragments(&normalized) {
            if fragment.is_empty() {
                continue;
            }
            if continuity_fragment_matches_fields(&fragment, fields, &expected_camera) {
                score -= 8;
            }
        }
    }

    score
}

pub fn score_continuity_specificity(note: &str) -> i32 {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return 0;
    }

    normalized
        .split('，')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .map(|fragment| {
            let mut score = 0;
            if fragment.contains("跳轴") {
                score += 20;
            }
            if ["视线", "构图", "方向"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 16;
            }
            if ["站位", "走位", "位置", "前后景"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 12;
            }
            if ["节奏", "动作"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 8;
            }
            score
        })
        .sum()
}

pub fn memory_storyboard_overlap_score(row: &str, storyboard_numeric_id: i32) -> i32 {
    if storyboard_numeric_id <= 0 {
        return 0;
    }
    let key = "storyboardIds";
    let mut remainder = row;
    let mut score = 0;
    while let Some(found) = remainder.find(key) {
        let next = &remainder[found + key.len()..];
        let Some(after_equal) = next.strip_prefix('=') else {
            remainder = next;
            continue;
        };
        let ids = parse_csv_positive_ints(after_equal);
        if ids.contains(&storyboard_numeric_id) {
            score += 10;
        }
        remainder = after_equal;
    }
    score
}

pub fn parse_csv_positive_ints(text: &str) -> Vec<i32> {
    let raw = text
        .chars()
        .take_while(|ch| ch.is_ascii_digit() || *ch == ',' || ch.is_ascii_whitespace())
        .collect::<String>();
    raw.split(',')
        .filter_map(|part| part.trim().parse::<i32>().ok())
        .filter(|value| *value > 0)
        .collect()
}
