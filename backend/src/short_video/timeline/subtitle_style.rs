//! Project `subtitle_style` → FFmpeg burn-in parameters.

use serde::Deserialize;

#[derive(Debug, Clone)]
pub struct SubtitleBurnInStyle {
    pub font_size: u32,
    pub margin_v: u32,
    #[allow(dead_code)]
    pub primary_colour: &'static str,
}

impl Default for SubtitleBurnInStyle {
    fn default() -> Self {
        Self {
            font_size: 28,
            margin_v: 48,
            primary_colour: "&HFFFFFF&",
        }
    }
}

#[derive(Debug, Deserialize)]
struct SubtitleStyleJson {
    #[serde(default, alias = "fontSize")]
    font_size: Option<u32>,
    #[serde(default, alias = "marginV")]
    margin_v: Option<u32>,
}

/// Parse `app_project.subtitle_style` (JSON object or style id string).
#[must_use]
pub fn burn_in_style_from_project(subtitle_style: Option<&str>) -> SubtitleBurnInStyle {
    let mut style = SubtitleBurnInStyle::default();
    let Some(raw) = subtitle_style.map(str::trim).filter(|s| !s.is_empty()) else {
        return style;
    };
    if raw.starts_with('{') {
        if let Ok(parsed) = serde_json::from_str::<SubtitleStyleJson>(raw) {
            if let Some(fs) = parsed.font_size {
                style.font_size = fs.clamp(12, 72);
            }
            if let Some(mv) = parsed.margin_v {
                style.margin_v = mv.clamp(8, 200);
            }
        }
        return style;
    }
    match raw.to_lowercase().as_str() {
        "modern" | "default" => {}
        "large" => style.font_size = 36,
        "compact" => {
            style.font_size = 22;
            style.margin_v = 32;
        }
        _ => {}
    }
    style
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_overrides_defaults() {
        let s = burn_in_style_from_project(Some(r#"{"fontSize":40,"marginV":60}"#));
        assert_eq!(s.font_size, 40);
        assert_eq!(s.margin_v, 60);
    }
}
