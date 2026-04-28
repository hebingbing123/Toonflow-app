use axum::{extract::State, http::HeaderMap, Json};
use serde_json::{json, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::llm::chat_completion_with_usage;
use crate::metering::llm_usage::record_llm_usage;
use crate::state::AppState;

use super::super::types::{
    ExtractArtStylePromptBody, ExtractArtStylePromptResponse, EXTRACT_STYLE_SYSTEM_PROMPT,
    MAX_EXTRACT_IMAGES, MAX_IMAGE_ENTRY_BYTES,
};

pub(super) async fn extract_style_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ExtractArtStylePromptBody>,
) -> Result<Json<ExtractArtStylePromptResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;

    if body.images.is_empty() {
        return Err(ApiError::BadRequest("images must be non-empty".into()));
    }
    if body.images.len() > MAX_EXTRACT_IMAGES {
        return Err(ApiError::BadRequest(format!(
            "at most {MAX_EXTRACT_IMAGES} images"
        )));
    }

    let mut parts: Vec<Value> = Vec::with_capacity(body.images.len());
    for (i, raw) in body.images.iter().enumerate() {
        let s = raw.trim();
        if s.is_empty() {
            return Err(ApiError::BadRequest(format!("images[{i}] is empty")));
        }
        if s.len() > MAX_IMAGE_ENTRY_BYTES {
            return Err(ApiError::BadRequest(format!(
                "images[{i}] exceeds max length ({MAX_IMAGE_ENTRY_BYTES} bytes)"
            )));
        }
        parts.push(json!({
            "type": "image_url",
            "image_url": { "url": s }
        }));
    }

    let cfg = state.llm.as_ref().ok_or(ApiError::LlmNotConfigured)?;

    let messages = vec![
        json!({ "role": "system", "content": EXTRACT_STYLE_SYSTEM_PROMPT }),
        json!({ "role": "user", "content": parts }),
    ];
    let prompt_chars = serde_json::to_string(&messages)
        .ok()
        .map(|raw| raw.chars().count() as i64);
    let started_at = std::time::Instant::now();

    let response = match chat_completion_with_usage(cfg, &state.http_client, messages).await {
        Ok(response) => response,
        Err(e) => {
            if let Some(pool) = state.pool.as_ref() {
                record_llm_usage(
                    pool,
                    uid,
                    None,
                    None,
                    None,
                    "art_styles.extract_prompt",
                    &cfg.model,
                    Some("openai"),
                    None,
                    prompt_chars,
                    false,
                    Some(&e),
                    Some(started_at.elapsed().as_millis() as i64),
                    json!({
                        "imageCount": body.images.len(),
                        "route": "art-styles.extract-prompt",
                    }),
                )
                .await;
            }
            tracing::warn!(error = %e, "extract_style_prompt");
            return Err(ApiError::Internal);
        }
    };

    if let Some(pool) = state.pool.as_ref() {
        record_llm_usage(
            pool,
            uid,
            None,
            None,
            None,
            "art_styles.extract_prompt",
            response.model.as_deref().unwrap_or(&cfg.model),
            Some("openai"),
            response.usage.as_ref(),
            prompt_chars,
            true,
            None,
            Some(started_at.elapsed().as_millis() as i64),
            json!({
                "imageCount": body.images.len(),
                "route": "art-styles.extract-prompt",
            }),
        )
        .await;
    }

    Ok(Json(ExtractArtStylePromptResponse {
        text: response.content,
    }))
}
