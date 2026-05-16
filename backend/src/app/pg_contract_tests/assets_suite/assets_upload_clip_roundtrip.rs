use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn assets_upload_clip_roundtrip() {
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
    let project_uuid = created["id"].as_str().expect("project uuid");

    let clip_name = format!("pg_clip_{}", Uuid::new_v4());
    let body = format!(r#"{{"name":"{clip_name}","base64Data":"QUJDRA=="}}"#);
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/upload-clip"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, uploaded) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "uploaded={uploaded}");
    assert_eq!(uploaded["message"].as_str(), Some("上传成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/material-data"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, material) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "material={material}");
    let row = material["data"]
        .as_array()
        .expect("material.data")
        .iter()
        .find(|r| r["name"].as_str() == Some(clip_name.as_str()))
        .expect("uploaded clip row");
    assert_eq!(row["type"].as_str(), Some("clip"));
    assert_eq!(
        row["filePath"].as_str(),
        Some("data:application/octet-stream;base64,QUJDRA==")
    );

    let clip_numeric_id = row["id"].as_i64().expect("clip numeric id") as i32;
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/projects/{project_uuid}/assets/workbench/image-bundle"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"assetsId":{clip_numeric_id}}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, image_bundle) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "image_bundle={image_bundle}");
    assert_eq!(
        image_bundle["imageId"].as_i64(),
        image_bundle["tempAssets"][0]["id"].as_i64()
    );
    assert_eq!(
        image_bundle["tempAssets"][0]["selected"].as_bool(),
        Some(true)
    );
}
