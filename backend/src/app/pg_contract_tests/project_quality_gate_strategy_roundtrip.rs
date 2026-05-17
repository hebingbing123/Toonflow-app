//! Project `quality_gate_strategy` PATCH + validation (需求 I.1).

use super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; cargo test project_quality_gate_strategy_patch_contract -- --ignored"]
async fn project_quality_gate_strategy_patch_contract() {
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

    let create_name = format!("pg_qg_strategy_{}", Uuid::new_v4().simple());
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"name":"{create_name}","qualityGateStrategy":"warn"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "create: {created}");
    assert_eq!(
        created["qualityGateStrategy"].as_str(),
        Some("warn"),
        "POST should persist qualityGateStrategy: {created}"
    );
    let project_uuid = created["id"].as_str().expect("project id");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, detail) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get after create: {detail}");
    assert_eq!(
        detail["project"]["qualityGateStrategy"].as_str(),
        Some("warn")
    );

    for strategy in ["off", "warn", "block"] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::PATCH)
                    .uri(format!("/api/v1/projects/{project_uuid}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"qualityGateStrategy":"{strategy}"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, patched) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "patch strategy={strategy}: {patched}"
        );
        assert_eq!(
            patched["qualityGateStrategy"].as_str(),
            Some(strategy),
            "PATCH response should echo strategy: {patched}"
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::GET)
                    .uri(format!("/api/v1/projects/{project_uuid}"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, detail) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "get after {strategy}: {detail}");
        assert_eq!(
            detail["project"]["qualityGateStrategy"].as_str(),
            Some(strategy)
        );
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"qualityGateStrategy":"skip"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, invalid) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "invalid strategy: {invalid}"
    );
}
