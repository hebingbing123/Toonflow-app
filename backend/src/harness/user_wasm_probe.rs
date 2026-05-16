//! WebSocket / async tool path for **`wasm.user.probe`**.

use serde_json::Value;
use uuid::Uuid;

use crate::error::ApiError;
use crate::harness::invoke::InvokeError;
use crate::harness::observe;
use crate::harness::user_wasm_audit;
use crate::harness::user_wasm_db;
use crate::harness::wasm_runtime;
use crate::harness::HarnessContext;

fn parse_wasm_id(arguments: &Value) -> Result<Uuid, InvokeError> {
    arguments
        .get("wasmId")
        .or_else(|| arguments.get("wasm_id"))
        .and_then(|v| v.as_str())
        .and_then(|s| Uuid::parse_str(s.trim()).ok())
        .ok_or_else(|| {
            InvokeError::InvalidArgs(
                "wasm.user.probe requires arguments.wasmId (UUID string)".into(),
            )
        })
}

fn optional_request_id(arguments: &Value) -> Option<&str> {
    arguments
        .get("requestId")
        .or_else(|| arguments.get("request_id"))
        .and_then(|v| v.as_str())
        .map(str::trim)
        .filter(|s| !s.is_empty())
}

/// Execute owner-scoped user WASM with fuel + wall-clock timeout; audit + signal on failures.
pub async fn invoke_wasm_user_probe_tool(
    ctx: &HarnessContext,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let wasm_id = parse_wasm_id(arguments)?;
    let request_id = optional_request_id(arguments);
    let pool = ctx.pool.as_ref().ok_or(InvokeError::DatabaseUnavailable)?;

    let row = user_wasm_db::get_active_user_wasm_for_owner(pool, ctx.user_id, wasm_id)
        .await
        .map_err(|e| match e {
            ApiError::NotFound => InvokeError::NotFound("user wasm not found or revoked".into()),
            ApiError::DatabaseError(m) => InvokeError::DatabaseError(m),
            other => InvokeError::DatabaseError(format!("{other:?}")),
        })?;

    let timeout_ms = wasm_runtime::user_wasm_invoke_timeout_ms_from_env();
    let sha_hex = row.wasm_sha256_hex.clone();
    let bytes = row.wasm_bytes;
    let uid = ctx.user_id;
    let ws = ctx.workspace_id;

    let join = tokio::task::spawn_blocking(move || wasm_runtime::invoke_user_probe(&bytes));

    let outcome = tokio::time::timeout(std::time::Duration::from_millis(timeout_ms), join).await;

    match outcome {
        Err(_) => {
            user_wasm_audit::insert_user_wasm_audit_best_effort(
                ctx.pool.as_ref(),
                "invoke",
                uid,
                ws,
                Some(wasm_id),
                Some(sha_hex.as_str()),
                request_id,
                "fail",
                Some("wasm_timeout"),
                Some("invoke_wasm_timeout"),
            )
            .await;
            observe::harness_user_wasm_signal(
                "invoke_wasm_timeout",
                uid,
                ws,
                request_id,
                Some(wasm_id),
                "fail",
                Some("wasm_timeout"),
            );
            Err(InvokeError::WasmTimeout)
        }
        Ok(Err(e)) => {
            tracing::warn!(error = %e, "wasm.user.probe join failed");
            user_wasm_audit::insert_user_wasm_audit_best_effort(
                ctx.pool.as_ref(),
                "invoke",
                uid,
                ws,
                Some(wasm_id),
                Some(sha_hex.as_str()),
                request_id,
                "fail",
                Some("wasm_failed"),
                Some("invoke_wasm_failed"),
            )
            .await;
            observe::harness_user_wasm_signal(
                "invoke_wasm_failed",
                uid,
                ws,
                request_id,
                Some(wasm_id),
                "fail",
                Some("wasm_failed"),
            );
            Err(InvokeError::WasmFailed(format!("join: {e}")))
        }
        Ok(Ok(Err(msg))) => {
            let code = "wasm_failed";
            user_wasm_audit::insert_user_wasm_audit_best_effort(
                ctx.pool.as_ref(),
                "invoke",
                uid,
                ws,
                Some(wasm_id),
                Some(sha_hex.as_str()),
                request_id,
                "fail",
                Some(code),
                Some("invoke_wasm_failed"),
            )
            .await;
            observe::harness_user_wasm_signal(
                "invoke_wasm_failed",
                uid,
                ws,
                request_id,
                Some(wasm_id),
                "fail",
                Some(code),
            );
            Err(InvokeError::WasmFailed(msg))
        }
        Ok(Ok(Ok(value))) => {
            user_wasm_audit::insert_user_wasm_audit_best_effort(
                ctx.pool.as_ref(),
                "invoke",
                uid,
                ws,
                Some(wasm_id),
                Some(sha_hex.as_str()),
                request_id,
                "success",
                None,
                None,
            )
            .await;
            Ok(value)
        }
    }
}
