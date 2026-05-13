//! Test: member removal resets current_workspace_id to personal workspace
//!
//! Validates that when a user is removed from a workspace (by admin/owner),
//! their `current_workspace_id` automatically resets to their personal workspace.
//!
//! This ensures users don't have a dangling reference to a workspace they're no longer a member of.

use super::super::*;
use crate::workspaces::ensure_personal_workspace;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; supabase db reset; cargo test member_removal_resets_current_workspace -- --ignored"]
async fn member_removal_resets_current_workspace() {
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
    let member_id = Uuid::new_v4();

    // Insert test users into auth.users
    for user_id in &[owner_id, member_id] {
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

    // Ensure personal workspaces exist for both users
    let owner_personal = ensure_personal_workspace(&pool, owner_id)
        .await
        .expect("ensure owner personal workspace");
    let member_personal = ensure_personal_workspace(&pool, member_id)
        .await
        .expect("ensure member personal workspace");

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

    // Add owner and member to enterprise workspace
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
    .bind(member_id)
    .bind("member")
    .execute(&pool)
    .await
    .expect("add member to enterprise workspace");

    // Set member's current_workspace_id to the enterprise workspace
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, current_workspace_id, updated_at)
        VALUES ($1, $2, NOW())
        ON CONFLICT (user_id) DO UPDATE
        SET current_workspace_id = EXCLUDED.current_workspace_id,
            updated_at = NOW()
        "#,
    )
    .bind(member_id)
    .bind(enterprise_ws)
    .execute(&pool)
    .await
    .expect("set member's current_workspace_id to enterprise");

    // Verify member's current_workspace_id is set to enterprise workspace
    let current_ws_before: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(member_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch current_workspace_id before removal")
    .flatten();

    assert_eq!(
        current_ws_before,
        Some(enterprise_ws),
        "member's current_workspace_id should be enterprise workspace before removal"
    );

    // Create tokens
    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // ========== Test: Owner removes member from enterprise workspace ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    enterprise_ws, member_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();

    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "owner should be able to remove member: {:?}",
        body
    );

    // ========== Verify: Member's current_workspace_id is reset to personal workspace ==========
    let current_ws_after: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(member_id)
    .fetch_optional(&pool)
    .await
    .expect("fetch current_workspace_id after removal")
    .flatten();

    assert_eq!(
        current_ws_after,
        Some(member_personal.workspace_id),
        "member's current_workspace_id should be reset to personal workspace after removal"
    );

    // ========== Verify: Member is no longer in enterprise workspace ==========
    let member_exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM public.app_workspace_member WHERE workspace_id = $1 AND user_id = $2)",
    )
    .bind(enterprise_ws)
    .bind(member_id)
    .fetch_one(&pool)
    .await
    .expect("check member existence");

    assert!(
        !member_exists,
        "member should no longer be in enterprise workspace"
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
            member_personal.workspace_id,
        ])
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_user_profile WHERE user_id = ANY($1)")
        .bind(vec![owner_id, member_id])
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind(vec![owner_id, member_id])
        .execute(&pool)
        .await;
}
