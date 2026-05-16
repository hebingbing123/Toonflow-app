use super::assert_bad_request_query;

#[tokio::test]
async fn billing_webhook_events_rejects_bad_created_from() {
    assert_bad_request_query("created_from=not-a-time").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_bad_event_created_from() {
    assert_bad_request_query("event_created_from=not-a-time").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_event_created_from_after_to() {
    assert_bad_request_query(
        "event_created_from=2026-04-30T23:59:59Z&event_created_to=2026-04-01T00:00:00Z",
    )
    .await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_created_from_after_to() {
    assert_bad_request_query("created_from=2026-04-30T23:59:59Z&created_to=2026-04-01T00:00:00Z")
        .await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_id_min_greater_than_id_max() {
    assert_bad_request_query("id_min=10&id_max=1").await;
}
