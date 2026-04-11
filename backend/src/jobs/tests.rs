use axum::http::{HeaderMap, HeaderName, HeaderValue};
use chrono::Utc;
use serde_json::json;
use uuid::Uuid;

use super::dto::JobRow;
use super::enqueue::envelope_generation_job_updated;
use super::handlers::{
    idempotency_key_header, list_jobs_limit_offset, normalize_job_list_status_filter,
    trim_query_opt,
};
use super::kinds::JOB_KIND_FLUTTER_PROBE;

fn sample_job_row() -> JobRow {
    JobRow {
        legacy_task_id: 1,
        id: Uuid::nil(),
        owner_user_id: Uuid::nil(),
        kind: JOB_KIND_FLUTTER_PROBE.into(),
        status: "queued".into(),
        payload: json!({ "n": 1 }),
        result: None,
        error_message: None,
        idempotency_key: Some("idem-1".into()),
        claimed_by: None,
        created_at: Utc::now(),
        updated_at: Utc::now(),
    }
}

#[test]
fn idempotency_key_header_trims_and_caps_length() {
    let mut h = HeaderMap::new();
    assert!(idempotency_key_header(&h).is_none());

    h.insert(
        HeaderName::from_static("idempotency-key"),
        HeaderValue::from_static("  abc  "),
    );
    assert_eq!(idempotency_key_header(&h).as_deref(), Some("abc"));

    h.insert(
        HeaderName::from_static("idempotency-key"),
        HeaderValue::from_static(""),
    );
    assert!(idempotency_key_header(&h).is_none());

    let long = "x".repeat(250);
    let mut h2 = HeaderMap::new();
    h2.insert(
        HeaderName::from_static("idempotency-key"),
        HeaderValue::from_str(&long).unwrap(),
    );
    let got = idempotency_key_header(&h2).unwrap();
    assert_eq!(got.len(), 200);
    assert!(got.chars().all(|c| c == 'x'));
}

#[test]
fn envelope_generation_job_updated_shape() {
    let text = envelope_generation_job_updated(&sample_job_row());
    let v: serde_json::Value = serde_json::from_str(&text).unwrap();
    assert_eq!(
        v.get("type").and_then(|x| x.as_str()),
        Some("generation.job.updated")
    );
    assert_eq!(v.get("schema_version").and_then(|x| x.as_i64()), Some(1));
    let payload = v.get("payload").unwrap();
    assert_eq!(
        payload.get("kind").and_then(|x| x.as_str()),
        Some(JOB_KIND_FLUTTER_PROBE)
    );
    assert_eq!(
        payload.get("idempotency_key").and_then(|x| x.as_str()),
        Some("idem-1")
    );
}

#[test]
fn create_job_body_rejects_unknown_fields() {
    let err = serde_json::from_str::<super::CreateJobBody>(
        r#"{"kind":"k","payload":{},"not_a_field":true}"#,
    )
    .unwrap_err();
    assert!(
        err.to_string().contains("unknown field") || err.to_string().contains("unknown variant"),
        "{err}"
    );
}

#[test]
fn trim_query_opt_trims_and_drops_empty() {
    assert_eq!(trim_query_opt(None), None);
    assert_eq!(trim_query_opt(Some(String::new())), None);
    assert_eq!(trim_query_opt(Some("   \t  ".into())), None);
    assert_eq!(
        trim_query_opt(Some(format!("  {}  ", JOB_KIND_FLUTTER_PROBE))),
        Some(JOB_KIND_FLUTTER_PROBE.into())
    );
}

#[test]
fn normalize_job_list_status_filter_accepts_known_statuses_case_insensitive() {
    assert_eq!(normalize_job_list_status_filter(None).unwrap(), None);
    assert_eq!(
        normalize_job_list_status_filter(Some(String::new())).unwrap(),
        None
    );
    assert_eq!(
        normalize_job_list_status_filter(Some("  RUNNING  ".into()))
            .unwrap()
            .as_deref(),
        Some("running")
    );
    assert!(normalize_job_list_status_filter(Some("nope".into())).is_err());
}

#[test]
fn list_jobs_limit_offset_defaults_and_validates() {
    assert_eq!(list_jobs_limit_offset(None, None).unwrap(), (100, 0));
    assert_eq!(list_jobs_limit_offset(Some(1), Some(0)).unwrap(), (1, 0));
    assert_eq!(list_jobs_limit_offset(Some(100), None).unwrap(), (100, 0));
    assert!(list_jobs_limit_offset(Some(0), None).is_err());
    assert!(list_jobs_limit_offset(Some(101), None).is_err());
    assert!(list_jobs_limit_offset(None, Some(-1)).is_err());
}
