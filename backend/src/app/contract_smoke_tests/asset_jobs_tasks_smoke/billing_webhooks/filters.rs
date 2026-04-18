use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn billing_webhook_events_rejects_bad_created_from() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?created_from=not-a-time",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_bad_event_created_from() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_created_from=not-a-time",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_event_created_from_after_to() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_created_from=2026-04-30T23:59:59Z&event_created_to=2026-04-01T00:00:00Z",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_created_from_after_to() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?created_from=2026-04-30T23:59:59Z&created_to=2026-04-01T00:00:00Z",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_id_min_greater_than_id_max() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/webhooks/billing/events?id_min=10&id_max=1", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_event_type() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?event_type=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id_prefix() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?provider_event_id_prefix=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?provider_event_id=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?raw_event_id=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id_prefix() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?raw_event_id_prefix=%20%20%20",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_unknown_provider() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?provider=foo", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn billing_webhook_events_rejects_invalid_sort() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?sort=unknown", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
