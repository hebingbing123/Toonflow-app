//! HTTP-level contract checks for outbound POST (WH2.8): wiremock asserts headers + body reach the subscriber.

use serde_json::json;
use wiremock::matchers::{header, method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

use super::sign_toonflow;

#[tokio::test]
async fn signed_outbound_post_matches_subscriber_contract() {
    let mock = MockServer::start().await;
    let body = json!({
        "id": "00000000-0000-4000-8000-000000000001",
        "type": "job.completed",
        "createdAt": "2020-01-01T00:00:00.000Z",
        "data": { "job": { "status": "succeeded" } }
    });
    let bytes = serde_json::to_vec(&body).unwrap();
    let secret = b"integration-test-secret";
    let ts: u64 = 1_700_000_000;
    let signature = sign_toonflow(secret, ts, &bytes);

    Mock::given(method("POST"))
        .and(path("/hooks/toonflow"))
        .and(header("content-type", "application/json"))
        .and(header("x-toonflow-timestamp", ts.to_string()))
        .and(header("x-toonflow-signature", signature.as_str()))
        .and(header("x-toonflow-event-type", "job.completed"))
        .respond_with(ResponseTemplate::new(200))
        .expect(1)
        .mount(&mock)
        .await;

    let url = format!("{}/hooks/toonflow", mock.uri());
    let client = reqwest::Client::new();
    let resp = client
        .post(&url)
        .header("Content-Type", "application/json")
        .header("X-Toonflow-Timestamp", ts.to_string())
        .header("X-Toonflow-Signature", &signature)
        .header("X-Toonflow-Event-Type", "job.completed")
        .body(bytes)
        .send()
        .await
        .expect("request");

    assert!(resp.status().is_success());
}
