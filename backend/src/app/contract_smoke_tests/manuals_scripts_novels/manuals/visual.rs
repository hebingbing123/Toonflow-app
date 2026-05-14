use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn project_add_visual_manual_unauthorized_without_bearer() {
    let body = r#"{"name":"n","images":[],"stylePath":"n","data":[]}"#;
    let (status, v) = post_json("/api/v1/project/add-visual-manual", body).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_add_visual_manual_rejects_duplicate_bundle_style() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"n","images":[],"stylePath":"2D_90s_japanese_anime","data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/add-visual-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_edit_visual_manual_not_found_for_missing_style() {
    let token = test_jwt(Uuid::nil());
    let body = r#"{"name":"t","stylePath":"__missing_visual_style_xx","images":[],"data":[]}"#;
    let (status, v) = post_json_bearer("/api/v1/project/edit-visual-manual", &token, body).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
    assert_eq!(v["message"], "Visual manual does not exist");
}

#[tokio::test]
async fn project_delete_visual_manual_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/project/delete-visual-manual",
        r#"{"name":"2D_90s_japanese_anime"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_delete_visual_manual_rejects_pure_digit_name() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-visual-manual",
        &token,
        r#"{"name":"42"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn project_delete_visual_manual_ok_for_missing_folder() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/project/delete-visual-manual",
        &token,
        r#"{"name":"__contract_smoke_missing_art_style"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["message"], "删除成功");
}
