use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test me_current_workspace_switch_roundtrip -- --ignored"]
async fn me_current_workspace_switch_roundtrip() {
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
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"PG Switch Target"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create workspace: {created}");
    let workspace_id = created["id"]
        .as_str()
        .expect("workspace id should be present")
        .to_string();

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/me/current-workspace")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"workspace_id":"{workspace_id}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, switched) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "switch current workspace: {switched}"
    );
    assert_eq!(switched["id"].as_str(), Some(workspace_id.as_str()));
    assert_eq!(switched["name"].as_str(), Some("PG Switch Target"));

    let res = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, me) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "me after switch: {me}");
    assert_eq!(
        me["current_workspace"]["id"].as_str(),
        Some(workspace_id.as_str())
    );
    assert_eq!(
        me["current_workspace"]["workspace_type"].as_str(),
        Some("enterprise")
    );

    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(Uuid::parse_str(&workspace_id).expect("parse workspace id"))
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(Uuid::parse_str(&workspace_id).expect("parse workspace id"))
        .execute(&pool)
        .await;
}
