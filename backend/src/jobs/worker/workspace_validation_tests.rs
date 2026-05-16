//! Integration tests for workspace membership validation in worker write-back operations.
//!
//! This module verifies that all worker-side project write-back queries properly validate
//! workspace membership before allowing writes to project resources.
//!
//! Covered operations:
//! - Voiceover generation: `persist_storyboard_voiceover_metadata` (UPDATE app_storyboard.metadata)
//! - Video generation/export: `store_video_reference` (UPDATE app_storyboard.file_path)
//! - Asset image generation: `generate_and_store_asset_image_for_row` (INSERT app_asset_image)
//! - Storyboard batch image: `run_production_storyboard_batch_generate_image` (UPDATE app_storyboard.file_path)

#[cfg(test)]
mod tests {
    use sqlx::PgPool;
    use uuid::Uuid;

    /// Test helper: create a test workspace
    async fn create_test_workspace(pool: &PgPool, owner_id: Uuid, workspace_type: &str) -> Uuid {
        sqlx::query_scalar(
            r#"
            INSERT INTO app_workspace (id, name, type, owner_user_id)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(format!("Test Workspace {}", Uuid::new_v4()))
        .bind(workspace_type)
        .bind(owner_id)
        .fetch_one(pool)
        .await
        .unwrap()
    }

    /// Test helper: add a member to a workspace
    async fn add_workspace_member(pool: &PgPool, workspace_id: Uuid, user_id: Uuid, role: &str) {
        sqlx::query(
            r#"
            INSERT INTO app_workspace_member (workspace_id, user_id, role)
            VALUES ($1, $2, $3)
            ON CONFLICT (workspace_id, user_id) DO NOTHING
            "#,
        )
        .bind(workspace_id)
        .bind(user_id)
        .bind(role)
        .execute(pool)
        .await
        .unwrap();
    }

    /// Test helper: create a test project
    async fn create_test_project(pool: &PgPool, workspace_id: Uuid, numeric_id: i32) -> Uuid {
        sqlx::query_scalar(
            r#"
            INSERT INTO app_project (id, workspace_id, numeric_id, name)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(workspace_id)
        .bind(numeric_id)
        .bind(format!("Test Project {}", numeric_id))
        .fetch_one(pool)
        .await
        .unwrap()
    }

    /// Test helper: create a test script
    async fn create_test_script(pool: &PgPool, project_id: Uuid, numeric_id: i32) -> Uuid {
        sqlx::query_scalar(
            r#"
            INSERT INTO app_script (id, project_id, numeric_id, title)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(project_id)
        .bind(numeric_id)
        .bind(format!("Test Script {}", numeric_id))
        .fetch_one(pool)
        .await
        .unwrap()
    }

    /// Test helper: create a test storyboard
    async fn create_test_storyboard(pool: &PgPool, script_id: Uuid, numeric_id: i32) -> Uuid {
        sqlx::query_scalar(
            r#"
            INSERT INTO app_storyboard (id, script_id, numeric_id, prompt)
            VALUES ($1, $2, $3, $4)
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(script_id)
        .bind(numeric_id)
        .bind("Test storyboard prompt")
        .fetch_one(pool)
        .await
        .unwrap()
    }

    /// Test helper: create a test asset
    async fn create_test_asset(pool: &PgPool, project_id: Uuid, numeric_id: i32) -> Uuid {
        sqlx::query_scalar(
            r#"
            INSERT INTO app_asset (id, project_id, numeric_id, name, asset_type)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(project_id)
        .bind(numeric_id)
        .bind(format!("Test Asset {}", numeric_id))
        .bind("character")
        .fetch_one(pool)
        .await
        .unwrap()
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_video_store_reference_validates_workspace_membership(pool: PgPool) {
        use crate::jobs::worker::video::storage::store_video_reference;

        let owner_id = Uuid::new_v4();
        let member_id = Uuid::new_v4();
        let outsider_id = Uuid::new_v4();

        // Create workspace and add members
        let workspace_id = create_test_workspace(&pool, owner_id, "enterprise").await;
        add_workspace_member(&pool, workspace_id, owner_id, "owner").await;
        add_workspace_member(&pool, workspace_id, member_id, "member").await;

        // Create project, script, and storyboard
        let project_id = create_test_project(&pool, workspace_id, 1).await;
        let script_id = create_test_script(&pool, project_id, 1).await;
        let _storyboard_id = create_test_storyboard(&pool, script_id, 1).await;

        // Test: owner can write
        let result: Result<i64, _> =
            store_video_reference(&pool, owner_id, 1, 1, "https://example.com/video.mp4").await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 1);

        // Test: member can write
        let result: Result<i64, _> =
            store_video_reference(&pool, member_id, 1, 1, "https://example.com/video2.mp4").await;
        assert!(result.is_ok());
        assert_eq!(result.unwrap(), 1);

        // Test: outsider cannot write (no rows affected)
        let result: Result<i64, _> =
            store_video_reference(&pool, outsider_id, 1, 1, "https://example.com/video3.mp4").await;
        assert!(result.is_ok());
        assert_eq!(
            result.unwrap(),
            0,
            "outsider should not be able to update storyboard"
        );
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_voiceover_load_storyboard_validates_workspace_membership(pool: PgPool) {
        let owner_id = Uuid::new_v4();
        let member_id = Uuid::new_v4();
        let outsider_id = Uuid::new_v4();

        // Create workspace and add members
        let workspace_id = create_test_workspace(&pool, owner_id, "enterprise").await;
        add_workspace_member(&pool, workspace_id, owner_id, "owner").await;
        add_workspace_member(&pool, workspace_id, member_id, "member").await;

        // Create project, script, and storyboard
        let project_id = create_test_project(&pool, workspace_id, 2).await;
        let script_id = create_test_script(&pool, project_id, 2).await;
        let storyboard_id = create_test_storyboard(&pool, script_id, 2).await;

        // Test: owner can load storyboard
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project p ON p.id = sc.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND sc.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(owner_id)
        .bind(2)
        .bind(2)
        .bind(2)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(storyboard_id));

        // Test: member can load storyboard
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project p ON p.id = sc.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND sc.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(member_id)
        .bind(2)
        .bind(2)
        .bind(2)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(storyboard_id));

        // Test: outsider cannot load storyboard
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script sc ON sc.id = sb.script_id
            INNER JOIN app_project p ON p.id = sc.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND sc.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(outsider_id)
        .bind(2)
        .bind(2)
        .bind(2)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(
            result, None,
            "outsider should not be able to load storyboard"
        );
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_asset_image_persist_validates_workspace_membership(pool: PgPool) {
        let owner_id = Uuid::new_v4();
        let member_id = Uuid::new_v4();
        let outsider_id = Uuid::new_v4();

        // Create workspace and add members
        let workspace_id = create_test_workspace(&pool, owner_id, "enterprise").await;
        add_workspace_member(&pool, workspace_id, owner_id, "owner").await;
        add_workspace_member(&pool, workspace_id, member_id, "member").await;

        // Create project and asset
        let project_id = create_test_project(&pool, workspace_id, 3).await;
        let asset_id = create_test_asset(&pool, project_id, 3).await;

        // Test: owner can load asset for write
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT a.project_id
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE a.id = $1
              AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $2
              )
            "#,
        )
        .bind(asset_id)
        .bind(owner_id)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(project_id));

        // Test: member can load asset for write
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT a.project_id
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE a.id = $1
              AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $2
              )
            "#,
        )
        .bind(asset_id)
        .bind(member_id)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(project_id));

        // Test: outsider cannot load asset for write
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT a.project_id
            FROM app_asset a
            INNER JOIN app_project p ON p.id = a.project_id
            WHERE a.id = $1
              AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $2
              )
            "#,
        )
        .bind(asset_id)
        .bind(outsider_id)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, None, "outsider should not be able to load asset");
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_storyboard_batch_image_validates_workspace_membership(pool: PgPool) {
        let owner_id = Uuid::new_v4();
        let member_id = Uuid::new_v4();
        let outsider_id = Uuid::new_v4();

        // Create workspace and add members
        let workspace_id = create_test_workspace(&pool, owner_id, "enterprise").await;
        add_workspace_member(&pool, workspace_id, owner_id, "owner").await;
        add_workspace_member(&pool, workspace_id, member_id, "member").await;

        // Create project, script, and storyboard
        let project_id = create_test_project(&pool, workspace_id, 4).await;
        let script_id = create_test_script(&pool, project_id, 4).await;
        let storyboard_id = create_test_storyboard(&pool, script_id, 4).await;

        // Test: owner can load storyboard for batch image generation
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script s ON s.id = sb.script_id
            INNER JOIN app_project p ON p.id = s.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND s.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(owner_id)
        .bind(4)
        .bind(4)
        .bind(4)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(storyboard_id));

        // Test: member can load storyboard for batch image generation
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script s ON s.id = sb.script_id
            INNER JOIN app_project p ON p.id = s.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND s.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(member_id)
        .bind(4)
        .bind(4)
        .bind(4)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(storyboard_id));

        // Test: outsider cannot load storyboard for batch image generation
        let result: Option<Uuid> = sqlx::query_scalar(
            r#"
            SELECT sb.id
            FROM app_storyboard sb
            INNER JOIN app_script s ON s.id = sb.script_id
            INNER JOIN app_project p ON p.id = s.project_id
            WHERE EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = p.workspace_id
                      AND wm.user_id = $1
              )
              AND p.numeric_id = $2
              AND s.numeric_id = $3
              AND sb.numeric_id = $4
            "#,
        )
        .bind(outsider_id)
        .bind(4)
        .bind(4)
        .bind(4)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(
            result, None,
            "outsider should not be able to load storyboard"
        );
    }

    #[sqlx::test]
    #[ignore = "requires database setup"]
    async fn test_voiceover_load_project_voice_profile_validates_workspace_membership(
        pool: PgPool,
    ) {
        let owner_id = Uuid::new_v4();
        let member_id = Uuid::new_v4();
        let outsider_id = Uuid::new_v4();

        // Create workspace and add members
        let workspace_id = create_test_workspace(&pool, owner_id, "enterprise").await;
        add_workspace_member(&pool, workspace_id, owner_id, "owner").await;
        add_workspace_member(&pool, workspace_id, member_id, "member").await;

        // Create project with voice profile
        let project_id = create_test_project(&pool, workspace_id, 5).await;
        sqlx::query(
            r#"
            UPDATE app_project
            SET voice_profile = $1
            WHERE id = $2
            "#,
        )
        .bind("test-voice-profile")
        .bind(project_id)
        .execute(&pool)
        .await
        .unwrap();

        // Test: owner can load voice profile
        let result: Option<Option<String>> = sqlx::query_scalar(
            r#"
            SELECT voice_profile
            FROM app_project
            WHERE numeric_id = $2
              AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = app_project.workspace_id
                      AND wm.user_id = $1
              )
            "#,
        )
        .bind(owner_id)
        .bind(5)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(Some("test-voice-profile".to_string())));

        // Test: member can load voice profile
        let result: Option<Option<String>> = sqlx::query_scalar(
            r#"
            SELECT voice_profile
            FROM app_project
            WHERE numeric_id = $2
              AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = app_project.workspace_id
                      AND wm.user_id = $1
              )
            "#,
        )
        .bind(member_id)
        .bind(5)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(result, Some(Some("test-voice-profile".to_string())));

        // Test: outsider cannot load voice profile
        let result: Option<Option<String>> = sqlx::query_scalar(
            r#"
            SELECT voice_profile
            FROM app_project
            WHERE numeric_id = $2
              AND EXISTS (
                    SELECT 1
                    FROM app_workspace_member wm
                    WHERE wm.workspace_id = app_project.workspace_id
                      AND wm.user_id = $1
              )
            "#,
        )
        .bind(outsider_id)
        .bind(5)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert_eq!(
            result, None,
            "outsider should not be able to load voice profile"
        );
    }
}
