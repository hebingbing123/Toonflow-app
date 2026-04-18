use super::assert_bad_request_query;

#[tokio::test]
async fn billing_webhook_events_rejects_blank_event_type() {
    assert_bad_request_query("event_type=%20%20%20").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id_prefix() {
    assert_bad_request_query("provider_event_id_prefix=%20%20%20").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_provider_event_id() {
    assert_bad_request_query("provider_event_id=%20%20%20").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id() {
    assert_bad_request_query("raw_event_id=%20%20%20").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_blank_raw_event_id_prefix() {
    assert_bad_request_query("raw_event_id_prefix=%20%20%20").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_unknown_provider() {
    assert_bad_request_query("provider=foo").await;
}

#[tokio::test]
async fn billing_webhook_events_rejects_invalid_sort() {
    assert_bad_request_query("sort=unknown").await;
}
