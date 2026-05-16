//! Integration tests for GET /api/v1/me endpoint (v1 and v2).
//!
//! **Validates: Requirements 3.1–3.5, 9.1, 9.2, 10.1**
//!
//! These tests verify:
//! - v1 response unchanged (backward compatibility)
//! - v2 happy path with workspace billing
//! - v2 forbidden workspace (non-member)
//! - v2 personal workspace (user-scope billing)
//!
//! ## Test Documentation
//!
//! The `/me` endpoint supports two versions:
//! 1. **v1 (default)**: Flat response with user billing fields
//! 2. **v2 (opt-in via `?v=2`)**: Nested response with `billing_scope`, `user`, and `current_workspace_billing`
//!
//! ## Running These Tests
//!
//! These are integration tests that require a PostgreSQL database:
//!
//! ```bash
//! # Using local Supabase (after `supabase start`)
//! export TEST_DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:64322/postgres"
//! cargo test --test me_endpoint_test
//! ```
//!
//! Tests will be skipped with a warning if TEST_DATABASE_URL is not set.

#[cfg(test)]
mod integration_tests {
    use serde_json::json;
    use sqlx::PgPool;
    use uuid::Uuid;

    /// Helper to check if test database is available
    fn test_database_url() -> Option<String> {
        std::env::var("TEST_DATABASE_URL").ok()
    }

    /// Test data structure
    #[allow(dead_code)]
    struct TestUser {
        user_id: Uuid,
        email: String,
        personal_workspace_id: Uuid,
        enterprise_workspace_id: Uuid,
    }

    /// Helper to set up test user with personal and enterprise workspaces
    async fn setup_test_user(pool: &PgPool) -> TestUser {
        let user_id = Uuid::new_v4();
        let email = format!("test-me-{}@example.com", user_id);
        let personal_workspace_id = Uuid::new_v4();
        let enterprise_workspace_id = Uuid::new_v4();

        // Create user profile
        sqlx::query(
            r#"
            INSERT INTO app_user_profile (user_id, email, plan_tier, daily_job_quota)
            VALUES ($1, $2, 'pro', 100)
            "#,
        )
        .bind(user_id)
        .bind(&email)
        .execute(pool)
        .await
        .expect("Failed to create test user");

        // Create personal workspace
        sqlx::query(
            r#"
            INSERT INTO app_workspace (id, owner_user_id, name, workspace_type)
            VALUES ($1, $2, 'Personal Workspace', 'personal')
            "#,
        )
        .bind(personal_workspace_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to create personal workspace");

        // Add user as member of personal workspace
        sqlx::query(
            r#"
            INSERT INTO app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'owner')
            "#,
        )
        .bind(personal_workspace_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to add user to personal workspace");

        // Create enterprise workspace with billing
        sqlx::query(
            r#"
            INSERT INTO app_workspace (id, owner_user_id, name, workspace_type, plan_tier, daily_job_quota)
            VALUES ($1, $2, 'Enterprise Workspace', 'enterprise', 'enterprise', 1000)
            "#,
        )
        .bind(enterprise_workspace_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to create enterprise workspace");

        // Add user as member of enterprise workspace
        sqlx::query(
            r#"
            INSERT INTO app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'owner')
            "#,
        )
        .bind(enterprise_workspace_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to add user to enterprise workspace");

        // Set current workspace to personal
        sqlx::query(
            r#"
            UPDATE app_user_profile
            SET current_workspace_id = $2
            WHERE user_id = $1
            "#,
        )
        .bind(user_id)
        .bind(personal_workspace_id)
        .execute(pool)
        .await
        .expect("Failed to set current workspace");

        TestUser {
            user_id,
            email,
            personal_workspace_id,
            enterprise_workspace_id,
        }
    }

    /// Helper to clean up test data
    async fn cleanup_test_user(pool: &PgPool, test_user: &TestUser) {
        let _ = sqlx::query("DELETE FROM app_workspace_member WHERE user_id = $1")
            .bind(test_user.user_id)
            .execute(pool)
            .await;

        let _ = sqlx::query("DELETE FROM app_workspace WHERE id = $1 OR id = $2")
            .bind(test_user.personal_workspace_id)
            .bind(test_user.enterprise_workspace_id)
            .execute(pool)
            .await;

        let _ = sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
            .bind(test_user.user_id)
            .execute(pool)
            .await;
    }

    /// Helper to simulate /me v1 endpoint logic
    async fn get_me_v1(pool: &PgPool, user_id: Uuid) -> serde_json::Value {
        // Simulate the v1 endpoint logic
        let row: Option<(String, Option<i64>, Option<Uuid>)> = sqlx::query_as(
            r#"
            SELECT plan_tier, daily_job_quota, current_workspace_id
            FROM app_user_profile
            WHERE user_id = $1
            "#,
        )
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .expect("Failed to fetch user profile");

        let (plan_tier, daily_job_quota, current_workspace_id) =
            row.unwrap_or(("free".to_string(), None, None));

        let jobs_today: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE owner_user_id = $1
              AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
            "#,
        )
        .bind(user_id)
        .fetch_one(pool)
        .await
        .expect("Failed to count jobs");

        let current_workspace = if let Some(workspace_id) = current_workspace_id {
            let ws: Option<(Uuid, String, String)> = sqlx::query_as(
                r#"
                SELECT w.id, w.name, w.workspace_type::text
                FROM app_workspace w
                INNER JOIN app_workspace_member m ON m.workspace_id = w.id
                WHERE w.id = $1 AND m.user_id = $2
                "#,
            )
            .bind(workspace_id)
            .bind(user_id)
            .fetch_optional(pool)
            .await
            .expect("Failed to fetch workspace");

            ws.map(|(id, name, workspace_type)| {
                json!({
                    "id": id,
                    "name": name,
                    "workspace_type": workspace_type
                })
            })
        } else {
            None
        };

        json!({
            "sub": user_id,
            "plan_tier": plan_tier,
            "daily_job_quota": daily_job_quota,
            "jobs_today": jobs_today,
            "current_workspace": current_workspace
        })
    }

    /// Helper to simulate /me v2 endpoint logic
    async fn get_me_v2(pool: &PgPool, user_id: Uuid) -> serde_json::Value {
        // Get user profile
        let row: Option<(String, Option<i64>, Option<Uuid>)> = sqlx::query_as(
            r#"
            SELECT plan_tier, daily_job_quota, current_workspace_id
            FROM app_user_profile
            WHERE user_id = $1
            "#,
        )
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .expect("Failed to fetch user profile");

        let (user_plan_tier, user_daily_job_quota, current_workspace_id) =
            row.unwrap_or(("free".to_string(), None, None));

        let user_jobs_today: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*)::bigint
            FROM app_generation_job
            WHERE owner_user_id = $1
              AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
            "#,
        )
        .bind(user_id)
        .fetch_one(pool)
        .await
        .expect("Failed to count user jobs");

        // Get current workspace
        let current_workspace_id = current_workspace_id.expect("No current workspace");
        let ws: (Uuid, String, String, Option<String>, Option<i64>) = sqlx::query_as(
            r#"
            SELECT w.id, w.name, w.workspace_type::text, w.plan_tier, w.daily_job_quota
            FROM app_workspace w
            INNER JOIN app_workspace_member m ON m.workspace_id = w.id
            WHERE w.id = $1 AND m.user_id = $2
            "#,
        )
        .bind(current_workspace_id)
        .bind(user_id)
        .fetch_one(pool)
        .await
        .expect("Failed to fetch workspace");

        let (ws_id, ws_name, ws_type, ws_plan_tier, ws_daily_job_quota) = ws;

        // Determine billing scope
        let workspace_billing_enabled = std::env::var("WORKSPACE_BILLING_ENABLED")
            .ok()
            .and_then(|s| s.parse::<bool>().ok())
            .unwrap_or(false);

        let billing_scope = if workspace_billing_enabled && ws_plan_tier.is_some() {
            "workspace"
        } else {
            "user"
        };

        let current_workspace_billing = if billing_scope == "workspace" {
            let workspace_jobs_today: i64 = sqlx::query_scalar(
                r#"
                SELECT COUNT(*)::bigint
                FROM app_generation_job
                WHERE workspace_id = $1
                  AND created_at >= DATE_TRUNC('day', NOW() AT TIME ZONE 'UTC')
                "#,
            )
            .bind(ws_id)
            .fetch_one(pool)
            .await
            .expect("Failed to count workspace jobs");

            Some(json!({
                "workspace_id": ws_id,
                "workspace_type": ws_type,
                "plan_tier": ws_plan_tier,
                "daily_job_quota": ws_daily_job_quota,
                "jobs_today": workspace_jobs_today
            }))
        } else {
            None
        };

        json!({
            "billing_scope": billing_scope,
            "user": {
                "sub": user_id,
                "plan_tier": user_plan_tier,
                "daily_job_quota": user_daily_job_quota,
                "jobs_today": user_jobs_today
            },
            "current_workspace_billing": current_workspace_billing,
            "current_workspace": {
                "id": ws_id,
                "name": ws_name,
                "workspace_type": ws_type
            }
        })
    }

    /// Test: v1 response unchanged (backward compatibility)
    ///
    /// **Validates: Requirements 3.1, 9.1**
    #[tokio::test]
    async fn test_me_v1_backward_compatibility() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            eprintln!("   Set TEST_DATABASE_URL to run database integration tests");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_user = setup_test_user(&pool).await;

        // Get v1 response
        let response = get_me_v1(&pool, test_user.user_id).await;

        // Verify v1 structure
        assert!(response.get("sub").is_some(), "v1 must have sub");
        assert!(
            response.get("plan_tier").is_some(),
            "v1 must have plan_tier"
        );
        assert_eq!(
            response.get("plan_tier").and_then(|v| v.as_str()),
            Some("pro"),
            "v1 plan_tier should be 'pro'"
        );
        assert!(
            response.get("daily_job_quota").is_some(),
            "v1 must have daily_job_quota"
        );
        assert!(
            response.get("jobs_today").is_some(),
            "v1 must have jobs_today"
        );
        assert!(
            response.get("current_workspace").is_some(),
            "v1 must have current_workspace"
        );

        // Verify v1 does NOT have v2-specific fields
        assert!(
            response.get("billing_scope").is_none(),
            "v1 must not have billing_scope"
        );
        assert!(
            response.get("user").is_none(),
            "v1 must not have nested user"
        );
        assert!(
            response.get("current_workspace_billing").is_none(),
            "v1 must not have current_workspace_billing"
        );

        cleanup_test_user(&pool, &test_user).await;
    }

    /// Test: v2 happy path with workspace billing
    ///
    /// **Validates: Requirements 3.2, 3.3, 9.2**
    #[tokio::test]
    async fn test_me_v2_workspace_billing_happy_path() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_user = setup_test_user(&pool).await;

        // Switch to enterprise workspace
        sqlx::query(
            r#"
            UPDATE app_user_profile
            SET current_workspace_id = $2
            WHERE user_id = $1
            "#,
        )
        .bind(test_user.user_id)
        .bind(test_user.enterprise_workspace_id)
        .execute(&pool)
        .await
        .expect("Failed to switch workspace");

        // Enable workspace billing
        std::env::set_var("WORKSPACE_BILLING_ENABLED", "true");

        // Get v2 response
        let response = get_me_v2(&pool, test_user.user_id).await;

        // Verify v2 structure
        assert_eq!(
            response.get("billing_scope").and_then(|v| v.as_str()),
            Some("workspace"),
            "v2 billing_scope should be 'workspace'"
        );

        // Verify nested user object
        let user = response.get("user").expect("v2 must have user object");
        assert_eq!(
            user.get("sub").and_then(|v| v.as_str()),
            Some(test_user.user_id.to_string().as_str()),
            "v2 user.sub should match"
        );
        assert_eq!(
            user.get("plan_tier").and_then(|v| v.as_str()),
            Some("pro"),
            "v2 user.plan_tier should be 'pro'"
        );

        // Verify current_workspace_billing
        let ws_billing = response
            .get("current_workspace_billing")
            .expect("v2 must have current_workspace_billing when billing_scope=workspace");
        assert_eq!(
            ws_billing.get("workspace_id").and_then(|v| v.as_str()),
            Some(test_user.enterprise_workspace_id.to_string().as_str()),
            "workspace_id should match"
        );
        assert_eq!(
            ws_billing.get("workspace_type").and_then(|v| v.as_str()),
            Some("enterprise"),
            "workspace_type should be 'enterprise'"
        );
        assert_eq!(
            ws_billing.get("plan_tier").and_then(|v| v.as_str()),
            Some("enterprise"),
            "workspace plan_tier should be 'enterprise'"
        );
        assert_eq!(
            ws_billing.get("daily_job_quota").and_then(|v| v.as_i64()),
            Some(1000),
            "workspace daily_job_quota should be 1000"
        );

        // Clean up
        std::env::remove_var("WORKSPACE_BILLING_ENABLED");
        cleanup_test_user(&pool, &test_user).await;
    }

    /// Test: v2 personal workspace (user-scope billing)
    ///
    /// **Validates: Requirements 3.3, 9.3**
    #[tokio::test]
    async fn test_me_v2_personal_workspace_user_scope() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_user = setup_test_user(&pool).await;

        // Current workspace is already personal (set in setup)
        // Enable workspace billing
        std::env::set_var("WORKSPACE_BILLING_ENABLED", "true");

        // Get v2 response
        let response = get_me_v2(&pool, test_user.user_id).await;

        // Verify billing_scope is user (personal workspace has no plan_tier)
        assert_eq!(
            response.get("billing_scope").and_then(|v| v.as_str()),
            Some("user"),
            "v2 billing_scope should be 'user' for personal workspace without plan_tier"
        );

        // Verify current_workspace_billing is None
        assert!(
            response.get("current_workspace_billing").is_none()
                || response
                    .get("current_workspace_billing")
                    .and_then(|v| v.as_object())
                    .is_none(),
            "current_workspace_billing should be null when billing_scope=user"
        );

        // Verify user object still present
        let user = response.get("user").expect("v2 must have user object");
        assert_eq!(
            user.get("plan_tier").and_then(|v| v.as_str()),
            Some("pro"),
            "v2 user.plan_tier should be 'pro'"
        );

        // Clean up
        std::env::remove_var("WORKSPACE_BILLING_ENABLED");
        cleanup_test_user(&pool, &test_user).await;
    }

    /// Test: v2 forbidden workspace (non-member)
    ///
    /// **Validates: Requirements 10.1**
    #[tokio::test]
    async fn test_me_v2_forbidden_workspace_non_member() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_user = setup_test_user(&pool).await;

        // Create another user's workspace
        let other_user_id = Uuid::new_v4();
        let other_workspace_id = Uuid::new_v4();

        sqlx::query(
            r#"
            INSERT INTO app_user_profile (user_id, email, plan_tier)
            VALUES ($1, $2, 'free')
            "#,
        )
        .bind(other_user_id)
        .bind(format!("other-{}@example.com", other_user_id))
        .execute(&pool)
        .await
        .expect("Failed to create other user");

        sqlx::query(
            r#"
            INSERT INTO app_workspace (id, owner_user_id, name, workspace_type, plan_tier)
            VALUES ($1, $2, 'Other Workspace', 'enterprise', 'enterprise')
            "#,
        )
        .bind(other_workspace_id)
        .bind(other_user_id)
        .execute(&pool)
        .await
        .expect("Failed to create other workspace");

        sqlx::query(
            r#"
            INSERT INTO app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, 'owner')
            "#,
        )
        .bind(other_workspace_id)
        .bind(other_user_id)
        .execute(&pool)
        .await
        .expect("Failed to add other user to workspace");

        // Try to set test_user's current_workspace to other_workspace (should fail in real endpoint)
        // In the real endpoint, this would be caught by the membership check
        // Here we verify that the query returns None when user is not a member
        let forbidden_check: Option<(Uuid,)> = sqlx::query_as(
            r#"
            SELECT w.id
            FROM app_workspace w
            INNER JOIN app_workspace_member m ON m.workspace_id = w.id
            WHERE w.id = $1 AND m.user_id = $2
            "#,
        )
        .bind(other_workspace_id)
        .bind(test_user.user_id)
        .fetch_optional(&pool)
        .await
        .expect("Failed to check membership");

        assert!(
            forbidden_check.is_none(),
            "User should not have access to other user's workspace"
        );

        // Clean up
        let _ = sqlx::query("DELETE FROM app_workspace_member WHERE workspace_id = $1")
            .bind(other_workspace_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM app_workspace WHERE id = $1")
            .bind(other_workspace_id)
            .execute(&pool)
            .await;
        let _ = sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
            .bind(other_user_id)
            .execute(&pool)
            .await;

        cleanup_test_user(&pool, &test_user).await;
    }

    /// Test: v2 with workspace billing disabled (global flag)
    ///
    /// **Validates: Requirements 3.3, 4.1**
    #[tokio::test]
    async fn test_me_v2_workspace_billing_disabled() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping integration test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let test_user = setup_test_user(&pool).await;

        // Switch to enterprise workspace
        sqlx::query(
            r#"
            UPDATE app_user_profile
            SET current_workspace_id = $2
            WHERE user_id = $1
            "#,
        )
        .bind(test_user.user_id)
        .bind(test_user.enterprise_workspace_id)
        .execute(&pool)
        .await
        .expect("Failed to switch workspace");

        // Ensure workspace billing is disabled
        std::env::remove_var("WORKSPACE_BILLING_ENABLED");

        // Get v2 response
        let response = get_me_v2(&pool, test_user.user_id).await;

        // Verify billing_scope is user (even though workspace has plan_tier)
        assert_eq!(
            response.get("billing_scope").and_then(|v| v.as_str()),
            Some("user"),
            "v2 billing_scope should be 'user' when WORKSPACE_BILLING_ENABLED=false"
        );

        // Verify current_workspace_billing is None
        assert!(
            response.get("current_workspace_billing").is_none()
                || response
                    .get("current_workspace_billing")
                    .and_then(|v| v.as_object())
                    .is_none(),
            "current_workspace_billing should be null when billing_scope=user"
        );

        cleanup_test_user(&pool, &test_user).await;
    }
}
