use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn art_styles_base64_cover_roundtrip() {
    use serde_json::json;

    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let tmp = tempfile::tempdir().expect("tempdir");
    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state_with_local_art_style_dir(
        pool.clone(),
        secret.clone(),
        tmp.path().to_path_buf(),
    ));

    let cover =
        "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "name": "pg_contract_art_style_cover",
                        "file_url": cover,
                        "prompt": "cover prompt"
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let numeric_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    let cover_uri = format!("/api/v1/art-styles/numeric/{numeric_id}/cover");
    assert_eq!(created["file_url"].as_str(), Some(cover_uri.as_str()));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(&cover_uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bytes, ct) = read_bytes_response(res, 64 * 1024).await;
    assert_eq!(status, StatusCode::OK);
    assert_eq!(ct.as_deref(), Some("image/png"));
    assert!(!bytes.is_empty(), "cover bytes should be non-empty");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/art-styles/numeric/{numeric_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"file_url":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert!(patched["file_url"].is_null());

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(&cover_uri)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, missing) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "missing={missing}");

    let _ = sqlx::query("DELETE FROM public.app_art_style WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
