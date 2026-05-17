//! Seedance 2.0 nine-dimension voice description builder.

use super::config::SeedanceVoiceDimensions;
use super::emotion::VoiceEmotion;

#[allow(dead_code)]
pub const SEEDANCE_DIMENSION_LABELS: &[&str] = &[
    "性别",
    "年龄音色",
    "音调",
    "音色质感",
    "声音厚度",
    "发音方式",
    "气息",
    "语速",
    "特殊质感",
];

#[allow(dead_code)]
pub fn build_seedance_voice_desc(dims: &SeedanceVoiceDimensions, emotion: VoiceEmotion) -> String {
    let (speech_rate, breath, pitch) = match emotion {
        VoiceEmotion::Angry => ("语速偏快", "气息急促", "音调偏高"),
        VoiceEmotion::Sad => ("语速偏慢", "气息绵长", "音调偏低"),
        VoiceEmotion::Tense => ("语速偏快", "气息急促", "音调偏高"),
        VoiceEmotion::Gentle => ("语速偏慢", "气息平稳", "音调适中"),
        VoiceEmotion::Happy => ("语速适中", "气息平稳", "音调偏高"),
        VoiceEmotion::Neutral => ("语速适中", "气息平稳", "音调适中"),
    };
    format!(
        "性别:{} 年龄音色:{} 音调:{} 音色质感:{} 声音厚度:{} 发音方式:{} 气息:{} 语速:{} 特殊质感:{}",
        dims.gender.as_deref().unwrap_or("女"),
        dims.age_tone.as_deref().unwrap_or("青年"),
        dims.pitch.as_deref().unwrap_or(pitch),
        dims.tone_quality.as_deref().unwrap_or("清澈"),
        dims.thickness.as_deref().unwrap_or("中等"),
        dims.pronunciation.as_deref().unwrap_or("标准"),
        dims.breath.as_deref().unwrap_or(breath),
        dims.speech_rate.as_deref().unwrap_or(speech_rate),
        dims.special_texture.as_deref().unwrap_or("无"),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn seedance_desc_includes_all_nine_dimensions() {
        let desc =
            build_seedance_voice_desc(&SeedanceVoiceDimensions::default(), VoiceEmotion::Neutral);
        for label in SEEDANCE_DIMENSION_LABELS {
            assert!(desc.contains(label), "missing {label} in {desc}");
        }
    }
}
