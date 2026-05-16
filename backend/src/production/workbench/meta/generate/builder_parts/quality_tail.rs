use super::super::*;
use super::continuity_pressure::continuity_fragment_matches_constraint_pressure;

pub(in crate::production::workbench::meta::generate) fn build_video_prompt_quality_tail(
    structured_fields: Option<&StructuredStoryboardDescription>,
    style_anchors: &[String],
    continuity_notes: &[String],
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> String {
    if structured_fields.is_some_and(video_prompt_scene_is_grounded_low_risk) {
        return "No extra shot changes.".to_string();
    }

    let performance_needed = structured_fields
        .is_some_and(current_storyboard_is_fragile_emotional_turn)
        || constraint_pressure.is_some_and(|pressure| {
            pressure.has_dialogue_guardrail || pressure.has_emotion_guardrail
        });

    let camera = structured_fields
        .map(|fields| {
            [fields.shot.as_str(), fields.camera_move.as_str()]
                .into_iter()
                .filter(|part| !part.is_empty())
                .collect::<String>()
        })
        .unwrap_or_default();
    let continuity_is_explicit = !continuity_notes.is_empty()
        || continuity_tail_matches(&camera)
        || style_anchors
            .iter()
            .any(|anchor| continuity_tail_matches(anchor));
    let guardrail_continuity_is_explicit =
        style_anchors
            .iter()
            .chain(continuity_notes.iter())
            .any(|fragment| {
                continuity_fragment_matches_constraint_pressure(fragment, constraint_pressure)
            });
    let performance_is_explicit =
        style_anchors
            .iter()
            .chain(continuity_notes.iter())
            .any(|fragment| {
                let normalized = normalize_prompt_text(fragment);
                fragment.starts_with("表演")
                    || fragment.starts_with("语气")
                    || [
                        "眼神", "嘴角", "喉结", "呼吸", "气息", "尾音", "发颤", "哽咽", "停顿",
                    ]
                    .iter()
                    .any(|keyword| normalized.contains(keyword))
            });
    let motion_is_explicit = style_anchors
        .iter()
        .chain(continuity_notes.iter())
        .any(|fragment| quality_tail_motion_is_explicit(fragment));
    let performance_tail_needed = performance_needed && !performance_is_explicit;

    if guardrail_continuity_is_explicit
        && constraint_pressure.is_some_and(|pressure| pressure.forces_compact_memory)
    {
        "No extra shot changes.".to_string()
    } else if continuity_is_explicit && motion_is_explicit {
        if performance_tail_needed {
            "Natural performance, no extra shot changes.".to_string()
        } else {
            "No extra shot changes.".to_string()
        }
    } else if continuity_is_explicit {
        if performance_tail_needed {
            "Natural performance, natural motion, no extra shot changes.".to_string()
        } else {
            "Natural motion, no extra shot changes.".to_string()
        }
    } else if motion_is_explicit {
        if performance_tail_needed {
            "Natural performance, stable continuity, no extra shot changes.".to_string()
        } else {
            "Stable continuity, no extra shot changes.".to_string()
        }
    } else if performance_tail_needed {
        "Natural performance, natural motion, stable continuity, no extra shot changes.".to_string()
    } else {
        "Natural motion, stable continuity, no extra shot changes.".to_string()
    }
}

pub(in crate::production::workbench::meta::generate) fn continuity_tail_matches(
    value: &str,
) -> bool {
    let normalized = normalize_prompt_text(value);
    !normalized.is_empty()
        && ["稳定", "跟拍", "衔接", "连续", "一致", "统一"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

fn quality_tail_motion_is_explicit(value: &str) -> bool {
    let normalized = normalize_prompt_text(value);
    !normalized.is_empty()
        && [
            "动作", "节奏", "跟拍", "推进", "拉远", "手持", "转身", "快步", "呼吸", "停顿", "自然",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}
