use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn novel_events_crud_roundtrip() {
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

    // Create project
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
    let project_uuid = created["id"].as_str().expect("project id");

    // Add novels first to have chapter_ids to associate
    for body in [
        r#"{"chapter_index":1,"reel":"卷一","chapter":"第一章","chapter_data":"第一章内容"}"#,
        r#"{"chapter_index":2,"reel":"卷一","chapter":"第二章","chapter_data":"第二章内容"}"#,
    ] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/novels"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, _) = read_json_response(res).await;
        assert_eq!(status, StatusCode::CREATED, "add novel");
    }

    // Create event
    let create_body = r#"{"name":"测试事件","detail":"事件详情","chapterIds":[1,2]}"#.to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, event) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create event={event}");
    assert_eq!(event["name"].as_str(), Some("测试事件"));
    let event_id = event["id"].as_i64().expect("event id") as i32;

    // List events
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list}");
    assert_eq!(list["total"].as_i64(), Some(1));
    let items = list["items"].as_array().expect("items");
    assert_eq!(items.len(), 1);
    assert_eq!(items[0]["name"].as_str(), Some("测试事件"));
    let chapters = items[0]["chapter_indexes"].as_array().expect("chapters");
    assert_eq!(chapters.len(), 2);

    // Update event
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novel-events/{event_id}",
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"更新后事件"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update event");

    // Verify update
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list2={list2}");
    assert_eq!(list2["items"][0]["name"].as_str(), Some("更新后事件"));

    // Delete event
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/novel-events/{event_id}",
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete event");

    // Verify deletion
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/projects/{project_uuid}/novel-events",))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "empty_list={empty_list}");
    assert_eq!(empty_list["total"].as_i64(), Some(0));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_novel WHERE project_id IN (SELECT id FROM public.app_project WHERE numeric_id = $1)")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
