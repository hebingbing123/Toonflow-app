use super::super::config::LlmConfig;
use super::edits::images_edit_url;
use super::generations::images_generation_url;

/// Uses **`images/edits`** when a reference image is provided; otherwise **`images/generations`**.
pub async fn images_generation_or_edit_url(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    model: &str,
    prompt: &str,
    size: &str,
    image_base64: Option<&str>,
) -> Result<(String, Option<String>), String> {
    let Some(reference) = image_base64.map(str::trim).filter(|s| !s.is_empty()) else {
        return images_generation_url(cfg, client, model, prompt, size).await;
    };
    images_edit_url(cfg, client, model, prompt, size, reference).await
}
