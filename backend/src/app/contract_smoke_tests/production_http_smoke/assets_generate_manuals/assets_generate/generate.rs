use super::{assert_bad_request, assert_database_error, assert_unauthorized};

#[tokio::test]
async fn assets_generate_generate_unauthorized_without_bearer() {
    assert_unauthorized(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_generate_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_generate_bad_request_empty_prompt_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"  "}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_generate_bad_request_non_positive_project_id_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":0,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p"}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_generate_accepts_raw_base64_before_database_with_jwt() {
    assert_database_error(
        "/api/v1/assets-generate/generate",
        r#"{"projectId":1,"model":"1:x","resolution":"1024x1024","id":1,"type":"role","name":"n","prompt":"p","base64":"QUJDRA=="}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_polish_prompt_requires_database_with_jwt() {
    assert_database_error(
        "/api/v1/assets-generate/polish-prompt",
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"d"}"#,
    )
    .await;
}

#[tokio::test]
async fn assets_generate_polish_prompt_bad_request_empty_describe_with_jwt() {
    assert_bad_request(
        "/api/v1/assets-generate/polish-prompt",
        r#"{"assetsId":1,"projectId":1,"type":"role","name":"n","describe":"  "}"#,
    )
    .await;
}
