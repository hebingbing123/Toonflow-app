//! Map scene / storyboard mood hints to voice emotion.

use super::emotion::VoiceEmotion;

#[derive(Debug, Clone, Default)]
pub struct SceneVoiceContext {
    pub mood: Option<String>,
    pub tension: Option<String>,
    pub character_state: Option<String>,
}

impl SceneVoiceContext {
    pub fn infer_emotion(&self) -> VoiceEmotion {
        let blob = [
            self.mood.as_deref(),
            self.tension.as_deref(),
            self.character_state.as_deref(),
        ]
        .into_iter()
        .flatten()
        .map(str::to_lowercase)
        .collect::<Vec<_>>()
        .join(" ");

        if blob.contains("怒") || blob.contains("angry") || blob.contains("冲突") {
            return VoiceEmotion::Angry;
        }
        if blob.contains("悲")
            || blob.contains("哭")
            || blob.contains("sad")
            || blob.contains("压抑")
        {
            return VoiceEmotion::Sad;
        }
        if blob.contains("紧") || blob.contains("tense") || blob.contains("悬") {
            return VoiceEmotion::Tense;
        }
        if blob.contains("温柔") || blob.contains("gentle") || blob.contains("暖") {
            return VoiceEmotion::Gentle;
        }
        if blob.contains("喜") || blob.contains("happy") || blob.contains("轻松") {
            return VoiceEmotion::Happy;
        }
        VoiceEmotion::Neutral
    }
}

pub fn scene_context_from_metadata(metadata: &serde_json::Value) -> SceneVoiceContext {
    let scene = metadata
        .get("scene")
        .or_else(|| metadata.get("sceneContext"));
    SceneVoiceContext {
        mood: scene
            .and_then(|v| v.get("mood"))
            .and_then(|v| v.as_str())
            .map(str::to_string)
            .or_else(|| {
                metadata
                    .get("mood")
                    .and_then(|v| v.as_str())
                    .map(str::to_string)
            }),
        tension: scene
            .and_then(|v| v.get("tension"))
            .and_then(|v| v.as_str())
            .map(str::to_string),
        character_state: scene
            .and_then(|v| v.get("characterState").or_else(|| v.get("character_state")))
            .and_then(|v| v.as_str())
            .map(str::to_string),
    }
}
