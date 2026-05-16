mod access;
mod filter_ranges;
mod filter_strings;

use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

async fn assert_bad_request_query(query: &str) {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let path = format!("/api/v1/webhooks/billing/events?{query}");
    let (status, value) = get_json_bearer(&path, &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(value["code"], "bad_request");
}
