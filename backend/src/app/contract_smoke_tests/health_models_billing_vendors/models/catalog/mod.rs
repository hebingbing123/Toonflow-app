mod model_catalog;
mod support_endpoints;

use super::super::super::helpers::*;
use axum::body::Body;
use axum::http::header;
use axum::http::Request;
use axum::http::StatusCode;
use uuid::Uuid;

async fn assert_auth_not_configured_with_bearer(uri: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = oneshot_json_state(
        smoke_state_without_jwt_secret(),
        Request::builder()
            .uri(uri)
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .extension(axum::extract::ConnectInfo(test_addr()))
            .body(Body::empty())
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "auth_not_configured");
}

async fn assert_unauthorized(uri: &str) {
    let (status, value) = get_json(uri).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(value["code"], "unauthorized");
}
