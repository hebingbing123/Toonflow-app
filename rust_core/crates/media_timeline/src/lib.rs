//! Timeline domain primitives for Openflow desktop-first media editing.
//!
//! This crate intentionally starts small: it defines the persisted document
//! shape that both desktop and backend can grow around before adding heavy
//! preview, waveform, or render logic.

use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TimelineDocument {
    pub id: Uuid,
    pub revision: u32,
    pub video_tracks: Vec<VideoTrack>,
    pub audio_tracks: Vec<AudioTrack>,
    pub subtitles: Vec<SubtitleCue>,
}

impl TimelineDocument {
    pub fn empty() -> Self {
        Self {
            id: Uuid::new_v4(),
            revision: 0,
            video_tracks: Vec::new(),
            audio_tracks: Vec::new(),
            subtitles: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct VideoTrack {
    pub id: Uuid,
    pub name: String,
    pub clips: Vec<VideoClip>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AudioTrack {
    pub id: Uuid,
    pub name: String,
    pub role: AudioTrackRole,
    pub clips: Vec<AudioClip>,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum AudioTrackRole {
    Voiceover,
    Music,
    Effects,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct VideoClip {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub timeline_in_ms: u64,
    pub duration_ms: u64,
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AudioClip {
    pub id: Uuid,
    pub asset_id: Uuid,
    pub timeline_in_ms: u64,
    pub duration_ms: u64,
    pub gain_db: i32,
    pub enabled: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SubtitleCue {
    pub id: Uuid,
    pub start_ms: u64,
    pub end_ms: u64,
    pub text: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_document_has_no_tracks() {
        let doc = TimelineDocument::empty();
        assert_eq!(doc.revision, 0);
        assert!(doc.video_tracks.is_empty());
        assert!(doc.audio_tracks.is_empty());
        assert!(doc.subtitles.is_empty());
    }
}
