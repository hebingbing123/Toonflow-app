use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn prompts_list_patch_roundtrip() {
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
    sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup app_user_prompt");

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    let arr = list.as_array().expect("prompts array");
    assert_eq!(arr.len(), 3);

    let patch_body = r#"{"data":"pg_contract_prompt_patch_slot_2"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/prompts/2")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(
        patched["data"].as_str(),
        Some("pg_contract_prompt_patch_slot_2")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts/2")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, one) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get one={one}");
    assert_eq!(one["id"].as_i64(), Some(2));
    assert_eq!(
        one["data"].as_str(),
        Some("pg_contract_prompt_patch_slot_2")
    );

    let res = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, again) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "again={again}");
    let p2 = again
        .as_array()
        .expect("array")
        .iter()
        .find(|row| row["id"].as_i64() == Some(2))
        .expect("id 2");
    assert_eq!(p2["data"].as_str(), Some("pg_contract_prompt_patch_slot_2"));

    let _ = sqlx::query("DELETE FROM public.app_user_prompt WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
