use super::super::super::helpers::*;
use axum::http::StatusCode;
use uuid::Uuid;

#[tokio::test]
async fn skills_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skills_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_binary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/skills/binary?path=_smoke/binary_probe.png").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_put_unauthorized_without_bearer() {
    let (status, v) = put_json(
        "/api/v1/skills/content",
        r#"{"path":"script_execution_script.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_put_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"../Cargo.toml","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_put_rejects_missing_file_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = put_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"__no_such_skill_file__.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_post_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/skills/content", r#"{"path":"x.md","content":"y"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_post_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"../README.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_post_conflict_when_file_exists() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/skills/content",
        &token,
        r#"{"path":"script_execution_script.md","content":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(v["code"], "conflict");
}

#[tokio::test]
async fn skill_content_post_get_delete_roundtrip() {
    let token = test_jwt(Uuid::nil());
    let name = format!("__contract_post_skill_{}.md", Uuid::new_v4());
    let body = serde_json::json!({
        "path": name.clone(),
        "content": "smoke_post_body",
    })
    .to_string();
    let (status, v) = post_json_bearer("/api/v1/skills/content", &token, &body).await;
    assert_eq!(status, StatusCode::CREATED, "v={v}");
    assert_eq!(v["path"], name);
    assert_eq!(v["content"], "smoke_post_body");

    let uri = format!("/api/v1/skills/content?path={name}");
    let (gstatus, gv) = get_json_bearer(&uri, &token).await;
    assert_eq!(gstatus, StatusCode::OK, "gv={gv}");
    assert_eq!(gv["content"], "smoke_post_body");

    let (dstatus, dv): (_, serde_json::Value) = delete_json_bearer(&uri, &token).await;
    assert_eq!(dstatus, StatusCode::NO_CONTENT, "dv={dv}");
    assert!(dv.is_null());

    let (gone_status, _) = get_json_bearer(&uri, &token).await;
    assert_eq!(gone_status, StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn skill_content_delete_unauthorized_without_bearer() {
    let (status, v) =
        delete_json_no_bearer("/api/v1/skills/content?path=script_execution_script.md").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn skill_content_delete_rejects_parent_path_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_json_bearer("/api/v1/skills/content?path=../Cargo.toml", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn skill_content_delete_not_found_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_json_bearer(
        "/api/v1/skills/content?path=__no_such_skill_for_delete__.md",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(v["code"], "not_found");
}
