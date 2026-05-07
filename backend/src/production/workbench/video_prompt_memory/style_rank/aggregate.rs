//! Aggregation and ranking logic for video style notes.

use super::super::style_role_select::role_style_storyboard_focus_score;
use super::super::*;

pub(in super::super) fn build_style_note_selection_context(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> StyleNoteSelectionContext {
    let description = storyboard_row
        .and_then(|row| {
            row.video_desc
                .as_deref()
                .map(normalize_prompt_text)
                .filter(|text| !text.is_empty())
                .or_else(|| {
                    row.prompt
                        .as_deref()
                        .map(normalize_prompt_text)
                        .filter(|text| !text.is_empty())
                })
        })
        .unwrap_or_default();
    let fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    StyleNoteSelectionContext {
        description,
        subject: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.subject))
            .unwrap_or_default(),
        action: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.action))
            .unwrap_or_default(),
        shot: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.shot))
            .unwrap_or_default(),
        camera_move: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.camera_move))
            .unwrap_or_default(),
        mood: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.mood))
            .unwrap_or_default(),
        lighting: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.lighting))
            .unwrap_or_default(),
        dialogue: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.dialogue))
            .unwrap_or_default(),
        sound: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.sound))
            .unwrap_or_default(),
    }
}

pub(in super::super) fn collect_ranked_video_style_note_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    _current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
) -> Vec<RankedStyleNote> {
    let mut candidates = Vec::new();
    for (idx, row) in rows.iter().enumerate() {
        let (base_score, note, context_note) = match row.name.as_str() {
            SELECTED_VIDEO_MEMORY_NAME => {
                if !memory_row_is_neighbor_selected_style(row, storyboard_numeric_id) {
                    continue;
                }
                let note = extract_selected_memory_style_note_for_storyboard(row, storyboard_row);
                (120, note, selected_video_style_value(row))
            }
            SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
                let note = generation_brief_style_memory_value(row);
                (96, note.clone(), note)
            }
            SCRIPT_VIDEO_STYLE_MEMORY_NAME => {
                let note = extract_style_note_value(row);
                (90, note.clone(), note)
            }
            SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => (
                102,
                role_style_memory_value_for_storyboard(row, storyboard_row),
                selected_video_style_value(row),
            ),
            PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
                let note = generation_brief_style_memory_value(row);
                (76, note.clone(), note)
            }
            PROJECT_VIDEO_STYLE_MEMORY_NAME => {
                let note = extract_style_note_value(row);
                (70, note.clone(), note)
            }
            PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => (
                82,
                role_style_memory_value_for_storyboard(row, storyboard_row),
                selected_video_style_value(row),
            ),
            _ => continue,
        };
        let Some(note) = note else {
            continue;
        };
        let context_note = context_note.unwrap_or_else(|| note.clone());
        let sample_count = extract_key_value(&row.content, "sampleCount")
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(1)
            .clamp(1, 8);
        candidates.push(RankedStyleNote {
            note,
            context_note,
            score: base_score + sample_count * 4,
            recency_idx: idx,
            source_name: row.name.clone(),
            storyboard_distance: (row.name == SELECTED_VIDEO_MEMORY_NAME)
                .then(|| {
                    storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                })
                .flatten(),
            storyboard_focus: role_style_storyboard_focus_score(&row.content, storyboard_row),
            subject_priority: memory_subject_match_priority(&row.content, subject_candidates),
        });
    }
    candidates
}

fn memory_row_is_neighbor_selected_style(row: &AgentMemoryRow, storyboard_numeric_id: i32) -> bool {
    let storyboard_ids = extract_storyboard_ids(&row.content);
    !storyboard_ids.is_empty() && !storyboard_ids.contains(&storyboard_numeric_id)
}

fn extract_style_note_value(row: &AgentMemoryRow) -> Option<String> {
    selected_video_style_value_from_content(&row.content)
}

pub(in super::super) fn extract_selected_memory_style_note_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    if should_prefer_selected_delivery_for_storyboard(storyboard_row) {
        if let Some(delivery) = selected_video_delivery_value_from_content(&row.content) {
            return Some(delivery);
        }
    }
    selected_video_style_value(row)
}

pub(in super::super) fn selected_video_style_value_from_content(content: &str) -> Option<String> {
    if let Some(value) = extract_key_value(content, "style") {
        return compact_video_style_prompt_note(&value);
    }
    extract_key_value(content, "note")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}
