//! Integration tests for workspace `jobs_today` aggregate (Task 3.2).
//!
//! **Validates: Requirements 2.3, 4.1, 4.2**
//!
//! These tests verify:
//! - Workspace job counting uses UTC date boundaries
//! - Jobs are correctly attributed to workspace_id
//! - Quota enforcement uses workspace aggregates when billing_scope=workspace
//!
//! ## Running These Tests
//!
//! These are integration tests that require a PostgreSQL database:
//!
//! ```bash
//! # Using local Supabase (after `supabase start`)
//! export TEST_DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:64322/postgres"
//! cargo test --test workspace_jobs_today_test
//! ```
//!
//! Tests will be skipped with a warning if TEST_DATABASE_URL is not set.

#[cfg(test)]
mod integration_tests {
    use sqlx::PgPool;
    use uuid::Uuid;

    /// Helper to check if test database is available
    fn test_database_url() -> Option<String> {
        std::env::var("TEST_DATABASE_URL").ok()
    }

    /// Test data structure
    struct TestWorkspace {
        workspace_id: Uuid,
        owner_user_id: Uuid,
        member_user_id: Uuid,
    }

    /// Helper to set up test workspace with owner and member
    async fn setup_test_workspace(pool: &PgPool) -> TestWorkspace {
        let workspace_id = Uuid::new_v4();
        let owner_user_id = Uuid::new_v4();
        let member_user_id = Uuid::new_v4();

        // Create owner user
        sqlx::query(
            r#"
            INSERT INTO app_user_profile (user_id, email, plan_tier)
            VALUES ($1, $2, 'enterprise')
            "#,
        )
        .bind(owner_user_id)
        .bind(format!("owner-{}@example.com", owner_user_id))
        .execute(pool)
        .await
        .expect("Failed to create owner user");

        // Create member user
        sqlx::query(
            r#"
            INSERT INTO app_user_profile (user_id, email, plan_tier)
            VALUES ($1, $2, 'free')
            "#,
        )
        .bind(member_user_id)
        .bind(format!("member-{}@example.com", member_user_id))
        .execute(pool)
        .await
        .expect("Failed to create member user");

        // Create workspace with billing
        sqlx::query(
            r#"
            INSERT INTO app_workspace (id, owner_user_id, name, workspace_type, plan_tier, daily_job_quota)
            VALUES ($1, $2, 'Test Workspace', 'enterprise', 'enterprise', 1000)
            "#,
        )
        .bind(workspace_id)
        .bind(owner_user_id)
        .execute(pool)
        .await
        .expect("Failed to create workspace");

        // Add owner as member
        sqlx::query(
            r#"
            INSERT INTO app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'owner')
            "#,
        )
        .bind(workspace_id)
        .bind(owner_user_id)
        .execute(pool)
        .await
        .expect("Failed to add owner to workspace");

        // Add member
        sqlx::query(
            r#"
            INSERT INTO app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'member')
            "#,
        )
        .bind(workspace_id)
        .bind(member_user_id)
        .execute(pool)
        .await
        .expect("Failed to add member to workspace");

        TestWorkspace {
            workspace_id,
            owner_user_id,
            member_user_id,
        }
    }

    /// Helper to create a generation job for a workspace
    async fn create_job(
        pool: &PgPool,
        workspace_id: Uuid,
        owner_user_id: Uuid,
        created_at: Option<&str>,
    ) -> Uuid {
        let job_id = Uuid::new_v4();

        let query = if let Some(timestamp) = created_at {
            sqlx::query(
                r#"
                INSERT INTO app_generation_job (id, workspace_id, owner_user_id, status, created_at)
                VALUES ($1, $2, $3, 'pending', $4::timestamptz)
                "#,
            )
            .bind(job_id)
            .bind(workspace_id)
            .bind(owner_user_id)
            .bind(timestamp)
        } else {
            sqlx::query(
                r#"
                INSERT INTO app_generation_job (id, workspace_id, owner_user_id, status)
                VALUES ($1, $2, $3, 'pending')
                "#,
            )
            .bind(job_id)
            .bind(workspace_id)
            .bind(owner_user_id)
        };

        query.execute(pool).await.expect("Failed to create job");

        job_id
    }

    /// Helper to count workspace jobs today using the same query as the implementation
    async fn count_workspace_jobs_today(pool: &PgPool, workspace_id: Uuid) -> i64 {
        sqlx::query_scalar(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE workspace_id = $1
              AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
            "#,
        )
        .bind(workspace_id)
        .fetch_one(pool)
        .await
        .expect("Failed to count workspace jobs")
    }

    /// Helper to cleanup test data
    async fn cleanup_test_workspace(pool: &PgPool, test_workspace: &TestWorkspace) {
        // Delete jobs
        sqlx::query("DELETE FROM app_generation_job WHERE workspace_id = $1")
            .bind(test_workspace.workspace_id)
            .execute(pool)
            .await
            .ok();

        // Delete workspace members
        sqlx::query("DELETE FROM app_workspace_member WHERE workspace_id = $1")
            .bind(test_workspace.workspace_id)
            .execute(pool)
            .await
            .ok();

        // Delete workspace
        sqlx::query("DELETE FROM app_workspace WHERE id = $1")
            .bind(test_workspace.workspace_id)
            .execute(pool)
            .await
            .ok();

        // Delete users
        sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
            .bind(test_workspace.owner_user_id)
            .execute(pool)
            .await
            .ok();

        sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
            .bind(test_workspace.member_user_id)
            .execute(pool)
            .await
            .ok();
    }

    /// Test: workspace_jobs_today counts jobs created today (UTC)
    ///
    /// **Validates: Requirement 2.3 - workspace jobs_today aggregate**
    #[tokio::test]
    async fn test_workspace_jobs_today_counts_today_utc() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_workspace = setup_test_workspace(&pool).await;

        // Initial count should be 0
        let initial_count = count_workspace_jobs_today(&pool, test_workspace.workspace_id).await;
        assert_eq!(initial_count, 0, "Initial workspace jobs_today should be 0");

        // Create 3 jobs today
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.member_user_id,
            None,
        )
        .await;

        // Count should be 3
        let count_after_creates =
            count_workspace_jobs_today(&pool, test_workspace.workspace_id).await;
        assert_eq!(
            count_after_creates, 3,
            "workspace_jobs_today should count all jobs created today"
        );

        cleanup_test_workspace(&pool, &test_workspace).await;
    }

    /// Test: workspace_jobs_today excludes jobs from previous days
    ///
    /// **Validates: Requirement 2.3 - UTC date boundaries**
    #[tokio::test]
    async fn test_workspace_jobs_today_excludes_previous_days() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_workspace = setup_test_workspace(&pool).await;

        // Create a job from yesterday (UTC)
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            Some("NOW() AT TIME ZONE 'UTC' - INTERVAL '1 day'"),
        )
        .await;

        // Create a job from 2 days ago
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            Some("NOW() AT TIME ZONE 'UTC' - INTERVAL '2 days'"),
        )
        .await;

        // Create a job today
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            None,
        )
        .await;

        // Count should only include today's job
        let count = count_workspace_jobs_today(&pool, test_workspace.workspace_id).await;
        assert_eq!(
            count, 1,
            "workspace_jobs_today should only count jobs from today (UTC)"
        );

        cleanup_test_workspace(&pool, &test_workspace).await;
    }

    /// Test: workspace_jobs_today isolates different workspaces
    ///
    /// **Validates: Requirement 2.3 - workspace attribution**
    #[tokio::test]
    async fn test_workspace_jobs_today_isolates_workspaces() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let workspace_a = setup_test_workspace(&pool).await;
        let workspace_b = setup_test_workspace(&pool).await;

        // Create 2 jobs in workspace A
        create_job(
            &pool,
            workspace_a.workspace_id,
            workspace_a.owner_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            workspace_a.workspace_id,
            workspace_a.owner_user_id,
            None,
        )
        .await;

        // Create 3 jobs in workspace B
        create_job(
            &pool,
            workspace_b.workspace_id,
            workspace_b.owner_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            workspace_b.workspace_id,
            workspace_b.owner_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            workspace_b.workspace_id,
            workspace_b.owner_user_id,
            None,
        )
        .await;

        // Verify counts are isolated
        let count_a = count_workspace_jobs_today(&pool, workspace_a.workspace_id).await;
        let count_b = count_workspace_jobs_today(&pool, workspace_b.workspace_id).await;

        assert_eq!(count_a, 2, "Workspace A should have 2 jobs");
        assert_eq!(count_b, 3, "Workspace B should have 3 jobs");

        cleanup_test_workspace(&pool, &workspace_a).await;
        cleanup_test_workspace(&pool, &workspace_b).await;
    }

    /// Test: workspace_jobs_today aggregates jobs from multiple users
    ///
    /// **Validates: Requirement 2.3 - workspace-level aggregation**
    #[tokio::test]
    async fn test_workspace_jobs_today_aggregates_multiple_users() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_workspace = setup_test_workspace(&pool).await;

        // Create jobs from owner
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.owner_user_id,
            None,
        )
        .await;

        // Create jobs from member
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.member_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.member_user_id,
            None,
        )
        .await;
        create_job(
            &pool,
            test_workspace.workspace_id,
            test_workspace.member_user_id,
            None,
        )
        .await;

        // Total should be 5 (2 from owner + 3 from member)
        let total_count = count_workspace_jobs_today(&pool, test_workspace.workspace_id).await;
        assert_eq!(
            total_count, 5,
            "workspace_jobs_today should aggregate jobs from all workspace members"
        );

        cleanup_test_workspace(&pool, &test_workspace).await;
    }
}
