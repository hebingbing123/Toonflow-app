use super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn prompts_patch_roundtrip() {
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

    // Get prompts list
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
    assert_eq!(status, StatusCode::OK, "list prompts");
    assert_eq!(
        list.as_array().map(|a| a.len()),
        Some(3),
        "should have 3 default prompts"
    );

    // Get single prompt
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts/1")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, prompt) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get prompt");
    assert_eq!(prompt["id"].as_i64(), Some(1));
    let original_data = prompt["data"].as_str().expect("data").to_string();

    // Patch prompt
    let new_data = "patched prompt data for testing";
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/prompts/1")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"data":"{}"}}"#, new_data)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, patched) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "patch prompt");
    assert_eq!(patched["id"].as_i64(), Some(1));
    assert_eq!(patched["data"].as_str(), Some(new_data));

    // Verify patch persisted
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts/1")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, verify) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "verify patched prompt");
    assert_eq!(verify["data"].as_str(), Some(new_data));

    // Patch back to original
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/prompts/1")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"data":"{}"}}"#, original_data)))
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    assert_eq!(status, StatusCode::OK, "patch back should return 200");

    // Verify patch back persisted
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/prompts/1")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, restored) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "verify restored prompt");
    assert_eq!(restored["data"].as_str(), Some(original_data.as_str()));
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn storyboards_crud_roundtrip() {
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
    let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;

    // Create script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script={script}");
    let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;

    // Get storyboards (empty)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/legacy/{project_id}/scripts/{script_id}/storyboards"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list storyboards={list}");
    assert_eq!(list["items"].as_array().map(|a| a.len()), Some(0));

    // Cleanup
    let _ = sqlx::query(
        "DELETE FROM public.app_storyboard WHERE script_id IN (SELECT id FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1))"
    )
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE legacy_id = $1)")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn scripts_crud_roundtrip() {
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
    let project_id = created["legacy_id"].as_i64().expect("legacy_id") as i32;
    let project_uuid = created["id"].as_str().expect("project uuid");

    // Create script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/legacy/{project_id}/scripts"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"name":"test_script","content":"script content"}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, script) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "script={script}");
    let script_id = script["legacy_id"].as_i64().expect("script legacy_id") as i32;
    assert_eq!(script["name"].as_str(), Some("test_script"));

    // Batch add scripts (UUID project path)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/projects/{project_uuid}/scripts/batch-add"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"data":[{"scriptName":"batch_1","scriptData":"content_1"},{"scriptName":"batch_2","scriptData":"content_2"}]}"#,
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, batch) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch add script={batch}");
    assert_eq!(batch["message"].as_str(), Some("添加剧本成功"));
    assert_eq!(batch["inserted"].as_i64(), Some(2));
    let scripts = batch["scripts"].as_array().expect("scripts array");
    assert_eq!(scripts.len(), 2);
    assert_eq!(scripts[0]["name"].as_str(), Some("batch_1"));
    assert_eq!(scripts[1]["name"].as_str(), Some("batch_2"));

    // Get script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get script={got}");
    assert_eq!(got["legacy_id"].as_i64(), Some(i64::from(script_id)));

    // Update script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"updated_script"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update script={updated}");
    assert_eq!(updated["name"].as_str(), Some("updated_script"));

    // Delete script
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let status = res.status();
    assert_eq!(status, StatusCode::NO_CONTENT, "delete script");

    // Verify deletion
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/scripts/legacy/{script_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(status, StatusCode::NOT_FOUND, "script should be deleted");

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_project WHERE legacy_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
async fn quality_reviews_require_bearer_token() {
    let (status, body) = post_json("/api/v1/quality/reviews", r#"{"targetType":"script"}"#).await;
    assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");

    let (status, body) = get_json("/api/v1/quality/reviews").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");

    let (status, body) = get_json("/api/v1/quality/stats").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");

    let (status, body) = get_json("/api/v1/quality/stage-pass-rate").await;
    assert_eq!(status, StatusCode::UNAUTHORIZED, "body={body}");
}

#[tokio::test]
async fn quality_review_create_validates_payload_before_db_access() {
    let token = test_jwt(Uuid::new_v4());

    let (status, body) = post_json_bearer(
        "/api/v1/quality/reviews",
        &token,
        r#"{"targetType":"chapter"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
    assert_eq!(body["code"], "bad_request");

    let (status, body) = post_json_bearer(
        "/api/v1/quality/reviews",
        &token,
        r#"{"targetType":"script","source":"robot"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
    assert_eq!(body["code"], "bad_request");

    let (status, body) = post_json_bearer(
        "/api/v1/quality/reviews",
        &token,
        r#"{"targetType":"script","isBadCase":true,"badCaseCategory":"typo"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
    assert_eq!(body["code"], "bad_request");

    let (status, body) = post_json_bearer(
        "/api/v1/quality/reviews",
        &token,
        r#"{"targetType":"script","overallScore":11}"#,
    )
    .await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
    assert_eq!(body["code"], "bad_request");
}

#[tokio::test]
async fn quality_reviews_list_validates_query_before_db_access() {
    let token = test_jwt(Uuid::new_v4());

    let (status, body) =
        get_json_bearer("/api/v1/quality/reviews?targetType=chapter", &token).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "body={body}");
    assert_eq!(body["code"], "bad_request");
}

#[tokio::test]
async fn quality_endpoints_return_database_error_without_pool() {
    let token = test_jwt(Uuid::new_v4());
    let review_id = Uuid::nil();

    let (status, body) = post_json_bearer(
        "/api/v1/quality/reviews",
        &token,
        r#"{"targetType":"script"}"#,
    )
    .await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
    assert_eq!(body["code"], "database_error");

    let (status, body) = get_json_bearer("/api/v1/quality/reviews", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
    assert_eq!(body["code"], "database_error");

    let (status, body) =
        get_json_bearer(&format!("/api/v1/quality/reviews/{review_id}"), &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
    assert_eq!(body["code"], "database_error");

    let (status, body) = get_json_bearer("/api/v1/quality/stats", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
    assert_eq!(body["code"], "database_error");

    let (status, body) = get_json_bearer("/api/v1/quality/stage-pass-rate", &token).await;
    assert_eq!(status, StatusCode::SERVICE_UNAVAILABLE, "body={body}");
    assert_eq!(body["code"], "database_error");
}
