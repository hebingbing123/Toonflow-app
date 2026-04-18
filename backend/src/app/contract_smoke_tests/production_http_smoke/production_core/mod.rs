mod assets;
mod flow;
mod storyboard;

use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

async fn assert_database_error(path: &str, body: &str) {
    let token = test_jwt(Uuid::nil());
    let (status, value) = post_json_bearer(path, &token, body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(value["code"], "database_error");
}
