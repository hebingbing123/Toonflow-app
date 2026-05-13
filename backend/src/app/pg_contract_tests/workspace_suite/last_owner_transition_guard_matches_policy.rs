//! Last owner transition guard test
//!
//! Validates that the last owner of a workspace cannot be downgraded to admin/member or removed,
//! ensuring workspace always has at least one owner.
//!
//! This test verifies the policy documented in workspace-project-permission-policy.md:
//! - A workspace must always have at least one owner
//! - The last owner cannot be demoted to admin or member
//! - The last owner cannot be removed from the workspace
//! - Multiple owners can be demoted/removed as long as at least one owner remains

use super::super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; supabase db reset; cargo test last_owner_transition_guard_matches_policy -- --ignored"]
async fn last_owner_transition_guard_matches_policy() {
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
    let owner1_id = Uuid::new_v4();
    let owner2_id = Uuid::new_v4();
    let admin_id = Uuid::new_v4();

    // Insert test users into auth.users
    for user_id in &[owner1_id, owner2_id, admin_id] {
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

    // Create enterprise workspace owned by owner1_id
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, metadata)
        VALUES ($1, $2, 'Test Last Owner Workspace', 'enterprise', '{}')
        "#,
    )
    .bind(workspace_id)
    .bind(owner1_id)
    .execute(&pool)
    .await
    .expect("create test workspace");

    // Add owner1 as the only owner initially
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, 'owner')
        "#,
    )
    .bind(workspace_id)
    .bind(owner1_id)
    .execute(&pool)
    .await
    .expect("add owner1");

    // Add admin
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, 'admin')
        "#,
    )
    .bind(workspace_id)
    .bind(admin_id)
    .execute(&pool)
    .await
    .expect("add admin");

    // Create tokens
    let owner1_token = jwt_fixture::encode_supabase_style(owner1_id, secret.as_bytes());
    let owner2_token = jwt_fixture::encode_supabase_style(owner2_id, secret.as_bytes());
    let admin_token = jwt_fixture::encode_supabase_style(admin_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // ========== Test 1: Cannot demote the last owner to admin ==========
    let demote_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner1_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(demote_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "should not be able to demote the last owner to admin: {:?}",
        body
    );
    assert!(
        body["message"]
            .as_str()
            .unwrap_or("")
            .contains("cannot demote the last workspace owner"),
        "error message should mention last owner: {:?}",
        body
    );

    // ========== Test 2: Cannot demote the last owner to member ==========
    let demote_body = serde_json::json!({
        "role": "member"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner1_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(demote_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "should not be able to demote the last owner to member: {:?}",
        body
    );
    assert!(
        body["message"]
            .as_str()
            .unwrap_or("")
            .contains("cannot demote the last workspace owner"),
        "error message should mention last owner: {:?}",
        body
    );

    // ========== Test 3: Cannot remove the last owner ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner1_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "should not be able to remove the last owner: {:?}",
        body
    );
    assert!(
        body["message"]
            .as_str()
            .unwrap_or("")
            .contains("cannot remove the last workspace owner"),
        "error message should mention last owner: {:?}",
        body
    );

    // ========== Test 4: Admin cannot demote the last owner ==========
    let demote_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", admin_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(demote_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "admin should not be able to demote the last owner: {:?}",
        body
    );

    // ========== Test 5: Admin cannot remove the last owner ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", admin_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "admin should not be able to remove the last owner: {:?}",
        body
    );

    // ========== Test 6: Add a second owner directly via database ==========
    // Note: The API doesn't allow adding owners directly (requires transfer flow),
    // so we add the second owner directly to the database for testing purposes
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, 'owner')
        "#,
    )
    .bind(workspace_id)
    .bind(owner2_id)
    .execute(&pool)
    .await
    .expect("add owner2 directly to database");

    // ========== Test 7: Can demote owner1 when there are 2 owners ==========
    let demote_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner1_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(demote_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "should be able to demote owner1 when there are 2 owners: {:?}",
        body
    );
    assert_eq!(
        body["role"].as_str().unwrap(),
        "admin",
        "owner1 should now be admin: {:?}",
        body
    );

    // ========== Test 8: Cannot demote the last remaining owner (owner2) ==========
    let demote_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner2_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner2_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(demote_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "should not be able to demote owner2 when they are the last owner: {:?}",
        body
    );

    // ========== Test 9: Restore owner1 back to owner via database ==========
    // Note: The API doesn't allow promoting to owner (requires transfer flow),
    // so we update the role directly in the database for testing purposes
    sqlx::query(
        r#"
        UPDATE public.app_workspace_member
        SET role = 'owner', updated_at = NOW()
        WHERE workspace_id = $1 AND user_id = $2
        "#,
    )
    .bind(workspace_id)
    .bind(owner1_id)
    .execute(&pool)
    .await
    .expect("restore owner1 to owner role");

    // ========== Test 10: Can remove owner2 when there are 2 owners ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner2_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner1_token))
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
        "should be able to remove owner2 when there are 2 owners: {:?}",
        body
    );

    // ========== Test 11: Verify owner1 is now the last owner again ==========
    let demote_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, owner1_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner1_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(demote_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::CONFLICT,
        "should not be able to demote owner1 after owner2 is removed: {:?}",
        body
    );

    // Cleanup
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind(vec![owner1_id, owner2_id, admin_id])
        .execute(&pool)
        .await;
}
