//! Process-isolated Harness tools: spawn the same binary with a hidden subcommand so allowlisted
//! tool logic runs outside the API process (address-space boundary), as a vm2-style replacement path.

use std::time::Duration;

use serde_json::Value;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

use super::invoke::InvokeError;

/// Child entry: read JSON from stdin, write the same JSON to stdout (echo). Used by `isolated.echo`.
pub fn stdio_echo_child() -> ! {
    let mut buf = Vec::new();
    if let Err(e) = std::io::Read::read_to_end(&mut std::io::stdin(), &mut buf) {
        eprintln!("harness isolate: stdin: {e}");
        std::process::exit(1);
    }
    let v: Value = match serde_json::from_slice(&buf) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("harness isolate: json: {e}");
            std::process::exit(1);
        }
    };
    let s = match serde_json::to_string(&v) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("harness isolate: serialize: {e}");
            std::process::exit(1);
        }
    };
    println!("{s}");
    std::process::exit(0);
}

/// Run a trivial JSON echo in a child process (same semantics as `echo`, but out-of-process).
pub async fn isolated_echo(arguments: &Value) -> Result<Value, InvokeError> {
    let exe = std::env::current_exe()
        .map_err(|e| InvokeError::IsolationFailed(format!("current_exe: {e}")))?;
    let payload = serde_json::to_string(arguments)
        .map_err(|e| InvokeError::IsolationFailed(format!("serialize arguments: {e}")))?;

    let mut child = Command::new(exe)
        .arg("__harness_isolate_echo__")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| InvokeError::IsolationFailed(format!("spawn: {e}")))?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(payload.as_bytes())
            .await
            .map_err(|e| InvokeError::IsolationFailed(format!("stdin: {e}")))?;
        stdin
            .shutdown()
            .await
            .map_err(|e| InvokeError::IsolationFailed(format!("stdin shutdown: {e}")))?;
    }

    let out = tokio::time::timeout(Duration::from_secs(10), child.wait_with_output())
        .await
        .map_err(|_| InvokeError::IsolationFailed("child timed out after 10s".into()))?
        .map_err(|e| InvokeError::IsolationFailed(format!("wait: {e}")))?;

    if !out.status.success() {
        let stderr = String::from_utf8_lossy(&out.stderr);
        return Err(InvokeError::IsolationFailed(format!(
            "child exit {:?}: {}",
            out.status.code(),
            stderr.trim()
        )));
    }

    let stdout = String::from_utf8_lossy(&out.stdout).trim().to_string();
    serde_json::from_str(&stdout).map_err(|e| {
        InvokeError::IsolationFailed(format!("child stdout not json: {e}; raw={stdout:?}"))
    })
}
