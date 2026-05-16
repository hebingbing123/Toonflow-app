use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn export_start_unauthorized_without_bearer() {
    let body = format!(
        r#"{{"project_id":"{}","format":"mp4","quality":{{"resolution":"1080p","bitrate":4000,"framerate":30}}}}"#,
        Uuid::nil()
    );
    let (status, v) = post_json("/api/v1/export/start", &body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn export_start_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = format!(
        r#"{{"project_id":"{}","format":"mp4","quality":{{"resolution":"1080p","bitrate":4000,"framerate":30}}}}"#,
        Uuid::nil()
    );
    let (status, v) = post_json_bearer("/api/v1/export/start", &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn export_tasks_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/export/tasks").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn export_tasks_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/export/tasks", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn export_task_detail_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/export/tasks/{}", Uuid::nil());
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn export_cancel_unauthorized_without_bearer() {
    let body = format!(r#"{{"task_id":"{}"}}"#, Uuid::nil());
    let (status, v) = post_json("/api/v1/export/cancel", &body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn export_cancel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = format!(r#"{{"task_id":"{}"}}"#, Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/export/cancel", &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
