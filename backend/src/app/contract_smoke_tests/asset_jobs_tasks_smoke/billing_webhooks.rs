use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn billing_webhook_events_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/webhooks/billing/events").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn billing_webhook_events_forbidden_when_list_disabled_with_jwt() {
    let _gate = BillingWebhookEventsListEnvGuard::disabled();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/webhooks/billing/events?limit=1", &token).await;
    assert_eq!(status, StatusCode::FORBIDDEN);
    assert_eq!(v["code"], "forbidden");
}

#[tokio::test]
async fn billing_webhook_events_requires_database_with_jwt() {
    let _gate = BillingWebhookEventsListEnvGuard::enable();
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/webhooks/billing/events?informational_event=true&provider=stripe&raw_event_id=evt_123&raw_event_id_prefix=evt_&event_type=invoice.payment_failed&provider_event_id=stripe:evt_123&provider_event_id_prefix=stripe:evt_&event_created_from=2026-04-01T00:00:00Z&event_created_to=2026-04-30T23:59:59Z&created_from=2026-04-01T00:00:00Z&created_to=2026-04-30T23:59:59Z&id_min=1&id_max=999999&sort=id_desc&limit=10&offset=0",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

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
