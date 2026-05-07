use std::collections::HashMap;

use super::summary::{UsageSummaryResponse, UsageSummaryScope};

#[test]
fn usage_summary_response_serialize_with_quota() {
    let mut event_counts = HashMap::new();
    event_counts.insert("generation_job.succeeded".to_string(), 5i64);
    event_counts.insert("generation_job.created".to_string(), 3i64);

    let resp = UsageSummaryResponse {
        scope: UsageSummaryScope::User,
        events_last_24h: 5,
        events_last_7d: 10,
        event_counts_last_7d: event_counts,
        jobs_today: 3,
        daily_job_quota: Some(10),
        quota_remaining: Some(7),
    };

    let json = serde_json::to_string(&resp).unwrap();
    assert!(json.contains("\"scope\":\"user\""));
    assert!(json.contains("\"events_last_24h\":5"));
    assert!(json.contains("\"events_last_7d\":10"));
    assert!(json.contains("\"jobs_today\":3"));
    assert!(json.contains("\"daily_job_quota\":10"));
    assert!(json.contains("\"quota_remaining\":7"));
}

#[test]
fn usage_summary_response_serialize_without_quota() {
    let resp = UsageSummaryResponse {
        scope: UsageSummaryScope::User,
        events_last_24h: 0,
        events_last_7d: 0,
        event_counts_last_7d: HashMap::new(),
        jobs_today: 0,
        daily_job_quota: None,
        quota_remaining: None,
    };

    let json = serde_json::to_string(&resp).unwrap();
    // quota_remaining should be skipped when None
    assert!(!json.contains("quota_remaining"));
}

#[test]
fn usage_summary_response_with_zero_remaining() {
    let resp = UsageSummaryResponse {
        scope: UsageSummaryScope::User,
        events_last_24h: 10,
        events_last_7d: 50,
        event_counts_last_7d: HashMap::new(),
        jobs_today: 10,
        daily_job_quota: Some(10),
        quota_remaining: Some(0),
    };

    let json = serde_json::to_string(&resp).unwrap();
    assert!(json.contains("\"quota_remaining\":0"));
}
