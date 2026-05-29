//! Workspace-scoped idempotency key composition (rebuild plan P0-2 / stage 22).

use uuid::Uuid;

/// Prefixes a client idempotency key with workspace scope for billing dedupe.
///
/// Stored value remains unique per `(owner_user_id, idempotency_key)` while
/// encoding workspace attribution for observability.
pub fn compose_workspace_idempotency_key(workspace_id: Uuid, client_key: &str) -> String {
    let trimmed = client_key.trim();
    format!("ws:{workspace_id}:{trimmed}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn compose_workspace_key_is_stable() {
        let ws = Uuid::nil();
        assert_eq!(
            compose_workspace_idempotency_key(ws, "gen-1"),
            format!("ws:{ws}:gen-1")
        );
    }
}
