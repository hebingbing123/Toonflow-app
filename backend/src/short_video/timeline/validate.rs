//! Timeline track validation (**NLE M2–M3**).

use crate::error::ApiError;
use crate::short_video::timeline::document::{
    TimelineSubtitleCue, TimelineTracks, TimelineTransition, TimelineTransitionType,
    TimelineVoiceoverClip, TIMELINE_SCHEMA_VERSION_V1, TIMELINE_SCHEMA_VERSION_V2,
    TIMELINE_SCHEMA_VERSION_V3, TIMELINE_SCHEMA_VERSION_V4,
};
use crate::short_video::timeline_effects::TimelineEffectPreset;

pub const MAX_CROSSFADE_MS: i64 = 2000;

pub fn validate_schema_version(schema_version: i32) -> Result<(), ApiError> {
    if ![
        TIMELINE_SCHEMA_VERSION_V1,
        TIMELINE_SCHEMA_VERSION_V2,
        TIMELINE_SCHEMA_VERSION_V3,
        TIMELINE_SCHEMA_VERSION_V4,
    ]
    .contains(&schema_version)
    {
        return Err(crate::error::bad_request_i18n(
            "unsupported schema_version",
            "不支持的 schema_version",
        ));
    }
    Ok(())
}

pub fn validate_tracks(tracks: &TimelineTracks) -> Result<(), ApiError> {
    for clip in &tracks.video {
        if clip.source_url.trim().is_empty() {
            return Err(crate::error::bad_request_i18n(
                "video clip source_url cannot be empty",
                "视频片段 source_url 不能为空",
            ));
        }
        if clip.out_ms <= clip.in_ms {
            return Err(crate::error::bad_request_i18n(
                "video clip out_ms must be greater than in_ms",
                "视频片段 out_ms 必须大于 in_ms",
            ));
        }
        if clip.in_ms < 0 {
            return Err(crate::error::bad_request_i18n(
                "video clip in_ms must be non-negative",
                "视频片段 in_ms 不能为负数",
            ));
        }
        if let Some(preset) = clip.effect_preset_id.as_deref() {
            let parsed = TimelineEffectPreset::parse(Some(preset));
            if parsed == TimelineEffectPreset::None && preset != "none" {
                return Err(crate::error::bad_request_i18n(
                    "unknown effectPresetId",
                    "未知的 effectPresetId",
                ));
            }
        }
    }
    if let Some(bgm) = &tracks.bgm {
        if !(0.0..=1.0).contains(&bgm.volume) {
            return Err(crate::error::bad_request_i18n(
                "bgm volume must be between 0 and 1",
                "BGM 音量必须在 0 到 1 之间",
            ));
        }
    }
    for cue in &tracks.subtitles {
        validate_subtitle_cue(cue)?;
    }
    let video_len = tracks.video.len();
    if tracks.transitions.len() > video_len.saturating_sub(1) {
        return Err(crate::error::bad_request_i18n(
            "too many transitions for video clip count",
            "转场数量不能超过相邻片段数",
        ));
    }
    for tr in &tracks.transitions {
        validate_transition(tr)?;
    }
    for vo in &tracks.voiceover {
        validate_voiceover(vo)?;
    }
    if let Some(tid) = tracks.template_id.as_deref() {
        if !crate::short_video::timeline::templates::is_known_template(tid) {
            return Err(crate::error::bad_request_i18n(
                "unknown templateId",
                "未知的 templateId",
            ));
        }
    }
    Ok(())
}

fn validate_subtitle_cue(cue: &TimelineSubtitleCue) -> Result<(), ApiError> {
    if cue.text.trim().is_empty() {
        return Err(crate::error::bad_request_i18n(
            "subtitle text cannot be empty",
            "字幕文本不能为空",
        ));
    }
    if cue.end_ms <= cue.start_ms {
        return Err(crate::error::bad_request_i18n(
            "subtitle end_ms must be greater than start_ms",
            "字幕 end_ms 必须大于 start_ms",
        ));
    }
    if cue.start_ms < 0 {
        return Err(crate::error::bad_request_i18n(
            "subtitle start_ms must be non-negative",
            "字幕 start_ms 不能为负数",
        ));
    }
    Ok(())
}

fn validate_transition(tr: &TimelineTransition) -> Result<(), ApiError> {
    match tr.transition_type {
        TimelineTransitionType::Cut => {
            if tr.duration_ms != 0 {
                return Err(crate::error::bad_request_i18n(
                    "cut transition duration_ms must be 0",
                    "硬切转场 duration_ms 必须为 0",
                ));
            }
        }
        TimelineTransitionType::Crossfade | TimelineTransitionType::FadeBlack => {
            if tr.duration_ms <= 0 || tr.duration_ms > MAX_CROSSFADE_MS {
                return Err(crate::error::bad_request_i18n(
                    "transition duration_ms must be 1..2000",
                    "转场时长必须在 1–2000 ms 之间",
                ));
            }
        }
    }
    Ok(())
}

fn validate_voiceover(vo: &TimelineVoiceoverClip) -> Result<(), ApiError> {
    if vo.source_url.trim().is_empty() {
        return Err(crate::error::bad_request_i18n(
            "voiceover source_url cannot be empty",
            "配音 source_url 不能为空",
        ));
    }
    if vo.start_ms < 0 {
        return Err(crate::error::bad_request_i18n(
            "voiceover start_ms must be non-negative",
            "配音 start_ms 不能为负数",
        ));
    }
    if !(0.0..=2.0).contains(&vo.volume) {
        return Err(crate::error::bad_request_i18n(
            "voiceover volume must be between 0 and 2",
            "配音音量必须在 0 到 2 之间",
        ));
    }
    Ok(())
}
