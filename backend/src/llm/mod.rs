//! OpenAI-compatible Chat Completions (streaming) for agent turns and **`images/generations`** for asset jobs.

mod agent_loop;
mod envelope;
mod openai;

pub use agent_loop::harness_agent_run;
pub use openai::{
    chat_completion_assistant_text, images_generation_url, resolve_openai_image_model,
    resolve_openai_image_size, stream_chat_turn, LlmConfig,
};
