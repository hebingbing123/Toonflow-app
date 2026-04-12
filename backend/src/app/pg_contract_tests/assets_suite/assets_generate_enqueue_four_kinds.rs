use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_generate_enqueue_four_kinds() {
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
    let app = build_router(contract_state(pool, secret));

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
    assert_eq!(status, StatusCode::CREATED, "body={created}");
    let numeric_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;
    let _project_uuid = created["id"].as_str().expect("project uuid");

    let gen_body = format!(
        r#"{{"projectId":{numeric_id},"model":"1:pg_ag","resolution":"1024x1024","id":1,"type":"role","name":"pg_ag_gen","prompt":"probe","base64":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(gen_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "generate body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_IMAGE));
    assert_eq!(job["status"].as_str(), Some("queued"));
    assert_eq!(job["payload"]["has_base64"].as_bool(), Some(true));
    assert_eq!(
        job["payload"]["image_base64"].as_str(),
        Some("data:image/jpeg;base64,QUJDRA==")
    );

    let pol_body = format!(
        r#"{{"assetsId":1,"projectId":{numeric_id},"type":"role","name":"n","describe":"d"}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/polish-prompt")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(pol_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "polish body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_PROMPT));
    assert_eq!(job["status"].as_str(), Some("queued"));

    let bat_gen = format!(
        r#"{{"projectId":{numeric_id},"model":"1:x","resolution":"1024x1024","items":[{{"id":1,"type":"role","name":"n","prompt":"p","base64":"data:image/png;base64,AA=="}}]}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/batch-generate")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(bat_gen))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch-generate body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_GENERATE_BATCH));
    assert_eq!(job["status"].as_str(), Some("queued"));
    assert_eq!(
        job["payload"]["items"][0]["has_base64"].as_bool(),
        Some(true)
    );
    assert_eq!(
        job["payload"]["items"][0]["image_base64"].as_str(),
        Some("data:image/png;base64,AA==")
    );

    let bat_pol = format!(
        r#"{{"projectId":{numeric_id},"items":[{{"assetsId":1,"type":"role","name":"n","describe":"d"}}]}}"#
    );
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/assets-generate/batch-polish")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(bat_pol))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, job) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch-polish body={job}");
    assert_eq!(job["kind"].as_str(), Some(JOB_KIND_ASSET_POLISH_BATCH));
    assert_eq!(job["status"].as_str(), Some("queued"));
}
