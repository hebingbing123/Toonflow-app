//! Per-clip FFmpeg effect presets for timeline preview (**NLE M4b**).

use std::path::Path;

/// Known per-clip effect preset ids (schema v4).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TimelineEffectPreset {
    None,
    Vivid,
    Cinematic,
    Bw,
    Speed110,
}

impl TimelineEffectPreset {
    #[must_use]
    #[allow(dead_code)]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::None => "none",
            Self::Vivid => "vivid",
            Self::Cinematic => "cinematic",
            Self::Bw => "bw",
            Self::Speed110 => "speed_110",
        }
    }

    pub fn parse(raw: Option<&str>) -> Self {
        match raw.map(str::trim).filter(|s| !s.is_empty()) {
            Some("vivid") => Self::Vivid,
            Some("cinematic") => Self::Cinematic,
            Some("bw") => Self::Bw,
            Some("speed_110") => Self::Speed110,
            _ => Self::None,
        }
    }

    #[must_use]
    #[allow(dead_code)]
    pub fn needs_reencode(self) -> bool {
        !matches!(self, Self::None)
    }
}

/// FFmpeg `vf` fragment applied after trim, before concat/xfade.
#[must_use]
pub fn video_filter_for_preset(preset: TimelineEffectPreset) -> Option<String> {
    match preset {
        TimelineEffectPreset::None => None,
        TimelineEffectPreset::Vivid => Some("eq=contrast=1.15:saturation=1.25".to_string()),
        TimelineEffectPreset::Cinematic => Some(
            "eq=contrast=1.08:brightness=-0.03:saturation=0.92,vignette=angle=PI/4".to_string(),
        ),
        TimelineEffectPreset::Bw => Some("hue=s=0".to_string()),
        TimelineEffectPreset::Speed110 => Some("setpts=PTS/1.1".to_string()),
    }
}

#[must_use]
pub fn segment_trim_args_with_effect(
    input: &Path,
    in_ms: i64,
    out_ms: i64,
    output: &Path,
    effect_preset_id: Option<&str>,
) -> Vec<String> {
    let preset = TimelineEffectPreset::parse(effect_preset_id);
    let start = format!("{:.3}", in_ms as f64 / 1000.0);
    let duration = format!("{:.3}", (out_ms - in_ms).max(1) as f64 / 1000.0);
    let mut args = vec![
        "-y".into(),
        "-ss".into(),
        start,
        "-i".into(),
        input.display().to_string(),
        "-t".into(),
        duration,
    ];
    if let Some(vf) = video_filter_for_preset(preset) {
        args.push("-vf".into());
        args.push(vf);
        args.push("-c:v".into());
        args.push("libx264".into());
        args.push("-preset".into());
        args.push("veryfast".into());
        args.push("-c:a".into());
        args.push("aac".into());
    } else {
        args.push("-c".into());
        args.push("copy".into());
    }
    args.push(output.display().to_string());
    args
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preset_filter_fragments() {
        assert_eq!(
            video_filter_for_preset(TimelineEffectPreset::Vivid).as_deref(),
            Some("eq=contrast=1.15:saturation=1.25")
        );
        assert_eq!(
            video_filter_for_preset(TimelineEffectPreset::Bw).as_deref(),
            Some("hue=s=0")
        );
        assert!(video_filter_for_preset(TimelineEffectPreset::Speed110)
            .unwrap()
            .contains("setpts"));
    }

    #[test]
    fn trim_with_vivid_uses_vf_not_copy() {
        let args = segment_trim_args_with_effect(
            Path::new("/in.mp4"),
            0,
            2000,
            Path::new("/out.mp4"),
            Some("vivid"),
        );
        assert!(args.contains(&"-vf".to_string()));
        assert!(!args.contains(&"copy".to_string()));
    }

    #[test]
    fn trim_none_uses_stream_copy() {
        let args = segment_trim_args_with_effect(
            Path::new("/in.mp4"),
            0,
            2000,
            Path::new("/out.mp4"),
            None,
        );
        assert!(args.contains(&"copy".to_string()));
    }
}
