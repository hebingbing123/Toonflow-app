//! Structured voice profile parsing (`voice_profile` string or JSON).

use serde::{Deserialize, Serialize};
use serde_json::Value;
use utoipa::ToSchema;

use super::emotion::VoiceEmotion;

pub const DEFAULT_OPENAI_VOICE: &str = "alloy";
pub const DEFAULT_AZURE_VOICE: &str = "zh-CN-XiaoxiaoNeural";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema, Default)]
#[serde(rename_all = "lowercase")]
pub enum VoiceProvider {
    #[default]
    Openai,
    Azure,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SeedanceVoiceDimensions {
    pub gender: Option<String>,
    pub age_tone: Option<String>,
    pub pitch: Option<String>,
    pub tone_quality: Option<String>,
    pub thickness: Option<String>,
    pub pronunciation: Option<String>,
    pub breath: Option<String>,
    pub speech_rate: Option<String>,
    pub special_texture: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct VoiceProfileConfig {
    #[serde(default)]
    pub provider: VoiceProvider,
    #[serde(default)]
    pub voice: String,
    #[serde(default)]
    pub style: Option<String>,
    #[serde(default)]
    pub pitch: Option<String>,
    #[serde(default)]
    pub rate: Option<String>,
    #[serde(default)]
    pub emotion: Option<String>,
    #[serde(default)]
    pub speed: Option<f32>,
    #[serde(default)]
    pub seedance: Option<SeedanceVoiceDimensions>,
    /// When true, narration text is split by speaker labels into multiple tracks.
    #[serde(default)]
    pub multi_track: bool,
    /// Custom cloned voice id (`customVoiceId` alias).
    #[serde(default, alias = "customVoiceId")]
    pub clone_voice_id: Option<String>,
}

impl VoiceProvider {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Openai => "openai",
            Self::Azure => "azure",
        }
    }
}

impl Default for VoiceProfileConfig {
    fn default() -> Self {
        Self {
            provider: VoiceProvider::Openai,
            voice: DEFAULT_OPENAI_VOICE.to_string(),
            style: None,
            pitch: None,
            rate: None,
            emotion: None,
            speed: Some(1.0),
            seedance: None,
            multi_track: false,
            clone_voice_id: None,
        }
    }
}

/// Parse project `voice_profile`, character `voice_config`, or legacy plain voice name.
pub fn parse_voice_profile(raw: Option<&str>) -> VoiceProfileConfig {
    let Some(text) = raw.map(str::trim).filter(|s| !s.is_empty()) else {
        return VoiceProfileConfig::default();
    };
    if text.starts_with('{') {
        if let Ok(mut cfg) = serde_json::from_str::<VoiceProfileConfig>(text) {
            if cfg.voice.trim().is_empty() {
                cfg.voice = default_voice_for_provider(cfg.provider).to_string();
            }
            apply_emotion_to_style(&mut cfg);
            return cfg;
        }
        if let Ok(value) = serde_json::from_str::<Value>(text) {
            return parse_voice_json_value(&value);
        }
    }
    VoiceProfileConfig {
        voice: text.to_string(),
        ..VoiceProfileConfig::default()
    }
}

pub fn parse_voice_json_value(value: &Value) -> VoiceProfileConfig {
    serde_json::from_value(value.clone()).unwrap_or_else(|_| VoiceProfileConfig {
        voice: value
            .get("voice")
            .or_else(|| value.get("voiceId"))
            .and_then(|v| v.as_str())
            .unwrap_or(DEFAULT_OPENAI_VOICE)
            .to_string(),
        ..VoiceProfileConfig::default()
    })
}

fn apply_emotion_to_style(cfg: &mut VoiceProfileConfig) {
    if cfg.style.is_none() {
        if let Some(emotion) = cfg.emotion.as_deref() {
            cfg.style = super::emotion::VoiceEmotion::parse(emotion)
                .azure_style()
                .map(str::to_string);
        }
    }
}

pub fn default_voice_for_provider(provider: VoiceProvider) -> &'static str {
    match provider {
        VoiceProvider::Openai => DEFAULT_OPENAI_VOICE,
        VoiceProvider::Azure => DEFAULT_AZURE_VOICE,
    }
}

pub fn merge_voice_config(
    mut base: VoiceProfileConfig,
    override_cfg: Option<VoiceProfileConfig>,
    explicit_voice: Option<&str>,
    explicit_emotion: Option<&str>,
    explicit_speed: Option<f32>,
    explicit_provider: Option<&str>,
) -> VoiceProfileConfig {
    if let Some(o) = override_cfg {
        if !o.voice.trim().is_empty() {
            base.voice = o.voice;
        }
        base.provider = o.provider;
        base.style = o.style.or(base.style);
        base.pitch = o.pitch.or(base.pitch);
        base.rate = o.rate.or(base.rate);
        base.emotion = o.emotion.or(base.emotion);
        base.speed = o.speed.or(base.speed);
        base.seedance = o.seedance.or(base.seedance);
        base.multi_track |= o.multi_track;
        base.clone_voice_id = o.clone_voice_id.or(base.clone_voice_id);
    }
    if let Some(v) = explicit_voice.map(str::trim).filter(|s| !s.is_empty()) {
        if v.starts_with('{') {
            let parsed = parse_voice_profile(Some(v));
            return merge_voice_config(
                base,
                Some(parsed),
                None,
                explicit_emotion,
                explicit_speed,
                explicit_provider,
            );
        }
        base.voice = v.to_string();
    }
    if let Some(e) = explicit_emotion.map(str::trim).filter(|s| !s.is_empty()) {
        base.emotion = Some(e.to_string());
    }
    if let Some(s) = explicit_speed.filter(|v| (0.25..=4.0).contains(v)) {
        base.speed = Some(s);
    }
    if let Some(p) = explicit_provider.map(str::trim).filter(|s| !s.is_empty()) {
        base.provider = match p.to_lowercase().as_str() {
            "azure" | "azure_tts" | "microsoft" => VoiceProvider::Azure,
            _ => VoiceProvider::Openai,
        };
    }
    if let Some(emotion) = base.emotion.as_deref() {
        if base.style.is_none() {
            base.style = VoiceEmotion::parse(emotion)
                .azure_style()
                .map(str::to_string);
        }
    }
    if base.voice.trim().is_empty() {
        base.voice = default_voice_for_provider(base.provider).to_string();
    }
    base
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_legacy_string_voice() {
        let cfg = parse_voice_profile(Some("nova"));
        assert_eq!(cfg.voice, "nova");
        assert_eq!(cfg.provider, VoiceProvider::Openai);
    }

    #[test]
    fn parses_json_voice_profile() {
        let raw = r#"{"provider":"azure","voice":"zh-CN-YunxiNeural","emotion":"sad"}"#;
        let cfg = parse_voice_profile(Some(raw));
        assert_eq!(cfg.provider, VoiceProvider::Azure);
        assert_eq!(cfg.voice, "zh-CN-YunxiNeural");
        assert_eq!(cfg.style.as_deref(), Some("sad"));
    }
}
