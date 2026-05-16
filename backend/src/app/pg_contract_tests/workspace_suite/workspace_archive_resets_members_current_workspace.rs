//! Test: workspace archive resets all members' current_workspace_id to personal workspace
//!
//! Validates that when a workspace is archived, ALL members' `current_workspace_id`
//! automatically resets to their personal workspace if it was pointing to the archived workspace.
//!
//! This ensures users don't have a dangling reference to an archived workspace they can no longer access.

use super::super::*;
use crate::workspaces::ensure_personal_workspace;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; supabase db reset; cargo test workspace_archive_resets_members_current_workspace -- --ignored"]
async fn workspace_archive_resets_members_current_workspace() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create test users
    let owner_id = Uuid::new_v4();
    let admin_id = Uuid::new_v4();
    let member_id = Uuid::new_v4();
    let other_user_id = Uuid::new_v4(); // User not in the workspace

    // Insert test users into auth.users
    for user_id in &[owner_id, admin_id, member_id, other_user_id] {
        sqlx::query(
            r#"
            INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
            VALUES ($1, $2, 'fake-hash', NOW(), NOW(), NOW())
            ON CONFLICT (id) DO NOTHING
            "#,
        )
        .bind(user_id)
        .bind(format!("test-{}@example.com", user_id))
        .execute(&pool)
        .await
        .expect("insert test user");
    }

    // Ensure personal workspaces exist for all users
    let owner_personal = ensure_personal_workspace(&pool, owner_id)
        .await
        .expect("ensure owner personal workspace");
    let admin_personal = ensure_personal_workspace(&pool, admin_id)
        .await
        .expect("ensure admin personal workspace");
    let member_personal = ensure_personal_workspace(&pool, member_id)
        .await
        .expect("ensure member personal workspace");
    let other_personal = ensure_personal_workspace(&pool, other_user_id)
        .await
        .expect("ensure other user personal workspace");

    // Create enterprise workspace owned by owner_id
    let enterprise_ws = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, metadata)
        VALUES ($1, $2, 'Test Enterprise Workspace', 'enterprise', '{}')
        "#,
    )
    .bind(enterprise_ws)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("create enterprise workspace");

    // Add owner, admin, and member to enterprise workspace
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(enterprise_ws)
    .bind(owner_id)
    .bind("owner")
    .execute(&pool)
    .await
    .expect("add owner to enterprise workspace");

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(enterprise_ws)
    .bind(admin_id)
    .bind("admin")
    .execute(&pool)
    .await
    .expect("add admin to enterprise workspace");

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(enterprise_ws)
    .bind(member_id)
    .bind("member")
    .execute(&pool)
    .await
    .expect("add member to enterprise workspace");

    // Set all members' current_workspace_id to the enterprise workspace
    for user_id in &[owner_id, admin_id, member_id] {
        sqlx::query(
            r#"
            INSERT INTO public.app_user_profile (user_id, current_workspace_id, updated_at)
            VALUES ($1, $2, NOW())
            ON CONFLICT (user_id) DO UPDATE
            SET current_workspace_id = EXCLUDED.current_workspace_id,
                updated_at = NOW()
            "#,
        )
        .bind(user_id)
        .bind(enterprise_ws)
        .execute(&pool)
        .await
        .expect("set user's current_workspace_id to enterprise");
    }

    // Set other_user's current_workspace_id to their personal workspace (should not be affected)
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET current_workspace_id = EXCLUDED.current_workspace_id,
            updated_at = NOW()
        "#,
    )
    .bind(other_user_id)
    .bind(other_personal.workspace_id)
    .execute(&pool)
    .await
    .expect("set other user's current_workspace_id to personal");

    // Verify all members' current_workspace_id is set to enterprise workspace before archiving
    for user_id in &[owner_id, admin_id, member_id] {
        let current_ws_before: Option<Uuid> = sqlx::query_scalar(
            "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
        )
        .bind(user_id)
        .fetch_optional(&pool)
        .await
        .expect("fetch current_workspace_id before archiving")
        .flatten();

        assert_eq!(
            current_ws_before,
            Some(enterprise_ws),
            "user {}'s current_workspace_id should be enterprise workspace before archiving",
            user_id
        );
    }

    // Verify other_user's current_workspace_id is still their personal workspace
    let other_current_ws_before: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(other_user_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch other user's current_workspace_id before archiving")
    .flatten();

    assert_eq!(
        other_current_ws_before,
        Some(other_personal.workspace_id),
        "other user's current_workspace_id should remain their personal workspace"
    );

    // Create token for owner to archive the workspace
    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // ========== Test: Owner archives the enterprise workspace ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/workspaces/{}", enterprise_ws))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(r#"{"archive": true}"#))
                .unwrap(),
        )
        .await
        .unwrap();

    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "owner should be able to archive workspace: {:?}",
        body
    );

    // ========== Verify: All members' current_workspace_id is reset to their personal workspace ==========
    let owner_current_ws_after: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(owner_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch owner's current_workspace_id after archiving")
    .flatten();

    assert_eq!(
        owner_current_ws_after,
        Some(owner_personal.workspace_id),
        "owner's current_workspace_id should be reset to personal workspace after archiving"
    );

    let admin_current_ws_after: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(admin_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch admin's current_workspace_id after archiving")
    .flatten();

    assert_eq!(
        admin_current_ws_after,
        Some(admin_personal.workspace_id),
        "admin's current_workspace_id should be reset to personal workspace after archiving"
    );

    let member_current_ws_after: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(member_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch member's current_workspace_id after archiving")
    .flatten();

    assert_eq!(
        member_current_ws_after,
        Some(member_personal.workspace_id),
        "member's current_workspace_id should be reset to personal workspace after archiving"
    );

    // ========== Verify: Other user's current_workspace_id is unchanged ==========
    let other_current_ws_after: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(other_user_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch other user's current_workspace_id after archiving")
    .flatten();

    assert_eq!(
        other_current_ws_after,
        Some(other_personal.workspace_id),
        "other user's current_workspace_id should remain unchanged"
    );

    // ========== Verify: Workspace is archived ==========
    let archived_at: Option<chrono::DateTime<chrono::Utc>> =
        sqlx::query_scalar("SELECT archived_at FROM public.app_workspace WHERE id = $1")
            .bind(enterprise_ws)
            .fetch_optional(&pool)
            .await
            .expect("fetch workspace archived_at")
            .flatten();

    assert!(
        archived_at.is_some(),
        "workspace should be archived (archived_at should be set)"
    );

    // ========== Verify: Members are still in the workspace (archiving doesn't remove members) ==========
    let member_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*)::bigint FROM public.app_workspace_member WHERE workspace_id = $1",
    )
    .bind(enterprise_ws)
    .fetch_one(&pool)
    .await
    .expect("count workspace members");

    assert_eq!(
        member_count, 3,
        "all members should still be in the workspace after archiving"
    );

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(enterprise_ws)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(enterprise_ws)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = ANY($1)")
        .bind(vec![
            owner_personal.workspace_id,
            admin_personal.workspace_id,
            member_personal.workspace_id,
            other_personal.workspace_id,
        ])
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = ANY($1)")
        .bind(vec![owner_id, admin_id, member_id, other_user_id])
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind(vec![owner_id, admin_id, member_id, other_user_id])
        .execute(&pool)
        .await;
}
