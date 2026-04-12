use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn production_assets_derivative_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let project_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_derivative_asset","type":"role","description":"hero"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset={asset}");
    let asset_id = asset["numeric_id"].as_i64().expect("asset numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"pg_derivative_script"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script={script}");
    let script_id = script["numeric_id"].as_i64().expect("script numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PUT)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/scripts/{script_id}/assets/{asset_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(
        res.status(),
        StatusCode::NO_CONTENT,
        "script↔asset link for production polling scope"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_derivative_asset_unlinked","type":"role","description":"extra"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset2={asset2}");
    let asset2_id = asset2["numeric_id"].as_i64().expect("asset2 numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/batch-generate-assets-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetIds":[{asset2_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(
        res.status(),
        StatusCode::NOT_FOUND,
        "batch-generate must require app_script_asset link"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/batch-generate-assets-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, batch) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch={batch}");
    assert_eq!(batch["total"].as_i64(), Some(1));
    assert_eq!(batch["enqueued"].as_array().map(|a| a.len()), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/get-assets-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetType":"role","limit":10,"offset":0}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, assets_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "assets_data={assets_data}");
    assert_eq!(assets_data["total"].as_i64(), Some(1));
    assert_eq!(
        assets_data["assets"][0]["id"].as_i64(),
        Some(i64::from(asset_id))
    );

    let image_url = "https://cdn.example.com/pg-asset-derivative.png";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/update-assets-url")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetId":{asset_id},"imageUrl":"{image_url}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_url) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_url={updated_url}");
    assert_eq!(updated_url["asset_id"].as_i64(), Some(i64::from(asset_id)));
    assert_eq!(updated_url["image_url"].as_str(), Some(image_url));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polling={polling}");
    assert_eq!(
        polling["statuses"][0]["asset_id"].as_i64(),
        Some(i64::from(asset_id))
    );
    assert_eq!(polling["statuses"][0]["image_count"].as_i64(), Some(1));
    assert_eq!(
        polling["statuses"][0]["latest_state"].as_str(),
        Some("已完成")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/delete-assets-derivative")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted={deleted}");
    assert_eq!(deleted["deleted"].as_i64(), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/production/assets/polling-image")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"scriptId":{script_id},"assetIds":[{asset_id}]}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, polling_after_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "polling_after_delete={polling_after_delete}"
    );
    assert_eq!(
        polling_after_delete["statuses"][0]["image_count"].as_i64(),
        Some(0)
    );
    assert!(polling_after_delete["statuses"][0]["latest_state"].is_null());

    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
