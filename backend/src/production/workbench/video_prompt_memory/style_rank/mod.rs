//! Video style note ranking and selection.

mod aggregate;
mod score;

use super::style_compact::collapse_local_framing_stable_tracking;
use super::*;
// Import all items from submodules for internal use
use aggregate::*;
use score::*;

// Re-export functions needed by other modules in video_prompt_memory
pub(super) use aggregate::{
    build_style_note_selection_context, extract_selected_memory_style_note_for_storyboard,
    selected_video_style_value_from_content,
};
pub(super) use score::{
    is_local_framing_only_fragment, score_style_note_context_evidence,
    style_note_selection_context_is_empty,
};

pub(crate) fn select_prioritized_video_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let context = build_style_note_selection_context(storyboard_row);
    let subject_candidates = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let mut candidates = collect_ranked_video_style_note_candidates(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        &subject_candidates,
    )
    .into_iter()
    .filter(|candidate| ranked_style_note_is_worth_recalling(candidate, &context))
    .collect::<Vec<_>>();
    if style_note_selection_context_is_empty(&context) {
        return candidates
            .into_iter()
            .filter_map(|candidate| {
                compact_video_style_prompt_note(&candidate.note)
                    .map(|note| collapse_local_framing_stable_tracking(&note))
                    .filter(|note| !note.is_empty())
            })
            .max_by(|a, b| {
                score_selected_video_style_note(a)
                    .cmp(&score_selected_video_style_note(b))
                    .then(
                        count_selected_video_style_axes(a).cmp(&count_selected_video_style_axes(b)),
                    )
                    .then(b.chars().count().cmp(&a.chars().count()))
                    .then(b.cmp(a))
            });
    }
    let locked_storyboard_focus = candidates
        .iter()
        .map(|candidate| candidate.storyboard_focus)
        .max()
        .unwrap_or(0);
    if locked_storyboard_focus > 0 {
        candidates.retain(|candidate| candidate.storyboard_focus == locked_storyboard_focus);
    }
    let locked_subject_priority = candidates
        .iter()
        .map(|candidate| candidate.subject_priority)
        .min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        if locked_subject_priority != usize::MAX {
            candidates.retain(|candidate| candidate.subject_priority == locked_subject_priority);
        }
    }
    candidates.sort_by(|a, b| {
        b.storyboard_focus
            .cmp(&a.storyboard_focus)
            .then(a.subject_priority.cmp(&b.subject_priority))
            .then(score_ranked_style_note(b, &context).cmp(&score_ranked_style_note(a, &context)))
            .then(a.note.chars().count().cmp(&b.note.chars().count()))
            .then(b.score.cmp(&a.score))
            .then(a.recency_idx.cmp(&b.recency_idx))
            .then(a.note.cmp(&b.note))
    });
    candidates.into_iter().find_map(|candidate| {
        compact_video_style_prompt_note(&candidate.note)
            .map(|note| collapse_local_framing_stable_tracking(&note))
            .filter(|note| !note.is_empty())
    })
}

#[allow(dead_code)]
pub(crate) fn select_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_selected_video_memory_notes_for_storyboard(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        None,
    )
}

pub(crate) fn select_selected_video_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 {
        return Vec::new();
    }
    let should_prefer_delivery = should_prefer_selected_delivery_for_storyboard(storyboard_row);
    let allow_unseeded_fallback = !has_exact_prompt_seed_memory_match(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[SELECTED_VIDEO_MEMORY_NAME],
    );
    let mut style_notes = Vec::new();
    let mut fallback_notes = Vec::new();
    for row in rows {
        if row.name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        if !memory_matches_storyboard(&row.content, storyboard_numeric_id) {
            continue;
        }
        if !memory_matches_prompt_seed_with_fallback(
            &row.content,
            current_prompt_seed,
            allow_unseeded_fallback,
        ) {
            continue;
        }
        if should_prefer_delivery {
            if let Some(note) = selected_video_delivery_value_from_content(&row.content) {
                if style_notes.iter().all(|existing| existing != &note) {
                    style_notes.push(note);
                }
                continue;
            }
        }
        if let Some(note) = selected_video_style_value(row) {
            if style_notes.iter().all(|existing| existing != &note) {
                style_notes.push(note);
            }
            continue;
        }

        let Some(note) = extract_key_value(&row.content, "note")
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
            .filter(|value| !is_low_signal_selected_memory_note(value))
        else {
            continue;
        };
        if fallback_notes.iter().all(|existing| existing != &note) {
            fallback_notes.push(note);
        }
    }

    if let Some(note) = select_best_selected_video_style_note(style_notes) {
        return vec![note];
    }
    fallback_notes.into_iter().take(1).collect()
}

#[allow(dead_code)]
pub(crate) fn select_neighbor_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    limit: usize,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 || limit == 0 {
        return Vec::new();
    }
    let mut scored = rows
        .iter()
        .enumerate()
        .filter_map(|(idx, row)| {
            if row.name != SELECTED_VIDEO_MEMORY_NAME {
                return None;
            }
            let storyboard_ids = extract_storyboard_ids(&row.content);
            if storyboard_ids.is_empty() || storyboard_ids.contains(&storyboard_numeric_id) {
                return None;
            }
            let distance = storyboard_ids
                .iter()
                .map(|id| (storyboard_numeric_id - *id).abs())
                .min()?;
            let note = extract_key_value(&row.content, "style")
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                .or_else(|| {
                    extract_key_value(&row.content, "note").and_then(|value| {
                        let fragments = value
                            .split(['，', ',', '；', ';', '。', '\n'])
                            .map(normalize_prompt_text)
                            .filter(|fragment| {
                                STYLE_NOTE_PREFIXES
                                    .iter()
                                    .any(|prefix| fragment.starts_with(prefix))
                            })
                            .collect::<Vec<_>>();
                        if fragments.is_empty() {
                            None
                        } else {
                            Some(clip_prompt_fragment(
                                &fragments.join("，"),
                                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                            ))
                        }
                    })
                })
                .or_else(|| selected_video_style_value(row))?;
            Some((distance, idx, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));

    let mut notes = Vec::new();
    for (_, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= limit {
            break;
        }
    }
    notes
}
