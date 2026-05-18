//! WP-A: 「登录上下文 → 建项 → 工作台驾驶舱曲面」契约链（可选 DB）。
//!
//! 与 `projects_create_stats_roundtrip` 拆分：本子模块只断言 **dashboard 相关端点统计口径一致**，
//! 不覆盖长篇资产/novel REST 矩阵。

use super::*;

fn five_counts(stats: &Value) -> (i64, i64, i64, i64, i64) {
    (
        stats["script_count"].as_i64().expect("script_count"),
        stats["storyboard_count"]
            .as_i64()
            .expect("storyboard_count"),
        stats["role_count"].as_i64().expect("role_count"),
        stats["novel_count"].as_i64().expect("novel_count"),
        stats["video_count"].as_i64().expect("video_count"),
    )
}

fn assert_launch_intent(path: &str, intent: &Value) {
    assert!(
        intent.is_object(),
        "{path} should exist as an object: {intent}"
    );
    let has_route = ["action", "target_step", "agent_kind", "asset_target"]
        .iter()
        .any(|key| {
            intent[*key]
                .as_str()
                .is_some_and(|value| !value.trim().is_empty())
        });
    assert!(
        has_route,
        "{path} should include action, target_step, agent_kind, or asset_target: {intent}"
    );
}

fn assert_home_cockpit_launch_intents(home: &Value) {
    assert_launch_intent(
        "home.cockpit.primary_action.launch_intent",
        &home["cockpit"]["primary_action"]["launch_intent"],
    );
    for (index, action) in home["cockpit"]["secondary_actions"]
        .as_array()
        .into_iter()
        .flatten()
        .enumerate()
    {
        assert_launch_intent(
            &format!("home.cockpit.secondary_actions[{index}].launch_intent"),
            &action["launch_intent"],
        );
    }
    for (index, metric) in home["cockpit"]["metrics"]
        .as_array()
        .into_iter()
        .flatten()
        .enumerate()
    {
        assert_launch_intent(
            &format!("home.cockpit.metrics[{index}].launch_intent"),
            &metric["launch_intent"],
        );
    }
    for (index, starter) in home["cockpit"]["starter_templates"]
        .as_array()
        .into_iter()
        .flatten()
        .enumerate()
    {
        assert_launch_intent(
            &format!("home.cockpit.starter_templates[{index}].launch_intent"),
            &starter["launch_intent"],
        );
    }
}

fn assert_assets_hub_launch_intents(assets_overview: &Value) {
    assert_launch_intent(
        "assets_overview.hub.primary_action.launch_intent",
        &assets_overview["hub"]["primary_action"]["launch_intent"],
    );
    for (index, metric) in assets_overview["hub"]["metrics"]
        .as_array()
        .into_iter()
        .flatten()
        .enumerate()
    {
        assert_launch_intent(
            &format!("assets_overview.hub.metrics[{index}].launch_intent"),
            &metric["launch_intent"],
        );
    }
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test project_dashboard_surface_roundtrip -- --ignored"]
async fn project_dashboard_triple_sources_stats_alignment() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    let pool_sql = pool.clone();
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool, secret.clone()));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, me) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "me={me}");
    assert!(
        me["current_workspace"]["id"].is_string(),
        "expected current_workspace.id for logged-in harness user: {me}"
    );

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
    let project_uuid = created["id"].as_str().expect("project uuid").to_owned();
    let project_id = Uuid::parse_str(&project_uuid).expect("project uuid parse");

    let fetch_stats_bundle = || async {
        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/{project_uuid}/stats"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (st, stats) = read_json_response(res).await;
        assert_eq!(st, StatusCode::OK, "stats={stats}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/{project_uuid}/home"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (ht, home) = read_json_response(res).await;
        assert_eq!(ht, StatusCode::OK, "home={home}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/{project_uuid}/overview"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (ot, overview) = read_json_response(res).await;
        assert_eq!(ot, StatusCode::OK, "overview={overview}");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/v1/projects/{project_uuid}/assets-overview"))
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (at, assets_overview) = read_json_response(res).await;
        assert_eq!(at, StatusCode::OK, "assets_overview={assets_overview}");

        (stats, home, overview, assets_overview)
    };

    let (stats0, home0, overview0, assets_overview0) = fetch_stats_bundle().await;
    assert_eq!(
        five_counts(&stats0),
        five_counts(&home0["stats"]),
        "home.stats must mirror GET …/stats (baseline)"
    );
    assert!(
        home0["cockpit"]["primary_action"]["target_step"].is_string(),
        "home.cockpit.primary_action.target_step should exist: {home0}"
    );
    assert_home_cockpit_launch_intents(&home0);
    assert_eq!(
        five_counts(&stats0),
        five_counts(&overview0["stats"]),
        "overview.stats must mirror GET …/stats (baseline)"
    );
    assert_assets_hub_launch_intents(&assets_overview0);
    assert_eq!(five_counts(&stats0), (0, 0, 0, 0, 0));

    let video_numeric_id: i32 =
        sqlx::query_scalar("SELECT COALESCE(MAX(numeric_id), 0) + 1 FROM app_video")
            .fetch_one(&pool_sql)
            .await
            .expect("allocate app_video.numeric_id for WP-A dashboard parity");
    let ins = sqlx::query(
        r#"
        INSERT INTO app_video (project_id, numeric_id, state)
        VALUES ($1, $2, 'succeeded')
        "#,
    )
    .bind(project_id)
    .bind(video_numeric_id)
    .execute(&pool_sql)
    .await
    .expect("insert app_video for WP-A dashboard parity");
    assert_eq!(ins.rows_affected(), 1);

    let (stats1, home1, overview1, assets_overview1) = fetch_stats_bundle().await;
    assert_eq!(
        five_counts(&stats1),
        (0, 0, 0, 0, 1),
        "stats after completed app_video"
    );
    assert_eq!(
        five_counts(&stats1),
        five_counts(&home1["stats"]),
        "home.stats must mirror GET …/stats (after video)"
    );
    assert_eq!(
        five_counts(&stats1),
        five_counts(&overview1["stats"]),
        "overview.stats must mirror GET …/stats (after video)"
    );
    assert_home_cockpit_launch_intents(&home1);
    assert_assets_hub_launch_intents(&assets_overview1);

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NO_CONTENT);
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test project_dashboard_surface_roundtrip -- --ignored"]
async fn me_then_create_project_lists_under_current_workspace_filter() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");
    ensure_contract_auth_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, me) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "me={me}");
    let ws_id = me["current_workspace"]["id"]
        .as_str()
        .expect("current_workspace id")
        .to_owned();

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
    assert_eq!(status, StatusCode::CREATED);
    let project_uuid = created["id"].as_str().expect("id").to_owned();
    assert_eq!(
        created["workspace_id"].as_str(),
        Some(ws_id.as_str()),
        "new project inherits current workspace view"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/projects?limit=5&offset=0")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, list_raw) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "list={list_raw}");
    let list_items = list_raw
        .as_array()
        .expect("GET …/projects returns array body");
    assert!(
        list_items
            .iter()
            .any(|row| row["id"].as_str() == Some(project_uuid.as_str())),
        "list should include freshly created row: uuid={project_uuid} list_len={}",
        list_items.len()
    );

    let res = app
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{project_uuid}"))
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    assert_eq!(res.status(), StatusCode::NO_CONTENT);
}
