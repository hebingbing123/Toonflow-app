//! Kling official API JWT (Access Key + Secret Key).
//!
//! Docs: https://app.klingai.com/cn/dev/document-api/apiReference/commonInfo

use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use serde::Serialize;

#[derive(Serialize)]
struct KlingJwtClaims<'a> {
    iss: &'a str,
    exp: i64,
    nbf: i64,
}

/// Bearer token valid ~30 minutes per Kling docs.
pub fn kling_bearer_token(access_key: &str, secret_key: &str) -> Result<String, String> {
    let access_key = access_key.trim();
    let secret_key = secret_key.trim();
    if access_key.is_empty() || secret_key.is_empty() {
        return Err("Kling requires Access Key (API Key) and Secret Key (API Secret)".into());
    }
    let now = chrono::Utc::now().timestamp();
    let claims = KlingJwtClaims {
        iss: access_key,
        exp: now + 1800,
        nbf: now - 5,
    };
    let mut header = Header::new(Algorithm::HS256);
    header.typ = Some("JWT".into());
    encode(
        &header,
        &claims,
        &EncodingKey::from_secret(secret_key.as_bytes()),
    )
    .map_err(|e| format!("Kling JWT encode failed: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kling_jwt_has_three_segments() {
        let token = kling_bearer_token("ak_test", "sk_test").expect("jwt");
        assert_eq!(token.matches('.').count(), 2);
    }
}
