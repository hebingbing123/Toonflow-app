use super::*;

#[allow(dead_code)]
pub(in crate::production::workbench::meta::generate) fn select_best_video_prompt_observation_note(
    candidates: Vec<String>,
) -> Option<String> {
    candidates.into_iter().max_by(|a, b| {
        score_video_prompt_observation_specificity(a)
            .cmp(&score_video_prompt_observation_specificity(b))
            .then(
                score_video_prompt_observation_quality(a)
                    .cmp(&score_video_prompt_observation_quality(b)),
            )
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(in crate::production::workbench::meta::generate) enum VideoPromptObservationFamily {
    Identity,
    Blocking,
    Dialogue,
    Lighting,
    Motion,
    Emotion,
    Generic,
}

#[cfg_attr(not(test), allow(dead_code))]
pub(in crate::production::workbench::meta::generate) fn prune_low_signal_observation_candidates(
    candidates: Vec<String>,
) -> Vec<String> {
    let mut kept = candidates
        .into_iter()
        .filter(|note| !observation_candidate_is_low_signal(note))
        .filter(|note| observation_candidate_matches_storyboard_risk(note, None))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        return Vec::new();
    }
    kept.dedup();
    kept
}

pub(in crate::production::workbench::meta::generate) fn prune_storyboard_observation_candidates(
    candidates: Vec<String>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let mut kept = candidates
        .into_iter()
        .filter(|note| !observation_candidate_is_low_signal(note))
        .filter(|note| observation_candidate_matches_storyboard_risk(note, storyboard_row))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        return Vec::new();
    }
    kept.dedup();
    kept
}

pub(in crate::production::workbench::meta::generate) fn observation_candidate_is_low_signal(
    note: &str,
) -> bool {
    matches!(
        canonical_observation_note(note).as_str(),
        "avoid repeating stable follow camera"
            | "avoid oppressive or frantic mood"
            | "avoid overly cold emotional tone"
            | "avoid heavy tragic mood"
            | "avoid overly cold, oppressive, or frantic mood"
    )
}

pub(in crate::production::workbench::meta::generate) fn observation_candidate_matches_storyboard_risk(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    let Some(row) = storyboard_row else {
        return !matches!(
            observation_note_budget_family(note),
            VideoPromptObservationFamily::Generic
        );
    };
    let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    else {
        return !matches!(
            observation_note_budget_family(note),
            VideoPromptObservationFamily::Generic
        );
    };

    match observation_note_budget_family(note) {
        VideoPromptObservationFamily::Identity => true,
        VideoPromptObservationFamily::Dialogue => {
            storyboard_has_visible_speech_performance_risk(&fields, row.prompt.as_deref())
        }
        VideoPromptObservationFamily::Blocking => video_prompt_scene_has_blocking_risk(&fields),
        VideoPromptObservationFamily::Lighting => video_prompt_scene_has_lighting_risk(&fields),
        VideoPromptObservationFamily::Motion => video_prompt_scene_has_motion_risk(&fields),
        VideoPromptObservationFamily::Emotion => video_prompt_scene_needs_emotional_memory(&fields),
        VideoPromptObservationFamily::Generic => false,
    }
}

pub(in crate::production::workbench::meta::generate) fn observation_note_budget_family(
    note: &str,
) -> VideoPromptObservationFamily {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return VideoPromptObservationFamily::Generic;
    }

    if [
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "face distortion",
        "脸",
        "身份",
        "服装",
        "角色一致",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Identity;
    }
    if [
        "lip-sync",
        "blank expression",
        "monotone delivery",
        "口型",
        "dialogue",
        "voice-over",
        "台词",
        "对白",
        "旁白",
        "语音",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Dialogue;
    }
    if [
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "composition",
        "direction",
        "camera angle",
        "close-up",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "机位",
        "景别",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Blocking;
    }
    if [
        "backlight",
        "silhouette",
        "lighting",
        "light",
        "flicker",
        "exposure",
        "reflection",
        "反光",
        "逆光",
        "光影",
        "曝光",
        "闪烁",
        "霓虹",
        "玻璃",
        "雨",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Lighting;
    }
    if [
        "shaky", "handheld", "motion", "stutter", "blur", "抖动", "手持", "运镜",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Motion;
    }
    if [
        "mood",
        "emotion",
        "tragic",
        "oppressive",
        "frantic",
        "情绪",
        "压迫",
        "悲怆",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return VideoPromptObservationFamily::Emotion;
    }

    VideoPromptObservationFamily::Generic
}

pub(in crate::production::workbench::meta::generate) fn score_video_prompt_observation_specificity(
    note: &str,
) -> i32 {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "composition",
        "direction",
        "camera angle",
        "close-up",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "机位",
        "景别",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "face distortion",
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "lip-sync",
        "blank expression",
        "monotone delivery",
        "口型",
        "脸",
        "身份",
        "服装",
        "角色一致",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "backlight",
        "silhouette",
        "lighting",
        "light",
        "flicker",
        "exposure",
        "reflection",
        "反光",
        "逆光",
        "光影",
        "曝光",
        "闪烁",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "shaky", "handheld", "motion", "stutter", "blur", "抖动", "手持", "运镜",
    ] {
        if normalized.contains(keyword) {
            score += 10;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "tragic",
        "oppressive",
        "frantic",
        "情绪",
        "压迫",
        "悲怆",
    ] {
        if normalized.contains(keyword) {
            score += 6;
        }
    }
    if normalized.contains("repeat")
        || normalized.contains("repeating")
        || normalized.contains("重复")
    {
        score -= 8;
    }
    score
}

pub(in crate::production::workbench::meta::generate) fn score_video_prompt_observation_quality(
    note: &str,
) -> i32 {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "face distortion",
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "lip-sync",
        "blank expression",
        "monotone delivery",
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "camera angle",
        "close-up",
        "backlight",
        "silhouette",
        "flicker",
        "stutter",
        "blur",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "逆光",
        "曝光",
        "闪烁",
    ] {
        if normalized.contains(keyword) {
            score += 10;
        }
    }
    score
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_scene_has_motion_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "跟拍", "推进", "拉远", "摇镜", "手持", "奔跑", "跑", "冲", "扑", "追", "快步",
                "转身", "扑向", "踉跄", "急退",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(in crate::production::workbench::meta::generate) fn video_prompt_scene_has_lighting_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "逆光",
                "霓虹",
                "反光",
                "玻璃",
                "雨",
                "车灯",
                "闪烁",
                "曝光",
                "剪影",
                "silhouette",
                "backlight",
                "reflection",
                "flicker",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}
