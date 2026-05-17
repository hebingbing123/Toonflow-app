//! Azure TTS REST (`/cognitiveservices/v1`) with SSML input.

use reqwest::Client;

#[derive(Debug, Clone)]
pub struct AzureSpeechCredentials {
    pub subscription_key: String,
    pub region: String,
}

pub async fn azure_speech_bytes(
    client: &Client,
    creds: &AzureSpeechCredentials,
    ssml: &str,
    output_format: &str,
) -> Result<Vec<u8>, String> {
    let region = creds.region.trim();
    let url = format!("https://{region}.tts.speech.microsoft.com/cognitiveservices/v1");
    let response = client
        .post(&url)
        .header("Ocp-Apim-Subscription-Key", &creds.subscription_key)
        .header("Content-Type", "application/ssml+xml")
        .header("X-Microsoft-OutputFormat", output_format)
        .body(ssml.to_string())
        .send()
        .await
        .map_err(|e| format!("azure speech request: {e}"))?;
    if !response.status().is_success() {
        let status = response.status();
        let text = response.text().await.unwrap_or_default();
        return Err(format!("azure speech HTTP {status}: {text}"));
    }
    response
        .bytes()
        .await
        .map(|b| b.to_vec())
        .map_err(|e| format!("azure speech body: {e}"))
}

pub fn load_azure_credentials_from_env() -> Option<AzureSpeechCredentials> {
    let key = std::env::var("AZURE_SPEECH_KEY")
        .ok()
        .or_else(|| std::env::var("AZURE_SPEECH_SUBSCRIPTION_KEY").ok())?;
    let key = key.trim();
    if key.is_empty() {
        return None;
    }
    let region = std::env::var("AZURE_SPEECH_REGION").unwrap_or_else(|_| "eastus".to_string());
    Some(AzureSpeechCredentials {
        subscription_key: key.to_string(),
        region: region.trim().to_string(),
    })
}
