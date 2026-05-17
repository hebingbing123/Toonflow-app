//! Emotion presets mapped to provider-specific parameters.

use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VoiceEmotion {
    Neutral,
    Happy,
    Sad,
    Angry,
    Tense,
    Gentle,
}

impl VoiceEmotion {
    pub fn parse(raw: &str) -> Self {
        Self::from_str(raw).unwrap_or(Self::Neutral)
    }

    /// Azure `mstts:express-as style` when supported.
    pub fn azure_style(self) -> Option<&'static str> {
        match self {
            Self::Neutral => None,
            Self::Happy => Some("cheerful"),
            Self::Sad => Some("sad"),
            Self::Angry => Some("angry"),
            Self::Tense => Some("terrified"),
            Self::Gentle => Some("gentle"),
        }
    }

    /// OpenAI has no emotion API; use speed as weak proxy.
    pub fn as_id(self) -> &'static str {
        match self {
            Self::Neutral => "neutral",
            Self::Happy => "happy",
            Self::Sad => "sad",
            Self::Angry => "angry",
            Self::Tense => "tense",
            Self::Gentle => "gentle",
        }
    }

    pub fn openai_speed_multiplier(self) -> f32 {
        match self {
            Self::Neutral => 1.0,
            Self::Happy => 1.05,
            Self::Sad => 0.9,
            Self::Angry => 1.1,
            Self::Tense => 1.08,
            Self::Gentle => 0.95,
        }
    }
}

impl FromStr for VoiceEmotion {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(match s.trim().to_lowercase().as_str() {
            "happy" | "cheerful" | "joy" => Self::Happy,
            "sad" | "sorrow" | "melancholy" => Self::Sad,
            "angry" | "rage" => Self::Angry,
            "tense" | "anxious" | "fear" => Self::Tense,
            "gentle" | "soft" | "calm" => Self::Gentle,
            _ => Self::Neutral,
        })
    }
}

pub const EMOTION_PRESET_IDS: &[&str] = &["neutral", "happy", "sad", "angry", "tense", "gentle"];
