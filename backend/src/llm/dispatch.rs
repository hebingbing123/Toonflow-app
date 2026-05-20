//! Route chat completions by catalog [`VendorProtocol`].

use serde_json::Value;

use crate::vendor::catalog::VendorProtocol;

use super::anthropic::anthropic_chat_completion_with_usage;
use super::gemini::gemini_chat_completion_with_usage;
use super::openai::chat::completion::{
    chat_completion_with_usage as openai_chat_completion_with_usage, ChatCompletionResult,
};
use super::LlmConfig;

pub async fn chat_completion_with_usage(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<ChatCompletionResult, String> {
    match cfg.protocol {
        VendorProtocol::Anthropic => {
            anthropic_chat_completion_with_usage(cfg, client, messages).await
        }
        VendorProtocol::GeminiNative => {
            gemini_chat_completion_with_usage(cfg, client, messages).await
        }
        VendorProtocol::OpenAiCompatible
        | VendorProtocol::VolcengineArk
        | VendorProtocol::AzureOpenAi => {
            openai_chat_completion_with_usage(cfg, client, messages).await
        }
    }
}

pub async fn chat_completion_assistant_text(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    messages: Vec<Value>,
) -> Result<String, String> {
    let result = chat_completion_with_usage(cfg, client, messages).await?;
    Ok(result.content)
}
