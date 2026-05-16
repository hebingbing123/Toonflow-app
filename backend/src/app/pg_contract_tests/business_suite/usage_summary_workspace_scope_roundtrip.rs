//! Workspace-scoped usage summary (`GET /api/v1/usage/summary?scope=workspace`).
//!
//! Covers Task 7.2 manual checklist: happy path, invalid scope, missing workspace
//! context, and non-member forbidden.

use super::super::*;
use std::sync::OnceLock;
use tower::ServiceExt;

const OUTSIDER_SUB: &str = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const TEST_EVENT_TYPE: &str = "pg_contract.usage_summary_workspace_scope";
static USAGE_SUMMARY_TEST_MUTEX: OnceLock<tokio::sync::Mutex<()>> = OnceLock::new();

struct EnvVarGuard {
    key: &'static str,
    prev: Option<std::ffi::OsString>,
}

impl Drop for EnvVarGuard {
    fn drop(&mut self) {
        match self.prev.take() {
            Some(value) => std::env::set_var(self.key, value),
            None => std::env::remove_var(self.key),
        }
    }
}

fn set_env_var_for_test(key: &'static str, value: &str) -> EnvVarGuard {
    let prev = std::env::var_os(key);
    std::env::set_var(key, value);
    EnvVarGuard { key, prev }
}

async fn usage_summary_test_lock() -> tokio::sync::MutexGuard<'static, ()> {
    USAGE_SUMMARY_TEST_MUTEX
        .get_or_init(|| tokio::sync::Mutex::new(()))
        .lock()
        .await
}

async fn ensure_outsider_user(pool: &PgPool) {
    let id = Uuid::parse_str(OUTSIDER_SUB).unwrap();
    sqlx::query(
        r#"
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
        VALUES ($1, 'outsider-contract@example.com', 'contract-test-password', NOW(), NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(id)
    .execute(pool)
    .await
    .expect("ensure outsider auth.users");

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, plan_tier)
        VALUES ($1, 'free')
        ON CONFLICT (user_id) DO NOTHING
        "#,
    )
    .bind(id)
    .execute(pool)
    .await
    .expect("ensure outsider app_user_profile");
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test usage_summary_workspace_scope_contract -- --ignored"]
async fn usage_summary_workspace_scope_contract() {
    let _lock = usage_summary_test_lock().await;
    let _ = dotenvy::dotenv();
    let _workspace_billing_guard = set_env_var_for_test("WORKSPACE_BILLING_ENABLED", "true");
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    ensure_contract_auth_user(&pool).await;
    ensure_outsider_user(&pool).await;

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret.clone()));

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/workspaces")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"name":"PG Usage Summary WS"}"#))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, created) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create workspace: {created}");
    let workspace_id = created["id"].as_str().expect("workspace id").to_string();
    let workspace_uuid = Uuid::parse_str(&workspace_id).expect("uuid");

    sqlx::query(
        r#"
        UPDATE public.app_workspace
        SET plan_tier = 'pro', daily_job_quota = 100
        WHERE id = $1
        "#,
    )
    .bind(workspace_uuid)
    .execute(&pool)
    .await
    .expect("enable workspace billing fixture");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri("/api/v1/me/current-workspace")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(format!(
                    r#"{{"workspace_id":"{workspace_id}"}}"#
                )))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, switched) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "switch current workspace: {switched}"
    );

    sqlx::query(
        r#"
        INSERT INTO public.app_usage_event (user_id, event_type, payload)
        VALUES ($1, $2, '{}'::jsonb)
        "#,
    )
    .bind(sub)
    .bind(TEST_EVENT_TYPE)
    .execute(&pool)
    .await
    .expect("seed usage event 1");

    sqlx::query(
        r#"
        INSERT INTO public.app_usage_event (user_id, event_type, payload)
        VALUES ($1, $2, '{}'::jsonb)
        "#,
    )
    .bind(sub)
    .bind(TEST_EVENT_TYPE)
    .execute(&pool)
    .await
    .expect("seed usage event 2");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "usage summary user: {body}");
    assert_eq!(body["scope"].as_str(), Some("user"));
    assert!(
        body.get("workspace_id").is_none(),
        "user scope should omit workspace_id: {body}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary?scope=workspace")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "usage summary workspace: {body}");
    assert_eq!(body["scope"].as_str(), Some("workspace"));
    assert_eq!(body["workspace_id"].as_str(), Some(workspace_id.as_str()));
    assert!(
        body["workspace_name"].as_str().is_some(),
        "workspace_name present: {body}"
    );
    assert!(
        body["events_last_7d"].as_i64().unwrap_or(0) >= 2,
        "aggregate 7d should include seeded rows: {body}"
    );
    assert!(
        body["event_counts_last_7d"][TEST_EVENT_TYPE]
            .as_i64()
            .unwrap_or(0)
            >= 2,
        "event breakdown should include seeded rows: {body}"
    );

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary?scope=not_a_scope")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::BAD_REQUEST, "invalid scope: {body}");

    sqlx::query(
        "UPDATE public.app_user_profile SET current_workspace_id = NULL WHERE user_id = $1",
    )
    .bind(sub)
    .execute(&pool)
    .await
    .expect("clear current workspace");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary?scope=workspace")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::BAD_REQUEST,
        "workspace scope without context: {body}"
    );

    let outsider = Uuid::parse_str(OUTSIDER_SUB).unwrap();
    sqlx::query("UPDATE public.app_user_profile SET current_workspace_id = $1 WHERE user_id = $2")
        .bind(workspace_uuid)
        .bind(outsider)
        .execute(&pool)
        .await
        .expect("point outsider at workspace without membership");

    let outsider_token = jwt_fixture::encode_supabase_style(outsider, secret.as_bytes());
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/usage/summary?scope=workspace")
                .header(header::AUTHORIZATION, format!("Bearer {outsider_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::FORBIDDEN, "non-member: {body}");

    let _ =
        sqlx::query("DELETE FROM public.app_usage_event WHERE user_id = $1 AND event_type = $2")
            .bind(sub)
            .bind(TEST_EVENT_TYPE)
            .execute(&pool)
            .await;
    let _ = sqlx::query(
        "UPDATE public.app_user_profile SET current_workspace_id = NULL WHERE user_id = $1",
    )
    .bind(outsider)
    .execute(&pool)
    .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_uuid)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_uuid)
        .execute(&pool)
        .await;
}
