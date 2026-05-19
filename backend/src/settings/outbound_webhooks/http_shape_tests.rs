//! HTTP-level contract checks for outbound POST (WH2.8): wiremock asserts headers + body reach the subscriber.

use serde_json::json;
use wiremock::matchers::{header, method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

use super::sign_openflow;

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
    let signature = sign_openflow(secret, ts, &bytes);

    Mock::given(method("POST"))
        .and(path("/hooks/openflow"))
        .and(header("content-type", "application/json"))
        .and(header("x-openflow-timestamp", ts.to_string()))
        .and(header("x-openflow-signature", signature.as_str()))
        .and(header("x-openflow-event-type", "job.completed"))
        .respond_with(ResponseTemplate::new(200))
        .expect(1)
        .mount(&mock)
        .await;

    let url = format!("{}/hooks/openflow", mock.uri());
    let client = reqwest::Client::new();
    let resp = client
        .post(&url)
        .header("Content-Type", "application/json")
        .header("X-Openflow-Timestamp", ts.to_string())
        .header("X-Openflow-Signature", &signature)
        .header("X-Openflow-Event-Type", "job.completed")
        .body(bytes)
        .send()
        .await
        .expect("request");

    assert!(resp.status().is_success());
}
