//! OpenAI-compatible Chat Completions (streaming) for agent turns.

mod agent_loop;
mod envelope;
mod openai;

pub use agent_loop::harness_agent_run;
pub use openai::{stream_chat_turn, LlmConfig};
