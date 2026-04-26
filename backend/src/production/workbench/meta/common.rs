pub(crate) use crate::production::workbench::video_prompt_memory::{
    clip_prompt_fragment, extract_key_value, normalize_prompt_text, parse_positive_int,
    parse_structured_storyboard_description, StoryboardPromptSeedRow,
    StructuredStoryboardDescription,
};

pub(crate) fn negative_constraint_conflicts_with_storyboard_style(
    constraint: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    let normalized_constraint = constraint.trim();
    if normalized_constraint.is_empty() {
        return false;
    }

    selected_style_note.is_some_and(|note| {
        negative_constraint_conflicts_with_style_note(normalized_constraint, note)
    }) || storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| {
            negative_constraint_conflicts_with_storyboard_context(normalized_constraint, &fields)
        })
}

fn negative_constraint_conflicts_with_style_note(constraint: &str, style_note: &str) -> bool {
    let note = style_note.trim();
    if note.is_empty() {
        return false;
    }

    if negative_constraint_targets_close_up(constraint) {
        return note.contains("近景") || note.contains("特写");
    }
    if negative_constraint_targets_extreme_angle(constraint) {
        return note.contains("低机位") || note.contains("高机位");
    }
    if negative_constraint_targets_cold_oppressive_mood(constraint) {
        return note.contains("压迫") || note.contains("紧张") || note.contains("冷峻");
    }
    if negative_constraint_targets_cold_emotional_tone(constraint) {
        return note.contains("冷调") || note.contains("冷色") || note.contains("冷峻");
    }
    if negative_constraint_targets_cold_lighting(constraint) {
        return note.contains("光影")
            && (note.contains("冷调") || note.contains("冷光") || note.contains("逆光"));
    }
    if negative_constraint_targets_backlight(constraint) {
        return note.contains("光影")
            && (note.contains("逆光") || note.contains("背光") || note.contains("剪影"));
    }

    false
}

fn negative_constraint_conflicts_with_storyboard_context(
    constraint: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    if negative_constraint_targets_close_up(constraint) {
        return fields.shot.contains("近景") || fields.shot.contains("特写");
    }
    if negative_constraint_targets_extreme_angle(constraint) {
        return fields.shot.contains("低机位")
            || fields.shot.contains("高机位")
            || fields.camera_move.contains("低机位")
            || fields.camera_move.contains("高机位");
    }
    if negative_constraint_targets_cold_oppressive_mood(constraint) {
        return fields.mood.contains("压迫")
            || fields.mood.contains("紧张")
            || fields.mood.contains("冷峻");
    }
    if negative_constraint_targets_cold_emotional_tone(constraint) {
        return fields.mood.contains("冷调")
            || fields.mood.contains("冷色")
            || fields.mood.contains("冷峻")
            || fields.lighting.contains("冷调")
            || fields.lighting.contains("冷光");
    }
    if negative_constraint_targets_cold_lighting(constraint) {
        return fields.lighting.contains("冷调")
            || fields.lighting.contains("冷光")
            || fields.lighting.contains("逆光")
            || fields.lighting.contains("背光");
    }
    if negative_constraint_targets_backlight(constraint) {
        return fields.lighting.contains("逆光")
            || fields.lighting.contains("背光")
            || fields.lighting.contains("剪影");
    }

    false
}

fn negative_constraint_targets_close_up(constraint: &str) -> bool {
    constraint == "avoid overly tight close-up framing"
}

fn negative_constraint_targets_extreme_angle(constraint: &str) -> bool {
    constraint == "avoid extreme camera angle"
}

fn negative_constraint_targets_cold_oppressive_mood(constraint: &str) -> bool {
    constraint == "avoid oppressive or frantic mood"
        || constraint == "avoid overly cold, oppressive, or frantic mood"
}

fn negative_constraint_targets_cold_emotional_tone(constraint: &str) -> bool {
    constraint == "avoid overly cold emotional tone"
        || constraint == "avoid overly cold, oppressive, or frantic mood"
}

fn negative_constraint_targets_cold_lighting(constraint: &str) -> bool {
    constraint == "avoid flat cold lighting"
        || constraint == "avoid flat cold lighting or harsh backlight silhouette"
}

fn negative_constraint_targets_backlight(constraint: &str) -> bool {
    constraint == "avoid harsh backlight silhouette"
        || constraint == "avoid flat cold lighting or harsh backlight silhouette"
}
