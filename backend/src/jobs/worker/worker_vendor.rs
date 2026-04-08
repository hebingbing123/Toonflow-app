use super::*;

const VENDOR_MODEL_TEST_PREVIEW_CHARS: usize = 160;

fn clip_preview(text: &str, max_chars: usize) -> String {
    let trimmed = text.trim();
    if trimmed.chars().count() <= max_chars {
        return trimmed.to_string();
    }
    let mut clipped = trimmed.chars().take(max_chars).collect::<String>();
    clipped.push_str("...");
    clipped
}

#[derive(sqlx::FromRow)]
struct VendorCredentialProbeRow {
    api_key_encrypted: Option<Vec<u8>>,
    api_secret_encrypted: Option<Vec<u8>>,
    api_token_encrypted: Option<Vec<u8>>,
}

async fn load_vendor_probe_secret(
    pool: &PgPool,
    owner_user_id: Uuid,
    candidates: &[String],
) -> Result<Option<String>, JobRunError> {
    for vendor_id in candidates {
        let row = sqlx::query_as::<_, VendorCredentialProbeRow>(
            r#"
            SELECT api_key_encrypted, api_secret_encrypted, api_token_encrypted
            FROM app_vendor_credential
            WHERE owner_user_id = $1 AND vendor_id = $2
            "#,
        )
        .bind(owner_user_id)
        .bind(vendor_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))?;

        let Some(row) = row else {
            continue;
        };

        for encrypted in [
            row.api_key_encrypted.as_deref(),
            row.api_token_encrypted.as_deref(),
            row.api_secret_encrypted.as_deref(),
        ]
        .into_iter()
        .flatten()
        {
            if let Some(value) = decrypt(encrypted) {
                let trimmed = value.trim();
                if !trimmed.is_empty() {
                    return Ok(Some(trimmed.to_string()));
                }
            }
        }
    }

    Ok(None)
}

fn vendor_probe_llm_config(
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

pub(super) async fn run_vendor_model_test(
    state: &AppState,
    pool: &PgPool,
    row: &JobRow,
) -> Result<serde_json::Value, JobRunError> {
    let payload = &row.payload;
    let model_name = payload
        .get("model_name")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing model_name".into()))?;
    let kind = payload
        .get("kind")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing kind".into()))?;
    let raw_vendor_id = payload
        .get("id")
        .and_then(|x| x.as_str())
        .ok_or_else(|| JobRunError::Failed("payload missing id".into()))?;

    let (vendor, resolved_vendor_id, vendor_candidates) =
        resolve_vendor_probe_targets(raw_vendor_id);

    let stored_secret =
        load_vendor_probe_secret(pool, row.owner_user_id, &vendor_candidates).await?;
    let credential_source = vendor_probe_credential_source(kind, stored_secret.is_some());

    match kind {
        "text" => {
            let cfg = vendor_probe_llm_config(state, stored_secret, model_name)?;
            let text = chat_completion_assistant_text(
                &cfg,
                &state.http_client,
                vec![
                    json!({"role": "system", "content": "Reply with exactly: pong"}),
                    json!({"role": "user", "content": "ping"}),
                ],
            )
            .await
            .map_err(JobRunError::Failed)?;

            Ok(json!({
                "source": "settings.vendors.model-test",
                "vendor_id": raw_vendor_id,
                "resolved_vendor_id": resolved_vendor_id,
                "resolved_vendor_name": vendor.as_ref().map(|v| v.name.clone()),
                "model_name": model_name,
                "kind": kind,
                "probe_status": "ok",
                "credential_source": credential_source,
                "response_preview": clip_preview(&text, VENDOR_MODEL_TEST_PREVIEW_CHARS),
            }))
        }
        "image" => {
            let cfg = vendor_probe_llm_config(state, stored_secret, model_name)?;
            let resolved_model = resolve_openai_image_model(model_name);
            let size = resolve_openai_image_size(&resolved_model, "1024x1024");
            let (image_url, revised_prompt) = images_generation_url(
                &cfg,
                &state.http_client,
                &resolved_model,
                "Toonflow vendor smoke test image: a simple gray card with the word OK centered.",
                size,
            )
            .await
            .map_err(JobRunError::Failed)?;

            Ok(json!({
                "source": "settings.vendors.model-test",
                "vendor_id": raw_vendor_id,
                "resolved_vendor_id": resolved_vendor_id,
                "resolved_vendor_name": vendor.as_ref().map(|v| v.name.clone()),
                "model_name": resolved_model,
                "kind": kind,
                "probe_status": "ok",
                "credential_source": credential_source,
                "image_url": image_url,
                "revised_prompt": revised_prompt,
            }))
        }
        "video" => {
            let provider = vendor
                .as_ref()
                .and_then(|v| VideoProvider::from_str(&v.slug))
                .or_else(|| VideoProvider::from_str(raw_vendor_id))
                .ok_or_else(|| {
                    JobRunError::Failed(format!(
                        "video vendor '{raw_vendor_id}' is not supported; expected Runway, Pika, or Kling"
                    ))
                })?;

            let response = VideoProviderClient::new()
                .generate_video_with_api_key(
                    &VideoGenerationRequest {
                        provider,
                        model: model_name.to_string(),
                        prompt: "Toonflow vendor smoke test video: a minimal monochrome title card with the word OK.".to_string(),
                        negative_prompt: None,
                        duration: 5,
                        resolution: "720p".to_string(),
                        aspect_ratio: "16:9".to_string(),
                        image_url: None,
                        seed: None,
                    },
                    stored_secret.as_deref(),
                )
                .await
                .map_err(|e| JobRunError::Failed(e.to_string()))?;

            Ok(json!({
                "source": "settings.vendors.model-test",
                "vendor_id": raw_vendor_id,
                "resolved_vendor_id": resolved_vendor_id,
                "resolved_vendor_name": vendor.as_ref().map(|v| v.name.clone()),
                "model_name": response.model,
                "kind": kind,
                "probe_status": match response.status {
                    VideoGenerationStatus::Failed => "failed",
                    _ => "queued",
                },
                "credential_source": credential_source,
                "provider": response.provider,
                "task_id": response.task_id,
                "status": response.status.as_str(),
                "preview_url": response.preview_url,
                "video_url": response.video_url,
                "error_message": response.error_message,
            }))
        }
        other => Err(JobRunError::Failed(format!(
            "unsupported vendor model test kind: {other}"
        ))),
    }
}

fn resolve_vendor_probe_targets(
    raw_vendor_id: &str,
) -> (
    Option<crate::models_catalog::VendorCatalogLookup>,
    String,
    Vec<String>,
) {
    let vendor = lookup_vendor_catalog(raw_vendor_id);
    let resolved_vendor_id = vendor
        .as_ref()
        .map(|v| v.slug.clone())
        .unwrap_or_else(|| raw_vendor_id.trim().to_ascii_lowercase());
    let mut vendor_candidates = vec![raw_vendor_id.trim().to_string()];
    if vendor_candidates.iter().all(|v| v != &resolved_vendor_id) {
        vendor_candidates.push(resolved_vendor_id.clone());
    }
    if let Some(vendor) = vendor.as_ref() {
        let legacy_id = vendor.legacy_id.to_string();
        if vendor_candidates.iter().all(|v| v != &legacy_id) {
            vendor_candidates.push(legacy_id);
        }
    }
    (vendor, resolved_vendor_id, vendor_candidates)
}

fn vendor_probe_credential_source(kind: &str, has_stored_secret: bool) -> &'static str {
    if has_stored_secret {
        "stored_vendor_credential"
    } else if kind == "video" {
        "provider_env"
    } else {
        "server_llm_env"
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use tokio::sync::RwLock;

    use super::*;
    use crate::notify_hub::WsNotifyHub;
    use crate::state::MemoryConfig;

    fn test_state_without_llm() -> AppState {
        AppState {
            pool: None,
            jwt_secret: None,
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_legacy())),
            switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
            local_asset_image_dir: None,
            local_art_style_cover_dir: None,
        }
    }

    #[test]
    fn clip_preview_trims_and_ellipsizes() {
        assert_eq!(clip_preview("  ok  ", 8), "ok");
        assert_eq!(clip_preview("abcdef", 4), "abcd...");
    }

    #[test]
    fn resolve_vendor_probe_targets_expands_catalog_aliases() {
        let (vendor, resolved_vendor_id, candidates) = resolve_vendor_probe_targets("1");
        assert!(
            vendor.is_some(),
            "legacy id should resolve into vendor catalog"
        );
        assert_eq!(resolved_vendor_id, "openai");
        assert_eq!(candidates, vec!["1", "openai"]);
    }

    #[test]
    fn resolve_vendor_probe_targets_normalizes_unknown_vendor_ids() {
        let (vendor, resolved_vendor_id, candidates) =
            resolve_vendor_probe_targets("  CUSTOM-ENDPOINT  ");
        assert!(vendor.is_none());
        assert_eq!(resolved_vendor_id, "custom-endpoint");
        assert_eq!(candidates, vec!["CUSTOM-ENDPOINT", "custom-endpoint"]);
    }

    #[test]
    fn vendor_probe_credential_source_prefers_stored_credentials() {
        assert_eq!(
            vendor_probe_credential_source("text", true),
            "stored_vendor_credential"
        );
        assert_eq!(
            vendor_probe_credential_source("image", false),
            "server_llm_env"
        );
        assert_eq!(
            vendor_probe_credential_source("video", false),
            "provider_env"
        );
    }

    #[test]
    fn vendor_probe_llm_config_without_state_llm_returns_clear_error() {
        let state = test_state_without_llm();
        let err = match vendor_probe_llm_config(&state, None, "gpt-4o-mini") {
            Ok(_) => panic!("text/image probe should require llm config or stored secret"),
            Err(err) => err,
        };

        match err {
            JobRunError::Failed(message) => {
                assert!(
                    message.contains("OPENAI_API_KEY") || message.contains("LLM_API_KEY"),
                    "unexpected message: {message}"
                );
            }
            JobRunError::Cancelled => panic!("unexpected cancellation"),
        }
    }
}
