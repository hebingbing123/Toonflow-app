//! Sound clause compaction and filtering.

use super::super::super::*;
use super::dialogue::{canonical_dialogue_fragment, looks_like_silence, speech_like_fragment};

pub(in crate::production::workbench::meta::generate) fn compact_sound_clause(
    sound: &str,
    dialogue: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let normalized = normalize_prompt_text(sound);
    if normalized.is_empty() || looks_like_silence(&normalized) {
        return None;
    }

    let dialogue = dialogue
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty() && !looks_like_silence(value));
    let mut kept = Vec::new();
    for fragment in split_prompt_clause_fragments(&normalized) {
        if looks_like_silence(&fragment) {
            continue;
        }
        let fragment = compact_sound_fragment(&fragment);
        if fragment.is_empty() || looks_like_silence(&fragment) {
            continue;
        }
        if sound_fragment_is_low_signal_ambient(&fragment) {
            continue;
        }
        if dialogue
            .as_deref()
            .is_some_and(|line| sound_fragment_is_dialogue_covered(&fragment, line))
        {
            continue;
        }
        if action.is_some_and(|line| sound_fragment_is_action_covered(&fragment, line)) {
            continue;
        }
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
    }

    if kept.is_empty() {
        None
    } else {
        Some(kept.join("，"))
    }
}

pub(in crate::production::workbench::meta::generate) fn compact_sound_fragment(
    fragment: &str,
) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    loop {
        let mut changed = false;
        for prefix in [
            "伴随",
            "伴着",
            "伴有",
            "夹杂着",
            "夹杂",
            "传来",
            "响起",
            "回荡着",
            "回荡",
            "只剩下",
            "只剩",
            "能听见",
            "听见",
            "可闻",
            "耳边传来",
            "空气里只剩",
        ] {
            let Some(stripped) = compacted.strip_prefix(prefix) else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、' | '的'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(in crate::production::workbench::meta::generate) fn split_prompt_clause_fragments(
    value: &str,
) -> Vec<String> {
    value
        .split(['，', ',', '；', ';', '。', '！', '!', '？', '?', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}

pub(in crate::production::workbench::meta::generate) fn sound_fragment_is_dialogue_covered(
    fragment: &str,
    dialogue: &str,
) -> bool {
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty() {
        return false;
    }
    let canonical_fragment = canonical_dialogue_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    speech_like_fragment(fragment)
        && (canonical_fragment == canonical_dialogue
            || canonical_fragment.contains(&canonical_dialogue)
            || canonical_dialogue.contains(&canonical_fragment))
}

pub(in crate::production::workbench::meta::generate) fn sound_fragment_is_action_covered(
    fragment: &str,
    action: &str,
) -> bool {
    let fragment = normalize_prompt_text(fragment);
    let action = normalize_prompt_text(action);
    if fragment.is_empty() || action.is_empty() {
        return false;
    }
    if sound_fragment_has_high_value_acoustic_detail(&fragment) {
        return false;
    }

    if sound_fragment_matches_footstep_action(&fragment, &action) {
        return true;
    }
    if sound_fragment_matches_door_action(&fragment, &action) {
        return true;
    }
    false
}

pub(in crate::production::workbench::meta::generate) fn sound_fragment_has_high_value_acoustic_detail(
    fragment: &str,
) -> bool {
    [
        "急促",
        "沉重",
        "细碎",
        "凌乱",
        "由远及近",
        "回响",
        "回荡",
        "吱呀",
        "砰",
        "轰",
        "巨响",
        "闷响",
        "脆响",
        "刺耳",
        "低鸣",
        "风声",
        "雨声",
        "滴答",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn sound_fragment_is_low_signal_ambient(
    fragment: &str,
) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || sound_fragment_has_high_value_acoustic_detail(&normalized) {
        return false;
    }

    let generic_ambient = [
        "背景音乐",
        "音乐渐起",
        "配乐渐起",
        "氛围音乐",
        "一片死寂",
        "四周死寂",
        "四周寂静",
        "周围寂静",
        "环境安静",
        "安静无声",
        "空气凝固",
        "气氛压抑",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword));
    if !generic_ambient {
        return false;
    }

    ![
        "风声", "雨声", "脚步", "足音", "门", "敲", "回响", "回荡", "滴答", "雷声", "水声",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn sound_fragment_matches_footstep_action(
    fragment: &str,
    action: &str,
) -> bool {
    (fragment.contains("脚步") || fragment.contains("足音"))
        && [
            "走近", "逼近", "靠近", "走来", "奔来", "跑来", "冲来", "踏入", "闯入", "离开", "走开",
            "退开",
        ]
        .iter()
        .any(|keyword| action.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn sound_fragment_matches_door_action(
    fragment: &str,
    action: &str,
) -> bool {
    let is_door_sound = [
        "敲门声",
        "敲门",
        "门响",
        "开门声",
        "关门声",
        "门被推开",
        "门被拉开",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword));
    is_door_sound
        && ["推门", "开门", "关门", "拉门", "夺门", "闯入"]
            .iter()
            .any(|keyword| action.contains(keyword))
}
