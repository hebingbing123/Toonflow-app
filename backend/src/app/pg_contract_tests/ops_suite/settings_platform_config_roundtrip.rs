use super::super::*;
use futures_util::FutureExt;
use tower::ServiceExt;

static PLATFORM_CONFIG_ENV_MUTEX: std::sync::OnceLock<std::sync::Mutex<()>> =
    std::sync::OnceLock::new();

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test settings_platform_config_roundtrip -- --ignored"]
#[allow(clippy::await_holding_lock)] // std mutex serializes env overrides for this ignored DB test.
async fn settings_platform_config_roundtrip() {
    let _ = dotenvy::dotenv();
    let _env_guard = PLATFORM_CONFIG_ENV_MUTEX
        .get_or_init(|| std::sync::Mutex::new(()))
        .lock()
        .expect("platform config env mutex");
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let previous_plan_env = std::env::var("TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON").ok();
    std::env::set_var(
        "TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON",
        r#"{
          "enterprise": {
            "helpHubEnabled": false,
            "qualityDashboardEnabled": false,
            "qualityRefreshControlsEnabled": false,
            "workspaceActivityEnabled": false,
            "benchmarkPaneEnabled": true,
            "jobsPaneEnabled": true
          }
        }"#,
    );

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let me_res = app
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
    let (me_status, me_body) = read_json_response(me_res).await;
    assert_eq!(me_status, StatusCode::OK, "me={me_body}");
    let personal_workspace_id = Uuid::parse_str(
        me_body["current_workspace"]["id"]
            .as_str()
            .expect("personal current workspace id"),
    )
    .expect("parse personal workspace uuid");

    let enterprise_workspace_id = Uuid::new_v4();
    let enterprise_name = format!("pg-platform-config-{}", enterprise_workspace_id);

    let test_result = std::panic::AssertUnwindSafe(async {
        sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
            .bind(enterprise_workspace_id)
            .execute(&pool)
            .await
            .expect("cleanup stale enterprise workspace");

        sqlx::query(
            r#"
            INSERT INTO public.app_workspace (
              id, owner_user_id, name, workspace_type, metadata
            )
            VALUES ($1, $2, $3, 'enterprise', $4)
            "#,
        )
        .bind(enterprise_workspace_id)
        .bind(sub)
        .bind(&enterprise_name)
        .bind(Json(serde_json::json!({
            "platform_config": {
                "helpHubEnabled": true,
                "qualityDashboardEnabled": true,
                "qualityRefreshControlsEnabled": true,
                "workspaceActivityEnabled": true,
                "benchmarkPaneEnabled": true,
                "jobsPaneEnabled": false
            }
        })))
        .execute(&pool)
        .await
        .expect("insert enterprise workspace");

        sqlx::query(
            r#"
            INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'owner')
            ON CONFLICT (workspace_id, user_id) DO UPDATE
            SET role = 'owner', updated_at = NOW()
            "#,
        )
        .bind(enterprise_workspace_id)
        .bind(sub)
        .execute(&pool)
        .await
        .expect("insert enterprise workspace owner membership");

        sqlx::query(
            r#"
            INSERT INTO public.app_user_profile (
              user_id, plan_tier, current_workspace_id, platform_config, updated_at
            )
            VALUES ($1, 'enterprise', $2, $3, NOW())
            ON CONFLICT (user_id) DO UPDATE SET
              plan_tier = 'enterprise',
              current_workspace_id = EXCLUDED.current_workspace_id,
              platform_config = EXCLUDED.platform_config,
              updated_at = NOW()
            "#,
        )
        .bind(sub)
        .bind(enterprise_workspace_id)
        .bind(Json(serde_json::json!({
            "helpHubEnabled": true,
            "qualityDashboardEnabled": true,
            "qualityRefreshControlsEnabled": true,
            "workspaceActivityEnabled": false,
            "benchmarkPaneEnabled": false,
            "jobsPaneEnabled": false
        })))
        .execute(&pool)
        .await
        .expect("seed user platform config");

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/v1/settings/platform-config")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, body) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "initial platform config={body}");
        let expected_workspace_id = enterprise_workspace_id.to_string();
        assert_eq!(body["scope"].as_str(), Some("plan+workspace+user"));
        assert_eq!(body["planTier"].as_str(), Some("enterprise"));
        assert_eq!(body["hasPlanOverride"].as_bool(), Some(true));
        assert_eq!(body["hasWorkspaceOverride"].as_bool(), Some(true));
        assert_eq!(body["hasUserOverride"].as_bool(), Some(true));
        assert_eq!(
            body["currentWorkspace"]["id"].as_str(),
            Some(expected_workspace_id.as_str())
        );
        assert_eq!(
            body["effective"]["workspaceActivityEnabled"].as_bool(),
            Some(false)
        );
        assert_eq!(
            body["effective"]["benchmarkPaneEnabled"].as_bool(),
            Some(false)
        );
        assert_eq!(body["effective"]["jobsPaneEnabled"].as_bool(), Some(false));

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/platform-config")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"scope":"user","reset":true}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, reset_user) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "reset_user={reset_user}");
        assert_eq!(reset_user["scope"].as_str(), Some("plan+workspace"));
        assert_eq!(reset_user["hasUserOverride"].as_bool(), Some(false));
        assert_eq!(
            reset_user["effective"]["workspaceActivityEnabled"].as_bool(),
            Some(true)
        );
        assert_eq!(
            reset_user["effective"]["jobsPaneEnabled"].as_bool(),
            Some(false)
        );

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .method(Method::POST)
                    .uri("/api/v1/settings/platform-config")
                    .header(header::AUTHORIZATION, format!("Bearer {token}"))
                    .header(header::CONTENT_TYPE, "application/json")
                    .extension(ConnectInfo(test_addr()))
                    .body(Body::from(r#"{"scope":"workspace","reset":true}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let (status, reset_workspace) = read_json_response(res).await;
        assert_eq!(status, StatusCode::OK, "reset_workspace={reset_workspace}");
        assert_eq!(reset_workspace["scope"].as_str(), Some("plan"));
        assert_eq!(
            reset_workspace["hasWorkspaceOverride"].as_bool(),
            Some(false)
        );
        assert_eq!(reset_workspace["hasPlanOverride"].as_bool(), Some(true));
        assert_eq!(
            reset_workspace["effective"]["helpHubEnabled"].as_bool(),
            Some(false)
        );
        assert_eq!(
            reset_workspace["effective"]["qualityDashboardEnabled"].as_bool(),
            Some(false)
        );
        assert_eq!(
            reset_workspace["effective"]["benchmarkPaneEnabled"].as_bool(),
            Some(true)
        );
        assert_eq!(
            reset_workspace["effective"]["jobsPaneEnabled"].as_bool(),
            Some(true)
        );

        let stored_profile: Option<(Option<Json<serde_json::Value>>, String, Option<Uuid>)> =
            sqlx::query_as(
                r#"
                SELECT platform_config, plan_tier, current_workspace_id
                FROM public.app_user_profile
                WHERE user_id = $1
                "#,
            )
            .bind(sub)
            .fetch_optional(&pool)
            .await
            .expect("select user profile");
        let stored_profile = stored_profile.expect("stored profile row");
        assert!(
            stored_profile.0.is_none(),
            "user platform config should be cleared"
        );
        assert_eq!(stored_profile.1.as_str(), "enterprise");
        assert_eq!(stored_profile.2, Some(enterprise_workspace_id));

        let stored_workspace_metadata: Option<Json<serde_json::Value>> =
            sqlx::query_scalar("SELECT metadata FROM public.app_workspace WHERE id = $1")
                .bind(enterprise_workspace_id)
                .fetch_optional(&pool)
                .await
                .expect("select workspace metadata");
        let stored_workspace_metadata = stored_workspace_metadata
            .expect("stored workspace metadata")
            .0;
        assert!(
            stored_workspace_metadata
                .as_object()
                .and_then(|obj| obj.get("platform_config"))
                .is_none(),
            "workspace platform_config should be removed after reset"
        );
    })
    .catch_unwind()
    .await;

    sqlx::query(
        r#"
        UPDATE public.app_user_profile
        SET current_workspace_id = $2, plan_tier = 'free', platform_config = NULL, updated_at = NOW()
        WHERE user_id = $1
        "#,
    )
    .bind(sub)
    .bind(personal_workspace_id)
    .execute(&pool)
    .await
    .expect("restore user profile");
    sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(enterprise_workspace_id)
        .execute(&pool)
        .await
        .expect("delete enterprise workspace");
    match previous_plan_env {
        Some(value) => std::env::set_var("TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON", value),
        None => std::env::remove_var("TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON"),
    }

    if let Err(panic) = test_result {
        std::panic::resume_unwind(panic);
    }
}
