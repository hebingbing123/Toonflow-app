//! Alipay PC web pay (page pay) + RSA2 notify verification.

use std::collections::BTreeMap;

use rsa::pkcs1::DecodeRsaPrivateKey;
use rsa::pkcs1v15::{Signature, SigningKey, VerifyingKey};
use rsa::pkcs8::{DecodePrivateKey, DecodePublicKey};
use rsa::signature::{SignatureEncoding, Signer, Verifier};
use rsa::RsaPrivateKey;
use sha2::Sha256;
use urlencoding::encode;

use crate::error::ApiError;

const ALIPAY_GATEWAY: &str = "https://openapi.alipay.com/gateway.do";
const ALIPAY_SANDBOX_GATEWAY: &str = "https://openapi-sandbox.dl.alipaydev.com/gateway.do";

pub struct AlipayConfig {
    pub app_id: String,
    pub private_key_pem: String,
    pub alipay_public_key_pem: String,
    pub notify_url: String,
    pub return_url: String,
    pub sandbox: bool,
}

impl AlipayConfig {
    pub fn from_env() -> Option<Self> {
        let app_id = std::env::var("ALIPAY_APP_ID").ok()?;
        if app_id.trim().is_empty() {
            return None;
        }
        let private_key_pem = std::env::var("ALIPAY_PRIVATE_KEY").ok()?;
        let alipay_public_key_pem = std::env::var("ALIPAY_PUBLIC_KEY").ok()?;
        let notify_url = std::env::var("ALIPAY_NOTIFY_URL").ok()?;
        let return_url = std::env::var("ALIPAY_RETURN_URL").unwrap_or_default();
        let sandbox = std::env::var("ALIPAY_SANDBOX")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);
        Some(Self {
            app_id,
            private_key_pem: normalize_pem(&private_key_pem),
            alipay_public_key_pem: normalize_pem(&alipay_public_key_pem),
            notify_url,
            return_url,
            sandbox,
        })
    }

    pub fn gateway(&self) -> &'static str {
        if self.sandbox {
            ALIPAY_SANDBOX_GATEWAY
        } else {
            ALIPAY_GATEWAY
        }
    }
}

fn normalize_pem(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.contains("BEGIN") {
        return trimmed.replace("\\n", "\n");
    }
    format!(
        "-----BEGIN PRIVATE KEY-----\n{}\n-----END PRIVATE KEY-----",
        chunk_pem_body(trimmed)
    )
}

fn normalize_public_pem(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.contains("BEGIN") {
        return trimmed.replace("\\n", "\n");
    }
    format!(
        "-----BEGIN PUBLIC KEY-----\n{}\n-----END PUBLIC KEY-----",
        chunk_pem_body(trimmed)
    )
}

fn chunk_pem_body(s: &str) -> String {
    s.chars()
        .collect::<Vec<_>>()
        .chunks(64)
        .map(|c| c.iter().collect::<String>())
        .collect::<Vec<_>>()
        .join("\n")
}

pub fn mock_checkout_enabled() -> bool {
    std::env::var("BILLING_CHECKOUT_MOCK")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false)
}

pub fn build_page_pay_url(
    cfg: &AlipayConfig,
    out_trade_no: &str,
    subject: &str,
    total_amount_yuan: &str,
    passback: &str,
) -> Result<String, ApiError> {
    let mut params = BTreeMap::new();
    params.insert("app_id".to_string(), cfg.app_id.clone());
    params.insert("method".to_string(), "alipay.trade.page.pay".to_string());
    params.insert("format".to_string(), "JSON".to_string());
    params.insert("charset".to_string(), "utf-8".to_string());
    params.insert("sign_type".to_string(), "RSA2".to_string());
    params.insert(
        "timestamp".to_string(),
        chrono::Utc::now().format("%Y-%m-%d %H:%M:%S").to_string(),
    );
    params.insert("version".to_string(), "1.0".to_string());
    params.insert("notify_url".to_string(), cfg.notify_url.clone());
    if !cfg.return_url.is_empty() {
        params.insert("return_url".to_string(), cfg.return_url.clone());
    }
    let biz = serde_json::json!({
        "out_trade_no": out_trade_no,
        "product_code": "FAST_INSTANT_TRADE_PAY",
        "total_amount": total_amount_yuan,
        "subject": subject,
        "passback_params": passback,
    });
    params.insert("biz_content".to_string(), biz.to_string());

    let sign = sign_params(&params, &cfg.private_key_pem)?;
    params.insert("sign".to_string(), sign);

    let query: String = params
        .iter()
        .map(|(k, v)| format!("{}={}", encode(k), encode(v)))
        .collect::<Vec<_>>()
        .join("&");
    Ok(format!("{}?{}", cfg.gateway(), query))
}

fn sign_params(
    params: &BTreeMap<String, String>,
    private_key_pem: &str,
) -> Result<String, ApiError> {
    let content = canonical_string(params);
    let key = RsaPrivateKey::from_pkcs1_pem(private_key_pem)
        .or_else(|_| RsaPrivateKey::from_pkcs8_pem(private_key_pem))
        .map_err(|e| {
            tracing::error!(error = %e, "alipay private key parse failed");
            ApiError::Internal
        })?;
    let signing_key = SigningKey::<Sha256>::new(key);
    let signature = signing_key.sign(content.as_bytes());
    Ok(base64::Engine::encode(
        &base64::engine::general_purpose::STANDARD,
        signature.to_bytes(),
    ))
}

pub fn verify_notify(
    params: &BTreeMap<String, String>,
    alipay_public_pem: &str,
) -> Result<(), ApiError> {
    let sign_b64 = params
        .get("sign")
        .ok_or(ApiError::InvalidWebhookSignature)?;
    let mut unsigned = params.clone();
    unsigned.remove("sign");
    unsigned.remove("sign_type");
    let content = canonical_string(&unsigned);
    let public_key = rsa::RsaPublicKey::from_public_key_pem(&normalize_public_pem(
        alipay_public_pem,
    ))
    .map_err(|e| {
        tracing::error!(error = %e, "alipay public key parse failed");
        ApiError::Internal
    })?;
    let verifying_key = VerifyingKey::<Sha256>::new(public_key);
    let sig_bytes = base64::Engine::decode(&base64::engine::general_purpose::STANDARD, sign_b64)
        .map_err(|_| ApiError::InvalidWebhookSignature)?;
    let signature =
        Signature::try_from(sig_bytes.as_slice()).map_err(|_| ApiError::InvalidWebhookSignature)?;
    verifying_key
        .verify(content.as_bytes(), &signature)
        .map_err(|_| ApiError::InvalidWebhookSignature)
}

fn canonical_string(params: &BTreeMap<String, String>) -> String {
    params
        .iter()
        .filter(|(k, v)| *k != "sign" && *k != "sign_type" && !v.is_empty())
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>()
        .join("&")
}

pub fn parse_form_body(body: &str) -> BTreeMap<String, String> {
    let mut map = BTreeMap::new();
    for pair in body.split('&') {
        if let Some((k, v)) = pair.split_once('=') {
            let key = urlencoding::decode(k).unwrap_or_else(|_| k.into());
            let val = urlencoding::decode(v).unwrap_or_else(|_| v.into());
            map.insert(key.into_owned(), val.into_owned());
        }
    }
    map
}

pub fn cents_to_yuan(amount_cents: i64) -> String {
    format!("{:.2}", amount_cents as f64 / 100.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cents_to_yuan_formats() {
        assert_eq!(cents_to_yuan(7900), "79.00");
    }

    #[test]
    fn parse_form_body_decodes() {
        let m = parse_form_body("out_trade_no=abc&trade_status=TRADE_SUCCESS");
        assert_eq!(m.get("out_trade_no").map(String::as_str), Some("abc"));
    }
}
