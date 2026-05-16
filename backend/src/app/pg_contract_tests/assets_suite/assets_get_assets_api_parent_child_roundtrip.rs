use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_get_assets_api_parent_child_roundtrip() {
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
    let project_numeric_id = created_project["numeric_id"]
        .as_i64()
        .expect("project numeric id") as i32;
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let parent_a_name = format!("pg_parent_a_{}", Uuid::new_v4());
    let parent_b_name = format!("pg_parent_b_{}", Uuid::new_v4());
    let child_a_name = format!("pg_child_a_{}", Uuid::new_v4());
    let child_b_name = format!("pg_child_b_{}", Uuid::new_v4());

    let (status, parent_a) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{parent_a_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "parent_a={parent_a}");
    let parent_a_numeric_id = parent_a["numeric_id"]
        .as_i64()
        .expect("parent_a numeric id") as i32;

    let (status, parent_b) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{parent_b_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "parent_b={parent_b}");
    let parent_b_numeric_id = parent_b["numeric_id"]
        .as_i64()
        .expect("parent_b numeric id") as i32;

    let (status, child_a) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{child_a_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "child_a={child_a}");
    let child_a_numeric_id = child_a["numeric_id"].as_i64().expect("child_a numeric id") as i32;

    let (status, child_b) = read_json_response(
        app.clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!("/api/v1/projects/{project_uuid}/assets"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"name":"{child_b_name}","type":"role"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap(),
    )
    .await;
    assert_eq!(status, StatusCode::CREATED, "child_b={child_b}");
    let child_b_numeric_id = child_b["numeric_id"].as_i64().expect("child_b numeric id") as i32;

    let parent_a_uuid: Uuid = sqlx::query_scalar(
        r#"SELECT id
           FROM app_asset
           WHERE project_id = (SELECT id FROM app_project WHERE numeric_id = $1 AND owner_user_id = $2)
             AND numeric_id = $3"#,
    )
    .bind(project_numeric_id)
    .bind(sub)
    .bind(parent_a_numeric_id)
    .fetch_one(&pool)
    .await
    .expect("parent_a uuid");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{assetsId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE numeric_id = $1 AND owner_user_id = $3)
          AND numeric_id = $4
        "#,
    )
    .bind(project_numeric_id)
    .bind(parent_a_numeric_id)
    .bind(sub)
    .bind(child_a_numeric_id)
    .execute(&pool)
    .await
    .expect("child_a metadata.assetsId");

    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{assetsId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE numeric_id = $1 AND owner_user_id = $3)
          AND numeric_id = $4
        "#,
    )
    .bind(project_numeric_id)
    .bind(parent_b_numeric_id)
    .bind(sub)
    .bind(child_b_numeric_id)
    .execute(&pool)
    .await
    .expect("child_b metadata.assetsId");

    let parent_a_image_numeric_id = 9_901_001;
    sqlx::query(
        r#"
        UPDATE app_asset
        SET metadata = jsonb_set(
          jsonb_set(COALESCE(metadata, '{}'::jsonb), '{projectId}', to_jsonb($1::integer), true),
          '{imageId}',
          to_jsonb($2::integer),
          true
        )
        WHERE project_id = (SELECT id FROM app_project WHERE numeric_id = $1 AND owner_user_id = $3)
          AND numeric_id = $4
        "#,
    )
    .bind(project_numeric_id)
    .bind(parent_a_image_numeric_id)
    .bind(sub)
    .bind(parent_a_numeric_id)
    .execute(&pool)
    .await
    .expect("parent_a metadata.imageId");

    sqlx::query(
        r#"
        INSERT INTO app_asset_image (asset_id, sort_index, file_path, state, numeric_image_id, metadata)
        VALUES ($1, 0, '/tmp/pg_parent_a_selected.png', '失败', $2, '{"errorReason":"provider_timeout"}'::jsonb)
        "#,
    )
    .bind(parent_a_uuid)
    .bind(parent_a_image_numeric_id)
    .execute(&pool)
    .await
    .expect("insert parent_a selected image");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/nested"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"type":"role","page":1,"limit":1}"#.to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, first_page) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "first_page={first_page}");
    assert_eq!(first_page["total"].as_i64(), Some(2));
    let rows = first_page["data"].as_array().expect("first page data");
    assert_eq!(rows.len(), 1);
    let first_parent = &rows[0];
    assert_eq!(
        first_parent["id"].as_i64(),
        Some(i64::from(parent_a_numeric_id))
    );
    assert_eq!(
        first_parent["filePath"].as_str(),
        Some("/tmp/pg_parent_a_selected.png")
    );
    assert_eq!(
        first_parent["src"].as_str(),
        Some("/tmp/pg_parent_a_selected.png")
    );
    assert_eq!(first_parent["state"].as_str(), Some("失败"));
    assert_eq!(
        first_parent["errorReason"].as_str(),
        Some("provider_timeout")
    );
    let first_children = first_parent["sonAssets"]
        .as_array()
        .expect("first parent sonAssets");
    assert_eq!(first_children.len(), 1);
    assert_eq!(
        first_children[0]["id"].as_i64(),
        Some(i64::from(child_a_numeric_id))
    );
    assert_eq!(
        first_children[0]["assetsId"].as_i64(),
        Some(i64::from(parent_a_numeric_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/nested"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    r#"{"type":"role","page":2,"limit":1}"#.to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, second_page) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "second_page={second_page}");
    assert_eq!(second_page["total"].as_i64(), Some(2));
    let rows = second_page["data"].as_array().expect("second page data");
    assert_eq!(rows.len(), 1);
    let second_parent = &rows[0];
    assert_eq!(
        second_parent["id"].as_i64(),
        Some(i64::from(parent_b_numeric_id))
    );
    let second_children = second_parent["sonAssets"]
        .as_array()
        .expect("second parent sonAssets");
    assert_eq!(second_children.len(), 1);
    assert_eq!(
        second_children[0]["id"].as_i64(),
        Some(i64::from(child_b_numeric_id))
    );
    assert_eq!(
        second_children[0]["assetsId"].as_i64(),
        Some(i64::from(parent_b_numeric_id))
    );
}
