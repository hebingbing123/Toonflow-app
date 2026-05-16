use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_batch_generation_data_filters_roundtrip() {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let make_asset = |name: &str, kind: &str| -> Request<Body> {
        Request::builder()
            .method(Method::POST)
            .uri(format!("/api/v1/projects/{project_uuid}/assets"))
            .header(header::AUTHORIZATION, format!("Bearer {token}"))
            .header(header::CONTENT_TYPE, "application/json")
            .extension(ConnectInfo(test_addr()))
            .body(Body::from(format!(
                r#"{{"name":"{name}","type":"{kind}"}}"#
            )))
            .unwrap()
    };

    let role_name_a = format!("pg_batch_role_a_{}", Uuid::new_v4());
    let role_name_b = format!("pg_batch_role_b_{}", Uuid::new_v4());
    let scene_name = format!("pg_batch_scene_{}", Uuid::new_v4());

    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&role_name_a, "role"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create role a");
    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&role_name_b, "role"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create role b");
    let (status, _) = read_json_response(
        app.clone()
            .oneshot(make_asset(&scene_name, "scene"))
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "create scene");

    let filter_body = r#"{"type":"role","name":"role_","page":1,"limit":1}"#.to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/batch-generation-data"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(filter_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, page_1) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "page_1={page_1}");
    assert_eq!(page_1["total"].as_i64(), Some(2));
    assert_eq!(page_1["data"].as_array().expect("page_1.data").len(), 1);
    let first_name = page_1["data"][0]["name"]
        .as_str()
        .expect("page_1 first name")
        .to_string();
    assert!(first_name == role_name_a || first_name == role_name_b);
    assert_eq!(page_1["data"][0]["type"].as_str(), Some("role"));

    let filter_body_page_2 = r#"{"type":"role","name":"role_","page":2,"limit":1}"#.to_string();
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/batch-generation-data"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(filter_body_page_2))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, page_2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "page_2={page_2}");
    assert_eq!(page_2["total"].as_i64(), Some(2));
    assert_eq!(page_2["data"].as_array().expect("page_2.data").len(), 1);
    let second_name = page_2["data"][0]["name"]
        .as_str()
        .expect("page_2 first name");
    assert!(second_name == role_name_a || second_name == role_name_b);
    assert_ne!(first_name, second_name);
    assert_eq!(page_2["data"][0]["type"].as_str(), Some("role"));
}
