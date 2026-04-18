use super::{
    assert_database_error_delete, assert_database_error_get, assert_database_error_patch,
    assert_database_error_post, PROJECTS_PATH, PROJECT_ID_PATH,
};

#[tokio::test]
async fn projects_get_by_id_requires_database_with_jwt() {
    assert_database_error_get(PROJECT_ID_PATH).await;
}

#[tokio::test]
async fn projects_patch_empty_body_requires_database_before_validation_with_jwt() {
    assert_database_error_patch(PROJECT_ID_PATH, r#"{}"#).await;
}

#[tokio::test]
async fn projects_patch_requires_database_with_jwt() {
    assert_database_error_patch(PROJECT_ID_PATH, r#"{"intro":"x"}"#).await;
}

#[tokio::test]
async fn asset_smoke_projects_list_requires_database_with_jwt() {
    assert_database_error_get(PROJECTS_PATH).await;
}

#[tokio::test]
async fn asset_smoke_projects_delete_requires_database_with_jwt() {
    assert_database_error_delete(PROJECT_ID_PATH).await;
}

#[tokio::test]
async fn asset_smoke_projects_post_create_requires_database_with_jwt() {
    assert_database_error_post(PROJECTS_PATH, "{}").await;
}

#[tokio::test]
async fn asset_smoke_projects_patch_requires_database_with_jwt() {
    assert_database_error_patch(PROJECT_ID_PATH, r#"{"name":"x"}"#).await;
}
