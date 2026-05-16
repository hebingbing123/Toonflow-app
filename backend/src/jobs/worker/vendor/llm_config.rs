use crate::llm::LlmConfig;
use crate::state::AppState;

use super::super::JobRunError;

pub(super) fn vendor_probe_llm_config(
    state: &AppState,
    api_key_override: Option<String>,
    model_name: &str,
) -> Result<LlmConfig, JobRunError> {
    if let Some(api_key) = api_key_override {
        let base_url = std::env::var("OPENAI_BASE_URL")
            .unwrap_or_else(|_| "https://api.openai.com/v1".to_string())
            .trim_end_matches('/')
            .to_string();
        return Ok(LlmConfig {
            api_key,
            base_url,
            model: model_name.to_string(),
        });
    }

    let Some(cfg) = state.llm.as_ref() else {
        return Err(JobRunError::Failed(
            "vendor probe requires stored credential or OPENAI_API_KEY / LLM_API_KEY".into(),
        ));
    };

    Ok(LlmConfig {
        api_key: cfg.api_key.clone(),
        base_url: cfg.base_url.clone(),
        model: model_name.to_string(),
    })
}
