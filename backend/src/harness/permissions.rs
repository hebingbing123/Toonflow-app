use uuid::Uuid;

/// Future: tool allowlists, quotas, tenant isolation. MVP: authenticated users only.
pub fn ws_channel_allowed(_user: Uuid, _channel: &str) -> bool {
    true
}
