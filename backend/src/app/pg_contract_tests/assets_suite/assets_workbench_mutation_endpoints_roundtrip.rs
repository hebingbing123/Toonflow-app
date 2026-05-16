use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_workbench_mutation_endpoints_roundtrip() {
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
    let (status, created_project) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CREATED,
        "created_project={created_project}"
    );
    let project_uuid = created_project["id"].as_str().expect("project uuid");

    let base_name = format!("pg_import_asset_{}", Uuid::new_v4().simple());
    let asset_a_name = format!("{base_name}_a");
    let asset_b_name = format!("{base_name}_b");
    let asset_c_name = format!("{base_name}_c");
    let asset_d_name = format!("{base_name}_d");

    let create_body = format!(
        r#"{{"name":"{asset_a_name}","describe":"desc a","type":"role","remark":"  r0  ","prompt":"  p0  "}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/add-assets"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, add_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");
    assert_eq!(add_msg["message"].as_str(), Some("新增资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_a_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_a) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_a={list_a}");
    assert_eq!(list_a["total"].as_i64(), Some(1));
    let asset_a_numeric_id = list_a["items"][0]["numeric_id"]
        .as_i64()
        .expect("asset_a numeric id") as i32;
    assert_eq!(
        list_a["items"][0]["metadata"]["prompt"].as_str(),
        Some("p0"),
        "prompt should be trimmed on add-assets"
    );
    assert_eq!(
        list_a["items"][0]["metadata"]["remark"].as_str(),
        Some("r0"),
        "remark should be trimmed on add-assets"
    );

    let save_body = format!(
        r#"{{"id":{asset_a_numeric_id},"type":"role","prompt":"  p1  ","base64":"QUJDRA=="}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/save-assets"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(save_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, save_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "save_msg={save_msg}");
    assert_eq!(save_msg["message"].as_str(), Some("保存资产图片成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/image-bundle"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"assetsId":{asset_a_numeric_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, get_image) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get_image={get_image}");
    let image_numeric_id = get_image["imageId"].as_i64().expect("imageId") as i32;
    assert_eq!(
        get_image["tempAssets"]
            .as_array()
            .map(|arr| arr.len())
            .unwrap_or(0),
        1
    );
    assert_eq!(get_image["tempAssets"][0]["selected"].as_bool(), Some(true));

    let update_body = format!(
        r#"{{"id":{asset_a_numeric_id},"name":"{asset_a_name}_u","describe":"desc a2","remark":"  r2  ","prompt":"   "}}"#
    );
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/update-assets"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(update_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, update_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "update_msg={update_msg}");
    assert_eq!(update_msg["message"].as_str(), Some("更新资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/{asset_a_numeric_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, asset_after_update) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "asset_after_update={asset_after_update}"
    );
    assert_eq!(
        asset_after_update["name"].as_str(),
        Some(format!("{asset_a_name}_u").as_str())
    );
    assert_eq!(asset_after_update["description"].as_str(), Some("desc a2"));
    assert!(
        asset_after_update["metadata"]["prompt"].is_null(),
        "blank prompt should clear metadata.prompt"
    );
    assert_eq!(
        asset_after_update["metadata"]["remark"].as_str(),
        Some("r2")
    );
    assert_eq!(
        asset_after_update["metadata"]["imageId"].as_i64(),
        Some(i64::from(image_numeric_id))
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/del-image"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{image_numeric_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_image_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "del_image_msg={del_image_msg}");
    assert_eq!(del_image_msg["message"].as_str(), Some("资产图片删除成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/image-bundle"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"assetsId":{asset_a_numeric_id}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, image_after_delete) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "image_after_delete={image_after_delete}"
    );
    assert!(image_after_delete["imageId"].is_null());
    assert!(image_after_delete["tempAssets"]
        .as_array()
        .is_some_and(|arr| arr.is_empty()));

    for name in [&asset_b_name, &asset_c_name, &asset_d_name] {
        let create_body = format!(r#"{{"name":"{name}","describe":"desc","type":"role"}}"#);
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri(format!(
                        "/api/v1/projects/{project_uuid}/assets/workbench/add-assets"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(create_body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, add_msg) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "add_msg={add_msg}");
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_b_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_b) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_b={list_b}");
    let asset_b_numeric_id = list_b["items"][0]["numeric_id"]
        .as_i64()
        .expect("asset_b numeric id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/del-assets"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":{asset_b_numeric_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, del_asset_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "del_asset_msg={del_asset_msg}");
    assert_eq!(del_asset_msg["message"].as_str(), Some("删除资产成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_c_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_c) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_c={list_c}");
    assert_eq!(list_c["total"].as_i64(), Some(1), "list_c={list_c}");
    let asset_c_numeric_id = list_c["items"][0]["numeric_id"]
        .as_i64()
        .expect("asset_c numeric id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets?name={asset_d_name}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_d) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list_d={list_d}");
    assert_eq!(list_d["total"].as_i64(), Some(1), "list_d={list_d}");
    let asset_d_numeric_id = list_d["items"][0]["numeric_id"]
        .as_i64()
        .expect("asset_d numeric id") as i32;

    let batch_delete_body = format!(r#"{{"id":[{asset_c_numeric_id},{asset_d_numeric_id}]}}"#);
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/batch-delete"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(batch_delete_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, batch_msg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "batch_msg={batch_msg}");
    assert_eq!(batch_msg["message"].as_str(), Some("删除资产成功"));

    for name in [&asset_b_name, &asset_c_name, &asset_d_name] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!(
                        "/api/v1/projects/{project_uuid}/assets?name={name}"
                    ))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, list_after_delete) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::OK,
            "list_after_delete={list_after_delete}"
        );
        assert_eq!(list_after_delete["total"].as_i64(), Some(0));
    }
}
