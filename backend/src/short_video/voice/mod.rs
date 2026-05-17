//! Drama voice control: structured profiles, emotion, Azure SSML, dialogue tracks (F.2).

pub(crate) mod clone;
pub(crate) mod config;
pub(crate) mod dialogue;
pub(crate) mod emotion;
pub(crate) mod preview;
pub(crate) mod resolve;
pub(crate) mod scene;
pub(crate) mod seedance;
pub(crate) mod ssml;
pub(crate) mod synthesize;

pub use config::{parse_voice_json_value, VoiceProfileConfig};
pub use dialogue::parse_dialogue_segments;
pub use emotion::EMOTION_PRESET_IDS;
pub use preview::{run_voice_preview, VoicePreviewInput};
pub use resolve::{resolve_tts_voice_name, resolve_voice_config, VoiceResolveInput};
pub use scene::scene_context_from_metadata;
pub use synthesize::synthesize_speech;
