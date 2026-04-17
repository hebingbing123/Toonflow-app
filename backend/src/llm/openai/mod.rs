//! OpenAI 兼容 API 客户端。
//!
//! 聊天补全和图像生成端点，支持流式响应。

mod chat;
mod config;
mod images;

pub use chat::{chat_completion_assistant_text, stream_chat_turn};
pub use config::LlmConfig;
pub use images::{
    images_generation_or_edit_url, images_generation_url, resolve_openai_image_model,
    resolve_openai_image_size,
};

#[cfg(test)]
pub(crate) use chat::{parse_assistant_content, parse_sse_data_line};
#[cfg(test)]
pub(crate) use images::parse_reference_image_upload;
#[cfg(test)]
mod tests;
