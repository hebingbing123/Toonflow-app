//! Job creation workspace attribution contract.
//!
//! Covers workspace-scope billing Task 9.1 scenarios for
//! `app_generation_job.workspace_id` assignment during job creation.

use super::super::*;
use serde_json::json;

async fn ensure_auth_user(pool: &PgPool, user_id: Uuid) {
    sqlx::query(
        r#"
        INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
        VALUES ($1, $2, 'contract-test-password', NOW(), NOW(), NOW())
        ON CONFLICT (id) DO NOTHING
        "#,
    )
    .bind(user_id)
    .bind(format!("job-workspace-{user_id}@example.com"))
    .execute(pool)
    .await
    .expect("ensure auth user");

    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, plan_tier)
        VALUES ($1, 'free')
        ON CONFLICT (user_id) DO UPDATE
        SET plan_tier = EXCLUDED.plan_tier, updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .execute(pool)
    .await
    .expect("ensure app_user_profile");
}

async fn create_workspace(
    pool: &PgPool,
    owner_user_id: Uuid,
    name: &str,
    archived: bool,
    add_member: bool,
) -> Uuid {
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (
          id, owner_user_id, name, workspace_type, archived_at, created_at, updated_at
        )
        VALUES ($1, $2, $3, 'enterprise', $4, NOW(), NOW())
        "#,
    )
    .bind(workspace_id)
    .bind(owner_user_id)
    .bind(name)
    .bind(if archived {
        Some(chrono::Utc::now())
    } else {
        None
    })
    .execute(pool)
    .await
    .expect("create workspace");

    if add_member {
        sqlx::query(
            r#"
            INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'owner')
            ON CONFLICT (workspace_id, user_id) DO NOTHING
            "#,
        )
        .bind(workspace_id)
        .bind(owner_user_id)
        .execute(pool)
        .await
        .expect("create workspace membership");
    }

    workspace_id
}

async fn set_current_workspace(pool: &PgPool, user_id: Uuid, workspace_id: Option<Uuid>) {
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id)
        VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE
        SET current_workspace_id = EXCLUDED.current_workspace_id, updated_at = NOW()
        "#,
    )
    .bind(user_id)
    .bind(workspace_id)
    .execute(pool)
    .await
    .expect("set current workspace");
}

async fn create_project(pool: &PgPool, owner_user_id: Uuid, workspace_id: Uuid) -> (Uuid, i32) {
    let project_id = Uuid::new_v4();
    let numeric_id = 1_900_000_000 + (Uuid::new_v4().as_u128() % 100_000_000) as i32;

    sqlx::query(
        r#"
        INSERT INTO public.app_project (
          id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, 'PG Workspace Attribution Project', NOW(), NOW())
        "#,
    )
    .bind(project_id)
    .bind(numeric_id)
    .bind(workspace_id)
    .bind(owner_user_id)
    .execute(pool)
    .await
    .expect("create project");

    (project_id, numeric_id)
}

async fn create_job_and_load_workspace(
    app: axum::Router,
    pool: &PgPool,
    token: &str,
    payload: serde_json::Value,
) -> (Uuid, Uuid) {
    let res = app
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .header("Idempotency-Key", format!("pg-job-ws-{}", Uuid::new_v4()))
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(
                    json!({
                        "kind": JOB_KIND_ASSET_GENERATE_IMAGE,
                        "payload": payload
                    })
                    .to_string(),
                ))
                .unwrap(),
        )
        .await
        .unwrap();

    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "create job: {body}");

    let job_id = Uuid::parse_str(body["id"].as_str().expect("job id")).expect("parse job id");
    let workspace_id: Uuid =
        sqlx::query_scalar("SELECT workspace_id FROM public.app_generation_job WHERE id = $1")
            .bind(job_id)
            .fetch_one(pool)
            .await
            .expect("load job workspace_id");

    (job_id, workspace_id)
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test job_workspace_attribution_roundtrip -- --ignored"]
async fn job_workspace_attribution_roundtrip() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let user_id = Uuid::new_v4();
    ensure_auth_user(&pool, user_id).await;
    let token = jwt_fixture::encode_supabase_style(user_id, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    let current_workspace =
        create_workspace(&pool, user_id, "PG Current Workspace", false, true).await;
    let project_workspace =
        create_workspace(&pool, user_id, "PG Project Workspace", false, true).await;
    let archived_workspace =
        create_workspace(&pool, user_id, "PG Archived Workspace", true, true).await;
    let invalid_member_workspace =
        create_workspace(&pool, user_id, "PG Invalid Member Workspace", false, false).await;
    let (project_id, _project_numeric_id) = create_project(&pool, user_id, project_workspace).await;

    let mut created_job_ids = Vec::new();

    set_current_workspace(&pool, user_id, Some(current_workspace)).await;
    let (job_id, workspace_id) = create_job_and_load_workspace(
        app.clone(),
        &pool,
        &token,
        json!({ "project_uuid": project_id.to_string(), "reason": "project_context" }),
    )
    .await;
    created_job_ids.push(job_id);
    assert_eq!(
        workspace_id, project_workspace,
        "project-based jobs should use the project's workspace_id"
    );

    let (job_id, workspace_id) = create_job_and_load_workspace(
        app.clone(),
        &pool,
        &token,
        json!({ "reason": "current_workspace_context" }),
    )
    .await;
    created_job_ids.push(job_id);
    assert_eq!(
        workspace_id, current_workspace,
        "non-project jobs should use a valid current_workspace_id"
    );

    set_current_workspace(&pool, user_id, None).await;
    let (job_id, workspace_id) = create_job_and_load_workspace(
        app.clone(),
        &pool,
        &token,
        json!({ "reason": "personal_workspace_context" }),
    )
    .await;
    created_job_ids.push(job_id);
    let personal_workspace_id: Uuid = sqlx::query_scalar(
        r#"
        SELECT id
        FROM public.app_workspace
        WHERE owner_user_id = $1 AND workspace_type = 'personal'
        ORDER BY created_at ASC, id ASC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .expect("load personal workspace");
    assert_eq!(
        workspace_id, personal_workspace_id,
        "non-project jobs without current_workspace_id should use personal workspace"
    );

    set_current_workspace(&pool, user_id, Some(archived_workspace)).await;
    let (job_id, workspace_id) = create_job_and_load_workspace(
        app.clone(),
        &pool,
        &token,
        json!({ "reason": "archived_current_workspace" }),
    )
    .await;
    created_job_ids.push(job_id);
    assert_eq!(
        workspace_id, personal_workspace_id,
        "archived current workspaces should fall back to personal workspace"
    );

    set_current_workspace(&pool, user_id, Some(invalid_member_workspace)).await;
    let (job_id, workspace_id) = create_job_and_load_workspace(
        app.clone(),
        &pool,
        &token,
        json!({ "reason": "invalid_current_workspace_membership" }),
    )
    .await;
    created_job_ids.push(job_id);
    assert_eq!(
        workspace_id, personal_workspace_id,
        "current workspaces without membership should fall back to personal workspace"
    );

    cleanup_jobs(&pool, &created_job_ids).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE user_id = $1")
        .bind(user_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE owner_user_id = $1")
        .bind(user_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = $1")
        .bind(user_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = $1")
        .bind(user_id)
        .execute(&pool)
        .await;
}
