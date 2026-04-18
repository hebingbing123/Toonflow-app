use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_query_director_manual_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/project/query-director-manual", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_query_director_manual_ok_with_jwt_when_story_skills_present() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/project/query-director-manual", &token, "{}").await;
    assert_eq!(status, StatusCode::OK, "query_director_manual={v}");
    let data = v["data"].as_array().expect("data array");
    assert!(data.len() >= 2, "expected story_skills rows");
    assert!(data
        .iter()
        .any(|row| row["directorManual"].as_str() == Some("Family_warmth")));
}

#[tokio::test]
async fn project_add_director_manual_unauthorized_without_bearer() {
    let body = r#"{"name":"n","images":[],"directorManual":"n","data":[]}"#;
    let (status, v) = post_json("/api/v1/project/add-director-manual", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_director_manual_rejects_duplicate_bundle_folder() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"n","images":[],"directorManual":"Family_warmth","data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-director-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_edit_director_manual_not_found_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let body =
        r#"{"name":"t","directorManual":"__missing_director_manual_zz","images":[],"data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-director-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "导演手册不存在");
}

#[tokio::test]
async fn project_delete_director_manual_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/project/delete-director-manual",
        r#"{"name":"Family_warmth"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_director_manual_rejects_pure_digit_name() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-director-manual",
        &token,
        r#"{"name":"123"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_delete_director_manual_ok_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-director-manual",
        &token,
        r#"{"name":"__contract_smoke_missing_story_skill"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "删除成功");
}
