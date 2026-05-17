//! SRT sidecar generation for FFmpeg `subtitles` filter (**NLE M2**).

use std::path::Path;

use crate::short_video::timeline::TimelineSubtitleCue;

fn ms_to_srt_time(ms: i64) -> String {
    let ms = ms.max(0);
    let h = ms / 3_600_000;
    let m = (ms % 3_600_000) / 60_000;
    let s = (ms % 60_000) / 1000;
    let rem = ms % 1000;
    format!("{h:02}:{m:02}:{s:02},{rem:03}")
}

/// Build SRT content; cues sorted by `start_ms`.
#[must_use]
pub fn build_srt_content(cues: &[TimelineSubtitleCue]) -> String {
    let mut sorted: Vec<&TimelineSubtitleCue> = cues.iter().collect();
    sorted.sort_by_key(|c| c.start_ms);
    let mut out = String::new();
    for (idx, cue) in sorted.iter().enumerate() {
        let text = cue.text.replace('\r', "").trim().to_string();
        if text.is_empty() || cue.end_ms <= cue.start_ms {
            continue;
        }
        out.push_str(&format!(
            "{}\n{} --> {}\n{}\n\n",
            idx + 1,
            ms_to_srt_time(cue.start_ms),
            ms_to_srt_time(cue.end_ms),
            text
        ));
    }
    out
}

pub async fn write_srt_file(
    cues: &[TimelineSubtitleCue],
    path: &Path,
) -> Result<bool, std::io::Error> {
    let body = build_srt_content(cues);
    if body.trim().is_empty() {
        return Ok(false);
    }
    tokio::fs::write(path, body).await?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn srt_format_basic() {
        let cues = vec![TimelineSubtitleCue {
            storyboard_numeric_id: None,
            start_ms: 0,
            end_ms: 1500,
            text: "Hi".into(),
            style_id: None,
        }];
        let srt = build_srt_content(&cues);
        assert!(srt.contains("00:00:00,000 --> 00:00:01,500"));
        assert!(srt.contains("Hi"));
    }
}
