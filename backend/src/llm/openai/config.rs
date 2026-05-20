use crate::vendor::catalog::VendorProtocol;

#[derive(Clone, Debug)]
pub struct LlmConfig {
    pub api_key: String,
    pub base_url: String,
    pub model: String,
    pub protocol: VendorProtocol,
}

impl LlmConfig {
    pub fn from_env() -> Option<Self> {
        let api_key = std::env::var("OPENAI_API_KEY")
            .or_else(|_| std::env::var("LLM_API_KEY"))
            .ok()
            .filter(|s| !s.is_empty())?;
        let base_url = std::env::var("OPENAI_BASE_URL")
            .unwrap_or_else(|_| "https://api.openai.com/v1".to_string());
        let base_url = base_url.trim_end_matches('/').to_string();
        let model = std::env::var("LLM_MODEL").unwrap_or_else(|_| "gpt-4o-mini".to_string());
        Some(Self {
            api_key,
            base_url,
            model,
            protocol: VendorProtocol::OpenAiCompatible,
        })
    }
}
