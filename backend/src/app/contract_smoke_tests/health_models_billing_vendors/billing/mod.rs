mod hmac;
mod ops_view;
mod stripe_signature;
mod user_pricing;

use ::hmac::{Hmac, Mac};
use axum::http::HeaderValue;
use sha2::Sha256;

fn set_billing_webhook_secret(secret: &str) -> Option<std::ffi::OsString> {
    let prev = std::env::var_os("BILLING_WEBHOOK_SECRET");
    std::env::set_var("BILLING_WEBHOOK_SECRET", secret);
    prev
}

fn restore_env_var(key: &str, prev: Option<std::ffi::OsString>) {
    match prev {
        Some(value) => std::env::set_var(key, value),
        None => std::env::remove_var(key),
    }
}

fn sign_webhook_payload(secret: &str, timestamp: u64, body: &[u8]) -> String {
    let mut mac = Hmac::<Sha256>::new_from_slice(secret.as_bytes()).expect("hmac key");
    let ts = timestamp.to_string();
    mac.update(ts.as_bytes());
    mac.update(b".");
    mac.update(body);
    hex::encode(mac.finalize().into_bytes())
}

fn toonflow_hmac_headers(secret: &str, timestamp: u64, body: &[u8]) -> (HeaderValue, String) {
    let signature = sign_webhook_payload(secret, timestamp, body);
    let header = HeaderValue::from_str(&format!("sha256={signature}")).expect("signature header");
    (header, timestamp.to_string())
}

fn stripe_signature_header(secret: &str, timestamp: u64, body: &[u8]) -> HeaderValue {
    let signature = sign_webhook_payload(secret, timestamp, body);
    HeaderValue::from_str(&format!("t={timestamp},v1={signature}"))
        .expect("stripe-signature header")
}
