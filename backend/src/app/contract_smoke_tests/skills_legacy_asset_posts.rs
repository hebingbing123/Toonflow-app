use super::helpers::*;
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

#[tokio::test]
async fn project_assets_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_assets_api_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/get-assets-api",
        r#"{"projectId":1,"type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_assets_api_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-assets-api",
        &token,
        r#"{"projectId":0,"type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_assets_api_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-assets-api",
        &token,
        r#"{"projectId":1,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_add_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/add-assets",
        r#"{"name":"hero","describe":"d","type":"role","projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_add_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/add-assets",
        &token,
        r#"{"name":"hero","describe":"d","type":"role","projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_add_assets_rejects_invalid_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/add-assets",
        &token,
        r#"{"name":"hero","describe":"d","type":"clip","projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_save_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/save-assets",
        r#"{"id":1,"projectId":1,"type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_save_assets_rejects_invalid_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/save-assets",
        &token,
        r#"{"id":1,"projectId":1,"type":"clip"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_save_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/save-assets",
        &token,
        r#"{"id":1,"projectId":1,"type":"role","imageId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_update_assets_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/update-assets",
        r#"{"id":1,"name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_update_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/update-assets",
        &token,
        r#"{"id":1,"name":"n","describe":"d"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_del_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/del-assets", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_del_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/assets/del-assets", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_batch_delete_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/batch-delete", r#"{"id":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_batch_delete_rejects_empty_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/assets/batch-delete", &token, r#"{"id":[]}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_del_image_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/del-image", r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_del_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer("/api/v1/assets/del-image", &token, r#"{"id":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_image_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/get-image", r#"{"assetsId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_image_rejects_non_positive_assets_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/assets/get-image", &token, r#"{"assetsId":0}"#).await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_image_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        post_json_bearer("/api/v1/assets/get-image", &token, r#"{"assetsId":1}"#).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_upload_clip_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/upload-clip",
        r#"{"projectId":1,"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_upload_clip_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":0,"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_invalid_base64_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","base64Data":"data:image/png;base64,not-base64"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_empty_name_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":" ","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_rejects_non_clip_type_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","type":"role","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_upload_clip_accepts_raw_base64_before_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","base64Data":"AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_upload_clip_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/upload-clip",
        &token,
        r#"{"projectId":1,"name":"smoke clip","base64Data":"data:image/png;base64,AA=="}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_get_material_data_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/get-material-data", r#"{"projectId":1}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_get_material_data_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-material-data",
        &token,
        r#"{"projectId":0}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_get_material_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/get-material-data",
        &token,
        r#"{"projectId":1}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_batch_generation_data_unauthorized_without_bearer() {
    let (status, v) = post_json(
        "/api/v1/assets/batch-generation-data",
        r#"{"projectId":1,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_batch_generation_data_rejects_non_positive_project_id_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/batch-generation-data",
        &token,
        r#"{"projectId":0,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_batch_generation_data_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/batch-generation-data",
        &token,
        r#"{"projectId":1,"type":"role","page":1,"limit":10}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_polling_image_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/polling-image-assets", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_polling_image_assets_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-image-assets",
        &token,
        r#"{"ids":[0]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_polling_image_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-image-assets",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn assets_polling_prompt_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/assets/polling-prompt-assets", r#"{"ids":[1]}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn assets_polling_prompt_assets_rejects_non_positive_ids_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-prompt-assets",
        &token,
        r#"{"ids":[0]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}

#[tokio::test]
async fn assets_polling_prompt_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/assets/polling-prompt-assets",
        &token,
        r#"{"ids":[1]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_assets_list_pagination_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        get_json_bearer("/api/v1/projects/legacy/1/assets?page=1&limit=2", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

/// Combined list filters (parity with legacy **`getAssetsApi`** query surface).
#[tokio::test]
async fn project_assets_list_combined_filters_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let uri = "/api/v1/projects/legacy/1/assets?script_legacy_id=1&asset_type=role&name=probe&page=1&limit=2";
    let (status, v) = get_json_bearer(uri, &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_assets_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets",
        &token,
        r#"{"name":"contract_smoke_role","type":"role"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_asset_link_put_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        put_empty_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn script_asset_unlink_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) =
        delete_empty_bearer("/api/v1/projects/legacy/1/scripts/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_get_by_legacy_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/legacy/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/legacy/1/assets/1",
        &token,
        r#"{"name":"patched"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_asset_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer("/api/v1/projects/legacy/1/assets/1", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_list_pagination_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels?page=1&limit=5",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novels_create_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels",
        &token,
        r#"{"chapter":"smoke"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_get_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels/1",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_patch_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = patch_json_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels/1",
        &token,
        r#"{"chapter":"x"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_novel_delete_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = delete_empty_bearer(
        "/api/v1/projects/00000000-0000-0000-0000-000000000001/novels/1",
        &token,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_summary_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects/summary", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn projects_summary_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/summary").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn projects_list_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = get_json_bearer("/api/v1/projects", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn project_stats_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/00000000-0000-0000-0000-000000000001/stats").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

/// Missing **`Authorization`** must yield **401** before any Postgres pool access (no **503** `database_error` when `DATABASE_URL` is unset).
#[tokio::test]
async fn art_styles_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_by_legacy_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles/legacy/1").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn art_style_cover_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/art-styles/legacy/1/cover").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn project_assets_list_unauthorized_without_bearer() {
    let (status, v) = get_json("/api/v1/projects/legacy/1/assets").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn corner_scape_assets_unauthorized_without_bearer() {
    let (status, v) = post_json("/api/v1/projects/legacy/1/assets/corner-scape", "{}").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED);
    assert_eq!(v["code"], "unauthorized");
}

#[tokio::test]
async fn corner_scape_assets_requires_database_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets/corner-scape",
        &token,
        "{}",
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE);
    assert_eq!(v["code"], "database_error");
}

#[tokio::test]
async fn corner_scape_assets_rejects_bad_types_with_jwt() {
    let token = test_jwt(Uuid::nil());
    let (status, v) = post_json_bearer(
        "/api/v1/projects/legacy/1/assets/corner-scape",
        &token,
        r#"{"types":["clip"]}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST);
    assert_eq!(v["code"], "bad_request");
}
