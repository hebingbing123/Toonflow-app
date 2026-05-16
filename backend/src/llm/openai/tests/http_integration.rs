use std::sync::{Arc, Mutex};

use axum::{body::Bytes, extract::State, http::HeaderMap, routing::post, Json, Router};
use serde_json::{json, Value};

use super::super::*;

#[derive(Clone, Default)]
struct TestImagesApiState {
    generation_hits: usize,
    edits_hits: usize,
    last_edit_content_type: Option<String>,
}

async fn test_images_generation(
    State(state): State<Arc<Mutex<TestImagesApiState>>>,
) -> Json<Value> {
    state.lock().expect("lock").generation_hits += 1;
    Json(json!({"data":[{"url":"https://example.test/generation.png"}]}))
}

async fn test_images_edits(
    State(state): State<Arc<Mutex<TestImagesApiState>>>,
    headers: HeaderMap,
    _body: Bytes,
) -> Json<Value> {
    let mut guard = state.lock().expect("lock");
    guard.edits_hits += 1;
    guard.last_edit_content_type = headers
        .get("content-type")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    Json(json!({"data":[{"url":"https://example.test/edit.png"}]}))
}

async fn spawn_test_images_api() -> (
    String,
    Arc<Mutex<TestImagesApiState>>,
    tokio::sync::oneshot::Sender<()>,
) {
    let state = Arc::new(Mutex::new(TestImagesApiState::default()));
    let app = Router::new()
        .route("/v1/images/generations", post(test_images_generation))
        .route("/v1/images/edits", post(test_images_edits))
        .with_state(state.clone());
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0")
        .await
        .expect("bind");
    let addr = listener.local_addr().expect("local addr");
    let (tx, rx) = tokio::sync::oneshot::channel::<()>();
    tokio::spawn(async move {
        let server = axum::serve(listener, app).with_graceful_shutdown(async {
            let _ = rx.await;
        });
        server.await.expect("serve");
    });
    (format!("http://{addr}/v1"), state, tx)
}

#[tokio::test]
async fn images_generation_or_edit_uses_generation_without_reference_image() {
    let (base_url, state, shutdown_tx) = spawn_test_images_api().await;
    let cfg = LlmConfig {
        api_key: "test-key".to_string(),
        base_url,
        model: "gpt-4o-mini".to_string(),
    };
    let client = reqwest::Client::new();
    let (url, revised) = images_generation_or_edit_url(
        &cfg,
        &client,
        "dall-e-3",
        "a test prompt",
        "1024x1024",
        None,
    )
    .await
    .expect("request ok");
    assert_eq!(url, "https://example.test/generation.png");
    assert_eq!(revised, None);

    let snapshot = state.lock().expect("lock").clone();
    assert_eq!(snapshot.generation_hits, 1);
    assert_eq!(snapshot.edits_hits, 0);
    let _ = shutdown_tx.send(());
}

#[tokio::test]
async fn images_generation_or_edit_uses_edits_with_reference_image() {
    let (base_url, state, shutdown_tx) = spawn_test_images_api().await;
    let cfg = LlmConfig {
        api_key: "test-key".to_string(),
        base_url,
        model: "gpt-4o-mini".to_string(),
    };
    let client = reqwest::Client::new();
    let (url, revised) = images_generation_or_edit_url(
        &cfg,
        &client,
        "dall-e-3",
        "a test prompt",
        "1024x1024",
        Some("data:image/png;base64,AA=="),
    )
    .await
    .expect("request ok");
    assert_eq!(url, "https://example.test/edit.png");
    assert_eq!(revised, None);

    let snapshot = state.lock().expect("lock").clone();
    assert_eq!(snapshot.generation_hits, 0);
    assert_eq!(snapshot.edits_hits, 1);
    assert!(
        snapshot
            .last_edit_content_type
            .as_deref()
            .unwrap_or_default()
            .starts_with("multipart/form-data;"),
        "content-type should be multipart/form-data"
    );
    let _ = shutdown_tx.send(());
}
