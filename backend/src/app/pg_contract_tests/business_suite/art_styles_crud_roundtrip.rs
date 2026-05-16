use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn art_styles_crud_roundtrip() {
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
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"pg_contract_art_style","prompt":"pg_contract_prompt"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let leg = created["numeric_id"].as_i64().expect("numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/art-styles")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert!(list["total"].as_i64().unwrap_or(0) >= 1);
    let items = list["items"].as_array().expect("items");
    assert!(items
        .iter()
        .any(|row| row["numeric_id"].as_i64() == Some(i64::from(leg))));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "one={one}");
    assert_eq!(one["name"].as_str(), Some("pg_contract_art_style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"label":"pg_contract_label"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(patched["label"].as_str(), Some("pg_contract_label"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NO_CONTENT);

    let res = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/art-styles/numeric/{leg}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, gone) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "gone={gone}");
}
