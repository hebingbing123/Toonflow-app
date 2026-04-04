//! Smoke test: child entry `__harness_isolate_echo__` round-trips JSON (integration; uses `CARGO_BIN_EXE_toonflow-server`).

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::process::Command;

#[tokio::test]
async fn harness_isolate_echo_roundtrip() {
    let exe =
        std::env::var("CARGO_BIN_EXE_toonflow-server").expect("cargo test sets CARGO_BIN_EXE_*");
    let mut child = Command::new(exe)
        .arg("__harness_isolate_echo__")
        .stdin(std::process::Stdio::piped())
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
        .expect("spawn isolate child");

    let mut stdin = child.stdin.take().expect("stdin");
    let payload = br#"{"hello":42,"x":"y"}"#;
    stdin.write_all(payload).await.expect("write stdin");
    drop(stdin);

    let mut stdout = child.stdout.take().expect("stdout");
    let mut buf = Vec::new();
    stdout.read_to_end(&mut buf).await.expect("read stdout");

    let status = child.wait().await.expect("wait");
    assert!(status.success());

    let out: serde_json::Value = serde_json::from_slice(&buf).expect("stdout json");
    assert_eq!(out["hello"], 42);
    assert_eq!(out["x"], "y");
}
