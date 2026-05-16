use super::style_rank::{
    build_style_note_selection_context, score_style_note_context_evidence,
    style_note_selection_context_is_empty,
};
use super::*;

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_script_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    select_script_video_style_memory_notes_for_storyboard(rows, None)
}

pub(crate) fn select_script_video_style_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    rows.iter()
        .filter(|row| {
            matches!(
                row.name.as_str(),
                SCRIPT_VIDEO_STYLE_MEMORY_NAME | SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME
            )
        })
        .filter_map(|row| contextual_style_memory_value_for_storyboard(row, storyboard_row))
        .take(1)
        .collect()
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_project_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    select_project_video_style_memory_notes_for_storyboard(rows, None)
}

pub(crate) fn select_project_video_style_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    rows.iter()
        .filter(|row| {
            matches!(
                row.name.as_str(),
                PROJECT_VIDEO_STYLE_MEMORY_NAME | PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME
            )
        })
        .filter_map(|row| contextual_style_memory_value_for_storyboard(row, storyboard_row))
        .take(1)
        .collect()
}

pub(crate) fn select_subject_role_video_style_memory_notes(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
) -> Vec<String> {
    select_subject_role_video_style_memory_notes_for_storyboard(rows, subject_candidates, None)
}

pub(crate) fn select_subject_role_video_style_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let subject_candidates = subject_candidates
        .iter()
        .map(|value| normalize_prompt_text(value))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    if subject_candidates.is_empty() {
        return Vec::new();
    }

    let context = build_style_note_selection_context(storyboard_row);
    let mut matches = rows
        .iter()
        .filter(|row| {
            matches!(
                row.name.as_str(),
                SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME | PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME
            )
        })
        .filter(|row| {
            let memory_subjects = role_memory_subject_candidates(&row.content);
            !memory_subjects.is_empty()
                && memory_subjects.iter().any(|memory_subject| {
                    subject_candidates.iter().any(|candidate| {
                        candidate == memory_subject
                            || candidate.contains(memory_subject)
                            || memory_subject.contains(candidate)
                    })
                })
        })
        .filter_map(|row| {
            role_style_memory_value_for_storyboard(row, storyboard_row).map(|note| {
                let evidence_note = selected_video_style_value(row).unwrap_or_else(|| note.clone());
                let storyboard_focus =
                    role_style_storyboard_focus_score(&row.content, storyboard_row);
                let subject_priority =
                    memory_subject_match_priority(&row.content, &subject_candidates);
                let evidence = score_role_style_note_context_evidence(
                    &evidence_note,
                    row.name.as_str(),
                    &context,
                );
                let min_evidence =
                    role_style_memory_min_context_evidence(row.name.as_str(), &context);
                (
                    evidence >= min_evidence,
                    (
                        storyboard_focus,
                        subject_priority,
                        role_style_memory_scope_priority(row.name.as_str()),
                        evidence,
                        role_style_memory_sample_count(&row.content),
                        note,
                    ),
                )
            })
        })
        .filter(|(passes_context_gate, _)| *passes_context_gate)
        .map(|(_, candidate)| candidate)
        .collect::<Vec<_>>();
    let locked_storyboard_focus = matches.iter().map(|entry| entry.0).max().unwrap_or(0);
    if locked_storyboard_focus > 0 {
        matches.retain(|entry| entry.0 == locked_storyboard_focus);
    }
    let locked_subject_priority = matches.iter().map(|entry| entry.1).min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        matches.retain(|entry| entry.1 == locked_subject_priority);
    }
    matches.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.2.cmp(&b.2))
            .then(b.3.cmp(&a.3))
            .then(b.4.cmp(&a.4))
            .then(a.5.len().cmp(&b.5.len()))
    });
    merge_subject_role_style_memory_notes(matches)
}

fn role_style_memory_scope_priority(name: &str) -> u8 {
    match name {
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => 0,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => 1,
        _ => 2,
    }
}

fn role_style_memory_sample_count(content: &str) -> usize {
    extract_key_value(content, "sampleCount")
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
}

pub(super) fn role_style_storyboard_focus_score(
    content: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> usize {
    let Some(storyboard_row) = storyboard_row else {
        return 0;
    };
    let memory_subjects = role_memory_subject_candidates(content);
    if memory_subjects.is_empty() {
        return 0;
    }

    let prompt = storyboard_row
        .prompt
        .as_deref()
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let fields = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    let action = fields
        .as_ref()
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let dialogue = fields
        .as_ref()
        .map(|fields| normalize_prompt_text(&fields.dialogue))
        .unwrap_or_default();

    memory_subjects
        .into_iter()
        .map(|memory_subject| {
            usize::from(!action.is_empty() && action.contains(&memory_subject)) * 4
                + usize::from(!dialogue.is_empty() && dialogue.contains(&memory_subject)) * 2
                + usize::from(!prompt.is_empty() && prompt.contains(&memory_subject))
        })
        .max()
        .unwrap_or(0)
}

fn merge_subject_role_style_memory_notes(
    matches: Vec<(usize, usize, u8, usize, usize, String)>,
) -> Vec<String> {
    let mut merged_fragments = Vec::<String>::new();
    let mut fallback_note = None;
    let has_script_scope = matches
        .iter()
        .any(|(_, _, scope_priority, _, _, _)| *scope_priority == 0);

    for (_, _, scope_priority, _, sample_count, note) in matches {
        let compacted = compact_video_style_prompt_note(&note).unwrap_or(note);
        if fallback_note.is_none() {
            fallback_note = Some(compacted.clone());
        }

        for fragment in split_prompt_note_fragments(&compacted) {
            if has_script_scope
                && scope_priority > 0
                && role_style_project_fill_fragment_is_low_support(fragment.as_str(), sample_count)
            {
                continue;
            }
            if has_script_scope
                && scope_priority > 0
                && role_style_fragments_have_high_value_signal(&merged_fragments)
                && role_style_fragment_is_low_gain_carryover(fragment.as_str())
            {
                continue;
            }
            if !role_memory_fragment_is_character_signal(fragment.as_str())
                || merged_fragments
                    .iter()
                    .any(|existing| role_style_fragment_conflicts_or_overlaps(existing, &fragment))
            {
                continue;
            }
            merged_fragments.push(fragment);
        }
    }

    if merged_fragments.is_empty() {
        return fallback_note.into_iter().collect();
    }

    compact_video_style_prompt_note(&merged_fragments.join("，"))
        .or(fallback_note)
        .into_iter()
        .collect()
}

pub(super) fn role_style_memory_min_context_evidence(
    name: &str,
    context: &StyleNoteSelectionContext,
) -> usize {
    if style_note_selection_context_is_empty(context) {
        return 0;
    }

    match name {
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => 1,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => 2,
        _ => usize::MAX,
    }
}

pub(super) fn score_role_style_note_context_evidence(
    note: &str,
    source_name: &str,
    context: &StyleNoteSelectionContext,
) -> usize {
    if style_note_selection_context_is_empty(context) {
        return 0;
    }

    let ranked = RankedStyleNote {
        note: note.to_string(),
        context_note: note.to_string(),
        score: 0,
        recency_idx: 0,
        source_name: source_name.to_string(),
        storyboard_distance: None,
        storyboard_focus: 0,
        subject_priority: usize::MAX,
    };
    score_style_note_context_evidence(&ranked, context)
}

fn role_style_fragment_conflicts_or_overlaps(existing: &str, candidate: &str) -> bool {
    if existing == candidate {
        return true;
    }

    let existing_family = role_style_fragment_family(existing);
    let candidate_family = role_style_fragment_family(candidate);
    if existing_family.is_some() && existing_family == candidate_family {
        return true;
    }

    existing.contains(candidate) || candidate.contains(existing)
}

fn role_style_fragment_family(fragment: &str) -> Option<&'static str> {
    for prefix in [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ] {
        if fragment.starts_with(prefix) {
            return Some(prefix);
        }
    }
    None
}

fn role_style_project_fill_fragment_is_low_support(fragment: &str, sample_count: usize) -> bool {
    sample_count < 4 && role_style_fragment_prefers_strong_support(fragment)
}

fn role_style_fragment_prefers_strong_support(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }

    if let Some(value) = normalized.strip_prefix("动作") {
        return matches!(
            normalize_prompt_text(value).as_str(),
            "从容克制" | "克制自然" | "自然" | "缓慢" | "轻盈" | "利落"
        );
    }
    if let Some(value) = normalized.strip_prefix("语气") {
        return matches!(
            normalize_prompt_text(value).as_str(),
            "轻声克制" | "低声克制" | "轻声" | "低声" | "短促"
        );
    }
    if let Some(value) = normalized.strip_prefix("情绪") {
        return matches!(
            normalize_prompt_text(value).as_str(),
            "克制" | "隐忍" | "压抑" | "沉静" | "冷静"
        );
    }

    false
}

fn role_style_fragment_is_low_gain_carryover(fragment: &str) -> bool {
    if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
        return selected_style_fragment_is_low_gain_voice(&voice);
    }
    if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
        return selected_style_fragment_is_generic_restrained_mood(&mood);
    }
    if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
        return selected_style_fragment_is_low_gain_motion(&action);
    }
    false
}

fn role_style_fragments_have_high_value_signal(fragments: &[String]) -> bool {
    fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            || fragment
                .strip_prefix("语气")
                .map(normalize_prompt_text)
                .is_some_and(|voice| !selected_style_fragment_is_low_gain_voice(&voice))
            || fragment
                .strip_prefix("情绪")
                .map(normalize_prompt_text)
                .is_some_and(|mood| !selected_style_fragment_is_generic_restrained_mood(&mood))
            || fragment
                .strip_prefix("动作")
                .map(normalize_prompt_text)
                .is_some_and(|action| !selected_style_fragment_is_low_gain_motion(&action))
    })
}
