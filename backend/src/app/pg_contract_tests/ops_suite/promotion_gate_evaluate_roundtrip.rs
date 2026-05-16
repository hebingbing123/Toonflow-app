use super::super::*;
use tower::ServiceExt;

/// Gate decide + GET gate：对齐 `/api/v1/benchmark/experiments/{id}/gate` 路由；写入 blocked 后在 latestDecisions 中可见。
#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn promotion_gate_evaluate_blocked_on_guard_failure() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL");
    let secret = std::env::var("SUPABASE_JWT_SECRET").expect("SUPABASE_JWT_SECRET");
    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let run_id = Uuid::new_v4();
    let variant_id = Uuid::new_v4();

    sqlx::query(
        r#"
        INSERT INTO public.app_experiment_run (id, owner_user_id, name, status, sample_tier, stage_scope)
        VALUES ($1, $2, 'pg_contract_promotion_gate', 'draft', 'smoke', '[]'::jsonb)
        "#,
    )
    .bind(run_id)
    .bind(sub)
    .execute(&pool)
    .await
    .expect("insert experiment run");

    sqlx::query(
        r#"
        INSERT INTO public.app_experiment_variant (
            id, experiment_run_id, label, is_baseline,
            skill_snapshot, prompt_snapshot, memory_budget_snapshot,
            observation_policy_snapshot, model_route_snapshot
        )
        VALUES ($1, $2, 'baseline', true, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb, '{}'::jsonb)
        "#,
    )
    .bind(variant_id)
    .bind(run_id)
    .execute(&pool)
    .await
    .expect("insert experiment variant");

    sqlx::query("UPDATE public.app_experiment_run SET baseline_variant_id = $1 WHERE id = $2")
        .bind(variant_id)
        .bind(run_id)
        .execute(&pool)
        .await
        .expect("set baseline variant");

    let gate_path = format!("/api/v1/benchmark/experiments/{run_id}/gate");
    let decide_path = format!("/api/v1/benchmark/experiments/{run_id}/gate/decide");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(&decide_path)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"variantId":"{variant_id}","decision":"blocked","rationaleNote":"guard sample degraded"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "decide={body}");
    assert_eq!(body["decision"].as_str(), Some("blocked"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(&gate_path)
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "summary={summary}");
    let decisions = summary["latestDecisions"]
        .as_array()
        .expect("decisions array");
    assert!(
        decisions
            .iter()
            .any(|d| d["decision"].as_str() == Some("blocked")),
        "should have a blocked decision"
    );

    let _ = sqlx::query("DELETE FROM public.app_experiment_run WHERE id = $1")
        .bind(run_id)
        .execute(&pool)
        .await;
}
