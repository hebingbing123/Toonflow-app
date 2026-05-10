use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn tts_generate_unauthorized_without_bearer() {
    let body = format!(
        r#"{{"project_id":"{}","shot_id":"{}","text":"hello","provider":"openai","voice_id":"alloy"}}"#,
        Uuid::nil(),
        Uuid::nil()
    );
    let (status, v) = post_json("/api/v1/tts/generate", &body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tts_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = format!(
        r#"{{"project_id":"{}","shot_id":"{}","text":"hello","provider":"openai","voice_id":"alloy"}}"#,
        Uuid::nil(),
        Uuid::nil()
    );
    let (status, v) = post_json_bearer("/api/v1/tts/generate", &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tts_batch_generate_unauthorized_without_bearer() {
    let body = format!(
        r#"{{"project_id":"{}","shots":[{{"project_id":"{}","shot_id":"{}","text":"hello","provider":"openai","voice_id":"alloy"}}]}}"#,
        Uuid::nil(),
        Uuid::nil(),
        Uuid::nil()
    );
    let (status, v) = post_json("/api/v1/tts/batch-generate", &body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tts_batch_generate_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = format!(
        r#"{{"project_id":"{}","shots":[{{"project_id":"{}","shot_id":"{}","text":"hello","provider":"openai","voice_id":"alloy"}}]}}"#,
        Uuid::nil(),
        Uuid::nil(),
        Uuid::nil()
    );
    let (status, v) = post_json_bearer("/api/v1/tts/batch-generate", &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tts_tasks_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/tts/tasks").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tts_tasks_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/tts/tasks", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tts_task_detail_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = format!("/api/v1/tts/tasks/{}", Uuid::nil());
    let (status, v) = get_json_bearer(&uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tts_cancel_unauthorized_without_bearer() {
    let body = format!(r#"{{"task_id":"{}"}}"#, Uuid::nil());
    let (status, v) = post_json("/api/v1/tts/cancel", &body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tts_cancel_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = format!(r#"{{"task_id":"{}"}}"#, Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/tts/cancel", &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn tts_retry_unauthorized_without_bearer() {
    let body = format!(r#"{{"task_id":"{}"}}"#, Uuid::nil());
    let (status, v) = post_json("/api/v1/tts/retry", &body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn tts_retry_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let body = format!(r#"{{"task_id":"{}"}}"#, Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/tts/retry", &token, &body).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}
