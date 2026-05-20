//! Tencent Cloud API 3.0 (TC3-HMAC-SHA256) signing for VCLM Hunyuan video.
//!
//! Docs: https://cloud.tencent.com/document/api/1616/107789

use anyhow::{anyhow, Context};
use hmac::{Hmac, Mac};
use reqwest::Client;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};

type HmacSha256 = Hmac<Sha256>;

const VCLM_HOST: &str = "vclm.tencentcloudapi.com";
const VCLM_SERVICE: &str = "vclm";
const VCLM_VERSION: &str = "2024-05-23";
const DEFAULT_REGION: &str = "ap-guangzhou";

#[derive(Clone, Debug)]
pub struct TencentTc3Config {
    pub secret_id: String,
    pub secret_key: String,
    pub host: String,
    pub endpoint_base: String,
    pub region: String,
}

impl TencentTc3Config {
    /// Build TC3 client config from Settings / catalog **`api_base`** (proxy or `vclm.tencentcloudapi.com`).
    pub fn from_keys_and_base(secret_id: &str, secret_key: &str, api_base: &str) -> Self {
        let (host, endpoint_base) = host_and_root_from_api_base(api_base);
        let region = std::env::var("TENCENT_REGION")
            .ok()
            .filter(|s| !s.trim().is_empty())
            .unwrap_or_else(|| DEFAULT_REGION.to_string());
        Self {
            secret_id: secret_id.trim().to_string(),
            secret_key: secret_key.trim().to_string(),
            host,
            endpoint_base,
            region,
        }
    }

    pub fn endpoint(&self) -> String {
        self.endpoint_base.trim_end_matches('/').to_string()
    }
}

fn host_and_root_from_api_base(api_base: &str) -> (String, String) {
    let trimmed = api_base.trim().trim_end_matches('/');
    if let Ok(url) = reqwest::Url::parse(trimmed) {
        if let Some(host) = url.host_str() {
            let host_with_port = match url.port() {
                Some(port) => format!("{host}:{port}"),
                None => host.to_string(),
            };
            return (host_with_port, trimmed.to_string());
        }
    }
    (VCLM_HOST.to_string(), format!("https://{VCLM_HOST}"))
}

fn hmac_sha256(key: &[u8], msg: &[u8]) -> Vec<u8> {
    let mut mac = HmacSha256::new_from_slice(key).expect("hmac key");
    mac.update(msg);
    mac.finalize().into_bytes().to_vec()
}

fn sha256_hex(data: &[u8]) -> String {
    hex::encode(Sha256::digest(data))
}

fn tc3_authorization(
    cfg: &TencentTc3Config,
    _action: &str,
    payload: &str,
    timestamp: i64,
) -> String {
    let date = chrono::DateTime::from_timestamp(timestamp, 0)
        .map(|dt| dt.format("%Y-%m-%d").to_string())
        .unwrap_or_else(|| "1970-01-01".to_string());
    let credential_scope = format!("{date}/{VCLM_SERVICE}/tc3_request");
    let canonical_headers = format!("content-type:application/json\nhost:{}\n", cfg.host);
    let signed_headers = "content-type;host";
    let hashed_payload = sha256_hex(payload.as_bytes());
    let canonical_request = format!(
        "POST\n/\n\n{canonical_headers}{signed_headers}\n{hashed_payload}"
    );
    let hashed_canonical = sha256_hex(canonical_request.as_bytes());
    let string_to_sign = format!(
        "TC3-HMAC-SHA256\n{timestamp}\n{credential_scope}\n{hashed_canonical}"
    );
    let secret_date = hmac_sha256(format!("TC3{}", cfg.secret_key).as_bytes(), date.as_bytes());
    let secret_service = hmac_sha256(&secret_date, VCLM_SERVICE.as_bytes());
    let secret_signing = hmac_sha256(&secret_service, b"tc3_request");
    let signature = hex::encode(hmac_sha256(&secret_signing, string_to_sign.as_bytes()));
    format!(
        "TC3-HMAC-SHA256 Credential={}/{}, SignedHeaders={}, Signature={}",
        cfg.secret_id, credential_scope, signed_headers, signature
    )
}

/// `POST https://{host}/` with `X-TC-Action` and JSON body; returns the `Response` object.
pub async fn call_vclm_action(
    client: &Client,
    cfg: &TencentTc3Config,
    action: &str,
    body: Value,
) -> anyhow::Result<Value> {
    let payload = serde_json::to_string(&body)?;
    let timestamp = chrono::Utc::now().timestamp();
    let authorization = tc3_authorization(cfg, action, &payload, timestamp);
    let url = format!("{}/", cfg.endpoint());
    let resp = client
        .post(&url)
        .header("Authorization", authorization)
        .header("Content-Type", "application/json")
        .header("Host", &cfg.host)
        .header("X-TC-Action", action)
        .header("X-TC-Version", VCLM_VERSION)
        .header("X-TC-Timestamp", timestamp.to_string())
        .header("X-TC-Region", &cfg.region)
        .body(payload)
        .send()
        .await
        .with_context(|| format!("VCLM {action} request failed"))?;
    let status = resp.status();
    let text = resp.text().await.unwrap_or_default();
    let parsed: Value = serde_json::from_str(&text).unwrap_or_else(|_| json!({ "raw": text }));
    if !status.is_success() {
        return Err(anyhow!(
            "VCLM {action} HTTP {status}: {}",
            parsed
                .pointer("/Response/Error/Message")
                .or_else(|| parsed.get("message"))
                .and_then(|v| v.as_str())
                .unwrap_or(&text)
        ));
    }
    parsed
        .get("Response")
        .cloned()
        .ok_or_else(|| anyhow!("VCLM {action}: missing Response in {parsed}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tc3_authorization_is_deterministic_for_fixture() {
        let cfg =
            TencentTc3Config::from_keys_and_base("AKID", "SECRET", &format!("https://{VCLM_HOST}"));
        let auth = tc3_authorization(&cfg, "SubmitHunyuanToVideoJob", r#"{"Prompt":"hi"}"#, 1_700_000_000);
        assert!(auth.starts_with("TC3-HMAC-SHA256 Credential=AKID/"));
        assert!(auth.contains("Signature="));
    }
}
