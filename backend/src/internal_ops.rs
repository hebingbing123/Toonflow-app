use axum::http::HeaderMap;

pub const INTERNAL_OPS_TOKEN_ENV: &str = "OPENFLOW_INTERNAL_OPS_TOKEN";
pub const INTERNAL_OPS_HEADER: &str = "x-openflow-internal-token";

pub fn expected_internal_ops_token() -> Option<String> {
    std::env::var(INTERNAL_OPS_TOKEN_ENV)
        .ok()
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
}

pub fn request_internal_ops_token(headers: &HeaderMap) -> Option<String> {
    headers
        .get(INTERNAL_OPS_HEADER)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.trim().to_owned())
        .filter(|s| !s.is_empty())
}

pub const INTERNAL_OPS_HEADER_NAMES: [&str; 1] = [INTERNAL_OPS_HEADER];
