use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn vendor_config_enable_update_roundtrip() {
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

    // Get vendors summary (initially no user config)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary={summary}");
    assert_eq!(
        summary["source"].as_str(),
        Some("static_catalog_with_user_config")
    );
    let vendors = summary["vendors"].as_array().expect("vendors array");
    assert!(!vendors.is_empty());
    let first_vendor_id = vendors[0]["id"].as_i64().expect("vendor id") as i32;
    let first_vendor_id_str = format!("{}", first_vendor_id);

    // Initially no userConfig present
    assert!(vendors[0]["userConfig"].is_null() || vendors[0]["userConfig"].is_object());

    // Enable vendor
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/enable")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","enable":1}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, enabled) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "enabled={enabled}");
    assert_eq!(
        enabled["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );
    assert_eq!(enabled["enabled"].as_bool(), Some(true));

    // Verify summary shows enabled vendor with userConfig
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary2) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary2={summary2}");
    let vendors2 = summary2["vendors"].as_array().expect("vendors array");
    let v0 = vendors2
        .iter()
        .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
        .expect("vendor in summary2");
    assert_eq!(
        v0["userConfig"]["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );
    assert_eq!(v0["userConfig"]["enabled"].as_bool(), Some(true));

    // Update vendor with display name and model selection
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/update")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","displayName":"My Vendor","selectedModels":["gpt-4o-mini"],"settings":{{"timeout":"30"}}}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated={updated}");
    assert_eq!(
        updated["vendorId"].as_str(),
        Some(first_vendor_id_str.as_str())
    );

    // Verify summary shows updated config
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary3) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary3={summary3}");
    let vendors3 = summary3["vendors"].as_array().expect("vendors array");
    let v0_3 = vendors3
        .iter()
        .find(|v| v["id"].as_i64() == Some(i64::from(first_vendor_id)))
        .expect("vendor");
    assert_eq!(
        v0_3["userConfig"]["displayName"].as_str(),
        Some("My Vendor")
    );
    let models = v0_3["userConfig"]["selectedModels"]
        .as_array()
        .expect("selectedModels");
    assert!(models.iter().any(|m| m.as_str() == Some("gpt-4o-mini")));
    assert_eq!(
        v0_3["userConfig"]["settings"]["timeout"].as_str(),
        Some("30")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/add")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"tsCode":"export default { id: 'probe' }"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, added) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "added={added}");
    let custom_vendor_id = added["vendorId"]
        .as_str()
        .expect("custom vendor id")
        .to_string();
    assert!(custom_vendor_id.starts_with("custom-"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/update-code")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{custom_vendor_id}","tsCode":"export default {{ updated: true }}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_code) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_code={updated_code}");
    assert_eq!(
        updated_code["vendorId"].as_str(),
        Some(custom_vendor_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/vendors/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary4) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary4={summary4}");
    let vendors4 = summary4["vendors"].as_array().expect("vendors array");
    assert!(vendors4
        .iter()
        .any(|v| v["userConfig"]["vendorId"].as_str() == Some(custom_vendor_id.as_str())));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/code-from-link")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"link":"https://example.com/vendor.ts"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "linked={linked}");
    let linked_vendor_id = linked["vendorId"]
        .as_str()
        .expect("linked vendor id")
        .to_string();
    assert!(linked_vendor_id.starts_with("linked-"));
    assert_eq!(
        linked["link"].as_str(),
        Some("https://example.com/vendor.ts")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":"{custom_vendor_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted={deleted}");
    assert_eq!(
        deleted["vendorId"].as_str(),
        Some(custom_vendor_id.as_str())
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/delete")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(r#"{{"id":"{linked_vendor_id}"}}"#)))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted_linked) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "deleted_linked={deleted_linked}");
    assert_eq!(
        deleted_linked["vendorId"].as_str(),
        Some(linked_vendor_id.as_str())
    );

    // Disable vendor
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/vendors/enable")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"id":"{}","enable":0}}"#,
                    first_vendor_id_str
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, disabled) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "disabled={disabled}");
    assert_eq!(disabled["enabled"].as_bool(), Some(false));

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
