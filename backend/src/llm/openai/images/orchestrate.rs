use super::super::config::LlmConfig;
use super::ark::ark_images_generation_url;
use super::dashscope_wan::{dashscope_wan_images_generation_url, is_dashscope_wan_image_model};
use super::edits::images_edit_url;
use super::gemini_imagen::gemini_imagen_generation_url;
use super::generations::images_generation_url;
use crate::vendor::catalog::VendorProtocol;
use crate::vendor::gateway::{
    is_dashscope_official_host, is_gemini_official_host, is_volcengine_ark_official_host,
};

/// Uses **`images/edits`** when a reference image is provided; otherwise protocol-aware generation.
pub async fn images_generation_or_edit_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
    image_base64: Option<&str>,
) -> Result<(String, Option<String>), String> {
    let Some(reference) = image_base64.map(str::trim).filter(|s| !s.is_empty()) else {
        return dispatch_images_generation(cfg, client, model, prompt, size).await;
    };
    images_edit_url(cfg, client, model, prompt, size, reference).await
}

async fn dispatch_images_generation(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
) -> Result<(String, Option<String>), String> {
    match cfg.protocol {
        VendorProtocol::VolcengineArk if is_volcengine_ark_official_host(&cfg.base_url) => {
            ark_images_generation_url(cfg, client, model, prompt, size).await
        }
        VendorProtocol::GeminiNative if is_gemini_official_host(&cfg.base_url) => {
            gemini_imagen_generation_url(cfg, client, model, prompt, size).await
        }
        _ if is_dashscope_wan_image_model(model) && is_dashscope_official_host(&cfg.base_url) => {
            dashscope_wan_images_generation_url(cfg, client, model, prompt, size).await
        }
        _ => images_generation_url(cfg, client, model, prompt, size).await,
    }
}
