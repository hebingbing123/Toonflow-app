use serde_json::{json, Value};
use sqlx::PgPool;

use crate::llm::{
    chat_completion_assistant_text, images_generation_url, resolve_openai_image_model,
    resolve_openai_image_size,
};
use crate::vendor::video::{
    VideoGenerationRequest, VideoGenerationStatus, VideoProvider, VideoProviderClient,
};

use super::llm_config::vendor_probe_llm_config;
use super::preview::{clip_preview, VENDOR_MODEL_TEST_PREVIEW_CHARS};
use super::resolve::{resolve_vendor_probe_targets, vendor_probe_credential_source};
use super::secret::load_vendor_probe_secret;

use super::super::{JobRow, JobRunError};

pub(crate) async fn run_vendor_model_test(
    state: &crate::state::AppState,
    pool: &PgPool,
    row: &JobRow,
) -> Result<Value, JobRunError> {
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
                .and_then(|v| v.slug.parse::<VideoProvider>().ok())
                .or_else(|| raw_vendor_id.parse::<VideoProvider>().ok())
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
