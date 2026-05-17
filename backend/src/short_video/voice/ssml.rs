//! Azure SSML builder for expressive Chinese/English TTS.

use super::config::VoiceProfileConfig;

pub fn build_azure_ssml(text: &str, cfg: &VoiceProfileConfig) -> String {
    let lang = if cfg.voice.starts_with("zh-") {
        "zh-CN"
    } else {
        "en-US"
    };
    let escaped = xml_escape(text);
    let style = cfg
        .style
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty());
    let rate = cfg.rate.as_deref().filter(|s| !s.is_empty());
    let pitch = cfg.pitch.as_deref().filter(|s| !s.is_empty());

    let mut inner = String::new();
    if let Some(style_name) = style {
        inner.push_str(&format!(r#"<mstts:express-as style="{style_name}">"#));
    }
    if rate.is_some() || pitch.is_some() {
        let rate_attr = rate.map(|r| format!(r#" rate="{r}""#)).unwrap_or_default();
        let pitch_attr = pitch
            .map(|p| format!(r#" pitch="{p}""#))
            .unwrap_or_default();
        inner.push_str(&format!(
            "<prosody{rate_attr}{pitch_attr}>{escaped}</prosody>"
        ));
    } else {
        inner.push_str(&escaped);
    }
    if style.is_some() {
        inner.push_str("</mstts:express-as>");
    }

    format!(
        r#"<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="{lang}"><voice name="{}">{inner}</voice></speak>"#,
        cfg.voice,
        inner = inner
    )
}

fn xml_escape(text: &str) -> String {
    text.replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&apos;")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::short_video::voice::config::{VoiceProfileConfig, VoiceProvider};

    #[test]
    fn ssml_includes_voice_and_style() {
        let cfg = VoiceProfileConfig {
            provider: VoiceProvider::Azure,
            voice: "zh-CN-XiaoxiaoNeural".into(),
            style: Some("sad".into()),
            ..VoiceProfileConfig::default()
        };
        let ssml = build_azure_ssml("你好", &cfg);
        assert!(ssml.contains("zh-CN-XiaoxiaoNeural"));
        assert!(ssml.contains("sad"));
        assert!(ssml.contains("你好"));
    }
}
