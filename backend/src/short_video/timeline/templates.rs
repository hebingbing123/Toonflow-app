//! Rough-cut template application (**NLE M3**).

use crate::short_video::assembly_query::AssemblyFlatRow;
use crate::short_video::timeline::default_tracks_from_assembly;
use crate::short_video::timeline::document::{
    TimelineSubtitleCue, TimelineTracks, TimelineTransition, TimelineTransitionType,
    TimelineVideoClip, TimelineVoiceoverClip,
};

pub const TEMPLATE_SHORT_DRAMA_DEFAULT: &str = "short_drama_default";
pub const TEMPLATE_DIALOGUE_PUNCH: &str = "dialogue_punch";

#[must_use]
pub fn is_known_template(id: &str) -> bool {
    matches!(
        id.trim(),
        TEMPLATE_SHORT_DRAMA_DEFAULT | TEMPLATE_DIALOGUE_PUNCH
    )
}

/// Apply template: rebuild video order/in-out, seed subtitles & voiceover from assembly.
#[must_use]
pub fn apply_template(
    template_id: &str,
    flat: &[AssemblyFlatRow],
    bgm_strategy: Option<&str>,
    existing: Option<&TimelineTracks>,
) -> TimelineTracks {
    let mut tracks = default_tracks_from_assembly(flat, bgm_strategy);
    tracks.template_id = Some(template_id.trim().to_string());

    if template_id == TEMPLATE_DIALOGUE_PUNCH {
        for clip in &mut tracks.video {
            let span = clip.out_ms - clip.in_ms;
            let punch = (span * 85 / 100).max(500);
            clip.out_ms = clip.in_ms + punch;
        }
        tracks.transitions = (0..tracks.video.len().saturating_sub(1))
            .map(|_| TimelineTransition {
                transition_type: TimelineTransitionType::Crossfade,
                duration_ms: 400,
            })
            .collect();
    } else {
        tracks.transitions = (0..tracks.video.len().saturating_sub(1))
            .map(|_| TimelineTransition {
                transition_type: TimelineTransitionType::Cut,
                duration_ms: 0,
            })
            .collect();
    }

    tracks.subtitles = seed_subtitles_from_assembly(flat, &tracks.video);
    tracks.voiceover = seed_voiceover_from_assembly(flat, &tracks.video);

    if let Some(prev) = existing {
        merge_persisted_extras(&mut tracks, prev);
    }

    tracks
}

fn seed_subtitles_from_assembly(
    flat: &[AssemblyFlatRow],
    video: &[TimelineVideoClip],
) -> Vec<TimelineSubtitleCue> {
    let mut cues = Vec::new();
    let mut timeline_offset: i64 = 0;
    for clip in video {
        let row = flat
            .iter()
            .find(|r| r.storyboard_numeric_id == clip.storyboard_numeric_id);
        let text = row
            .and_then(|r| {
                r.video_desc
                    .as_deref()
                    .filter(|s| !s.trim().is_empty())
                    .or(r.prompt.as_deref())
            })
            .unwrap_or("")
            .chars()
            .take(80)
            .collect::<String>();
        if !text.trim().is_empty() {
            let dur = clip.out_ms - clip.in_ms;
            cues.push(TimelineSubtitleCue {
                storyboard_numeric_id: Some(clip.storyboard_numeric_id),
                start_ms: timeline_offset,
                end_ms: timeline_offset + dur,
                text,
                style_id: None,
            });
        }
        timeline_offset += clip.out_ms - clip.in_ms;
    }
    cues
}

fn seed_voiceover_from_assembly(
    flat: &[AssemblyFlatRow],
    video: &[TimelineVideoClip],
) -> Vec<TimelineVoiceoverClip> {
    let mut out = Vec::new();
    let mut timeline_offset: i64 = 0;
    for clip in video {
        if let Some(row) = flat
            .iter()
            .find(|r| r.storyboard_numeric_id == clip.storyboard_numeric_id)
        {
            if let Some(url) = row
                .voiceover_audio_url
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty())
            {
                out.push(TimelineVoiceoverClip {
                    storyboard_numeric_id: clip.storyboard_numeric_id,
                    start_ms: timeline_offset,
                    source_url: url.to_string(),
                    volume: 1.0,
                });
            }
        }
        timeline_offset += clip.out_ms - clip.in_ms;
    }
    out
}

fn merge_persisted_extras(tracks: &mut TimelineTracks, prev: &TimelineTracks) {
    if !prev.subtitles.is_empty() {
        tracks.subtitles = prev.subtitles.clone();
    }
    if !prev.transitions.is_empty() && prev.transitions.len() == tracks.transitions.len() {
        tracks.transitions = prev.transitions.clone();
    }
    if !prev.voiceover.is_empty() {
        tracks.voiceover = prev.voiceover.clone();
    }
    if let Some(bgm) = &prev.bgm {
        tracks.bgm = Some(bgm.clone());
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn row(n: i32, url: &str, vo: Option<&str>) -> AssemblyFlatRow {
        AssemblyFlatRow {
            storyboard_id: Uuid::nil(),
            storyboard_numeric_id: n,
            script_numeric_id: 1,
            script_name: None,
            sb_index: Some(n),
            file_path: Some(url.to_string()),
            duration: Some("5s".into()),
            state: None,
            track_id: None,
            prompt: Some(format!("line {n}")),
            video_desc: None,
            voiceover_state: None,
            voiceover_audio_url: vo.map(str::to_string),
            voiceover_error: None,
            candidate_status: None,
        }
    }

    #[test]
    fn dialogue_punch_shortens_clips() {
        let flat = vec![row(1, "https://x/v.mp4", None)];
        let tracks = apply_template(TEMPLATE_DIALOGUE_PUNCH, &flat, None, None);
        assert!(tracks.video[0].out_ms - tracks.video[0].in_ms <= 5000);
        assert_eq!(tracks.transitions.len(), 0);
    }

    #[test]
    fn default_template_seeds_voiceover() {
        let flat = vec![row(1, "https://x/v.mp4", Some("https://x/vo.mp3"))];
        let tracks = apply_template(TEMPLATE_SHORT_DRAMA_DEFAULT, &flat, None, None);
        assert_eq!(tracks.voiceover.len(), 1);
        assert!(!tracks.video.is_empty());
    }
}
