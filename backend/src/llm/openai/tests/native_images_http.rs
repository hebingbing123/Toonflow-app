//! Protocol-aware image generation against mock Ark / Imagen / DashScope HTTP.

use serde_json::json;
use wiremock::matchers::{header, method, path, path_regex, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

use super::super::{images_generation_or_edit_url, LlmConfig};
use crate::vendor::catalog::VendorProtocol;

#[tokio::test]
async fn volcengine_ark_protocol_hits_images_generations() {
    let mock = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/api/v3/images/generations"))
        .and(header("authorization", "Bearer ark-user-key"))
        .respond_with(
            ResponseTemplate::new(200)
                .set_body_json(json!({"data":[{"url":"https://cdn.example.test/seedream.png"}]})),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let cfg = LlmConfig {
        api_key: "ark-user-key".to_string(),
        base_url: format!("{}/api/v3", mock.uri()),
        model: "doubao-seedream-3-0-t2i".to_string(),
        protocol: VendorProtocol::VolcengineArk,
    };
    let client = reqwest::Client::new();
    let (url, _) = images_generation_or_edit_url(
        &cfg,
        &client,
        "doubao-seedream-3-0-t2i",
        "studio still frame",
        "1024x1024",
        None,
    )
    .await
    .expect("ark images");
    assert_eq!(url, "https://cdn.example.test/seedream.png");
    mock.verify().await;
}

#[tokio::test]
async fn gemini_native_protocol_hits_imagen_predict() {
    let mock = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/v1beta/models/imagen-3.0-generate-002:predict"))
        .and(query_param("key", "gemini-user-key"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(json!({
                "generatedImages": [{"imageUri": "https://cdn.example.test/imagen.png"}]
            })),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let cfg = LlmConfig {
        api_key: "gemini-user-key".to_string(),
        base_url: format!("{}/v1beta", mock.uri()),
        model: "imagen-3.0-generate-002".to_string(),
        protocol: VendorProtocol::GeminiNative,
    };
    let client = reqwest::Client::new();
    let (url, _) = images_generation_or_edit_url(
        &cfg,
        &client,
        "imagen-3.0-generate-002",
        "product poster",
        "1024x1024",
        None,
    )
    .await
    .expect("imagen");
    assert_eq!(url, "https://cdn.example.test/imagen.png");
    mock.verify().await;
}

#[tokio::test]
async fn dashscope_wanx_native_text2image_and_task_poll() {
    let mock = MockServer::start().await;
    let task_id = "wan-task-mock-1";

    Mock::given(method("POST"))
        .and(path("/api/v1/services/aigc/text2image/image-synthesis"))
        .and(header("authorization", "Bearer dash-key"))
        .and(header("x-dashscope-async", "enable"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "output": {
                "task_id": task_id,
                "task_status": "PENDING",
            }
        })))
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path_regex(r"/api/v1/tasks/wan-task-mock-1$"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "output": {
                "task_id": task_id,
                "task_status": "SUCCEEDED",
                "results": [{ "url": "https://cdn.example.test/wanx.png" }],
            }
        })))
        .expect(1)
        .mount(&mock)
        .await;

    let cfg = LlmConfig {
        api_key: "dash-key".to_string(),
        base_url: format!("{}/compatible-mode/v1", mock.uri()),
        model: "wanx2.1-t2i-turbo".to_string(),
        protocol: VendorProtocol::OpenAiCompatible,
    };
    let client = reqwest::Client::new();
    let (url, _) = images_generation_or_edit_url(
        &cfg,
        &client,
        "wanx2.1-t2i-turbo",
        "watercolor landscape",
        "1024x1024",
        None,
    )
    .await
    .expect("wanx");
    assert_eq!(url, "https://cdn.example.test/wanx.png");
    mock.verify().await;
}
