//! Multi-speaker dialogue parsing for multi-track voiceover assembly.

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema, PartialEq, Eq)]
pub struct DialogueSegment {
    pub speaker: String,
    pub text: String,
}

/// Parse lines like `林晚：你终于来了` or `陆景深: 别走`.
pub fn parse_dialogue_segments(text: &str) -> Vec<DialogueSegment> {
    let mut segments = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        if let Some((speaker, rest)) = line.split_once('：').or_else(|| line.split_once(':')) {
            let speaker = speaker.trim();
            let rest = rest.trim();
            if !speaker.is_empty() && !rest.is_empty() {
                segments.push(DialogueSegment {
                    speaker: speaker.to_string(),
                    text: rest.to_string(),
                });
                continue;
            }
        }
        if let Some(last) = segments.last_mut() {
            if !last.text.is_empty() {
                last.text.push(' ');
            }
            last.text.push_str(line);
        } else {
            segments.push(DialogueSegment {
                speaker: "narrator".into(),
                text: line.to_string(),
            });
        }
    }
    segments
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_chinese_speaker_labels() {
        let text = "林晚：你终于来了\n陆景深：别碰我";
        let segs = parse_dialogue_segments(text);
        assert_eq!(segs.len(), 2);
        assert_eq!(segs[0].speaker, "林晚");
        assert_eq!(segs[1].speaker, "陆景深");
    }
}
