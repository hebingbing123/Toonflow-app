//! Integration tests for jobs workspace visibility (W2.2)
//!
//! Tests that jobs are filtered by workspace membership:
//! - Owner can see their own jobs
//! - Workspace members can see jobs from projects in their workspace
//! - Non-members cannot see jobs from workspaces they don't belong to

use super::super::*;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_page_workspace_visibility_owner_and_member() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create owner user
    let owner_id = Uuid::new_v4();
    let owner_email = format!("owner-{}@test.com", owner_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(owner_id)
    .bind(&owner_email)
    .execute(&pool)
    .await
    .expect("create owner user");

    // Create member user
    let member_id = Uuid::new_v4();
    let member_email = format!("member-{}@test.com", member_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(member_id)
    .bind(&member_email)
    .execute(&pool)
    .await
    .expect("create member user");

    // Create outsider user
    let outsider_id = Uuid::new_v4();
    let outsider_email = format!("outsider-{}@test.com", outsider_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(outsider_id)
    .bind(&outsider_email)
    .execute(&pool)
    .await
    .expect("create outsider user");

    // Create enterprise workspace
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, created_at, updated_at) 
         VALUES ($1, $2, $3, 'enterprise', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Workspace")
    .execute(&pool)
    .await
    .expect("create workspace");

    // Add owner as workspace owner
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'owner', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("add owner to workspace");

    // Add member as workspace member
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'member', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(member_id)
    .execute(&pool)
    .await
    .expect("add member to workspace");

    // Create project in workspace
    let project_id = Uuid::new_v4();
    let project_numeric_id = ((Uuid::new_v4().as_u128() % 900_000) as i32) + 1_000;
    sqlx::query(
        "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
    )
    .bind(project_id)
    .bind(project_numeric_id)
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Project")
    .execute(&pool)
    .await
    .expect("create project");

    // Create job with project_uuid in payload
    let job_with_uuid_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(job_with_uuid_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create job with project_uuid");

    // Create job with project_numeric_id in payload
    let job_with_numeric_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(job_with_numeric_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_numeric_id": project_numeric_id,
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create job with project_numeric_id");

    // Create job with both project_uuid and project_numeric_id
    let job_with_both_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(job_with_both_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "project_numeric_id": project_numeric_id,
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create job with both ids");

    // Create job without project info (personal job)
    let personal_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.personal', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(personal_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({"note": "personal job"}))
    .execute(&pool)
    .await
    .expect("create personal job");

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let member_token = jwt_fixture::encode_supabase_style(member_id, secret.as_bytes());
    let outsider_token = jwt_fixture::encode_supabase_style(outsider_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // Test 1: Owner can see all their jobs (project jobs + personal jobs)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=100")
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, owner_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "owner_jobs={owner_jobs}");
    let owner_jobs_data = owner_jobs["data"].as_array().expect("owner jobs data");
    let owner_job_ids: Vec<String> = owner_jobs_data
        .iter()
        .map(|j| j["id"].as_str().unwrap().to_string())
        .collect();
    assert!(
        owner_job_ids.contains(&job_with_uuid_id.to_string()),
        "Owner should see job with project_uuid"
    );
    assert!(
        owner_job_ids.contains(&job_with_numeric_id.to_string()),
        "Owner should see job with project_numeric_id"
    );
    assert!(
        owner_job_ids.contains(&job_with_both_id.to_string()),
        "Owner should see job with both ids"
    );
    assert!(
        owner_job_ids.contains(&personal_job_id.to_string()),
        "Owner should see personal job"
    );

    // Test 2: Member can see workspace project jobs but not personal jobs
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=100")
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, member_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "member_jobs={member_jobs}");
    let member_jobs_data = member_jobs["data"].as_array().expect("member jobs data");
    let member_job_ids: Vec<String> = member_jobs_data
        .iter()
        .map(|j| j["id"].as_str().unwrap().to_string())
        .collect();
    assert!(
        member_job_ids.contains(&job_with_uuid_id.to_string()),
        "Member should see job with project_uuid"
    );
    assert!(
        member_job_ids.contains(&job_with_numeric_id.to_string()),
        "Member should see job with project_numeric_id"
    );
    assert!(
        member_job_ids.contains(&job_with_both_id.to_string()),
        "Member should see job with both ids"
    );
    assert!(
        !member_job_ids.contains(&personal_job_id.to_string()),
        "Member should NOT see owner's personal job"
    );

    // Test 3: Outsider cannot see any workspace jobs
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=100")
                .header(header::AUTHORIZATION, format!("Bearer {outsider_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, outsider_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "outsider_jobs={outsider_jobs}");
    let outsider_jobs_data = outsider_jobs["data"]
        .as_array()
        .expect("outsider jobs data");
    let outsider_job_ids: Vec<String> = outsider_jobs_data
        .iter()
        .map(|j| j["id"].as_str().unwrap().to_string())
        .collect();
    assert!(
        !outsider_job_ids.contains(&job_with_uuid_id.to_string()),
        "Outsider should NOT see job with project_uuid"
    );
    assert!(
        !outsider_job_ids.contains(&job_with_numeric_id.to_string()),
        "Outsider should NOT see job with project_numeric_id"
    );
    assert!(
        !outsider_job_ids.contains(&job_with_both_id.to_string()),
        "Outsider should NOT see job with both ids"
    );
    assert!(
        !outsider_job_ids.contains(&personal_job_id.to_string()),
        "Outsider should NOT see owner's personal job"
    );

    // Test 4: Filter by project_id - member can access
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/page?page=1&limit=100&project_id={project_numeric_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, filtered_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "filtered_jobs={filtered_jobs}");
    let filtered_jobs_data = filtered_jobs["data"]
        .as_array()
        .expect("filtered jobs data");
    assert!(
        filtered_jobs_data.len() >= 2,
        "Should see at least jobs with project_numeric_id"
    );

    // Test 5: Filter by project_id - outsider gets 404
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!(
                    "/api/v1/jobs/page?page=1&limit=100&project_id={project_numeric_id}"
                ))
                .header(header::AUTHORIZATION, format!("Bearer {outsider_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "Outsider should get 404 when filtering by project they don't have access to"
    );

    // Cleanup
    cleanup_jobs(
        &pool,
        &[
            job_with_uuid_id,
            job_with_numeric_id,
            job_with_both_id,
            personal_job_id,
        ],
    )
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind([owner_id, member_id, outsider_id])
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_page_workspace_visibility_archived_project() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create owner user
    let owner_id = Uuid::new_v4();
    let owner_email = format!("owner-{}@test.com", owner_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(owner_id)
    .bind(&owner_email)
    .execute(&pool)
    .await
    .expect("create owner user");

    // Create workspace
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, created_at, updated_at) 
         VALUES ($1, $2, $3, 'personal', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Workspace")
    .execute(&pool)
    .await
    .expect("create workspace");

    // Add owner to workspace
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'owner', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("add owner to workspace");

    // Create archived project
    let project_id = Uuid::new_v4();
    let project_numeric_id = ((Uuid::new_v4().as_u128() % 900_000) as i32) + 1_000;
    sqlx::query(
        "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, archived_at, created_at, updated_at) 
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), NOW())",
    )
    .bind(project_id)
    .bind(project_numeric_id)
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Archived Project")
    .execute(&pool)
    .await
    .expect("create archived project");

    // Create job with archived project
    let job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "project_numeric_id": project_numeric_id,
    }))
    .execute(&pool)
    .await
    .expect("create job with archived project");

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // Test: Owner can still see jobs from archived projects (as owner)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=100")
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, owner_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "owner_jobs={owner_jobs}");
    let owner_jobs_data = owner_jobs["data"].as_array().expect("owner jobs data");
    let owner_job_ids: Vec<String> = owner_jobs_data
        .iter()
        .map(|j| j["id"].as_str().unwrap().to_string())
        .collect();
    assert!(
        owner_job_ids.contains(&job_id.to_string()),
        "Owner should see job from archived project (because they own the job)"
    );

    // Cleanup
    cleanup_jobs(&pool, &[job_id]).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = $1")
        .bind(owner_id)
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_detail_cancel_retry_workspace_permissions() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create owner user
    let owner_id = Uuid::new_v4();
    let owner_email = format!("owner-{}@test.com", owner_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(owner_id)
    .bind(&owner_email)
    .execute(&pool)
    .await
    .expect("create owner user");

    // Create member user
    let member_id = Uuid::new_v4();
    let member_email = format!("member-{}@test.com", member_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(member_id)
    .bind(&member_email)
    .execute(&pool)
    .await
    .expect("create member user");

    // Create outsider user
    let outsider_id = Uuid::new_v4();
    let outsider_email = format!("outsider-{}@test.com", outsider_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(outsider_id)
    .bind(&outsider_email)
    .execute(&pool)
    .await
    .expect("create outsider user");

    // Create enterprise workspace
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, created_at, updated_at) 
         VALUES ($1, $2, $3, 'enterprise', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Workspace")
    .execute(&pool)
    .await
    .expect("create workspace");

    // Add owner as workspace owner
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'owner', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("add owner to workspace");

    // Add member as workspace member
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'member', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(member_id)
    .execute(&pool)
    .await
    .expect("add member to workspace");

    // Create project in workspace
    let project_id = Uuid::new_v4();
    let project_numeric_id = ((Uuid::new_v4().as_u128() % 900_000) as i32) + 1_000;
    sqlx::query(
        "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
    )
    .bind(project_id)
    .bind(project_numeric_id)
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Project")
    .execute(&pool)
    .await
    .expect("create project");

    // Create job for detail test
    let detail_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'succeeded', $4, NOW(), NOW())
        "#,
    )
    .bind(detail_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create detail job");

    // Create job for cancel test
    let cancel_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(cancel_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create cancel job");

    // Create job for retry test
    let retry_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'failed', $4, NOW(), NOW())
        "#,
    )
    .bind(retry_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create retry job");

    // Create personal job (no project info)
    let personal_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.personal', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(personal_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({"note": "personal job"}))
    .execute(&pool)
    .await
    .expect("create personal job");

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let member_token = jwt_fixture::encode_supabase_style(member_id, secret.as_bytes());
    let outsider_token = jwt_fixture::encode_supabase_style(outsider_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // Test 1: Owner can view job detail
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{detail_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, detail_response) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Owner should be able to view job detail: {detail_response}"
    );
    assert_eq!(
        detail_response["id"].as_str().unwrap(),
        detail_job_id.to_string()
    );

    // Test 2: Member can view job detail
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{detail_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, detail_response) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Member should be able to view job detail: {detail_response}"
    );
    assert_eq!(
        detail_response["id"].as_str().unwrap(),
        detail_job_id.to_string()
    );

    // Test 3: Outsider cannot view job detail (404 for security)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{detail_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {outsider_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "Outsider should get 404 when viewing job detail"
    );

    // Test 4: Member can cancel job
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{cancel_job_id}/cancel"))
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, cancel_response) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Member should be able to cancel job: {cancel_response}"
    );
    assert_eq!(cancel_response["status"].as_str().unwrap(), "cancelled");

    // Test 5: Outsider cannot cancel job (404 for security)
    // First, create another job to cancel
    let cancel_job_2_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(cancel_job_2_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create cancel job 2");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{cancel_job_2_id}/cancel"))
                .header(header::AUTHORIZATION, format!("Bearer {outsider_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "Outsider should get 404 when canceling job"
    );

    // Test 6: Member can retry job
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{retry_job_id}/retry"))
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, retry_response) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Member should be able to retry job: {retry_response}"
    );
    assert_eq!(retry_response["status"].as_str().unwrap(), "queued");

    // Test 7: Outsider cannot retry job (404 for security)
    // First, create another failed job to retry
    let retry_job_2_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'failed', $4, NOW(), NOW())
        "#,
    )
    .bind(retry_job_2_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create retry job 2");

    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/jobs/{retry_job_2_id}/retry"))
                .header(header::AUTHORIZATION, format!("Bearer {outsider_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from("{}"))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "Outsider should get 404 when retrying job"
    );

    // Test 8: Owner can view personal job detail
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{personal_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, personal_response) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Owner should be able to view personal job detail: {personal_response}"
    );

    // Test 9: Member cannot view personal job detail (404)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{personal_job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "Member should get 404 when viewing owner's personal job"
    );

    // Cleanup
    cleanup_jobs(
        &pool,
        &[
            detail_job_id,
            cancel_job_id,
            cancel_job_2_id,
            retry_job_id,
            retry_job_2_id,
            personal_job_id,
        ],
    )
    .await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind([owner_id, member_id, outsider_id])
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_detail_archived_project_permission() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create owner user
    let owner_id = Uuid::new_v4();
    let owner_email = format!("owner-{}@test.com", owner_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(owner_id)
    .bind(&owner_email)
    .execute(&pool)
    .await
    .expect("create owner user");

    // Create member user
    let member_id = Uuid::new_v4();
    let member_email = format!("member-{}@test.com", member_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(member_id)
    .bind(&member_email)
    .execute(&pool)
    .await
    .expect("create member user");

    // Create workspace
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, created_at, updated_at) 
         VALUES ($1, $2, $3, 'enterprise', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Workspace")
    .execute(&pool)
    .await
    .expect("create workspace");

    // Add owner to workspace
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'owner', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("add owner to workspace");

    // Add member to workspace
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'member', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(member_id)
    .execute(&pool)
    .await
    .expect("add member to workspace");

    // Create archived project
    let project_id = Uuid::new_v4();
    let project_numeric_id = ((Uuid::new_v4().as_u128() % 900_000) as i32) + 1_000;
    sqlx::query(
        "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, archived_at, created_at, updated_at) 
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), NOW())",
    )
    .bind(project_id)
    .bind(project_numeric_id)
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Archived Project")
    .execute(&pool)
    .await
    .expect("create archived project");

    // Create job with archived project
    let job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'succeeded', $4, NOW(), NOW())
        "#,
    )
    .bind(job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "project_numeric_id": project_numeric_id,
    }))
    .execute(&pool)
    .await
    .expect("create job with archived project");

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let member_token = jwt_fixture::encode_supabase_style(member_id, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // Test 1: Owner can view job detail (as job owner)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, detail_response) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "Owner should be able to view job detail from archived project: {detail_response}"
    );

    // Test 2: Member cannot view job detail from archived project (404)
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri(format!("/api/v1/jobs/{job_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, _) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::NOT_FOUND,
        "Member should get 404 when viewing job from archived project"
    );

    // Cleanup
    cleanup_jobs(&pool, &[job_id]).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind([owner_id, member_id])
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_summary_workspace_visibility() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create owner user
    let owner_id = Uuid::new_v4();
    let owner_email = format!("owner-{}@test.com", owner_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(owner_id)
    .bind(&owner_email)
    .execute(&pool)
    .await
    .expect("create owner user");

    // Create member user
    let member_id = Uuid::new_v4();
    let member_email = format!("member-{}@test.com", member_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(member_id)
    .bind(&member_email)
    .execute(&pool)
    .await
    .expect("create member user");

    // Create enterprise workspace
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, created_at, updated_at) 
         VALUES ($1, $2, $3, 'enterprise', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Workspace")
    .execute(&pool)
    .await
    .expect("create workspace");

    // Add owner as workspace owner
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'owner', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("add owner to workspace");

    // Add member as workspace member
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'member', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(member_id)
    .execute(&pool)
    .await
    .expect("add member to workspace");

    // Create project in workspace
    let project_id = Uuid::new_v4();
    let project_numeric_id = ((Uuid::new_v4().as_u128() % 900_000) as i32) + 1_000;
    sqlx::query(
        "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
    )
    .bind(project_id)
    .bind(project_numeric_id)
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Project")
    .execute(&pool)
    .await
    .expect("create project");

    // Create workspace jobs with different statuses
    let queued_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(queued_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create queued job");

    let succeeded_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'succeeded', $4, NOW(), NOW())
        "#,
    )
    .bind(succeeded_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create succeeded job");

    // Create personal job
    let personal_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.personal', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(personal_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({"note": "personal job"}))
    .execute(&pool)
    .await
    .expect("create personal job");

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let member_token = jwt_fixture::encode_supabase_style(member_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // Test 1: Owner sees summary including all their jobs
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=100")
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, owner_summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "owner_summary={owner_summary}");
    // Owner should see counts that include both workspace and personal jobs
    let total = owner_summary["total"].as_i64().expect("total count");
    assert!(
        total >= 3,
        "Owner should see at least 3 jobs in summary (2 workspace + 1 personal)"
    );

    // Test 2: Member sees summary only for workspace jobs
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs/page?page=1&limit=100")
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, member_summary) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "member_summary={member_summary}");
    // Member should see counts that include only workspace jobs, not personal
    let total = member_summary["total"].as_i64().expect("total count");
    assert!(
        total >= 2,
        "Member should see at least 2 workspace jobs in summary"
    );
    // The member's total should be less than owner's if personal job is excluded
    let owner_total = owner_summary["total"].as_i64().expect("owner total");
    assert!(
        total < owner_total || total == owner_total - 1,
        "Member's job count should not include owner's personal job"
    );

    // Cleanup
    cleanup_jobs(&pool, &[queued_job_id, succeeded_job_id, personal_job_id]).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind([owner_id, member_id])
        .execute(&pool)
        .await;
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn jobs_list_endpoint_workspace_visibility() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create owner user
    let owner_id = Uuid::new_v4();
    let owner_email = format!("owner-{}@test.com", owner_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(owner_id)
    .bind(&owner_email)
    .execute(&pool)
    .await
    .expect("create owner user");

    // Create member user
    let member_id = Uuid::new_v4();
    let member_email = format!("member-{}@test.com", member_id);
    sqlx::query(
        "INSERT INTO auth.users (id, email, created_at, updated_at) 
         VALUES ($1, $2, NOW(), NOW())",
    )
    .bind(member_id)
    .bind(&member_email)
    .execute(&pool)
    .await
    .expect("create member user");

    // Create enterprise workspace
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        "INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, created_at, updated_at) 
         VALUES ($1, $2, $3, 'enterprise', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Workspace")
    .execute(&pool)
    .await
    .expect("create workspace");

    // Add owner as workspace owner
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'owner', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("add owner to workspace");

    // Add member as workspace member
    sqlx::query(
        "INSERT INTO public.app_workspace_member (workspace_id, user_id, role, created_at, updated_at) 
         VALUES ($1, $2, 'member', NOW(), NOW())",
    )
    .bind(workspace_id)
    .bind(member_id)
    .execute(&pool)
    .await
    .expect("add member to workspace");

    // Create project in workspace
    let project_id = Uuid::new_v4();
    let project_numeric_id = ((Uuid::new_v4().as_u128() % 900_000) as i32) + 1_000;
    sqlx::query(
        "INSERT INTO public.app_project (id, numeric_id, workspace_id, owner_user_id, name, created_at, updated_at) 
         VALUES ($1, $2, $3, $4, $5, NOW(), NOW())",
    )
    .bind(project_id)
    .bind(project_numeric_id)
    .bind(workspace_id)
    .bind(owner_id)
    .bind("Test Project")
    .execute(&pool)
    .await
    .expect("create project");

    // Create workspace job
    let workspace_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.job', 'succeeded', $4, NOW(), NOW())
        "#,
    )
    .bind(workspace_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({
        "project_uuid": project_id.to_string(),
        "workspace_id": workspace_id.to_string(),
    }))
    .execute(&pool)
    .await
    .expect("create workspace job");

    // Create personal job
    let personal_job_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_generation_job 
        (id, owner_user_id, workspace_id, kind, status, payload, created_at, updated_at)
        VALUES ($1, $2, $3, 'test.personal', 'queued', $4, NOW(), NOW())
        "#,
    )
    .bind(personal_job_id)
    .bind(owner_id)
    .bind(workspace_id)
    .bind(serde_json::json!({"note": "personal job"}))
    .execute(&pool)
    .await
    .expect("create personal job");

    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let member_token = jwt_fixture::encode_supabase_style(member_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // Test 1: Owner can see all jobs via /api/v1/jobs endpoint
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {owner_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, owner_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "owner_jobs={owner_jobs}");
    let owner_jobs_array = owner_jobs.as_array().expect("owner jobs array");
    let owner_job_ids: Vec<String> = owner_jobs_array
        .iter()
        .map(|j| j["id"].as_str().unwrap().to_string())
        .collect();
    assert!(
        owner_job_ids.contains(&workspace_job_id.to_string()),
        "Owner should see workspace job via /api/v1/jobs"
    );
    assert!(
        owner_job_ids.contains(&personal_job_id.to_string()),
        "Owner should see personal job via /api/v1/jobs"
    );

    // Test 2: Member can see workspace jobs but not personal jobs via /api/v1/jobs
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::GET)
                .uri("/api/v1/jobs")
                .header(header::AUTHORIZATION, format!("Bearer {member_token}"))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, member_jobs) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "member_jobs={member_jobs}");
    let member_jobs_array = member_jobs.as_array().expect("member jobs array");
    let member_job_ids: Vec<String> = member_jobs_array
        .iter()
        .map(|j| j["id"].as_str().unwrap().to_string())
        .collect();
    assert!(
        member_job_ids.contains(&workspace_job_id.to_string()),
        "Member should see workspace job via /api/v1/jobs"
    );
    assert!(
        !member_job_ids.contains(&personal_job_id.to_string()),
        "Member should NOT see personal job via /api/v1/jobs"
    );

    // Cleanup
    cleanup_jobs(&pool, &[workspace_job_id, personal_job_id]).await;
    let _ = sqlx::query("DELETE FROM public.app_project WHERE id = $1")
        .bind(project_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind([owner_id, member_id])
        .execute(&pool)
        .await;
}

async fn cleanup_jobs(pool: &sqlx::PgPool, job_ids: &[Uuid]) {
    for job_id in job_ids {
        let _ = sqlx::query("DELETE FROM public.app_generation_job WHERE id = $1")
            .bind(job_id)
            .execute(pool)
            .await;
    }
}
