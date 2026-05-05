//! LLM 模块：OpenAI 兼容的聊天补全和图像生成。
//!
//! 为代理对话提供流式聊天补全，为资产生成任务提供 `images/generations` 和 `images/edits` 功能。
//! 子模块：
//! - `openai` — OpenAI API 客户端
//! - `agent_loop` — 代理执行循环
//! - `envelope` — 消息信封处理

mod agent_loop;
mod envelope;
pub mod openai;

pub use agent_loop::harness_agent_run;
pub use openai::{
    audio_speech_bytes, chat_completion_assistant_text, chat_completion_with_usage,
    images_generation_or_edit_url, images_generation_url, resolve_openai_image_model,
    resolve_openai_image_size, stream_chat_turn, LlmConfig, TokenUsage,
};
