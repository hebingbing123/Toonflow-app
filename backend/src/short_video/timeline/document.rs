//! Timeline JSON document types (**NLE M1–M3**).

use serde::{Deserialize, Serialize};

pub const TIMELINE_SCHEMA_VERSION_V1: i32 = 1;
pub const TIMELINE_SCHEMA_VERSION_V2: i32 = 2;
pub const TIMELINE_SCHEMA_VERSION_V3: i32 = 3;
pub const TIMELINE_SCHEMA_VERSION_V4: i32 = 4;
/// Latest schema written on PUT.
pub const TIMELINE_SCHEMA_VERSION: i32 = TIMELINE_SCHEMA_VERSION_V4;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TimelineVideoClip {
    pub storyboard_numeric_id: i32,
    pub source_url: String,
    pub in_ms: i64,
    pub out_ms: i64,
    /// Per-clip FFmpeg preset (**NLE M4b**): none | vivid | cinematic | bw | speed_110.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub effect_preset_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TimelineBgmTrack {
    #[serde(default)]
    pub enabled: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub asset_url: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bgm_strategy: Option<String>,
    #[serde(default = "default_bgm_volume")]
    pub volume: f64,
}

fn default_bgm_volume() -> f64 {
    0.35
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TimelineSubtitleCue {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub storyboard_numeric_id: Option<i32>,
    pub start_ms: i64,
    pub end_ms: i64,
    pub text: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub style_id: Option<String>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TimelineTransitionType {
    Cut,
    Crossfade,
    #[serde(rename = "fade_black")]
    FadeBlack,
}

impl TimelineTransitionType {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Cut => "cut",
            Self::Crossfade => "crossfade",
            Self::FadeBlack => "fade_black",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s.trim().to_lowercase().as_str() {
            "cut" => Some(Self::Cut),
            "crossfade" => Some(Self::Crossfade),
            "fade_black" => Some(Self::FadeBlack),
            _ => None,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TimelineTransition {
    #[serde(rename = "type")]
    pub transition_type: TimelineTransitionType,
    pub duration_ms: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TimelineVoiceoverClip {
    pub storyboard_numeric_id: i32,
    pub start_ms: i64,
    pub source_url: String,
    #[serde(default = "default_voiceover_volume")]
    pub volume: f64,
}

fn default_voiceover_volume() -> f64 {
    1.0
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
#[serde(rename_all = "camelCase")]
pub struct TimelineTracks {
    #[serde(default)]
    pub video: Vec<TimelineVideoClip>,
    #[serde(default)]
    pub bgm: Option<TimelineBgmTrack>,
    #[serde(default)]
    pub subtitles: Vec<TimelineSubtitleCue>,
    #[serde(default)]
    pub transitions: Vec<TimelineTransition>,
    #[serde(default)]
    pub voiceover: Vec<TimelineVoiceoverClip>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub template_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ProjectTimelineDocument {
    pub schema_version: i32,
    pub tracks: TimelineTracks,
}

impl Default for ProjectTimelineDocument {
    fn default() -> Self {
        Self {
            schema_version: TIMELINE_SCHEMA_VERSION,
            tracks: TimelineTracks::default(),
        }
    }
}
