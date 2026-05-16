use super::super::super::*;
use super::super::continuity_pressure::{
    continuity_note_mentions_axis_risk, continuity_note_mentions_blocking_risk,
    continuity_note_mentions_dialogue_risk, continuity_note_mentions_emotional_risk,
    continuity_note_mentions_lighting_risk, continuity_note_mentions_motion_risk,
};

pub(in crate::production::workbench::meta::generate) fn video_prompt_scene_has_axis_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    let has_dialogue = storyboard_has_meaningful_spoken_dialogue(fields);
    let subject_count = video_prompt_scene_subject_count(fields);
    let low_gain_dialogue = dialogue_fragment_is_low_gain_utterance(&fields.dialogue);
    if has_dialogue && !low_gain_dialogue && subject_count > 1 {
        return true;
    }

    let has_relational_staging = [
        fields.action.as_str(),
        fields.mood.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "对视", "对峙", "回头", "转身", "逼近", "靠近", "擦肩", "并肩", "交错", "相望",
                "互看",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    if !has_relational_staging {
        return false;
    }

    if subject_count > 1
        && low_gain_dialogue
        && !video_prompt_scene_has_motion_risk(fields)
        && !normalize_prompt_text(&fields.action)
            .split(['，', ',', '；', ';', '。', '\n'])
            .any(|fragment| {
                ["停步", "回头", "侧身", "让开", "逼近", "后退", "绕过"]
                    .iter()
                    .any(|keyword| fragment.contains(keyword))
            })
    {
        return false;
    }

    true
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_scene_subject_count(
    fields: &StructuredStoryboardDescription,
) -> usize {
    let subject_refs = structured_subject_ref_names(fields);
    if !subject_refs.is_empty() {
        return subject_refs.len();
    }

    fields
        .subject
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut subjects, value| {
            if !subjects.iter().any(|existing| existing == &value) {
                subjects.push(value);
            }
            subjects
        })
        .len()
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_scene_has_blocking_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    if video_prompt_scene_has_motion_risk(fields) || video_prompt_scene_has_axis_risk(fields) {
        return true;
    }

    normalize_prompt_text(&fields.action)
        .split(['，', ',', '；', ';', '。', '\n'])
        .any(|fragment| {
            [
                "停步", "站定", "侧身", "让开", "绕过", "穿过", "退后", "后退",
            ]
            .iter()
            .any(|keyword| fragment.contains(keyword))
        })
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_matches_storyboard_risk(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> bool {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return false;
    }
    let Some(fields) = structured_fields else {
        return true;
    };
    if continuity_note_mentions_axis_risk(&normalized) {
        return video_prompt_scene_has_axis_risk(fields)
            || (continuity_note_mentions_blocking_risk(&normalized)
                && video_prompt_scene_has_blocking_risk(fields))
            || (video_prompt_scene_has_motion_risk(fields)
                && ["视线", "方向", "站位", "走位", "跳轴", "构图"]
                    .iter()
                    .any(|keyword| normalized.contains(keyword)));
    }
    if continuity_note_mentions_blocking_risk(&normalized) {
        return video_prompt_scene_has_blocking_risk(fields);
    }
    if super::super::super::builder::continuity_note_adds_specific_guidance(&normalized) {
        return video_prompt_scene_has_motion_risk(fields)
            || video_prompt_scene_has_axis_risk(fields)
            || video_prompt_scene_has_blocking_risk(fields)
            || (normalized.contains("视线") || normalized.contains("方向"))
                && [
                    fields.subject.as_str(),
                    fields.action.as_str(),
                    fields.dialogue.as_str(),
                ]
                .into_iter()
                .map(normalize_prompt_text)
                .any(|value| {
                    !value.is_empty()
                        && ["对视", "看向", "望向", "抬眼", "回头"]
                            .iter()
                            .any(|keyword| value.contains(keyword))
                });
    }
    if continuity_note_mentions_dialogue_risk(&normalized) {
        return storyboard_has_meaningful_spoken_dialogue(fields);
    }
    if continuity_note_mentions_emotional_risk(&normalized) {
        return video_prompt_scene_needs_emotional_memory(fields);
    }
    if continuity_note_mentions_lighting_risk(&normalized) {
        return video_prompt_scene_has_lighting_risk(fields);
    }
    if continuity_note_mentions_motion_risk(&normalized) {
        return video_prompt_scene_has_motion_risk(fields);
    }
    false
}
