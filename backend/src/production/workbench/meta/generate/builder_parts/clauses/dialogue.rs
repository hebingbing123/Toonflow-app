//! Dialogue clause compaction and filtering.

use super::super::super::*;
use super::super::continuity::risk::video_prompt_scene_subject_count;

pub(in crate::production::workbench::meta::generate) fn looks_like_silence(text: &str) -> bool {
    let normalized = text.trim().to_lowercase();
    normalized.is_empty()
        || normalized == "无"
        || normalized == "无台词"
        || normalized == "无音效"
        || normalized == "none"
        || normalized == "no dialogue"
        || normalized == "no sound"
}

pub(in crate::production::workbench::meta::generate) fn compact_dialogue_clause(
    dialogue: &str,
    fields: Option<&StructuredStoryboardDescription>,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let normalized = normalize_prompt_text(dialogue);
    if normalized.is_empty() || looks_like_silence(&normalized) {
        return None;
    }

    let compacted = canonical_dialogue_fragment(&normalized);
    if compacted.is_empty() {
        return Some(normalized);
    }

    let normalized_len = normalized.chars().count();
    let compacted_len = compacted.chars().count();
    let selected = if compacted_len >= 2 && normalized_len.saturating_sub(compacted_len) >= 2 {
        compacted
    } else {
        normalized
    };

    if dialogue_fragment_is_non_semantic_vocalization(&selected) {
        return None;
    }
    if dialogue_fragment_looks_like_nonspoken_sound(&selected) {
        return None;
    }

    let prompt = context
        .and_then(|value| value.storyboard_prompt.as_deref())
        .unwrap_or_default();
    if fields.is_some_and(|fields| {
        dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
            &selected, fields, prompt,
        )
    }) {
        return None;
    }

    Some(selected)
}

pub(in crate::production::workbench::meta::generate) fn dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
    dialogue: &str,
    fields: &StructuredStoryboardDescription,
    prompt: &str,
) -> bool {
    if storyboard_has_visible_speech_performance_risk(fields, Some(prompt))
        || current_storyboard_is_fragile_emotional_turn(fields)
    {
        return false;
    }

    let normalized = canonical_dialogue_fragment(dialogue);
    if normalized.is_empty() {
        return true;
    }

    let char_count = normalized.chars().count();
    let shot = normalize_prompt_text(&fields.shot);
    let has_wide_or_far_shot = ["远景", "全景"]
        .iter()
        .any(|keyword| shot.contains(keyword));
    if char_count <= 4 && !dialogue_fragment_has_high_semantic_density(&normalized) {
        return true;
    }

    if has_wide_or_far_shot && video_prompt_scene_has_motion_risk(fields) && char_count <= 4 {
        return true;
    }

    if video_prompt_scene_has_motion_risk(fields) && video_prompt_scene_subject_count(fields) > 1 {
        return char_count <= 6 && !dialogue_fragment_has_high_semantic_density(&normalized);
    }

    false
}

pub(in crate::production::workbench::meta::generate) fn dialogue_fragment_has_high_semantic_density(
    dialogue: &str,
) -> bool {
    let normalized = canonical_dialogue_fragment(dialogue);
    if normalized.is_empty() {
        return false;
    }

    if normalized.chars().count() >= 8 {
        return true;
    }

    [
        "别",
        "为什么",
        "怎么",
        "不能",
        "不要",
        "必须",
        "一定",
        "马上",
        "终于",
        "已经",
        "真的",
        "不是",
        "别再",
        "快点",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn dialogue_fragment_looks_like_nonspoken_sound(
    dialogue: &str,
) -> bool {
    let normalized = canonical_dialogue_fragment(dialogue);
    !normalized.is_empty()
        && [
            "脚步声",
            "足音",
            "风声",
            "雨声",
            "门响",
            "门轴",
            "回响",
            "回荡",
            "低鸣",
            "滴答",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn dialogue_fragment_is_non_semantic_vocalization(
    value: &str,
) -> bool {
    let normalized = canonical_dialogue_fragment(value);
    if normalized.is_empty() {
        return false;
    }

    let mut residual = normalized;
    for fragment in [
        "急促",
        "短促",
        "轻微",
        "微弱",
        "低低",
        "沙哑",
        "压抑地",
        "压着",
        "颤抖着",
        "颤声",
        "轻声",
        "低声",
        "缓缓",
        "忍不住",
        "一声",
        "几声",
        "地",
        "着",
        "了",
    ] {
        residual = residual.replace(fragment, "");
    }
    for fragment in [
        "倒吸一口气",
        "呼吸声",
        "喘息",
        "喘气",
        "呼吸",
        "吸气",
        "叹息",
        "长叹",
        "闷哼",
        "呻吟",
        "哽咽",
        "抽泣",
        "啜泣",
        "惊呼",
        "尖叫",
        "低吼",
        "嘶吼",
        "呜咽",
    ] {
        residual = residual.replace(fragment, "");
    }
    for fragment in ["啊", "嗯", "呃", "哈", "哼", "唔", "呀", "哦"] {
        residual = residual.replace(fragment, "");
    }

    normalize_prompt_text(&residual).is_empty()
}

pub(in crate::production::workbench::meta::generate) fn canonical_dialogue_fragment(
    value: &str,
) -> String {
    let mut canonical = normalize_prompt_text(value)
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    '“' | '”' | '‘' | '’' | '"' | '\'' | '「' | '」' | '『' | '』' | ':' | '：'
                )
        })
        .to_string();
    loop {
        let mut changed = false;
        for prefix in [
            "低声说",
            "轻声说",
            "小声说",
            "喃喃道",
            "喃喃说",
            "呢喃",
            "说道",
            "说出",
            "说",
            "喊道",
            "喊出",
            "大喊",
            "呼喊",
            "叫喊",
            "质问",
            "回答",
            "回应",
            "重复",
            "台词",
            "对白",
            "旁白",
        ] {
            if let Some(stripped) = canonical.strip_prefix(prefix) {
                canonical = stripped
                    .trim_start_matches(|ch: char| {
                        ch.is_whitespace()
                            || matches!(
                                ch,
                                '“' | '”'
                                    | '‘'
                                    | '’'
                                    | '"'
                                    | '\''
                                    | '「'
                                    | '」'
                                    | '『'
                                    | '』'
                                    | ':'
                                    | '：'
                            )
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

pub(in crate::production::workbench::meta::generate) fn speech_like_fragment(
    fragment: &str,
) -> bool {
    [
        "说", "喊", "台词", "对白", "旁白", "低声", "轻声", "呢喃", "喃喃", "口播", "voice",
        "dialogue",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}
