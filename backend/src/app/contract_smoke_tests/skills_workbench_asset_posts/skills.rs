use super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn skill_content_ok_with_jwt_for_known_file() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/skills/content?path=script_execution_script.md";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(v["path"], "script_execution_script.md");
    assert!(v["content"].as_str().is_some_and(|s| !s.trim().is_empty()));
}

#[tokio::test]
async fn skill_binary_ok_with_jwt_for_smoke_png() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/skills/binary?path=_smoke/binary_probe.png";
    let (status, body, ct) = get_bytes_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(ct.as_deref(), Some("image/png"));
    assert!(body.starts_with(&[0x89, b'P', b'N', b'G']));
}

#[tokio::test]
async fn skill_binary_rejects_markdown_extension_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/skills/binary?path=script_execution_script.md";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
