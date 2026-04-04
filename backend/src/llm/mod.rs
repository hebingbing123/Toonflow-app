//! OpenAI-compatible Chat Completions (streaming) for agent turns.

mod openai;

pub use openai::{stream_chat_turn, LlmConfig};
