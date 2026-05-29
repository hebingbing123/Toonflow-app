//! Personal compliance cleared template delete — optimistic UI contract.

use super::super::*;
use serde_json::json;
use tower::ServiceExt;
use uuid::Uuid;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; cargo test notifications_compliance_template_delete_roundtrip -- --ignored"]
async fn notifications_compliance_template_delete_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool, secret));

    let template_id = format!("contract_tpl_{}", Uuid::new_v4().simple());
    let upsert_body = json!({
        "template": {
            "id": template_id,
            "label": "Contract template",
            "description": "delete roundtrip",
            "policy": { "globalMinutes": 15, "stageMinutes": {} },
            "kind": "custom",
            "canEdit": true,
            "canDelete": true
        }
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/notifications/content-compliance/cleared-templates")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(upsert_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, upserted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "upsert template: {upserted:?}");
    let templates = upserted["templates"].as_array().expect("templates");
    assert!(
        templates
            .iter()
            .any(|row| row["id"].as_str() == Some(template_id.as_str())),
        "template should exist after upsert: {upserted:?}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri("/api/v1/settings/notifications/content-compliance/cleared-templates")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(json!({ "id": template_id }).to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, deleted) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "delete template: {deleted:?}");
    assert_eq!(deleted["deleted"].as_bool(), Some(true));
    let remaining = deleted["templates"]
        .as_array()
        .expect("templates after delete");
    assert!(
        !remaining
            .iter()
            .any(|row| row["id"].as_str() == Some(template_id.as_str())),
        "template should be removed: {deleted:?}"
    );
}
