use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn script_agent_plan_roundtrip() {
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
    let project_id = created["numeric_id"].as_i64().expect("numeric_id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, initial_plan) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "initial_plan={initial_plan}");
    assert_eq!(initial_plan["code"].as_i64(), Some(200));
    assert_eq!(initial_plan["data"]["storySkeleton"].as_str(), Some(""));
    assert_eq!(
        initial_plan["data"]["adaptationStrategy"].as_str(),
        Some("")
    );

    let set_body = serde_json::json!({
        "projectId": project_id,
        "agentType": "scriptAgent",
        "data": {
            "storySkeleton": "三幕短剧",
            "adaptationStrategy": "先冲突后反转",
            "script": [
                { "name": "第1集", "content": "第一集内容" },
                { "name": "第2集", "content": "第二集内容" }
            ]
        }
    })
    .to_string();
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/set-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(set_body))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, set_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "set_ok={set_ok}");
    assert_eq!(set_ok["code"].as_i64(), Some(200));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_plan) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "fetched_plan={fetched_plan}");
    assert_eq!(
        fetched_plan["data"]["data"]["storySkeleton"].as_str(),
        Some("三幕短剧")
    );
    assert_eq!(
        fetched_plan["data"]["data"]["adaptationStrategy"].as_str(),
        Some("先冲突后反转")
    );
    let plan_id = fetched_plan["data"]["id"].as_i64().expect("plan id");
    let scripts = fetched_plan["data"]["data"]["script"]
        .as_array()
        .expect("scripts array");
    assert_eq!(scripts.len(), 2);
    assert_eq!(scripts[0]["name"].as_str(), Some("第1集"));
    assert_eq!(scripts[0]["content"].as_str(), Some("第一集内容"));
    let script_row_id = scripts[0]["id"].as_i64().expect("script row id") as i32;

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/set-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "projectId": project_id,
                        "agentType": "scriptAgent",
                        "data": {
                            "storySkeleton": "四幕短剧",
                            "adaptationStrategy": "强化人物弧光",
                            "script": [
                                { "name": "第1集", "content": "第一集修订版" }
                            ]
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, set_again_ok) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "set_again_ok={set_again_ok}");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/get-plan-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_after_update) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "fetched_after_update={fetched_after_update}"
    );
    assert_eq!(
        fetched_after_update["data"]["data"]["storySkeleton"].as_str(),
        Some("四幕短剧")
    );
    let scripts_after_update = fetched_after_update["data"]["data"]["script"]
        .as_array()
        .expect("scripts_after_update");
    assert_eq!(
        scripts_after_update.len(),
        2,
        "existing unnamed rows preserved"
    );
    assert_eq!(
        scripts_after_update[0]["content"].as_str(),
        Some("第一集修订版")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/script-agent/update-data")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    serde_json::json!({
                        "id": plan_id,
                        "data": {
                            "storySkeleton": "终稿大纲",
                            "adaptationStrategy": "保留反转",
                            "script": [
                                { "id": script_row_id, "content": "终稿正文" }
                            ]
                        }
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, updated_data) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "updated_data={updated_data}");
    assert_eq!(updated_data["data"].as_str(), Some("更新成功"));

    let stored_plan: Option<Value> = sqlx::query_scalar(
        r#"
        SELECT plan_data
        FROM public.app_script_agent_plan
        WHERE owner_user_id = $1
          AND project_id IN (
            SELECT id FROM public.app_project WHERE numeric_id = $2
          )
          AND agent_key = 'scriptAgent'
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .fetch_optional(&pool)
    .await
    .expect("select plan_data");
    let stored_plan = stored_plan.expect("stored plan_data");
    assert_eq!(stored_plan["storySkeleton"].as_str(), Some("终稿大纲"));
    assert_eq!(stored_plan["adaptationStrategy"].as_str(), Some("保留反转"));
    assert_eq!(
        stored_plan["script"][0]["id"].as_i64(),
        Some(i64::from(script_row_id))
    );
    assert_eq!(
        stored_plan["script"][0]["content"].as_str(),
        Some("终稿正文")
    );

    let _ = sqlx::query(
        "DELETE FROM public.app_script WHERE project_id IN (SELECT id FROM public.app_project WHERE numeric_id = $1)",
    )
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
}
