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
    if negative_constraint_targets_oppressive_mood(constraint) {
        return note.contains("压迫") || note.contains("紧张") || note.contains("冷峻");
    }
    if negative_constraint_targets_frantic_mood(constraint) {
        return note.contains("惊慌")
            || note.contains("崩溃")
            || note.contains("失控")
            || note.contains("怒吼")
            || note.contains("慌乱");
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
    if negative_constraint_targets_handheld_motion(constraint) {
        return note.contains("手持");
    }
    if negative_constraint_targets_stable_follow_camera(constraint) {
        return note.contains("稳定跟拍")
            || note.contains("跟拍")
            || note.contains("推进")
            || note.contains("慢推");
    }
    if negative_constraint_targets_neon_reflections(constraint) {
        return note.contains("霓虹") || note.contains("反光");
    }
    if negative_constraint_targets_tragic_mood(constraint) {
        return note.contains("悲怆");
    }
    if negative_constraint_targets_blank_expression_or_monotone_delivery(constraint) {
        return style_note_has_specific_performance_direction(note);
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
    if negative_constraint_targets_oppressive_mood(constraint) {
        return fields.mood.contains("压迫")
            || fields.mood.contains("紧张")
            || fields.mood.contains("冷峻");
    }
    if negative_constraint_targets_frantic_mood(constraint) {
        return fields.mood.contains("惊慌")
            || fields.mood.contains("崩溃")
            || fields.mood.contains("失控")
            || fields.mood.contains("慌乱")
            || fields.action.contains("狂奔")
            || fields.action.contains("冲")
            || fields.action.contains("扑")
            || fields.dialogue.contains("怒吼");
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
    if negative_constraint_targets_handheld_motion(constraint) {
        return fields.camera_move.contains("手持");
    }
    if negative_constraint_targets_stable_follow_camera(constraint) {
        return fields.camera_move.contains("稳定跟拍")
            || fields.camera_move.contains("跟拍")
            || fields.camera_move.contains("推进")
            || fields.camera_move.contains("慢推");
    }
    if negative_constraint_targets_neon_reflections(constraint) {
        return fields.lighting.contains("霓虹")
            || fields.lighting.contains("反光")
            || fields.setting.contains("霓虹");
    }
    if negative_constraint_targets_tragic_mood(constraint) {
        return fields.mood.contains("悲怆");
    }

    false
}

fn negative_constraint_targets_close_up(constraint: &str) -> bool {
    constraint == "avoid overly tight close-up framing"
}

fn negative_constraint_targets_extreme_angle(constraint: &str) -> bool {
    constraint == "avoid extreme camera angle"
}

fn negative_constraint_targets_oppressive_mood(constraint: &str) -> bool {
    constraint == "avoid oppressive mood"
        || constraint == "avoid oppressive or frantic mood"
        || constraint == "avoid overly cold, oppressive, or frantic mood"
}

fn negative_constraint_targets_frantic_mood(constraint: &str) -> bool {
    constraint == "avoid frantic mood"
        || constraint == "avoid oppressive or frantic mood"
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

fn negative_constraint_targets_handheld_motion(constraint: &str) -> bool {
    constraint == "avoid shaky handheld motion"
}

fn negative_constraint_targets_stable_follow_camera(constraint: &str) -> bool {
    constraint == "avoid repeating stable follow camera"
}

fn negative_constraint_targets_neon_reflections(constraint: &str) -> bool {
    constraint == "avoid distracting neon reflections"
}

fn negative_constraint_targets_tragic_mood(constraint: &str) -> bool {
    constraint == "avoid heavy tragic mood"
}

fn negative_constraint_targets_blank_expression_or_monotone_delivery(constraint: &str) -> bool {
    constraint == "avoid blank expression or monotone delivery"
}

fn style_note_has_specific_performance_direction(note: &str) -> bool {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return false;
    }

    let has_specific_performance = normalized.contains("表演")
        && [
            "喉结",
            "吞咽",
            "呼吸",
            "抽气",
            "发颤",
            "眼眶",
            "眼尾",
            "唇线",
            "唇角",
            "眉心",
            "嘴角",
            "下颌",
            "指尖",
            "欲言又止",
            "停顿",
            "抬眼",
            "垂眼",
            "强忍",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword));
    let has_specific_voice = normalized.contains("语气")
        && [
            "哽咽", "失声", "发颤", "抽气", "气息", "换气", "尾音", "压低", "短促",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword));

    has_specific_performance || has_specific_voice
}
