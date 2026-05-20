use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; cargo test pg_contract_tests -- --ignored"]
async fn projects_style_config_patch_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let create_body = format!(
        r#"{{
            "name":"pg_style_config_{}"
        }}"#,
        Uuid::new_v4().simple()
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert!(
        status == StatusCode::OK || status == StatusCode::CREATED,
        "create: {created:?}"
    );
    let project_id = created["id"].as_str().expect("project id");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_id}/style-config"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "empty body: {empty:?}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_id}/style-config"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"artStylePack":"__nonexistent_art_pack__"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, bad_pack) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "unknown pack: {bad_pack:?}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_id}/style-config"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"artStylePack":"2D_chinese_guofeng","storyStylePack":"Family_warmth"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patch style-config: {patched:?}");
    assert_eq!(
        patched["art_style_pack"].as_str(),
        Some("art_skills/2D_chinese_guofeng")
    );
    assert_eq!(
        patched["story_style_pack"].as_str(),
        Some("story_skills/Family_warmth")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{project_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, detail) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get project: {detail:?}");
    let proj = &detail["project"];
    assert_eq!(
        proj["art_style_pack"].as_str(),
        Some("art_skills/2D_chinese_guofeng")
    );
    assert_eq!(
        proj["story_style_pack"].as_str(),
        Some("story_skills/Family_warmth")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_id}/style-config"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"artStylePack":null}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "clear art pack: {cleared:?}");
    assert!(cleared["art_style_pack"].is_null());
    assert_eq!(
        cleared["story_style_pack"].as_str(),
        Some("story_skills/Family_warmth"),
        "story pack unchanged when only art cleared"
    );

    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(Uuid::parse_str(project_id).unwrap())
        .execute(&pool)
        .await;
}
