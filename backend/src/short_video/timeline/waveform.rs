//! Deterministic voiceover waveform peaks for timeline UI (**NLE M3** stub).

use crate::short_video::timeline::document::TimelineVoiceoverClip;

const PEAK_COUNT: usize = 64;

/// Downsampled peaks in `0.0..=1.0` for Flutter `CustomPaint` bars (no FFmpeg astats).
#[must_use]
pub fn mock_waveform_peaks_for_voiceover(clips: &[TimelineVoiceoverClip]) -> Vec<f64> {
    if clips.is_empty() {
        return Vec::new();
    }
    let seed: u64 = clips.iter().fold(0u64, |acc, c| {
        acc.wrapping_add(c.storyboard_numeric_id as u64)
            .wrapping_add(c.start_ms as u64)
    });
    (0..PEAK_COUNT)
        .map(|i| {
            let x = seed.wrapping_add(i as u64 * 1103515245);
            let n = ((x >> 16) & 0x7fff) as f64 / 32767.0;
            (0.15 + n * 0.85).clamp(0.0, 1.0)
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn peaks_are_stable() {
        let clips = vec![TimelineVoiceoverClip {
            storyboard_numeric_id: 3,
            start_ms: 0,
            source_url: "https://x/a.mp3".into(),
            volume: 1.0,
        }];
        let a = mock_waveform_peaks_for_voiceover(&clips);
        let b = mock_waveform_peaks_for_voiceover(&clips);
        assert_eq!(a, b);
        assert_eq!(a.len(), 64);
    }
}
