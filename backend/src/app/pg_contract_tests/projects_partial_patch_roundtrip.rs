use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn projects_patch_partial_fields_roundtrip() {
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
            "name":"pg_general_project_{}",
            "intro":"before update",
            "project_type":"movie",
            "art_style":"orig-style",
            "mode":"orig-mode",
            "video_ratio":"9:16"
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
    assert_eq!(status, StatusCode::CREATED, "created={created}");
    let project_uuid = Uuid::parse_str(created["id"].as_str().expect("project id")).unwrap();

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
    let (status, before_update) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "before_update={before_update}");
    let proj = &before_update["project"];
    assert_eq!(proj["intro"].as_str(), Some("before update"));
    assert_eq!(proj["mode"].as_str(), Some("orig-mode"));
    assert_eq!(proj["art_style"].as_str(), Some("orig-style"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, empty_patch) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "empty_patch={empty_patch}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"intro":"after update","mode":"compat-mode","art_style":null,"video_ratio":"1:1","project_type":"series"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patched={patched}");
    assert_eq!(patched["intro"].as_str(), Some("after update"));
    assert_eq!(patched["mode"].as_str(), Some("compat-mode"));
    assert!(patched["art_style"].is_null());
    assert_eq!(patched["video_ratio"].as_str(), Some("1:1"));
    assert_eq!(patched["project_type"].as_str(), Some("series"));

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
    let (status, after_update) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "after_update={after_update}");
    let row = &after_update["project"];
    assert_eq!(
        row["name"].as_str(),
        created["name"].as_str(),
        "PATCH must preserve untouched fields"
    );
    assert_eq!(row["intro"].as_str(), Some("after update"));
    assert_eq!(row["mode"].as_str(), Some("compat-mode"));
    assert!(row["art_style"].is_null());
    assert_eq!(row["video_ratio"].as_str(), Some("1:1"));
    assert_eq!(row["project_type"].as_str(), Some("series"));

    let stored: (Option<String>, Option<String>, Option<String>, Option<String>) = sqlx::query_as(
        "SELECT intro, mode, art_style, project_type FROM public.app_project WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(project_uuid)
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("select updated project");
    assert_eq!(stored.0.as_deref(), Some("after update"));
    assert_eq!(stored.1.as_deref(), Some("compat-mode"));
    assert_eq!(stored.2, None);
    assert_eq!(stored.3.as_deref(), Some("series"));

    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_uuid)
        .execute(&pool)
        .await;
}
