use super::super::helpers::*;
use axum::body::Body;
use axum::extract::ConnectInfo;
use axum::http::Request;
use axum::http::StatusCode;
use tower::ServiceExt;

#[tokio::test]
async fn health_routes_ok_without_database() {
    for uri in ["/health", "/api/v1/health"] {
        let (status, v) = get_json(uri).await;
        assert_eq!(status, StatusCode::OK, "uri={uri}");
        assert_eq!(v["status"], "ok");
        assert_eq!(v["service"], "toonflow-server");
    }
}

#[tokio::test]
async fn openapi_yaml_and_swagger_ui_served_without_database() {
    let app = crate::app::build_router(smoke_state());
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/openapi.yaml")
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::OK);
    let body = axum::body::to_bytes(res.into_body(), 6 * 1024 * 1024)
        .await
        .unwrap();
    let s = std::str::from_utf8(&body).expect("utf8");
    assert!(
        s.lines().any(|line| line.starts_with("openapi:")),
        "merged YAML should include an openapi version line (key order may differ after merge)"
    );
    assert!(s.contains("Toonflow API"));
    assert!(
        s.contains("  /api/v1/ws:") && s.contains("websocketUpgrade"),
        "openapi spec should document GET /api/v1/ws"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/docs")
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::OK);
    let body = axum::body::to_bytes(res.into_body(), 64 * 1024)
        .await
        .unwrap();
    let html = String::from_utf8(body.to_vec()).unwrap();
    assert!(html.contains("swagger-ui"));
    assert!(html.contains("swagger-ui-standalone-preset"));
    assert!(html.contains("StandaloneLayout"));
    assert!(html.contains("/api/v1/openapi.yaml"));
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
    assert_eq!(v["service"], "toonflow-server");
    assert!(v["version"].as_str().is_some_and(|s| !s.is_empty()));
}

#[tokio::test]
async fn ready_without_database_reports_not_configured() {
    let (status, v) = get_json("/api/v1/ready").await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["status"], "ok");
    assert_eq!(v["database"], "not_configured");
}
