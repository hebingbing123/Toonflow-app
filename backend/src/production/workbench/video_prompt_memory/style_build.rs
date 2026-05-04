use super::*;

use super::style_compact::{
    selected_style_fragment_is_generic_restrained_mood, selected_style_fragment_is_low_gain_motion,
};
use super::style_notes::{
    distinct_project_selected_video_style_notes, distinct_selected_video_style_notes,
    distinct_selected_video_style_notes_with_subject, recurring_style_fragments,
};
use super::style_role::{
    compact_role_recurring_style_fragments, global_delivery_fragment_is_worth_persisting,
    role_style_supplement_fragments, role_voice_variant_is_low_gain_carryover,
    summarize_role_delivery_fragment,
};

pub(super) fn local_shot_framing_fragment(fragment: &str) -> bool {
    ["低机位", "高机位", "特写", "近景", "中景", "全景", "远景"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn build_script_video_style_memory(
    rows: &[AgentMemoryRow],
    rejected_rows: &[AgentMemoryRow],
) -> Option<String> {
    build_script_video_style_memory_with_bias(rows, rejected_rows, None)
}

pub(super) fn build_script_video_style_memory_with_bias(
    rows: &[AgentMemoryRow],
    rejected_rows: &[AgentMemoryRow],
    optimization_bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let notes = distinct_selected_video_style_notes(rows);
    if notes.len() < 2 {
        return None;
    }
    let distinct_subject_group_count =
        distinct_selected_video_subject_group_count(rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds")
                    .map(|storyboard_id| format!("script:{storyboard_id}")),
                None,
            )
        }));

    let mut recurring = compact_global_recurring_style_fragments(
        recurring_style_fragments(&notes),
        distinct_subject_group_count,
    );
    let rejected_signals = summarize_rejected_style_signals(
        rejected_rows
            .iter()
            .map(|row| (row.name.as_str(), row.content.as_str(), None)),
    );
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    compact_global_character_style_redundancy(&mut recurring);
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    let delivery = summarize_role_delivery_fragment(&notes)
        .filter(|value| {
            global_delivery_fragment_is_worth_persisting(value, distinct_subject_group_count)
        })
        .filter(|value| {
            !delivery_fragment_conflicts_with_rejected_signals(value, &rejected_signals)
        })
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS));
    let style_fragments = compact_global_visual_style_fragments(&recurring, delivery.as_deref());
    let style = clip_prompt_fragment(
        &style_fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    );
    let mut parts = vec![
        format!("sampleCount={}", notes.len()),
        format!("style={style}"),
    ];
    if let Some(delivery) = delivery.filter(|value| value != &style) {
        parts.push(format!("delivery={delivery}"));
    }
    compact_summary_video_style_memory_for_focus(&parts.join(" | "), optimization_bias)
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn build_project_video_style_memory(
    rows: &[ScopedAgentMemoryRow],
    rejected_rows: &[ScopedAgentMemoryRow],
) -> Option<String> {
    build_project_video_style_memory_with_bias(rows, rejected_rows, None)
}

pub(super) fn build_project_video_style_memory_with_bias(
    rows: &[ScopedAgentMemoryRow],
    rejected_rows: &[ScopedAgentMemoryRow],
    optimization_bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let notes = distinct_project_selected_video_style_notes(rows);
    if notes.len() < 3 {
        return None;
    }
    let distinct_subject_group_count =
        distinct_selected_video_subject_group_count(rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                    format!(
                        "{}:{storyboard_id}",
                        row.episodes_id
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "project".to_string())
                    )
                }),
                row.episodes_id.map(|value| value.to_string()),
            )
        }));

    let mut recurring = compact_global_recurring_style_fragments(
        recurring_style_fragments(&notes),
        distinct_subject_group_count,
    );
    let rejected_signals = summarize_rejected_style_signals(
        rejected_rows
            .iter()
            .map(|row| (row.name.as_str(), row.content.as_str(), row.episodes_id)),
    );
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    compact_global_character_style_redundancy(&mut recurring);
    recurring.retain(|fragment| {
        !style_fragment_conflicts_with_rejected_signals(fragment, &rejected_signals)
    });
    if recurring.is_empty() {
        return None;
    }
    let delivery = summarize_role_delivery_fragment(&notes)
        .filter(|value| {
            global_delivery_fragment_is_worth_persisting(value, distinct_subject_group_count)
        })
        .filter(|value| {
            !delivery_fragment_conflicts_with_rejected_signals(value, &rejected_signals)
        })
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS));
    let style_fragments = compact_global_visual_style_fragments(&recurring, delivery.as_deref());
    let style = clip_prompt_fragment(
        &style_fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    );
    let mut parts = vec![
        format!("sampleCount={}", notes.len()),
        format!("style={style}"),
    ];
    if let Some(delivery) = delivery.filter(|value| value != &style) {
        parts.push(format!("delivery={delivery}"));
    }
    compact_summary_video_style_memory_for_focus(&parts.join(" | "), optimization_bias)
}

pub(super) fn build_script_role_video_style_memories(rows: &[AgentMemoryRow]) -> Vec<String> {
    build_role_video_style_memories(rows.iter().map(|row| {
        (
            row.name.as_str(),
            row.content.as_str(),
            extract_key_value(&row.content, "storyboardIds")
                .map(|storyboard_id| format!("script:{storyboard_id}")),
            None,
        )
    }))
}

fn summarize_rejected_style_signals<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<i32>)>,
) -> RejectedStyleSignals {
    let mut signals = RejectedStyleSignals::default();
    for (name, content, _) in rows {
        if name != REJECTED_VIDEO_NEGATIVE_MEMORY_NAME {
            continue;
        }
        let rejection_count = extract_key_value(content, "rejectionCount")
            .and_then(|value| value.parse::<usize>().ok())
            .unwrap_or(1)
            .clamp(1, 4);
        let avoid = extract_key_value(content, "avoid").unwrap_or_default();
        if avoid.is_empty() {
            continue;
        }
        let add = |slot: &mut usize| *slot = slot.saturating_add(rejection_count);
        if avoid.contains("avoid blank expression or monotone delivery")
            || avoid.contains("avoid lip-sync mismatch")
        {
            add(&mut signals.monotone_delivery);
        }
        if avoid.contains("avoid flat cold lighting") {
            add(&mut signals.cold_lighting);
        }
        if avoid.contains("avoid harsh backlight silhouette") {
            add(&mut signals.harsh_backlight);
        }
        if avoid.contains("avoid repeating stable follow camera") {
            add(&mut signals.stable_follow_camera);
        }
        if avoid.contains("avoid shaky handheld motion") {
            add(&mut signals.shaky_handheld);
        }
        if avoid.contains("avoid oppressive mood")
            || avoid.contains("avoid oppressive or frantic mood")
        {
            add(&mut signals.oppressive_mood);
        }
        if avoid.contains("avoid overly cold emotional tone")
            || avoid.contains("avoid overly cold, oppressive, or frantic mood")
        {
            add(&mut signals.cold_emotional_tone);
        }
        if avoid.contains("avoid heavy tragic mood") {
            add(&mut signals.tragic_mood);
        }
    }
    signals
}

fn style_fragment_conflicts_with_rejected_signals(
    fragment: &str,
    signals: &RejectedStyleSignals,
) -> bool {
    if fragment.is_empty() {
        return false;
    }
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }
    if signals.monotone_delivery >= 2
        && (normalized.starts_with("语气低声克制")
            || normalized.starts_with("语气轻声克制")
            || normalized.starts_with("语气呢喃")
            || normalized == "情绪克制"
            || normalized == "情绪隐忍"
            || normalized == "情绪压抑")
    {
        return true;
    }
    if signals.cold_lighting >= 2
        && normalized.starts_with("光影")
        && (normalized.contains("冷调")
            || normalized.contains("冷光")
            || normalized.contains("冷蓝")
            || normalized.contains("冷色"))
    {
        return true;
    }
    if signals.harsh_backlight >= 2
        && normalized.starts_with("光影")
        && (normalized.contains("逆光")
            || normalized.contains("背光")
            || normalized.contains("剪影"))
    {
        return true;
    }
    if signals.stable_follow_camera >= 2
        && normalized.starts_with("镜头")
        && (normalized.contains("稳定跟拍")
            || normalized.contains("跟拍")
            || normalized.contains("推进")
            || normalized.contains("慢推"))
    {
        return true;
    }
    if signals.shaky_handheld >= 2 && normalized.starts_with("镜头") && normalized.contains("手持")
    {
        return true;
    }
    if signals.oppressive_mood >= 2
        && normalized.starts_with("情绪")
        && (normalized.contains("压迫")
            || normalized.contains("紧张")
            || normalized.contains("冷峻"))
    {
        return true;
    }
    if signals.cold_emotional_tone >= 2
        && normalized.starts_with("情绪")
        && (normalized.contains("冷调")
            || normalized.contains("冷色")
            || normalized.contains("冷峻")
            || normalized.contains("冷静"))
    {
        return true;
    }
    if signals.tragic_mood >= 2 && normalized.starts_with("情绪") && normalized.contains("悲怆")
    {
        return true;
    }
    false
}

fn delivery_fragment_conflicts_with_rejected_signals(
    fragment: &str,
    signals: &RejectedStyleSignals,
) -> bool {
    style_fragment_conflicts_with_rejected_signals(fragment, signals)
        || (signals.monotone_delivery >= 2
            && normalize_prompt_text(fragment).contains("克制")
            && !normalize_prompt_text(fragment).contains("发颤")
            && !normalize_prompt_text(fragment).contains("哽咽"))
}

pub(super) fn build_project_role_video_style_memories(
    rows: &[ScopedAgentMemoryRow],
) -> Vec<String> {
    build_role_video_style_memories(rows.iter().map(|row| {
        (
            row.name.as_str(),
            row.content.as_str(),
            extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                format!(
                    "{}:{storyboard_id}",
                    row.episodes_id
                        .map(|value| value.to_string())
                        .unwrap_or_else(|| "project".to_string())
                )
            }),
            row.episodes_id.map(|value| value.to_string()),
        )
    }))
}

fn build_role_video_style_memories<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> Vec<String> {
    #[derive(Default)]
    struct RoleStyleGroup {
        primary_subject: String,
        aliases: Vec<String>,
        notes: Vec<String>,
    }

    let mut grouped = Vec::<RoleStyleGroup>::new();
    for (subject, aliases, note) in distinct_selected_video_style_notes_with_subject(rows) {
        if let Some(existing) = grouped.iter_mut().find(|group| {
            group
                .aliases
                .iter()
                .any(|alias| aliases.iter().any(|candidate| candidate == alias))
        }) {
            if existing.primary_subject.is_empty() {
                existing.primary_subject = subject.clone();
            }
            existing.aliases.extend(aliases);
            existing.aliases.sort();
            existing.aliases.dedup();
            existing.notes.push(note);
            continue;
        }

        grouped.push(RoleStyleGroup {
            primary_subject: subject,
            aliases,
            notes: vec![note],
        });
    }

    grouped
        .into_iter()
        .filter_map(|group| {
            let (style, delivery) = if group.notes.len() >= 2 {
                let recurring = compact_role_recurring_style_fragments(
                    recurring_style_fragments(&group.notes),
                    role_style_supplement_fragments(&group.notes),
                );
                if recurring.is_empty() {
                    return None;
                }
                let style =
                    clip_prompt_fragment(&recurring.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
                let delivery = summarize_role_delivery_fragment(&group.notes)
                    .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                    .filter(|value| value != &style);
                (style, delivery)
            } else {
                let note = group.notes.first()?;
                single_sample_role_style_memory_seed(note)?
            };
            let primary_subject = clip_prompt_fragment(&group.primary_subject, 16);
            let subject_aliases = group
                .aliases
                .iter()
                .filter(|alias| **alias != group.primary_subject)
                .cloned()
                .collect::<Vec<_>>();
            let mut parts = vec![
                format!("subject={primary_subject}"),
                format!("sampleCount={}", group.notes.len()),
            ];
            if !subject_aliases.is_empty() {
                parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
            }
            parts.push(format!("style={style}"));
            if let Some(delivery) = delivery
                .filter(|delivery| role_style_memory_should_persist_delivery(&style, delivery))
            {
                parts.push(format!("delivery={delivery}"));
            }
            Some(parts.join(" | "))
        })
        .collect()
}

fn role_style_memory_should_persist_delivery(style: &str, delivery: &str) -> bool {
    let has_visual_axis = split_prompt_note_fragments(style).any(|fragment| {
        fragment.starts_with("镜头")
            || fragment.starts_with("光影")
            || fragment.starts_with("环境")
            || fragment.starts_with("声场")
    });
    has_visual_axis
        || delivery.contains("尾音")
        || delivery.contains("发颤")
        || delivery.contains("哽咽")
}

fn single_sample_role_style_memory_seed(note: &str) -> Option<(String, Option<String>)> {
    let style = selected_video_delivery_value_from_note(note)
        .or_else(|| compact_video_style_prompt_note(note))
        .filter(|value| single_sample_role_style_seed_is_high_signal(value))?;
    let delivery = selected_video_delivery_value_from_note(note)
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| value != &style)
        .filter(|value| single_sample_role_style_seed_is_high_signal(value));
    Some((style, delivery))
}

fn single_sample_role_style_seed_is_high_signal(note: &str) -> bool {
    split_prompt_note_fragments(note).any(|fragment| {
        if fragment.starts_with("表演") {
            [
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
            .count()
                >= 2
        } else if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
            !role_voice_variant_is_low_gain_carryover(&voice)
        } else if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
            !global_mood_fragment_is_generic_restrained(&mood)
        } else {
            false
        }
    })
}

fn compact_global_recurring_style_fragments(
    fragments: Vec<String>,
    distinct_subject_group_count: usize,
) -> Vec<String> {
    if distinct_subject_group_count < 2 {
        return fragments;
    }

    fragments
        .into_iter()
        .filter(|fragment| {
            !fragment.starts_with("表演")
                && !fragment.starts_with("语气")
                && !fragment.starts_with("声场")
        })
        .collect()
}

fn compact_global_character_style_redundancy(fragments: &mut Vec<String>) {
    if fragments.len() < 2 {
        return;
    }

    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_visual_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("光影") || fragment.starts_with("环境") || fragment.starts_with("镜头")
    });
    if has_performance_signal {
        fragments.retain(|fragment| {
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !global_voice_fragment_is_low_gain_carryover(&voice);
            }
            if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
                return !global_mood_fragment_is_generic_restrained(&mood);
            }
            if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
                return !global_motion_fragment_is_low_gain_carryover(&action);
            }
            if has_visual_signal {
                if let Some(sound) = fragment.strip_prefix("声场").map(normalize_prompt_text) {
                    return !global_sound_fragment_is_low_gain_ambience(&sound);
                }
            }
            true
        });
    }
}

fn compact_global_visual_style_fragments(
    fragments: &[String],
    delivery: Option<&str>,
) -> Vec<String> {
    if delivery.is_none() {
        return fragments.to_vec();
    }
    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_visual_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("光影") || fragment.starts_with("环境") || fragment.starts_with("镜头")
    });

    let filtered = fragments
        .iter()
        .filter(|fragment| {
            !fragment.starts_with("表演")
                && !fragment.starts_with("语气")
                && !(fragment.starts_with("声场")
                    && has_performance_signal
                    && has_visual_signal
                    && fragment
                        .strip_prefix("声场")
                        .map(normalize_prompt_text)
                        .is_some_and(|sound| global_sound_fragment_is_low_gain_ambience(&sound)))
                && !(fragment.starts_with("情绪")
                    && fragment
                        .strip_prefix("情绪")
                        .map(normalize_prompt_text)
                        .is_some_and(|mood| {
                            selected_style_fragment_is_generic_restrained_mood(&mood)
                        }))
                && !(fragment.starts_with("动作")
                    && fragment
                        .strip_prefix("动作")
                        .map(normalize_prompt_text)
                        .is_some_and(|action| selected_style_fragment_is_low_gain_motion(&action)))
        })
        .cloned()
        .collect::<Vec<_>>();

    if filtered.is_empty() {
        fragments.to_vec()
    } else {
        filtered
    }
}

fn global_voice_fragment_is_low_gain_carryover(voice: &str) -> bool {
    matches!(voice, "低声克制" | "轻声克制" | "呢喃")
}

fn global_mood_fragment_is_generic_restrained(mood: &str) -> bool {
    matches!(mood, "克制" | "隐忍" | "压抑" | "沉静" | "冷静")
}

fn global_motion_fragment_is_low_gain_carryover(action: &str) -> bool {
    matches!(action, "从容克制" | "克制自然" | "自然" | "简洁平滑")
}

fn global_sound_fragment_is_low_gain_ambience(sound: &str) -> bool {
    matches!(sound, "雨声回响" | "风声回荡" | "车流闷响" | "水滴回声")
}

fn distinct_selected_video_subject_group_count<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> usize {
    let mut groups = Vec::<Vec<String>>::new();
    for (_, aliases, _) in distinct_selected_video_style_notes_with_subject(rows) {
        if groups.iter().any(|existing| {
            existing
                .iter()
                .any(|alias| aliases.iter().any(|candidate| candidate == alias))
        }) {
            continue;
        }
        groups.push(aliases);
    }
    groups.len()
}
