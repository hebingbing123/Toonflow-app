use std::collections::HashSet;

use uuid::Uuid;

use super::tools::ToolRegistry;

/// Optional comma-separated allowlist from **`HARNESS_WS_CHANNELS`** (e.g. `script` or `script,production`).
/// When unset or empty after parsing, both **`script`** and **`production`** attach are allowed (legacy default).
fn ws_channel_allowlist_from_env() -> Option<HashSet<String>> {
    let raw = std::env::var("HARNESS_WS_CHANNELS").ok()?;
    let set: HashSet<String> = raw
        .split(',')
        .map(|s| s.trim().to_ascii_lowercase())
        .filter(|s| !s.is_empty())
        .collect();
    if set.is_empty() {
        None
    } else {
        Some(set)
    }
}

fn ws_channel_allowed_inner(allowlist: &Option<HashSet<String>>, channel: &str) -> bool {
    let key = channel.trim().to_ascii_lowercase();
    match allowlist {
        None => true,
        Some(set) => set.contains(&key),
    }
}

/// Whether the user may attach the given WebSocket agent channel (`script` / `production`).
pub fn ws_channel_allowed(user: Uuid, channel: &str) -> bool {
    let _ = user;
    ws_channel_allowed_inner(&ws_channel_allowlist_from_env(), channel)
}

/// True when `tool_name` is listed in the static Harness tool catalog.
pub fn tool_invocation_allowed(_user: Uuid, tool_name: &str) -> bool {
    ToolRegistry::catalog().iter().any(|t| t.name == tool_name)
}

#[cfg(test)]
mod tests {
    use std::collections::HashSet;

    use super::ws_channel_allowed_inner;

    #[test]
    fn ws_channel_unrestricted_when_allowlist_none() {
        assert!(ws_channel_allowed_inner(&None, "script"));
        assert!(ws_channel_allowed_inner(&None, "production"));
    }

    #[test]
    fn ws_channel_restricted_by_allowlist() {
        let mut s = HashSet::new();
        s.insert("script".to_string());
        let allow = Some(s);
        assert!(ws_channel_allowed_inner(&allow, "script"));
        assert!(!ws_channel_allowed_inner(&allow, "production"));
    }
}
