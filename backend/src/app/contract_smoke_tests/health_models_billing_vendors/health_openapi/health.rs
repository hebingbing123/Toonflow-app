use super::super::super::helpers::*;
use axum::http::StatusCode;

#[tokio::test]
async fn health_routes_ok_without_database() {
    for uri in ["/health", "/api/v1/health"] {
        let (status, v) = get_json(uri).await;
        assert_eq!(status, StatusCode::OK, "uri={uri}");
        assert_eq!(v["status"], "ok");
        assert_eq!(v["service"], "openflow-server");
    }
}

#[tokio::test]
async fn ping_ok_without_database() {
    let (status, v) = get_json("/api/v1/ping").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["ok"], true);
}

#[tokio::test]
async fn version_shape_matches_contract() {
    let (status, v) = get_json("/api/v1/version").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["service"], "openflow-server");
    assert!(v["version"].as_str().is_some_and(|s| !s.is_empty()));
}

#[tokio::test]
async fn ready_without_database_reports_not_configured() {
    let (status, v) = get_json("/api/v1/ready").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["status"], "ok");
    assert_eq!(v["database"], "not_configured");
    let hi = v
        .get("harness_isolate")
        .expect("ready JSON must include harness_isolate");
    assert!(hi["max_slots"].as_u64().is_some_and(|u| u > 0));
    assert!(hi["total_child_spawns"].is_number());
    assert_eq!(hi["total_pool_evictions"], 0);
}
