pub(in crate::production::workbench::video_prompt_memory) fn canonical_observation_note(
    value: &str,
) -> String {
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

#[derive(Debug, Default)]
struct ObservationCharacterConsistencyFlags {
    face_distortion: bool,
    identity_drift: bool,
    costume_drift: bool,
}

#[derive(Debug, Default)]
struct ObservationVisualErrorFlags {
    warped_anatomy: bool,
    blur: bool,
    flicker: bool,
}

#[derive(Debug, Default)]
struct ObservationVisualStyleConstraintFlags {
    extreme_camera_angle: bool,
    tight_close_up: bool,
    oppressive_or_frantic_mood: bool,
    overly_cold_emotional_tone: bool,
    blank_expression_or_monotone_delivery: bool,
    flat_cold_lighting: bool,
    harsh_backlight_silhouette: bool,
}

pub(in crate::production::workbench::video_prompt_memory) fn compact_rejected_negative_fragment_families(
    fragments: Vec<String>,
) -> Vec<String> {
    let mut character_flags = ObservationCharacterConsistencyFlags::default();
    let mut visual_error_flags = ObservationVisualErrorFlags::default();
    let mut visual_style_flags = ObservationVisualStyleConstraintFlags::default();
    let mut retained = Vec::new();

    for fragment in fragments {
        if let Some(parsed) = parse_observation_character_consistency_fragment(&fragment) {
            character_flags.face_distortion |= parsed.face_distortion;
            character_flags.identity_drift |= parsed.identity_drift;
            character_flags.costume_drift |= parsed.costume_drift;
            continue;
        }
        if let Some(parsed) = parse_observation_visual_error_fragment(&fragment) {
            visual_error_flags.warped_anatomy |= parsed.warped_anatomy;
            visual_error_flags.blur |= parsed.blur;
            visual_error_flags.flicker |= parsed.flicker;
            continue;
        }
        if let Some(parsed) = parse_observation_visual_style_constraint_fragment(&fragment) {
            visual_style_flags.extreme_camera_angle |= parsed.extreme_camera_angle;
            visual_style_flags.tight_close_up |= parsed.tight_close_up;
            visual_style_flags.oppressive_or_frantic_mood |= parsed.oppressive_or_frantic_mood;
            visual_style_flags.overly_cold_emotional_tone |= parsed.overly_cold_emotional_tone;
            visual_style_flags.blank_expression_or_monotone_delivery |=
                parsed.blank_expression_or_monotone_delivery;
            visual_style_flags.flat_cold_lighting |= parsed.flat_cold_lighting;
            visual_style_flags.harsh_backlight_silhouette |= parsed.harsh_backlight_silhouette;
            continue;
        }
        retained.push(fragment);
    }

    retained.extend(render_observation_character_consistency_fragment(
        character_flags,
    ));
    retained.extend(render_observation_visual_error_fragments(
        visual_error_flags,
    ));
    retained.extend(render_observation_visual_style_constraint_fragments(
        visual_style_flags,
    ));
    retained
}

fn parse_observation_character_consistency_fragment(
    fragment: &str,
) -> Option<ObservationCharacterConsistencyFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid face distortion" => Some(ObservationCharacterConsistencyFlags {
            face_distortion: true,
            ..Default::default()
        }),
        "avoid identity drift" | "avoid face distortion or identity drift" => {
            Some(ObservationCharacterConsistencyFlags {
                face_distortion: canonical_observation_note(fragment)
                    == "avoid face distortion or identity drift",
                identity_drift: true,
                ..Default::default()
            })
        }
        "avoid costume drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => {
            let canonical = canonical_observation_note(fragment);
            Some(ObservationCharacterConsistencyFlags {
                face_distortion: matches!(
                    canonical.as_str(),
                    "avoid face distortion, identity drift, costume drift"
                ),
                identity_drift: matches!(
                    canonical.as_str(),
                    "avoid face drift or costume inconsistency"
                        | "avoid face distortion, identity drift, costume drift"
                ),
                costume_drift: true,
            })
        }
        _ => None,
    }
}

fn render_observation_character_consistency_fragment(
    flags: ObservationCharacterConsistencyFlags,
) -> Vec<String> {
    if flags.face_distortion && flags.identity_drift && flags.costume_drift {
        return vec!["avoid face distortion, identity drift, costume drift".to_string()];
    }
    if flags.face_distortion && flags.identity_drift {
        return vec!["avoid face distortion or identity drift".to_string()];
    }
    if flags.identity_drift && flags.costume_drift {
        return vec!["avoid face drift or costume inconsistency".to_string()];
    }
    if flags.costume_drift {
        return vec!["avoid costume or character drift".to_string()];
    }
    if flags.identity_drift {
        return vec!["avoid identity drift".to_string()];
    }
    if flags.face_distortion {
        return vec!["avoid face distortion".to_string()];
    }
    Vec::new()
}

fn parse_observation_visual_error_fragment(fragment: &str) -> Option<ObservationVisualErrorFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid warped hands or limbs" | "avoid warped anatomy" => {
            Some(ObservationVisualErrorFlags {
                warped_anatomy: true,
                ..Default::default()
            })
        }
        "avoid blur" => Some(ObservationVisualErrorFlags {
            blur: true,
            ..Default::default()
        }),
        "avoid flicker" | "avoid flicker or motion jitter" => Some(ObservationVisualErrorFlags {
            flicker: true,
            ..Default::default()
        }),
        "avoid warped anatomy, blur, flicker" => Some(ObservationVisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            flicker: true,
        }),
        _ => None,
    }
}

fn render_observation_visual_error_fragments(flags: ObservationVisualErrorFlags) -> Vec<String> {
    if flags.warped_anatomy && flags.blur && flags.flicker {
        return vec!["avoid warped anatomy, blur, flicker".to_string()];
    }

    let mut fragments = Vec::new();
    if flags.warped_anatomy {
        fragments.push("avoid warped anatomy".to_string());
    }
    if flags.blur {
        fragments.push("avoid blur".to_string());
    }
    if flags.flicker {
        fragments.push("avoid flicker or motion jitter".to_string());
    }
    fragments
}

fn parse_observation_visual_style_constraint_fragment(
    fragment: &str,
) -> Option<ObservationVisualStyleConstraintFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid extreme camera angle" => Some(ObservationVisualStyleConstraintFlags {
            extreme_camera_angle: true,
            ..Default::default()
        }),
        "avoid overly tight close-up framing" => Some(ObservationVisualStyleConstraintFlags {
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle or overly tight close-up framing" => {
            Some(ObservationVisualStyleConstraintFlags {
                extreme_camera_angle: true,
                tight_close_up: true,
                ..Default::default()
            })
        }
        "avoid oppressive or frantic mood" => Some(ObservationVisualStyleConstraintFlags {
            oppressive_or_frantic_mood: true,
            ..Default::default()
        }),
        "avoid overly cold emotional tone" => Some(ObservationVisualStyleConstraintFlags {
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid blank expression or monotone delivery" => {
            Some(ObservationVisualStyleConstraintFlags {
                blank_expression_or_monotone_delivery: true,
                ..Default::default()
            })
        }
        "avoid overly cold, oppressive, or frantic mood" => {
            Some(ObservationVisualStyleConstraintFlags {
                oppressive_or_frantic_mood: true,
                overly_cold_emotional_tone: true,
                ..Default::default()
            })
        }
        "avoid flat cold lighting" => Some(ObservationVisualStyleConstraintFlags {
            flat_cold_lighting: true,
            ..Default::default()
        }),
        "avoid harsh backlight silhouette" => Some(ObservationVisualStyleConstraintFlags {
            harsh_backlight_silhouette: true,
            ..Default::default()
        }),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            Some(ObservationVisualStyleConstraintFlags {
                flat_cold_lighting: true,
                harsh_backlight_silhouette: true,
                ..Default::default()
            })
        }
        _ => None,
    }
}

fn render_observation_visual_style_constraint_fragments(
    flags: ObservationVisualStyleConstraintFlags,
) -> Vec<String> {
    let mut fragments = Vec::new();
    if flags.extreme_camera_angle && flags.tight_close_up {
        fragments.push("avoid extreme camera angle or overly tight close-up framing".to_string());
    } else if flags.extreme_camera_angle {
        fragments.push("avoid extreme camera angle".to_string());
    } else if flags.tight_close_up {
        fragments.push("avoid overly tight close-up framing".to_string());
    }

    if flags.oppressive_or_frantic_mood && flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold, oppressive, or frantic mood".to_string());
    } else if flags.oppressive_or_frantic_mood {
        fragments.push("avoid oppressive or frantic mood".to_string());
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

    fragments
}
