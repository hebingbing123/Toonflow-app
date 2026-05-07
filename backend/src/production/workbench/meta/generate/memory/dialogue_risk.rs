use super::*;

#[allow(dead_code)] // Exported within `generate`; not wired on all paths yet.
pub(in crate::production::workbench::meta::generate) fn storyboard_dialogue_is_empty_row(
    row: &StoryboardPromptSeedRow,
) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| storyboard_dialogue_is_empty(&fields.dialogue))
}

pub(in crate::production::workbench::meta::generate) fn storyboard_dialogue_is_empty(
    dialogue: &str,
) -> bool {
    let normalized = normalize_prompt_text(dialogue);
    let normalized_ascii = normalized.to_ascii_lowercase();
    normalized.is_empty()
        || [
            "无台词",
            "无对白",
            "无旁白",
            "无语音",
            "no dialogue",
            "no voice-over",
            "silent",
        ]
        .iter()
        .map(|marker| normalize_prompt_text(marker).to_ascii_lowercase())
        .any(|marker| normalized_ascii == marker)
}

#[allow(dead_code)] // Exported within `generate`; not wired on all paths yet.
pub(in crate::production::workbench::meta::generate) fn storyboard_lacks_meaningful_spoken_dialogue(
    row: &StoryboardPromptSeedRow,
) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_none_or(|fields| {
            !storyboard_has_meaningful_spoken_dialogue_with_prompt(&fields, row.prompt.as_deref())
        })
}

pub(in crate::production::workbench::meta::generate) fn storyboard_lacks_visible_speech_performance_risk(
    row: &StoryboardPromptSeedRow,
) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_none_or(|fields| {
            !storyboard_has_visible_speech_performance_risk(&fields, row.prompt.as_deref())
        })
}

pub(in crate::production::workbench::meta::generate) fn storyboard_has_meaningful_spoken_dialogue(
    fields: &StructuredStoryboardDescription,
) -> bool {
    storyboard_has_meaningful_spoken_dialogue_with_prompt(fields, None)
}

pub(in crate::production::workbench::meta::generate) fn storyboard_has_meaningful_spoken_dialogue_with_prompt(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    if storyboard_dialogue_is_empty(&fields.dialogue) {
        return false;
    }

    let dialogue = normalize_prompt_text(&fields.dialogue);
    let action = normalize_prompt_text(&fields.action);
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();

    if dialogue_fragment_is_low_gain_utterance(&dialogue)
        && !storyboard_explicitly_signals_speech(&action, &dialogue, &prompt)
    {
        return false;
    }

    true
}

pub(in crate::production::workbench::meta::generate) fn storyboard_has_visible_speech_performance_risk(
    fields: &StructuredStoryboardDescription,
    prompt: Option<&str>,
) -> bool {
    if !storyboard_has_meaningful_spoken_dialogue_with_prompt(fields, prompt) {
        return false;
    }

    let shot = normalize_prompt_text(&fields.shot);
    let camera_move = normalize_prompt_text(&fields.camera_move);
    let action = normalize_prompt_text(&fields.action);
    let dialogue = normalize_prompt_text(&fields.dialogue);
    let prompt = prompt.map(normalize_prompt_text).unwrap_or_default();

    let mut score = 0i32;
    if ["特写", "近景", "近特写", "大特写"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score += 2;
    } else if shot.contains("中景") {
        score += 1;
    } else if ["远景", "全景"]
        .iter()
        .any(|keyword| shot.contains(keyword))
    {
        score -= 1;
    }

    if storyboard_explicitly_signals_speech(&action, &dialogue, &prompt)
        || [
            "嘴角", "唇线", "抿唇", "喉结", "口型", "嘴唇", "失声", "哽咽", "呢喃", "低声", "轻声",
        ]
        .iter()
        .any(|keyword| {
            action.contains(keyword) || dialogue.contains(keyword) || prompt.contains(keyword)
        })
    {
        score += 2;
    }

    if !video_prompt_scene_has_motion_risk(fields)
        || ["静止", "缓推", "慢推", "停顿", "驻足", "停步"]
            .iter()
            .any(|keyword| camera_move.contains(keyword) || action.contains(keyword))
    {
        score += 1;
    }

    if video_prompt_scene_subject_count(fields) > 1 {
        score -= 1;
    }

    score >= 2
}

pub(in crate::production::workbench::meta::generate) fn dialogue_fragment_is_low_gain_utterance(
    dialogue: &str,
) -> bool {
    let stripped = dialogue
        .chars()
        .filter(|ch| {
            !ch.is_whitespace()
                && !matches!(ch, '：' | ':' | '，' | ',' | '。' | '！' | '!' | '？' | '?')
        })
        .collect::<String>();
    if stripped.is_empty() {
        return true;
    }
    let char_count = stripped.chars().count();
    if char_count > 2 {
        return false;
    }

    [
        "嗯", "啊", "呀", "哎", "欸", "诶", "哦", "喂", "哈", "呵", "呃", "唉", "哼",
    ]
    .iter()
    .any(|token| stripped == *token)
}

pub(in crate::production::workbench::meta::generate) fn storyboard_explicitly_signals_speech(
    action: &str,
    dialogue: &str,
    prompt: &str,
) -> bool {
    [action, dialogue, prompt].into_iter().any(|value| {
        !value.is_empty()
            && [
                "开口",
                "说道",
                "说出",
                "说着",
                "低声说",
                "轻声说",
                "哽咽",
                "失声",
                "喊",
                "叫住",
                "质问",
                "回答",
                "回应",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(in crate::production::workbench::meta::generate) fn canonical_observation_note(
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

pub(in crate::production::workbench::meta::generate) fn compact_negative_constraint_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }
    let conflicts = |value: &str| {
        negative_constraint_conflicts_with_storyboard_style(
            value.trim(),
            selected_style_note,
            storyboard_row,
        )
    };
    match canonical_observation_note(trimmed).as_str() {
        "avoid extreme camera angle or overly tight close-up framing" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid extreme camera angle",
                "avoid overly tight close-up framing",
                conflicts,
            )
        }
        "avoid overly cold, oppressive, or frantic mood" => compact_conflicting_negative_pair(
            trimmed,
            "avoid oppressive or frantic mood",
            "avoid overly cold emotional tone",
            conflicts,
        ),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid flat cold lighting",
                "avoid harsh backlight silhouette",
                conflicts,
            )
        }
        _ => (!conflicts(trimmed)).then_some(trimmed.to_string()),
    }
}

pub(in crate::production::workbench::meta::generate) fn compact_conflicting_negative_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_conflicts = conflicts(lhs);
    let rhs_conflicts = conflicts(rhs);
    match (lhs_conflicts, rhs_conflicts) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}
