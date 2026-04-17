use axum::{extract::State, http::HeaderMap, Json};
use serde_json::{json, Value};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::llm::chat_completion_assistant_text;
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
    let _uid = require_user_uuid(&state, &headers)?;

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

    let text = chat_completion_assistant_text(cfg, &state.http_client, messages)
        .await
        .map_err(|e| {
            tracing::warn!(error = %e, "extract_style_prompt");
            ApiError::Internal
        })?;

    Ok(Json(ExtractArtStylePromptResponse { text }))
}
