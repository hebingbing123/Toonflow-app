use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract -- --ignored"]
async fn settings_memory_config_and_clear_agent_memories_roundtrip() {
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
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, default_cfg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "default_cfg={default_cfg}");
    assert_eq!(default_cfg["messagesPerSummary"].as_i64(), Some(10));
    assert_eq!(default_cfg["modelDtype"].as_str(), Some("fp16"));

    let custom_cfg = r#"{"messagesPerSummary":12,"shortTermLimit":7,"summaryMaxLength":640,"summaryLimit":11,"ragLimit":4,"deepRetrieveSummaryLimit":6,"modelOnnxFile":["custom","onnx","model.onnx"],"modelDtype":"int8"}"#;
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(custom_cfg))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, saved) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "saved={saved}");
    assert_eq!(saved["message"].as_str(), Some("保存设置成功"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/memory-config")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, fetched_cfg) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "fetched_cfg={fetched_cfg}");
    assert_eq!(fetched_cfg["messagesPerSummary"].as_i64(), Some(12));
    assert_eq!(fetched_cfg["shortTermLimit"].as_i64(), Some(7));
    assert_eq!(fetched_cfg["modelDtype"].as_str(), Some("int8"));

    let stored_cfg: Option<Json<MemoryConfig>> =
        sqlx::query_scalar("SELECT memory_config FROM public.app_user_profile WHERE user_id = $1")
            .bind(sub)
            .fetch_optional(&pool)
            .await
            .expect("select memory_config");
    let stored_cfg = stored_cfg.expect("stored memory_config").0;
    assert_eq!(stored_cfg.messages_per_summary, 12);
    assert_eq!(stored_cfg.model_dtype, "int8");

    for body in [
        format!(
            r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7,"role":"user","content":"episode scoped memory"}}"#
        ),
        format!(
            r#"{{"projectId":{project_id},"agentType":"scriptAgent","role":"assistant","content":"project scoped memory"}}"#
        ),
    ] {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/agents/memory/append")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(body))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, appended) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "appended={appended}");
        assert!(appended["id"].as_str().is_some());
        assert_eq!(appended["scope"].as_str(), Some("user"));
    }

    sqlx::query(
        r#"
        INSERT INTO public.app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'scriptAgent', 'summary', 'assistant', 'auto_scope_memory', 'episode scoped summary', 1, 1)
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .bind(7_i32)
    .execute(&pool)
    .await
    .expect("insert summary memory");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "episode_memory={episode_memory}");
    assert_eq!(episode_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(episode_memory[0]["scope"].as_str(), Some("user"));
    assert_eq!(
        episode_memory[0]["content"][0]["data"].as_str(),
        Some("episode scoped memory")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7,"memoryType":"summary"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_summary_memory) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "episode_summary_memory={episode_summary_memory}"
    );
    assert_eq!(episode_summary_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(episode_summary_memory[0]["scope"].as_str(), Some("user"));
    assert_eq!(
        episode_summary_memory[0]["content"][0]["data"].as_str(),
        Some("episode scoped summary")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7,"memoryType":"all"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_all_memory) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "episode_all_memory={episode_all_memory}"
    );
    assert_eq!(episode_all_memory.as_array().map(|a| a.len()), Some(2));
    assert_eq!(episode_all_memory[0]["scope"].as_str(), Some("user"));
    assert_eq!(episode_all_memory[1]["scope"].as_str(), Some("user"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/settings/memory-config/clear-agent-memories")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "cleared={cleared}");
    assert_eq!(cleared["ok"].as_bool(), Some(true));
    assert_eq!(cleared["scope"].as_str(), Some("user"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","episodesId":7}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, episode_memory_after_clear) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "episode_memory_after_clear={episode_memory_after_clear}"
    );
    assert_eq!(
        episode_memory_after_clear.as_array().map(|a| a.len()),
        Some(0)
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
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
    let (status, project_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "project_memory={project_memory}");
    assert_eq!(project_memory.as_array().map(|a| a.len()), Some(1));
    assert_eq!(
        project_memory[0]["content"][0]["data"].as_str(),
        Some("project scoped memory")
    );

    sqlx::query(
        r#"
        INSERT INTO public.app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms, memory_tier, scope_signature
        )
        VALUES
          ($1, $2, NULL, 'scriptAgent', 'message', 'assistant', 'scene_memory_a', 'scene A exact memory', 0, 11, 'delta_memory', '{"storyboardIds":[11]}'::jsonb),
          ($1, $2, NULL, 'scriptAgent', 'message', 'assistant', 'scene_memory_b', 'scene B unrelated memory', 0, 12, 'delta_memory', '{"storyboardIds":[12]}'::jsonb),
          ($1, $2, NULL, 'scriptAgent', 'summary', 'assistant', 'project_stage_summary', 'project stage summary survives message clear', 1, 13, 'stage_summary', '{"episodeId":9}'::jsonb)
        "#,
    )
    .bind(sub)
    .bind(project_id)
    .execute(&pool)
    .await
    .expect("insert scoped test memories");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","memoryType":"all","scopeSignature":{{"storyboardIds":[11]}}}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, scoped_memory) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "scoped_memory={scoped_memory}");
    let scoped_memory = scoped_memory.as_array().expect("scoped_memory list");
    assert_eq!(scoped_memory.len(), 1);
    assert_eq!(scoped_memory[0]["scope"].as_str(), Some("user"));
    assert_eq!(
        scoped_memory[0]["content"][0]["data"].as_str(),
        Some("scene A exact memory")
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/clear")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","clearType":"message"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cleared_messages) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "cleared_messages={cleared_messages}"
    );
    assert_eq!(cleared_messages["ok"].as_bool(), Some(true));
    assert_eq!(cleared_messages["scope"].as_str(), Some("user"));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/agents/memory/query")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"projectId":{project_id},"agentType":"scriptAgent","memoryType":"summary"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, summary_after_message_clear) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "summary_after_message_clear={summary_after_message_clear}"
    );
    let summary_after_message_clear = summary_after_message_clear
        .as_array()
        .expect("summary_after_message_clear list");
    assert!(
        summary_after_message_clear.iter().any(|row| {
            row["content"][0]["data"].as_str()
                == Some("project stage summary survives message clear")
        }),
        "summary memory should survive message clear: {summary_after_message_clear:?}"
    );

    let _ = sqlx::query(
        "DELETE FROM public.app_agent_memory WHERE owner_user_id = $1 AND numeric_project_id = $2",
    )
    .bind(sub)
    .bind(project_id)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE numeric_id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await;
}
