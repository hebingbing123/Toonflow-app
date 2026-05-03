use super::*;

pub(in crate::production::workbench::video_prompt_memory) fn compact_rejected_negative_avoid(
    avoid: &str,
) -> String {
    let mut scored = ranked_rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| (score_rejected_negative_fragment(&fragment), idx, fragment))
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));

    let mut selected = Vec::new();
    for (_, _, fragment) in scored {
        if selected.iter().any(|existing| existing == &fragment) {
            continue;
        }
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    selected.join(", ")
}

pub(in crate::production::workbench::video_prompt_memory) fn ranked_rejected_negative_fragments(
    avoid: &str,
) -> Vec<String> {
    let mut ranked = rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            let note = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            (score_rejected_negative_fragment(&note), idx, note)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut selected = Vec::new();
    for (_, _, fragment) in ranked {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
    }
    selected
}

pub(in crate::production::workbench::video_prompt_memory) fn score_rejected_negative_fragment(
    fragment: &str,
) -> i32 {
    let normalized = normalize_prompt_text(fragment).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "follow", "stable", "shot", "framing", "镜头",
        "运镜", "抖动", "跳轴", "机位",
    ] {
        if normalized.contains(keyword) {
            score += 20;
        }
    }
    for keyword in [
        "flicker", "jitter", "stutter", "blur", "warped", "anatom", "face", "identity", "costume",
        "flash", "闪烁", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "lighting",
        "light",
        "silhouette",
        "backlight",
        "cold",
        "neon",
        "flat",
        "光影",
        "逆光",
        "冷光",
        "曝光",
        "反光",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "tone",
        "monotone",
        "expression",
        "delivery",
        "情绪",
        "压迫",
        "冷调",
        "悲怆",
        "台词",
        "表演",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 8
}

pub(in crate::production::workbench::video_prompt_memory) fn score_rejected_negative_fragment_for_storyboard(
    fragment: &str,
    storyboard_tags: &[String],
) -> i32 {
    score_rejected_negative_fragment(fragment)
        + fragment_storyboard_risk_overlap(fragment, storyboard_tags) as i32 * 18
        + rejected_fragment_storyboard_tag_priority_bonus(fragment, storyboard_tags)
}

fn rejected_fragment_storyboard_tag_priority_bonus(
    fragment: &str,
    storyboard_tags: &[String],
) -> i32 {
    if storyboard_tags.is_empty() {
        return 0;
    }

    let tags = negative_fragment_storyboard_risk_tags(fragment);
    let has_storyboard_tag = |candidate: &str| storyboard_tags.iter().any(|tag| tag == candidate);
    let has_fragment_tag = |candidate: &str| tags.iter().any(|tag| *tag == candidate);
    let mut bonus = 0;
    let dialogue_scene = has_storyboard_tag("dialogue");

    if has_fragment_tag("performance")
        && (has_storyboard_tag("performance")
            || has_storyboard_tag("dialogue")
            || has_storyboard_tag("emotion"))
    {
        bonus += if dialogue_scene { 26 } else { 6 };
    }
    if has_fragment_tag("identity") && has_storyboard_tag("identity") {
        bonus += if dialogue_scene { 18 } else { 28 };
    }
    if has_fragment_tag("lighting") && has_storyboard_tag("lighting") {
        bonus += 6;
    }
    if has_fragment_tag("motion") && has_storyboard_tag("motion") {
        bonus += 4;
    }
    if has_fragment_tag("framing") && has_storyboard_tag("framing") {
        bonus += 4;
    }

    bonus
}

pub(in crate::production::workbench::video_prompt_memory) fn score_pending_observation_note(
    note: &str,
) -> i32 {
    let normalized = normalize_prompt_text(note).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "镜头", "运镜", "抖动", "跳轴", "站位", "走位",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "lighting", "light", "flat", "flicker", "冷光", "光影", "曝光", "闪烁", "色温",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "blur", "warped", "anatom", "face", "identity", "costume", "模糊", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "monotone",
        "expression",
        "delivery",
        "情绪",
        "压迫",
        "节奏",
        "表演",
        "台词",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 6
}

pub(in crate::production::workbench::video_prompt_memory) fn score_pending_observation_note_for_storyboard(
    note: &str,
    storyboard_tags: &[String],
) -> i32 {
    score_pending_observation_note(note)
        + fragment_storyboard_risk_overlap(note, storyboard_tags) as i32 * 18
}

pub(in crate::production::workbench::video_prompt_memory) fn score_rejected_video_memory_bias_for_fragment(
    fragment: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };
    let tags = negative_fragment_storyboard_risk_tags(fragment);
    let mut score = 0;
    for tag in tags {
        score += match *tag {
            "performance" if bias.prefer_delivery => 42,
            "dialogue" | "emotion" if bias.prefer_delivery => 36,
            "identity" if bias.prefer_visual_continuity => 42,
            "lighting" if bias.prefer_visual_continuity => 36,
            "framing" if bias.prefer_visual_continuity => 24,
            "motion" if bias.prefer_visual_continuity => 18,
            _ => 0,
        };
    }
    score
}

pub(in crate::production::workbench::video_prompt_memory) fn score_rejected_video_memory_bias_for_content(
    content: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };
    let tags = extract_rejected_video_focus_tags(content);
    if tags.is_empty() {
        return 0;
    }

    let mut score = 0;
    if bias.prefer_delivery
        && tags
            .iter()
            .any(|tag| matches!(tag.as_str(), "delivery_realism"))
    {
        score += 28;
    }
    if bias.prefer_visual_continuity
        && tags
            .iter()
            .any(|tag| matches!(tag.as_str(), "identity_continuity"))
    {
        score += 24;
    }
    if bias.prefer_visual_continuity
        && tags
            .iter()
            .any(|tag| matches!(tag.as_str(), "lighting_realism"))
    {
        score += 20;
    }
    score
}

pub(in crate::production::workbench::video_prompt_memory) fn compact_rejected_negative_fragment_risk_budget(
    fragments: Vec<String>,
) -> Vec<String> {
    if fragments.len() < 2 {
        return fragments;
    }

    let has_high_signal_visual_guard = fragments
        .iter()
        .any(|fragment| rejected_negative_fragment_is_high_signal_visual_guard(fragment));
    let has_character_guard = fragments
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    let has_mood_tone = fragments
        .iter()
        .any(|fragment| observation_note_family(fragment) == "mood_tone");
    let has_stronger_nonstyle_guard = fragments.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "performance_delivery" | "camera_motion_stability" | "flicker_motion_jitter"
        )
    });
    let should_drop_style_fillers = has_high_signal_visual_guard
        || (has_character_guard && has_mood_tone && !has_stronger_nonstyle_guard);
    if !should_drop_style_fillers {
        return fragments;
    }

    let filtered = fragments
        .iter()
        .filter(|fragment| !rejected_negative_fragment_is_low_priority_style_retry(fragment))
        .cloned()
        .collect::<Vec<_>>();
    if filtered.is_empty() {
        fragments
    } else {
        filtered
    }
}

fn rejected_negative_fragment_is_high_signal_visual_guard(fragment: &str) -> bool {
    matches!(
        canonical_observation_note(fragment).as_str(),
        "avoid face distortion, identity drift, costume drift"
            | "avoid warped anatomy, blur, flicker"
    )
}

fn rejected_negative_fragment_is_low_priority_style_retry(fragment: &str) -> bool {
    if rejected_negative_memory_fragment_is_low_signal(fragment) {
        return true;
    }

    matches!(
        observation_note_family(fragment),
        "camera_framing" | "lighting_backlight" | "lighting_reflection"
    )
}

pub(in crate::production::workbench::video_prompt_memory) fn observation_note_is_covered(
    candidate: &str,
    existing_notes: &[String],
) -> bool {
    existing_notes
        .iter()
        .any(|existing| observation_note_covers(existing, candidate))
}

pub(in crate::production::workbench::video_prompt_memory) fn observation_note_covers(
    existing: &str,
    candidate: &str,
) -> bool {
    if observation_note_same_family(existing, candidate) {
        return score_pending_observation_note(existing)
            >= score_pending_observation_note(candidate);
    }
    observation_note_contains(existing, candidate)
}

fn observation_note_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_observation_note(existing);
    let candidate = canonical_observation_note(candidate);
    if existing.is_empty() || candidate.is_empty() {
        return false;
    }
    if existing == candidate {
        return true;
    }
    let min_overlap_len = 12;
    existing.len() >= candidate.len()
        && candidate.len() >= min_overlap_len
        && existing.contains(&candidate)
}

fn observation_note_same_family(existing: &str, candidate: &str) -> bool {
    let existing = observation_note_family(existing);
    let candidate = observation_note_family(candidate);
    !existing.is_empty() && existing == candidate
}

pub(in crate::production::workbench::video_prompt_memory) fn observation_note_family(
    value: &str,
) -> &'static str {
    let canonical = canonical_observation_note(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" | "avoid extra shot changes or wrong framing" => {
            "shot_change_framing"
        }
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid warped hands or limbs"
        | "avoid warped anatomy"
        | "avoid blur"
        | "avoid warped anatomy, blur, flicker" => "visual_error",
        "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => {
            if canonical.contains("shaky")
                || canonical.contains("handheld")
                || canonical.contains("stable follow camera")
                || canonical.contains("follow camera")
            {
                "camera_motion_stability"
            } else if canonical.contains("shot change")
                || canonical.contains("wrong framing")
                || canonical.contains("unnecessary shot")
            {
                "shot_change_framing"
            } else if canonical.contains("tragic")
                || canonical.contains("oppressive")
                || canonical.contains("frantic")
                || canonical.contains("cold emotional tone")
            {
                "mood_tone"
            } else if canonical.contains("blank expression")
                || canonical.contains("monotone")
                || canonical.contains("delivery")
            {
                "performance_delivery"
            } else if canonical.contains("neon reflection") || canonical.contains("reflection") {
                "lighting_reflection"
            } else if canonical.contains("lip-sync") {
                "lip_sync"
            } else {
                ""
            }
        }
    }
}
