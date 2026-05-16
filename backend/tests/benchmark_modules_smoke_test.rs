//! Smoke tests for benchmark backend modules (Task 7).
//!
//! **Validates: Requirements 2.2**
//!
//! These tests verify basic create + read operations for:
//! - review_queue: create review item → read it back
//! - observation_assets: create asset → read it back
//! - memory_profiles: list profiles
//! - promotion_gate: get gate decision for experiment
//!
//! ## Running These Tests
//!
//! These are integration tests that require a PostgreSQL database:
//!
//! ```bash
//! # Using local Supabase (after `supabase start`)
//! export TEST_DATABASE_URL="postgresql://postgres:postgres@127.0.0.1:64322/postgres"
//! cargo test --test benchmark_modules_smoke_test
//! ```
//!
//! Tests will be skipped with a warning if TEST_DATABASE_URL is not set.

#[cfg(test)]
mod smoke_tests {
    use sqlx::PgPool;
    use uuid::Uuid;

    /// Helper to check if test database is available
    fn test_database_url() -> Option<String> {
        std::env::var("TEST_DATABASE_URL").ok()
    }

    /// Helper to create a test user
    async fn create_test_user(pool: &PgPool) -> Uuid {
        let user_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_user_profile (user_id, email, plan_tier)
            VALUES ($1, $2, 'free')
            "#,
        )
        .bind(user_id)
        .bind(format!("test-{}@example.com", user_id))
        .execute(pool)
        .await
        .expect("Failed to create test user");
        user_id
    }

    /// Helper to create a test project
    async fn create_test_project(pool: &PgPool, user_id: Uuid) -> i32 {
        let project_id: i32 = sqlx::query_scalar(
            r#"
            INSERT INTO app_project (owner_user_id, name, project_type)
            VALUES ($1, 'Test Project', 'drama')
            RETURNING id
            "#,
        )
        .bind(user_id)
        .fetch_one(pool)
        .await
        .expect("Failed to create test project");
        project_id
    }

    /// Helper to create a test experiment run
    async fn create_test_experiment(pool: &PgPool, user_id: Uuid, project_id: i32) -> Uuid {
        let experiment_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_experiment_run (id, owner_user_id, name, status, sample_tier, stage_scope)
            VALUES ($1, $2, 'Test Experiment', 'running', 'smoke', '["video_prompt"]'::jsonb)
            "#,
        )
        .bind(experiment_id)
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to create test experiment");
        let _ = project_id;
        experiment_id
    }

    /// Helper to create a test benchmark case
    async fn create_test_benchmark_case(pool: &PgPool, user_id: Uuid, project_id: i32) -> Uuid {
        let case_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_benchmark_case (
                id, owner_user_id, project_id, stage, case_type, issue_tags, weight, source_kind, summary
            )
            VALUES ($1, $2, $3, 'video_prompt', 'golden', '[]'::jsonb, 1, 'manual', 'test benchmark case')
            "#,
        )
        .bind(case_id)
        .bind(user_id)
        .bind(project_id)
        .execute(pool)
        .await
        .expect("Failed to create test benchmark case");
        case_id
    }

    /// Helper to create a test experiment result
    async fn create_test_experiment_result(
        pool: &PgPool,
        experiment_id: Uuid,
        variant_id: Uuid,
        case_id: Uuid,
    ) -> Uuid {
        let result_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_experiment_result (id, experiment_run_id, variant_id, benchmark_case_id, status, score_summary, roi_summary)
            VALUES ($1, $2, $3, $4, 'completed', '{"overallScore": 85, "passed": true}', '{"tokensUsed": 1000}')
            "#,
        )
        .bind(result_id)
        .bind(experiment_id)
        .bind(variant_id)
        .bind(case_id)
        .execute(pool)
        .await
        .expect("Failed to create test experiment result");
        result_id
    }

    #[tokio::test]
    async fn smoke_review_queue_create_and_read() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let user_id = create_test_user(&pool).await;
        let project_id = create_test_project(&pool, user_id).await;
        let experiment_id = create_test_experiment(&pool, user_id, project_id).await;
        let case_id = create_test_benchmark_case(&pool, user_id, project_id).await;

        // Create a variant
        let variant_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_experiment_variant (
                id, experiment_run_id, label, is_baseline,
                skill_snapshot, prompt_snapshot, memory_budget_snapshot,
                observation_policy_snapshot, model_route_snapshot
            )
            VALUES (
                $1, $2, 'baseline', true,
                '{"skillFiles":[],"versionTag":"v1"}'::jsonb,
                '{"templates":[],"versionTag":"v1"}'::jsonb,
                '{"budgetTier":"lean","compressionRules":{},"retentionBuckets":{},"observationNoteLimit":100}'::jsonb,
                '{"negativeConstraints":[],"observationNoteLimit":100,"policyVersion":"v1"}'::jsonb,
                '{"modelName":"gpt-4.1"}'::jsonb
            )
            "#,
        )
        .bind(variant_id)
        .bind(experiment_id)
        .execute(&pool)
        .await
        .expect("Failed to create variant");

        let result_id =
            create_test_experiment_result(&pool, experiment_id, variant_id, case_id).await;

        // Create a review queue item
        let review_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_review_queue (id, owner_user_id, experiment_run_id, experiment_result_id, review_type, status, priority, prompt, rubric_snapshot)
            VALUES ($1, $2, $3, $4, 'quality', 'pending', 1, 'Review this result', '{}')
            "#,
        )
        .bind(review_id)
        .bind(user_id)
        .bind(experiment_id)
        .bind(result_id)
        .execute(&pool)
        .await
        .expect("Failed to create review queue item");

        // Read it back
        let retrieved: (Uuid, String, String) = sqlx::query_as(
            r#"
            SELECT id, review_type, status
            FROM app_review_queue
            WHERE id = $1
            "#,
        )
        .bind(review_id)
        .fetch_one(&pool)
        .await
        .expect("Failed to read review queue item");

        assert_eq!(retrieved.0, review_id);
        assert_eq!(retrieved.1, "quality");
        assert_eq!(retrieved.2, "pending");

        println!("✅ review_queue smoke test passed");
    }

    #[tokio::test]
    async fn smoke_observation_assets_create_and_read() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let user_id = create_test_user(&pool).await;
        let project_id = create_test_project(&pool, user_id).await;

        // Create an observation asset
        let asset_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_observation_asset (id, owner_user_id, project_id, scope_kind, issue_type, source_kind, signal_strength, status, normalized_note)
            VALUES ($1, $2, $3, 'project', 'character_consistency', 'quality_review', 5, 'candidate', 'Test observation note')
            "#,
        )
        .bind(asset_id)
        .bind(user_id)
        .bind(project_id)
        .execute(&pool)
        .await
        .expect("Failed to create observation asset");

        // Read it back
        let retrieved: (Uuid, String, String, String) = sqlx::query_as(
            r#"
            SELECT id, scope_kind, issue_type, status
            FROM app_observation_asset
            WHERE id = $1
            "#,
        )
        .bind(asset_id)
        .fetch_one(&pool)
        .await
        .expect("Failed to read observation asset");

        assert_eq!(retrieved.0, asset_id);
        assert_eq!(retrieved.1, "project");
        assert_eq!(retrieved.2, "character_consistency");
        assert_eq!(retrieved.3, "candidate");

        println!("✅ observation_assets smoke test passed");
    }

    #[tokio::test]
    async fn smoke_memory_profiles_list() {
        // memory_profiles doesn't require database for listing predefined profiles
        // This is a simple smoke test to verify the module is accessible

        use toonflow_server::prompting::benchmark::memory_profiles::{
            CompressionRules, MemoryBudgetProfileSnapshot, RetentionBuckets,
        };

        // Create a sample profile to verify types work
        let profile = MemoryBudgetProfileSnapshot {
            budget_tier: "lean".to_string(),
            compression_rules: CompressionRules {
                compact_silent_low_risk: true,
                continuity_note_max_chars: Some(120),
                memory_note_max_chars: Some(80),
                style_fragment_retention: Some("best_only".to_string()),
            },
            retention_buckets: RetentionBuckets {
                project_scope_retention: Some(2),
                script_scope_retention: Some(3),
                scene_scope_retention: Some(1),
                prioritize_emotional_memory: false,
                prioritize_dialogue_performance: false,
            },
            observation_note_limit: Some(100),
            character_memory_priority: None,
            profile_version: Some("v1".to_string()),
        };

        assert_eq!(profile.budget_tier, "lean");
        assert_eq!(
            profile.compression_rules.continuity_note_max_chars,
            Some(120)
        );

        println!("✅ memory_profiles smoke test passed");
    }

    #[tokio::test]
    async fn smoke_promotion_gate_get_decision() {
        let Some(db_url) = test_database_url() else {
            eprintln!("⚠️  Skipping test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("Failed to connect to test database");

        let user_id = create_test_user(&pool).await;
        let project_id = create_test_project(&pool, user_id).await;
        let experiment_id = create_test_experiment(&pool, user_id, project_id).await;

        // Create a variant
        let variant_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_experiment_variant (
                id, experiment_run_id, label, is_baseline,
                skill_snapshot, prompt_snapshot, memory_budget_snapshot,
                observation_policy_snapshot, model_route_snapshot
            )
            VALUES (
                $1, $2, 'baseline', true,
                '{"skillFiles":[],"versionTag":"v1"}'::jsonb,
                '{"templates":[],"versionTag":"v1"}'::jsonb,
                '{"budgetTier":"lean","compressionRules":{},"retentionBuckets":{},"observationNoteLimit":100}'::jsonb,
                '{"negativeConstraints":[],"observationNoteLimit":100,"policyVersion":"v1"}'::jsonb,
                '{"modelName":"gpt-4.1"}'::jsonb
            )
            "#,
        )
        .bind(variant_id)
        .bind(experiment_id)
        .execute(&pool)
        .await
        .expect("Failed to create variant");

        // Create a gate decision
        let decision_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO app_promotion_gate_decision (id, experiment_run_id, variant_id, decision, rationale, decided_by)
            VALUES ($1, $2, $3, 'approved', '{"note": "test"}', $4)
            "#,
        )
        .bind(decision_id)
        .bind(experiment_id)
        .bind(variant_id)
        .bind(user_id)
        .execute(&pool)
        .await
        .expect("Failed to create gate decision");

        // Read it back
        let retrieved: (Uuid, String) = sqlx::query_as(
            r#"
            SELECT id, decision
            FROM app_promotion_gate_decision
            WHERE id = $1
            "#,
        )
        .bind(decision_id)
        .fetch_one(&pool)
        .await
        .expect("Failed to read gate decision");

        assert_eq!(retrieved.0, decision_id);
        assert_eq!(retrieved.1, "approved");

        println!("✅ promotion_gate smoke test passed");
    }
}
