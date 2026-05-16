//! Best-effort inserts into **`app_harness_user_wasm_audit`** (WP‑C observability).

use sqlx::PgPool;
use uuid::Uuid;

/// Insert one audit row; failures are logged and ignored (never block HTTP / WS).
#[allow(clippy::too_many_arguments)]
pub async fn insert_user_wasm_audit_best_effort(
    pool: Option<&PgPool>,
    event: &str,
    user_id: Uuid,
    workspace_id: Option<Uuid>,
    wasm_id: Option<Uuid>,
    wasm_sha256: Option<&str>,
    request_id: Option<&str>,
    outcome: &str,
    error_code: Option<&str>,
    signal_name: Option<&str>,
) {
    let Some(pool) = pool else {
        return;
    };
    let rid = request_id.map(str::trim).filter(|s| !s.is_empty());
    let ec = error_code.map(str::trim).filter(|s| !s.is_empty());
    let sha = wasm_sha256.map(str::trim).filter(|s| !s.is_empty());
    let sig = signal_name.map(str::trim).filter(|s| !s.is_empty());
    if let Err(e) = sqlx::query(
        r#"
        INSERT INTO public.app_harness_user_wasm_audit (
          event,
          user_id,
          workspace_id,
          wasm_id,
          wasm_sha256,
          request_id,
          outcome,
          error_code,
          signal_name
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        "#,
    )
    .bind(event)
    .bind(user_id)
    .bind(workspace_id)
    .bind(wasm_id)
    .bind(sha)
    .bind(rid)
    .bind(outcome)
    .bind(ec)
    .bind(sig)
    .execute(pool)
    .await
    {
        tracing::debug!(
            target: "harness.user_wasm.audit",
            error = %e,
            event,
            "app_harness_user_wasm_audit insert failed"
        );
    }
}
