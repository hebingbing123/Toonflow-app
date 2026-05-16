//! `GET/PUT /api/v1/search/saved-views` round-trip + workspace 成员 403。
use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test search_saved_views_roundtrip -- --ignored"]
async fn search_saved_views_roundtrip() {
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
    let _ = sqlx::query("DELETE FROM public.app_user_search_saved_view WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;

    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/search/saved-views")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get empty: {empty}");
    assert_eq!(empty["items"].as_array().map(|a| a.len()), Some(0));

    let fake_ws = "550e8400-e29b-41d4-a716-446655440099";
    let body_bad_ws = format!(
        r#"{{"items":[{{"id":"sv-contract-1","title":"t","query":"q","pinned":false,"resultTypes":[],"workspaceId":"{fake_ws}","updatedAt":"2026-05-11T12:00:00Z","useCount":0}}]}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PUT)
                .uri("/api/v1/search/saved-views")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body_bad_ws))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, err) = read_json_response(res).await;
    assert_eq!(status, StatusCode::FORBIDDEN, "non-member workspace: {err}");

    let body_ok = r#"{"items":[{"id":"sv-contract-1","title":"Title","query":"hello","pinned":true,"resultTypes":["project"],"updatedAt":"2026-05-11T12:00:00Z","useCount":3}]}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PUT)
                .uri("/api/v1/search/saved-views")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body_ok))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, put_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "put ok: {put_ok}");
    let items = put_ok["items"].as_array().expect("items");
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["id"].as_str(), Some("sv-contract-1"));
    assert_eq!(items[0]["title"].as_str(), Some("Title"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/search/saved-views")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, listed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get listed: {listed}");
    assert_eq!(listed["items"].as_array().map(|a| a.len()), Some(1));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"PG Saved Views WS"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create workspace: {created}");
    let workspace_id = created["id"].as_str().expect("workspace id");

    let body_with_ws = format!(
        r#"{{"items":[{{"id":"sv-contract-2","title":"With WS","query":"x","pinned":false,"resultTypes":["novel"],"workspaceId":"{workspace_id}","updatedAt":"2026-05-11T13:00:00Z","useCount":0}}]}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PUT)
                .uri("/api/v1/search/saved-views")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body_with_ws))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, put_ws) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "put with workspace: {put_ws}");
    assert_eq!(put_ws["items"].as_array().map(|a| a.len()), Some(1));
    assert_eq!(
        put_ws["items"][0]["workspaceId"].as_str(),
        Some(workspace_id)
    );

    let ws_uuid = Uuid::parse_str(workspace_id).unwrap();
    let _ = sqlx::query("DELETE FROM public.app_user_search_saved_view WHERE owner_user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(ws_uuid)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(ws_uuid)
        .execute(&pool)
        .await;
}
