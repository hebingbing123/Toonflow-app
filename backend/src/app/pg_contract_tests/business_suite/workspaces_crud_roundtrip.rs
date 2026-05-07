use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema (incl. app_workspace.archived_at); supabase db reset; cargo test workspaces_crud_roundtrip -- --ignored"]
async fn workspaces_crud_roundtrip() {
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

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_before) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list workspaces: {list_before:?}");
    let arr = list_before.as_array().expect("workspace list array");
    assert!(
        arr.iter().any(|row| row["workspace_type"] == "personal"),
        "expected personal workspace in list"
    );

    let create_body = serde_json::json!({
        "name": "Contract PG Enterprise",
        "metadata": {"contract": "pg_workspace_crud"}
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create enterprise: {created:?}");
    assert_eq!(created["workspace_type"], "enterprise");
    let enterprise_id = created["id"].as_str().expect("enterprise id");
    assert!(
        created.get("archived_at").is_none() || created["archived_at"].is_null(),
        "new workspace should not be archived"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/workspaces/{enterprise_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get workspace: {got:?}");
    assert_eq!(got["id"].as_str(), Some(enterprise_id));

    let patch_archive = serde_json::json!({ "archive": true });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/workspaces/{enterprise_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_archive.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "archive: {patched:?}");
    assert!(
        patched["archived_at"].is_string(),
        "archived_at should be set: {patched:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_active) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    let active = list_active.as_array().expect("list");
    assert!(
        !active
            .iter()
            .any(|row| row["id"].as_str() == Some(enterprise_id)),
        "archived enterprise should not appear in default list"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/workspaces?include_archived=true")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_all) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK);
    let all = list_all.as_array().expect("list all");
    let ent = all
        .iter()
        .find(|row| row["id"].as_str() == Some(enterprise_id))
        .expect("enterprise visible when include_archived");
    assert!(
        ent["archived_at"].is_string(),
        "archived row should carry archived_at"
    );

    let patch_restore = serde_json::json!({ "archive": false });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/workspaces/{enterprise_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(patch_restore.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, restored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "restore: {restored:?}");
    assert!(
        restored.get("archived_at").is_none() || restored["archived_at"].is_null(),
        "restored workspace should clear archived_at"
    );

    let wid = Uuid::parse_str(enterprise_id).unwrap();
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(wid)
        .execute(&pool)
        .await
        .expect("cleanup enterprise workspace");
}
