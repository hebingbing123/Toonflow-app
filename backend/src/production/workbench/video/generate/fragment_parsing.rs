#[derive(Debug, Default, Clone, Copy)]
pub(super) struct CharacterConsistencyFlags {
    pub(super) face_distortion: bool,
    pub(super) identity_drift: bool,
    pub(super) costume_inconsistency: bool,
}

#[derive(Debug, Default, Clone, Copy)]
pub(super) struct VisualStyleConstraintFlags {
    pub(super) unnecessary_shot_changes: bool,
    pub(super) extreme_camera_angle: bool,
    pub(super) tight_close_up: bool,
    pub(super) oppressive_mood: bool,
    pub(super) frantic_mood: bool,
    pub(super) blank_expression_or_monotone_delivery: bool,
    pub(super) overly_cold_emotional_tone: bool,
    pub(super) flat_cold_lighting: bool,
    pub(super) harsh_backlight_silhouette: bool,
    pub(super) distracting_neon_reflections: bool,
}

#[derive(Debug, Default, Clone, Copy)]
pub(super) struct VisualErrorFlags {
    pub(super) warped_anatomy: bool,
    pub(super) blur: bool,
    pub(super) flicker: bool,
}

pub(super) fn parse_character_consistency_fragment(
    fragment: &str,
) -> Option<CharacterConsistencyFlags> {
    let canonical = canonical_negative_fragment(fragment);
    match canonical.as_str() {
        "avoid face distortion" => Some(CharacterConsistencyFlags {
            face_distortion: true,
            ..Default::default()
        }),
        "avoid identity drift" => Some(CharacterConsistencyFlags {
            identity_drift: true,
            ..Default::default()
        }),
        "avoid costume drift" => Some(CharacterConsistencyFlags {
            costume_inconsistency: true,
            ..Default::default()
        }),
        "avoid face distortion or identity drift" => Some(CharacterConsistencyFlags {
            face_distortion: true,
            identity_drift: true,
            costume_inconsistency: false,
        }),
        "avoid costume or character drift" => Some(CharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        "avoid face drift or costume inconsistency" => Some(CharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        _ => None,
    }
}

pub(super) fn render_character_consistency_fragment(flags: CharacterConsistencyFlags) -> String {
    if flags.face_distortion && flags.costume_inconsistency {
        "avoid face distortion, identity drift, costume drift".to_string()
    } else if flags.face_distortion && flags.identity_drift {
        "avoid face distortion or identity drift".to_string()
    } else if flags.identity_drift && flags.costume_inconsistency {
        "avoid costume or character drift".to_string()
    } else if flags.face_distortion {
        "avoid face distortion".to_string()
    } else if flags.identity_drift {
        "avoid identity drift".to_string()
    } else if flags.costume_inconsistency {
        "avoid costume drift".to_string()
    } else {
        "avoid face distortion or identity drift".to_string()
    }
}

pub(super) fn parse_visual_style_constraint_fragment(
    fragment: &str,
) -> Option<VisualStyleConstraintFlags> {
    let canonical = canonical_negative_fragment(fragment);
    match canonical.as_str() {
        "avoid unnecessary shot changes" => Some(VisualStyleConstraintFlags {
            unnecessary_shot_changes: true,
            ..Default::default()
        }),
        "avoid extra shot changes or wrong framing" => Some(VisualStyleConstraintFlags {
            unnecessary_shot_changes: true,
            extreme_camera_angle: true,
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle" => Some(VisualStyleConstraintFlags {
            extreme_camera_angle: true,
            ..Default::default()
        }),
        "avoid overly tight close-up framing" => Some(VisualStyleConstraintFlags {
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle or overly tight close-up framing" => {
            Some(VisualStyleConstraintFlags {
                extreme_camera_angle: true,
                tight_close_up: true,
                ..Default::default()
            })
        }
        "avoid oppressive or frantic mood" => Some(VisualStyleConstraintFlags {
            oppressive_mood: true,
            frantic_mood: true,
            ..Default::default()
        }),
        "avoid blank expression" => Some(VisualStyleConstraintFlags {
            blank_expression_or_monotone_delivery: true,
            ..Default::default()
        }),
        "avoid monotone delivery" => Some(VisualStyleConstraintFlags {
            blank_expression_or_monotone_delivery: true,
            ..Default::default()
        }),
        "avoid blank expression or monotone delivery" => Some(VisualStyleConstraintFlags {
            blank_expression_or_monotone_delivery: true,
            ..Default::default()
        }),
        "avoid oppressive mood" => Some(VisualStyleConstraintFlags {
            oppressive_mood: true,
            ..Default::default()
        }),
        "avoid frantic mood" => Some(VisualStyleConstraintFlags {
            frantic_mood: true,
            ..Default::default()
        }),
        "avoid overly cold emotional tone" => Some(VisualStyleConstraintFlags {
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid overly cold, oppressive, or frantic mood" => Some(VisualStyleConstraintFlags {
            oppressive_mood: true,
            frantic_mood: true,
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid flat cold lighting" => Some(VisualStyleConstraintFlags {
            flat_cold_lighting: true,
            ..Default::default()
        }),
        "avoid harsh backlight silhouette" => Some(VisualStyleConstraintFlags {
            harsh_backlight_silhouette: true,
            ..Default::default()
        }),
        "avoid distracting neon reflections" => Some(VisualStyleConstraintFlags {
            distracting_neon_reflections: true,
            ..Default::default()
        }),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            Some(VisualStyleConstraintFlags {
                flat_cold_lighting: true,
                harsh_backlight_silhouette: true,
                ..Default::default()
            })
        }
        _ => None,
    }
}

pub(super) fn render_visual_style_constraint_fragments(
    flags: VisualStyleConstraintFlags,
) -> Vec<String> {
    let mut fragments = Vec::new();
    if flags.unnecessary_shot_changes && (flags.extreme_camera_angle || flags.tight_close_up) {
        fragments.push("avoid extra shot changes or wrong framing".to_string());
    } else if flags.unnecessary_shot_changes {
        fragments.push("avoid unnecessary shot changes".to_string());
    } else if flags.extreme_camera_angle && flags.tight_close_up {
        fragments.push("avoid extreme camera angle or overly tight close-up framing".to_string());
    } else if flags.extreme_camera_angle {
        fragments.push("avoid extreme camera angle".to_string());
    } else if flags.tight_close_up {
        fragments.push("avoid overly tight close-up framing".to_string());
    }

    if flags.oppressive_mood && flags.frantic_mood && flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold, oppressive, or frantic mood".to_string());
    } else if flags.oppressive_mood && flags.frantic_mood {
        fragments.push("avoid oppressive or frantic mood".to_string());
    } else if flags.oppressive_mood {
        fragments.push("avoid oppressive mood".to_string());
    } else if flags.frantic_mood {
        fragments.push("avoid frantic mood".to_string());
    } else if flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold emotional tone".to_string());
    }
    if flags.blank_expression_or_monotone_delivery {
        fragments.push("avoid blank expression or monotone delivery".to_string());
    }

    if flags.flat_cold_lighting && flags.harsh_backlight_silhouette {
        fragments.push("avoid flat cold lighting or harsh backlight silhouette".to_string());
    } else if flags.flat_cold_lighting {
        fragments.push("avoid flat cold lighting".to_string());
    } else if flags.harsh_backlight_silhouette {
        fragments.push("avoid harsh backlight silhouette".to_string());
    }
    if flags.distracting_neon_reflections {
        fragments.push("avoid distracting neon reflections".to_string());
    }

    fragments
}

pub(super) fn parse_visual_error_fragment(fragment: &str) -> Option<VisualErrorFlags> {
    match canonical_negative_fragment(fragment).as_str() {
        "avoid warped anatomy, blur, flicker" => Some(VisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            flicker: true,
        }),
        "avoid warped anatomy or blur" => Some(VisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            ..Default::default()
        }),
        "avoid warped hands or limbs" | "avoid warped anatomy" => Some(VisualErrorFlags {
            warped_anatomy: true,
            ..Default::default()
        }),
        "avoid blur" => Some(VisualErrorFlags {
            blur: true,
            ..Default::default()
        }),
        "avoid flicker" | "avoid flicker or motion jitter" => Some(VisualErrorFlags {
            flicker: true,
            ..Default::default()
        }),
        _ => None,
    }
}

#[allow(dead_code)]
pub(super) fn render_visual_error_fragments(flags: VisualErrorFlags) -> Vec<String> {
    if flags.warped_anatomy && flags.blur && flags.flicker {
        return vec!["avoid warped anatomy, blur, flicker".to_string()];
    }
    if flags.warped_anatomy && flags.blur {
        return vec!["avoid warped anatomy or blur".to_string()];
    }

    let mut fragments = Vec::new();
    if flags.warped_anatomy {
        fragments.push("avoid warped hands or limbs".to_string());
    }
    if flags.flicker {
        fragments.push("avoid flicker or motion jitter".to_string());
    }
    if flags.blur {
        fragments.push("avoid blur".to_string());
    }
    fragments
}

pub(super) fn character_consistency_flags_cover(
    existing: CharacterConsistencyFlags,
    candidate: CharacterConsistencyFlags,
) -> bool {
    (!candidate.face_distortion || existing.face_distortion)
        && (!candidate.identity_drift || existing.identity_drift)
        && (!candidate.costume_inconsistency || existing.costume_inconsistency)
}

pub(super) fn visual_error_flags_cover(
    existing: VisualErrorFlags,
    candidate: VisualErrorFlags,
) -> bool {
    (!candidate.warped_anatomy || existing.warped_anatomy)
        && (!candidate.blur || existing.blur)
        && (!candidate.flicker || existing.flicker)
}

pub(super) fn visual_style_constraint_flags_cover(
    existing: VisualStyleConstraintFlags,
    candidate: VisualStyleConstraintFlags,
) -> bool {
    (!candidate.unnecessary_shot_changes || existing.unnecessary_shot_changes)
        && (!candidate.extreme_camera_angle || existing.extreme_camera_angle)
        && (!candidate.tight_close_up || existing.tight_close_up)
        && (!candidate.oppressive_mood || existing.oppressive_mood)
        && (!candidate.frantic_mood || existing.frantic_mood)
        && (!candidate.blank_expression_or_monotone_delivery
            || existing.blank_expression_or_monotone_delivery)
        && (!candidate.overly_cold_emotional_tone || existing.overly_cold_emotional_tone)
        && (!candidate.flat_cold_lighting || existing.flat_cold_lighting)
        && (!candidate.harsh_backlight_silhouette || existing.harsh_backlight_silhouette)
        && (!candidate.distracting_neon_reflections || existing.distracting_neon_reflections)
}

pub(super) fn canonical_negative_fragment(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

pub(super) fn negative_fragment_family(value: &str) -> &'static str {
    let canonical = canonical_negative_fragment(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" => "shot_change_only",
        "avoid extra shot changes or wrong framing" => "shot_change_framing",
        "avoid rushed motion" | "avoid rushed or jerky motion" => "rushed_motion",
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid distracting neon reflections" => "lighting_reflection",
        "avoid lip-sync mismatch" => "lip_sync_mismatch",
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => "",
    }
}

pub(super) fn negative_fragment_information_score(value: &str) -> usize {
    canonical_negative_fragment(value).chars().count()
}
