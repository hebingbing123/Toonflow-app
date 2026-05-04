use super::continuity::summarize_recurring_prefixed_fragment;
use super::style_compact::{
    selected_style_fragment_is_low_gain_motion, selected_style_fragment_is_low_gain_voice,
};
use super::*;

pub(super) fn compact_role_recurring_style_fragments(
    fragments: Vec<String>,
    supplements: Vec<String>,
) -> Vec<String> {
    let mut combined = Vec::new();
    for fragment in fragments.into_iter().chain(supplements) {
        if combined.iter().any(|existing| existing == &fragment) {
            continue;
        }
        combined.push(fragment);
    }
    if combined.is_empty() {
        return combined;
    }

    let has_character_signal = combined
        .iter()
        .any(|fragment| role_memory_fragment_is_character_signal(fragment));
    if !has_character_signal {
        return Vec::new();
    }

    let mut filtered = combined
        .into_iter()
        .filter(|fragment| !fragment.starts_with("镜头"))
        .collect::<Vec<_>>();
    compact_role_character_mood_redundancy(&mut filtered);
    filtered
}

pub(super) fn role_memory_fragment_is_character_signal(fragment: &str) -> bool {
    ["动作", "表演", "语气", "情绪"]
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
}

pub(super) fn role_style_supplement_fragments(notes: &[String]) -> Vec<String> {
    summarize_role_voice_fragment(notes).into_iter().collect()
}

pub(super) fn summarize_role_delivery_fragment(notes: &[String]) -> Option<String> {
    let recurring_performance = summarize_recurring_role_performance_fragment(notes);
    let recurring_voice = summarize_role_voice_fragment(notes);

    let delivery = match (recurring_performance.as_deref(), recurring_voice.as_deref()) {
        (Some(performance), Some(voice)) => {
            compact_selected_memory_delivery_style(Some(performance), Some(voice))
                .or(recurring_performance)
                .or(recurring_voice)
        }
        (Some(_), None) => recurring_performance,
        (None, Some(_)) => recurring_voice,
        (None, None) => None,
    };

    delivery.filter(|fragment| global_delivery_fragment_is_high_signal(fragment))
}

pub(super) fn global_delivery_fragment_is_worth_persisting(
    fragment: &str,
    distinct_subject_group_count: usize,
) -> bool {
    if fragment.is_empty() {
        return false;
    }
    if distinct_subject_group_count <= 1 {
        return true;
    }
    global_delivery_fragment_is_high_signal(fragment)
        && global_delivery_fragment_is_cross_subject_worth_persisting(fragment)
}

pub(super) fn global_delivery_fragment_is_cross_subject_worth_persisting(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    normalized.contains("喉结")
        || normalized.contains("唇线")
        || normalized.contains("眉心")
        || normalized.contains("下颌")
        || normalized.contains("呼吸")
        || normalized.contains("发颤")
        || normalized.contains("尾音")
        || normalized.contains("哽咽")
}

pub(super) fn global_delivery_fragment_is_high_signal(fragment: &str) -> bool {
    split_prompt_note_fragments(fragment).any(|fragment| {
        if fragment.starts_with("表演") {
            let keyword_hits = [
                "抬眼",
                "垂眼",
                "眼神",
                "目光",
                "喉结",
                "唇线",
                "眉心",
                "嘴角",
                "下颌",
                "呼吸",
                "停顿",
                "发颤",
                "欲言又止",
                "强忍",
                "哽咽",
            ]
            .iter()
            .filter(|keyword| fragment.contains(**keyword))
            .count();
            let strong_signal = [
                "喉结",
                "唇线",
                "眉心",
                "下颌",
                "呼吸",
                "发颤",
                "欲言又止",
                "强忍",
                "哽咽",
            ]
            .iter()
            .any(|keyword| fragment.contains(*keyword));
            (keyword_hits >= 1 && strong_signal)
                || (keyword_hits >= 2
                    && (fragment.contains("抬眼停顿") || fragment.contains("垂眼停顿")))
        } else if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
            !role_voice_variant_is_low_gain_carryover(&voice)
        } else {
            false
        }
    })
}

pub(super) fn summarize_role_voice_fragment(notes: &[String]) -> Option<String> {
    let recurring_performance = summarize_recurring_role_performance_fragment(notes);
    let mut variants = Vec::<(&str, usize)>::new();

    for note in notes {
        for fragment in split_prompt_note_fragments(note) {
            if !fragment.starts_with("语气") {
                continue;
            }
            if let Some(variant) = summarize_role_voice_variant(&fragment) {
                if let Some((_, count)) = variants
                    .iter_mut()
                    .find(|(existing, _)| *existing == variant)
                {
                    *count += 1;
                } else {
                    variants.push((variant, 1));
                }
            }
        }
    }

    let total_support = variants.iter().map(|(_, count)| *count).sum::<usize>();
    if total_support < 2 {
        return None;
    }

    variants.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then_with(|| role_voice_variant_priority(a.0).cmp(&role_voice_variant_priority(b.0)))
    });
    let best = variants.first()?.0;
    if recurring_performance.is_some() && role_voice_variant_is_low_gain_carryover(best) {
        return None;
    }
    Some(format!("语气{best}"))
}

pub(super) fn summarize_recurring_role_performance_fragment(notes: &[String]) -> Option<String> {
    let parsed = notes
        .iter()
        .map(|note| split_prompt_note_fragments(note).collect::<Vec<_>>())
        .collect::<Vec<_>>();
    summarize_recurring_prefixed_fragment(&parsed, "表演")
}

pub(super) fn role_voice_variant_is_low_gain_carryover(variant: &str) -> bool {
    matches!(variant, "低声克制" | "轻声克制" | "呢喃")
}

pub(super) fn summarize_role_voice_variant(fragment: &str) -> Option<&'static str> {
    if fragment.contains("压低气息尾音发颤") {
        return Some("压低气息尾音发颤");
    }
    if fragment.contains("低声尾音发颤") || (fragment.contains("低声") && fragment.contains("尾音"))
    {
        return Some("低声尾音发颤");
    }
    if fragment.contains("轻声尾音发颤") || (fragment.contains("轻声") && fragment.contains("尾音"))
    {
        return Some("轻声尾音发颤");
    }
    if fragment.contains("哽咽克制") || fragment.contains("哽咽") {
        return Some("哽咽克制");
    }
    if fragment.contains("低声克制") || fragment.contains("低声") {
        return Some("低声克制");
    }
    if fragment.contains("轻声克制") || fragment.contains("轻声") {
        return Some("轻声克制");
    }
    if fragment.contains("呢喃克制") || fragment.contains("呢喃") {
        return Some("呢喃");
    }
    if fragment.contains("短促") {
        return Some("短促");
    }
    None
}

pub(super) fn role_voice_variant_priority(variant: &str) -> usize {
    match variant {
        "压低气息尾音发颤" => 0,
        "低声尾音发颤" => 1,
        "轻声尾音发颤" => 2,
        "哽咽克制" => 3,
        "低声克制" => 4,
        "轻声克制" => 5,
        "呢喃" => 6,
        "短促" => 7,
        _ => usize::MAX,
    }
}

pub(super) fn compact_role_character_mood_redundancy(fragments: &mut Vec<String>) {
    if fragments.len() < 2 {
        return;
    }

    let has_character_performance_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("表演") || fragment.starts_with("语气") || fragment.starts_with("动作")
    });
    if !has_character_performance_signal {
        return;
    }

    fragments.retain(|fragment| {
        let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) else {
            return true;
        };
        !matches!(mood.as_str(), "克制" | "隐忍" | "压抑" | "沉静" | "冷静")
    });

    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    if has_performance_signal {
        fragments.retain(|fragment| {
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_voice(&voice);
            }
            if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_motion(&action);
            }
            true
        });
    }
}
