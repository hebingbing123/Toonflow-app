use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn asset_image_file_local_storage_roundtrip() {
    use base64::Engine;
    use serde_json::json;

    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let tmp = tempfile::tempdir().expect("tempdir");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let user_dir = tmp.path().join(sub.to_string());
    std::fs::create_dir_all(&user_dir).expect("mkdir user image dir");

    let img_id = Uuid::new_v4();
    let png = base64::engine::general_purpose::STANDARD
        .decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")
        .expect("1x1 png");
    std::fs::write(user_dir.join(format!("{img_id}.png")), &png).expect("write png");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state_with_local_dir(
        pool.clone(),
        secret.clone(),
        tmp.path().to_path_buf(),
    ));

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
    assert_eq!(status, StatusCode::CREATED, "body={created}");
    let _numeric_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
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
                    r#"{"name":"pg_contract_local_png_asset","type":"role"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_row) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "asset={asset_row}");
    let asset_leg = asset_row["numeric_id"].as_i64().expect("asset numeric_id") as i32;
    let asset_id = Uuid::parse_str(asset_row["id"].as_str().expect("asset id")).unwrap();

    let api_file_path =
        format!("/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_id}/file");
    let meta = json!({"storage": "local", "source": "pg_contract"});
    sqlx::query(
        r#"
        INSERT INTO app_asset_image (id, asset_id, sort_index, file_path, state, metadata)
        VALUES ($1, $2, 0, $3, '已完成', $4)
        "#,
    )
    .bind(img_id)
    .bind(asset_id)
    .bind(&api_file_path)
    .bind(Json(meta))
    .execute(&pool)
    .await
    .expect("insert app_asset_image row");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_leg}/images/{img_id}/file"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let cache_control = res
        .headers()
        .get(header::CACHE_CONTROL)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string);
    let (status, body, ct) = read_bytes_response(res, 512 * 1024).await;
    assert_eq!(status, StatusCode::OK, "file GET");
    assert_eq!(body, png);
    assert!(
        ct.as_deref()
            .is_some_and(|s| s.to_lowercase().starts_with("image/png")),
        "content-type: {ct:?}"
    );
    assert_eq!(
        cache_control.as_deref(),
        Some("private, max-age=300"),
        "cache-control: {cache_control:?}"
    );

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NO_CONTENT);
}
