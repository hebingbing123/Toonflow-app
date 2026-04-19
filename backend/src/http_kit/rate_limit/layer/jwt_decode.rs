use base64::engine::{general_purpose::STANDARD, Engine};

/// Extract user_id from JWT token payload.
/// Note: This only decodes the payload without verification - safe for rate limiting
/// because the actual JWT verification happens in the auth middleware.
pub(super) fn extract_user_id_from_jwt(token: &str) -> Option<String> {
    // JWT format: header.payload.signature
    let parts: Vec<&str> = token.split('.').collect();
    if parts.len() != 3 {
        return None;
    }

    // Decode base64url payload
    let payload = parts[1];
    let decoded = base64_url_decode(payload).ok()?;
    let json: serde_json::Value = serde_json::from_slice(&decoded).ok()?;

    // Extract sub (subject) as user_id
    json.get("sub")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
}

fn base64_url_decode(input: &str) -> Result<Vec<u8>, base64::DecodeError> {
    // Replace URL-safe characters and add padding
    let normalized = input.replace('-', "+").replace('_', "/");
    let padding_needed = (4 - normalized.len() % 4) % 4;
    let padded = format!("{}{}", normalized, "=".repeat(padding_needed));
    STANDARD.decode(padded)
}
