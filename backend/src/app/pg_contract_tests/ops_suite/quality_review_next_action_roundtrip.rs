//! Quality review `next_action` typed field (需求 I.4).
//!
//! Covers explicit storage, inference when omitted, list filter, invalid enum rejection,
//! and `model_params.diagnostics.nextAction` population.

use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test quality_review_next_action_contract -- --ignored"]
async fn quality_review_next_action_contract() {
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

    const ALL_NEXT_ACTIONS: &[&str] = &[
        "patch_storyboard_items",
        "rollback_to_director_planning",
        "update_character_anchor",
        "observe",
        "regenerate_storyboard",
        "adjust_video_prompt",
        "retry_video_generation",
        "manual_review",
    ];

    let explicit_target = format!("pg_next_action_explicit_{}", Uuid::new_v4());
    let inferred_target = format!("pg_next_action_inferred_{}", Uuid::new_v4());
    let mut review_ids = Vec::new();

    for action in ALL_NEXT_ACTIONS {
        let target = format!("pg_next_action_all_{action}_{}", Uuid::new_v4());
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/quality/reviews")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(format!(
                        r#"{{"targetType":"script","targetId":"{target}","source":"manual","overallScore":7,"passed":true,"nextAction":"{action}"}}"#
                    )))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, row) = read_json_response(res).await;
        assert_eq!(
            status,
            StatusCode::CREATED,
            "create nextAction={action}: {row}"
        );
        assert_eq!(row["nextAction"].as_str(), Some(*action));
        review_ids.push(Uuid::parse_str(row["id"].as_str().expect("id")).unwrap());
    }

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"script","targetId":"{explicit_target}","source":"manual","overallScore":8,"passed":true,"nextAction":"observe","comments":"explicit next_action"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "explicit create: {created}");
    let explicit_id = created["id"].as_str().expect("review id").to_string();
    review_ids.push(Uuid::parse_str(&explicit_id).unwrap());
    assert_eq!(
        created["nextAction"].as_str(),
        Some("observe"),
        "explicit nextAction on create response: {created}"
    );
    let diagnostics = created["modelParams"]["diagnostics"]
        .as_object()
        .expect("modelParams.diagnostics");
    assert_eq!(
        diagnostics.get("nextAction").and_then(|v| v.as_str()),
        Some("observe")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/quality/reviews/{explicit_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, got) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "get explicit: {got}");
    assert_eq!(got["nextAction"].as_str(), Some("observe"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"script","targetId":"{inferred_target}","source":"manual","grade":"D","overallScore":3,"passed":false,"comments":"infer rollback"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, inferred) = read_json_response(res).await;
    assert_eq!(status, StatusCode::CREATED, "inferred create: {inferred}");
    let inferred_id = inferred["id"].as_str().expect("review id").to_string();
    review_ids.push(Uuid::parse_str(&inferred_id).unwrap());
    assert_eq!(
        inferred["nextAction"].as_str(),
        Some("rollback_to_director_planning"),
        "grade D should infer rollback: {inferred}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/quality/reviews?nextAction=observe&limit=50")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, listed) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list filter: {listed}");
    let items = listed["items"].as_array().expect("items array");
    assert!(
        items
            .iter()
            .any(|row| row["id"].as_str() == Some(explicit_id.as_str())),
        "filter nextAction=observe should include explicit review: {listed}"
    );
    assert!(
        !items
            .iter()
            .any(|row| row["id"].as_str() == Some(inferred_id.as_str())),
        "rollback review must not match observe filter: {listed}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/quality/reviews")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"targetType":"script","targetId":"pg_invalid_{}","source":"manual","overallScore":5,"nextAction":"not_a_valid_action"}}"#,
                    Uuid::new_v4()
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, invalid) = read_json_response(res).await;
    assert_ne!(
        status,
        StatusCode::CREATED,
        "invalid nextAction must not succeed: status={status} body={invalid}"
    );

    cleanup_quality_reviews(&pool, &review_ids).await;
}
