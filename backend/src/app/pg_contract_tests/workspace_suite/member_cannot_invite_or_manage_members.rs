//! Member role boundary test: member cannot invite or manage members
//!
//! Validates that member users have proper permission boundaries:
//! - Member cannot invite new members to workspace (admin/owner privilege)
//! - Member cannot add members to workspace (admin/owner privilege)
//! - Member cannot remove members from workspace (admin/owner privilege)
//! - Member cannot manage member roles (admin/owner privilege)
//! - Member can perform basic operations like create projects
//!
//! This test verifies the policy documented in workspace-project-permission-policy.md:
//! - Only workspace owners and admins can manage workspace membership
//! - Member role is limited to project-level operations within the workspace

use super::super::*;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; supabase db reset; cargo test member_cannot_invite_or_manage_members -- --ignored"]
async fn member_cannot_invite_or_manage_members() {
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
    let target_user_id = Uuid::new_v4();
    let outsider_id = Uuid::new_v4();

    // Insert test users into auth.users
    for user_id in &[owner_id, admin_id, member_id, target_user_id, outsider_id] {
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

    // Create enterprise workspace owned by owner_id
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (id, owner_user_id, name, workspace_type, metadata)
        VALUES ($1, $2, 'Test Enterprise Workspace', 'enterprise', '{}')
        "#,
    )
    .bind(workspace_id)
    .bind(owner_id)
    .execute(&pool)
    .await
    .expect("create test workspace");

    // Add members with different roles
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(workspace_id)
    .bind(owner_id)
    .bind("owner")
    .execute(&pool)
    .await
    .expect("add owner");

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(workspace_id)
    .bind(admin_id)
    .bind("admin")
    .execute(&pool)
    .await
    .expect("add admin");

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(workspace_id)
    .bind(member_id)
    .bind("member")
    .execute(&pool)
    .await
    .expect("add member");

    // Add target_user_id as a member to test role changes
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, $3)
        "#,
    )
    .bind(workspace_id)
    .bind(target_user_id)
    .bind("member")
    .execute(&pool)
    .await
    .expect("add target member");

    // Create tokens for each user
    let owner_token = jwt_fixture::encode_supabase_style(owner_id, secret.as_bytes());
    let admin_token = jwt_fixture::encode_supabase_style(admin_id, secret.as_bytes());
    let member_token = jwt_fixture::encode_supabase_style(member_id, secret.as_bytes());
    let _outsider_token = jwt_fixture::encode_supabase_style(outsider_id, secret.as_bytes());

    let app = build_router(contract_state(pool.clone(), secret.clone()));

    // ========== Test 1: Member cannot invite new members via email ==========
    let invite_body = serde_json::json!({
        "email": "member-invite@example.com",
        "role": "member"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/workspaces/{}/invites", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(invite_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to invite new members via email: {:?}",
        body
    );

    // ========== Test 2: Member cannot add existing users as members ==========
    let add_member_body = serde_json::json!({
        "user_id": outsider_id,
        "role": "member"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/workspaces/{}/members", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(add_member_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to add existing users as members: {:?}",
        body
    );

    // ========== Test 3: Member cannot remove other members ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, target_user_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to remove other members: {:?}",
        body
    );

    // ========== Test 4: Member cannot change other members' roles ==========
    let update_role_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, target_user_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(update_role_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to change other members' roles: {:?}",
        body
    );

    // ========== Test 5: Member cannot revoke workspace invites ==========
    // First, create an invite as owner to have something to revoke
    let invite_body = serde_json::json!({
        "email": "test-invite@example.com",
        "role": "member"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/workspaces/{}/invites", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(invite_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "owner create invite: {:?}", body);
    let invite_id = body["id"].as_str().expect("invite id");

    // Now try to revoke as member
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!(
                    "/api/v1/workspaces/{}/invites/{}",
                    workspace_id, invite_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to revoke workspace invites: {:?}",
        body
    );

    // ========== Test 6: Member cannot resend workspace invites ==========
    let resend_body = serde_json::json!({
        "expires_in_hours": 168
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/workspaces/{}/invites/{}/resend",
                    workspace_id, invite_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(resend_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to resend workspace invites: {:?}",
        body
    );

    // ========== Test 7: Verify admin CAN invite members (positive control) ==========
    let admin_invite_body = serde_json::json!({
        "email": "admin-invite@example.com",
        "role": "member"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/workspaces/{}/invites", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", admin_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(admin_invite_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "admin should be able to invite members (positive control): {:?}",
        body
    );

    // ========== Test 8: Verify admin CAN add members (positive control) ==========
    let admin_add_body = serde_json::json!({
        "user_id": outsider_id,
        "role": "member"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/workspaces/{}/members", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", admin_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(admin_add_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "admin should be able to add members (positive control): {:?}",
        body
    );

    // ========== Test 9: Verify admin CAN manage member roles (positive control) ==========
    let admin_role_update_body = serde_json::json!({
        "role": "admin"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!(
                    "/api/v1/workspaces/{}/members/{}",
                    workspace_id, outsider_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", admin_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(admin_role_update_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "admin should be able to manage member roles (positive control): {:?}",
        body
    );

    // ========== Test 10: Member CAN create projects (allowed operation) ==========
    let create_project_body = serde_json::json!({
        "name": "Member's Project",
        "intro": "Created by member to verify basic operations work"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri("/api/v1/projects")
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(create_project_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::OK,
        "member should be able to create projects (allowed operation): {:?}",
        body
    );
    let member_project_id = body["id"].as_str().expect("project id");

    // ========== Test 11: Member CAN view workspace members (read access) ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/workspaces/{}/members", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
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
        "member should be able to view workspace members (read access): {:?}",
        body
    );

    // ========== Test 12: Member CAN view workspace details (read access) ==========
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/workspaces/{}", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
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
        "member should be able to view workspace details (read access): {:?}",
        body
    );

    // ========== Test 13: Member CAN leave workspace (self-management) ==========
    // Note: We won't actually execute this as it would remove the member from the workspace
    // and break subsequent tests. This is tested in other test files.
    // Just verify the endpoint exists and would be accessible
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!("/api/v1/workspaces/{}/leave", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    // This should succeed (member can leave), but we're just testing the permission boundary
    // The actual leave operation is tested in other test files
    assert_eq!(
        status,
        StatusCode::OK,
        "member should be able to leave workspace (self-management): {:?}",
        body
    );

    // Re-add the member since they left in the previous test
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace_member (workspace_id, user_id, role)
        VALUES ($1, $2, 'member')
        ON CONFLICT (workspace_id, user_id) DO NOTHING
        "#,
    )
    .bind(workspace_id)
    .bind(member_id)
    .execute(&pool)
    .await
    .expect("re-add member after leave test");

    // ========== Test 14: Member cannot transfer workspace ownership ==========
    let transfer_body = serde_json::json!({
        "target_user_id": admin_id
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::POST)
                .uri(format!(
                    "/api/v1/workspaces/{}/owner-transfer",
                    workspace_id
                ))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(transfer_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to transfer workspace ownership: {:?}",
        body
    );

    // ========== Test 15: Member cannot modify workspace settings ==========
    let update_workspace_body = serde_json::json!({
        "name": "Member Modified Name"
    });
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::PATCH)
                .uri(format!("/api/v1/workspaces/{}", workspace_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", member_token))
                .header(header::CONTENT_TYPE, "application/json")
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(update_workspace_body.to_string()))
                .unwrap(),
        )
        .await
        .unwrap();
    let (status, body) = read_json_response(res).await;
    assert_eq!(
        status,
        StatusCode::FORBIDDEN,
        "member should NOT be able to modify workspace settings: {:?}",
        body
    );

    // Cleanup - delete the project created by member
    let _ = app
        .clone()
        .oneshot(
            Request::builder()
                .method(Method::DELETE)
                .uri(format!("/api/v1/projects/{}", member_project_id))
                .header(header::AUTHORIZATION, format!("Bearer {}", owner_token))
                .extension(ConnectInfo(test_addr()))
                .body(Body::empty())
                .unwrap(),
        )
        .await;

    // Cleanup database
    let _ = sqlx::query("DELETE FROM public.app_workspace_member WHERE workspace_id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM public.app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await;
    let _ = sqlx::query("DELETE FROM auth.users WHERE id = ANY($1)")
        .bind(vec![
            owner_id,
            admin_id,
            member_id,
            target_user_id,
            outsider_id,
        ])
        .execute(&pool)
        .await;
}
