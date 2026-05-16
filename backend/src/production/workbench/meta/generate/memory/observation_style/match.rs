use super::super::*;

pub(in crate::production::workbench::meta::generate) fn observation_style_note_context_evidence(
    style_note: &str,
    context: &StructuredStoryboardDescription,
) -> usize {
    let note = normalize_prompt_text(style_note);
    let mut evidence = 0usize;

    let mood = normalize_prompt_text(&context.mood);
    if (!mood.is_empty() && note.contains(&mood))
        || style_note_matches_mood_keyword(&note, &context.mood)
    {
        evidence += 1;
    }

    let lighting = normalize_prompt_text(&context.lighting);
    if !lighting.is_empty() && note.contains(&lighting) {
        evidence += 1;
    }

    let shot = normalize_prompt_text(&context.shot);
    let camera_move = normalize_prompt_text(&context.camera_move);
    if (!shot.is_empty() && note.contains(&shot))
        || (!camera_move.is_empty() && note.contains(&camera_move))
    {
        evidence += 1;
    }

    let action = normalize_prompt_text(&context.action);
    let dialogue = normalize_prompt_text(&context.dialogue);
    if style_note_matches_shared_keyword_family(
        &note,
        &[action.as_str(), dialogue.as_str()],
        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    ) {
        evidence += 1;
    }
    if style_note_matches_shared_keyword_family(
        &note,
        &[action.as_str(), dialogue.as_str()],
        VOICE_SHARED_KEYWORD_FAMILIES,
    ) {
        evidence += 1;
    }

    let sound = normalize_prompt_text(&context.sound);
    if style_note_matches_shared_keyword_family(
        &note,
        &[sound.as_str()],
        SOUND_SHARED_KEYWORD_FAMILIES,
    ) || (!sound.is_empty() && note.contains(&sound))
    {
        evidence += 1;
    }

    evidence
}

pub(in crate::production::workbench::meta::generate) fn style_note_matches_shared_keyword_family(
    note: &str,
    fields: &[&str],
    families: &[&[&str]],
) -> bool {
    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    !normalized_fields.is_empty()
        && families.iter().any(|family| {
            family.iter().any(|keyword| note.contains(keyword))
                && normalized_fields
                    .iter()
                    .any(|field| family.iter().any(|keyword| field.contains(keyword)))
        })
}

pub(in crate::production::workbench::meta::generate) fn style_note_matches_mood_keyword(
    note: &str,
    mood: &str,
) -> bool {
    let normalized_mood = normalize_prompt_text(mood);
    !normalized_mood.is_empty()
        && ["克制", "隐忍", "压抑", "平静", "冷静", "从容", "沉静"]
            .iter()
            .any(|keyword| normalized_mood.contains(keyword) && note.contains(keyword))
}

#[cfg_attr(not(test), allow(dead_code))]
pub(in crate::production::workbench::meta::generate) fn video_prompt_observation_conflicts_with_style(
    observation_note: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    negative_constraint_conflicts_with_storyboard_style(
        observation_note.trim(),
        selected_style_note,
        storyboard_row,
    )
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_observation_is_irrelevant_to_storyboard(
    observation_note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    canonical_observation_note(observation_note) == "avoid lip-sync mismatch"
        && storyboard_row.is_some_and(storyboard_lacks_visible_speech_performance_risk)
}
