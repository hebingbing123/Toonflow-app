//! Integration test for webhook dual-write (Task 4.1, 4.2).
//!
//! Verifies that billing webhooks with workspace_id update both:
//! - app_user_profile (legacy user-scope billing)
//! - app_workspace (new workspace-scope billing)
//!
//! Tests Requirements 5.1, 5.2, 5.3:
//! - 5.1: Dual-write to workspace billing record
//! - 5.2: Preserve idempotency (duplicate events don't double-write)
//! - 5.3: Reconciliation detects mismatches

use super::super::*;
use serde_json::json;
use tower::ServiceExt;

#[tokio::test]
#[ignore = "needs DATABASE_URL + BILLING_WEBHOOK_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn billing_webhook_dual_write_personal_workspace() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");
    let webhook_secret =
        std::env::var("BILLING_WEBHOOK_SECRET").expect("BILLING_WEBHOOK_SECRET for webhook HMAC");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create test user
    let user_id = Uuid::new_v4();
    let _user_sub = user_id.to_string();
    let _token = jwt_fixture::encode_supabase_style(user_id, secret.as_bytes());

    // Insert user profile
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, plan_tier, created_at, updated_at)
        VALUES ($1, 'free', NOW(), NOW())
        "#,
    )
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("insert user profile");

    // Create personal workspace for user
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (
            id, owner_user_id, workspace_type, name, created_at, updated_at
        )
        VALUES ($1, $2, 'personal', 'Test Personal Workspace', NOW(), NOW())
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("insert personal workspace");

    // Build app with webhook secret
    let app = build_router(contract_state(pool.clone(), secret));

    // Create webhook payload with workspace_id
    let event_id = format!("evt_test_dual_write_{}", Uuid::new_v4().simple());
    let payload = json!({
        "id": event_id,
        "user_id": user_id.to_string(),
        "workspace_id": workspace_id.to_string(),
        "plan_tier": "pro",
        "type": "customer.subscription.updated",
        "subscription_status": "active",
        "subscription_current_period_end": "2026-12-31T23:59:59Z"
    });

    let payload_bytes = serde_json::to_vec(&payload).unwrap();

    // Compute HMAC signature
    use hmac::{Hmac, Mac};
    use sha2::Sha256;
    type HmacSha256 = Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(webhook_secret.as_bytes()).unwrap();
    mac.update(&payload_bytes);
    let signature = hex::encode(mac.finalize().into_bytes());

    // Send webhook
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/webhooks/billing")
                .method("POST")
                .header(header::CONTENT_TYPE, "application/json")
                .header("X-Toonflow-Signature", signature)
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload_bytes.clone()))
                .unwrap(),
        )
        .await
        .unwrap();

    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "webhook response: {body}");
    assert_eq!(body["received"], true);
    assert_eq!(body["duplicate"], false);
    assert_eq!(body["profile_updated"], true);

    // Verify user profile was updated
    let user_row: (String, Option<String>, Option<String>) = sqlx::query_as(
        r#"
        SELECT plan_tier, billing_provider, subscription_status
        FROM app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .expect("fetch user profile");

    assert_eq!(
        user_row.0, "pro",
        "user profile plan_tier should be updated"
    );
    assert_eq!(
        user_row.2,
        Some("active".to_string()),
        "user profile subscription_status should be updated"
    );

    // Verify workspace billing was updated (dual-write)
    let workspace_row: (Option<String>, Option<String>) = sqlx::query_as(
        r#"
        SELECT plan_tier, billing_provider
        FROM app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_one(&pool)
    .await
    .expect("fetch workspace");

    assert_eq!(
        workspace_row.0,
        Some("pro".to_string()),
        "workspace plan_tier should be updated via dual-write"
    );

    // Test idempotency: send same webhook again
    let mut mac2 = HmacSha256::new_from_slice(webhook_secret.as_bytes()).unwrap();
    mac2.update(&payload_bytes);
    let signature2 = hex::encode(mac2.finalize().into_bytes());

    let res2 = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/webhooks/billing")
                .method("POST")
                .header(header::CONTENT_TYPE, "application/json")
                .header("X-Toonflow-Signature", signature2)
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload_bytes))
                .unwrap(),
        )
        .await
        .unwrap();

    let (status2, body2) = read_json_response(res2).await;
    assert_eq!(
        status2,
        StatusCode::OK,
        "duplicate webhook response: {body2}"
    );
    assert_eq!(body2["received"], true);
    assert_eq!(body2["duplicate"], true, "should detect duplicate event");
    assert!(
        body2["profile_updated"].is_null(),
        "profile_updated should be null for duplicates"
    );

    // Verify reconciliation detects no mismatches
    let mismatches = crate::billing::check_personal_workspace_billing_consistency(&pool, user_id)
        .await
        .expect("reconciliation check");

    assert_eq!(
        mismatches.len(),
        0,
        "reconciliation should find no mismatches after dual-write"
    );

    // Cleanup
    sqlx::query("DELETE FROM app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
        .bind(user_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_billing_webhook_event WHERE provider_event_id LIKE 'stripe:evt_test_dual_write_%'")
        .execute(&pool)
        .await
        .ok();
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + BILLING_WEBHOOK_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn billing_webhook_without_workspace_id_only_updates_user() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");
    let webhook_secret =
        std::env::var("BILLING_WEBHOOK_SECRET").expect("BILLING_WEBHOOK_SECRET for webhook HMAC");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create test user
    let user_id = Uuid::new_v4();
    let _token = jwt_fixture::encode_supabase_style(user_id, secret.as_bytes());

    // Insert user profile
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, plan_tier, created_at, updated_at)
        VALUES ($1, 'free', NOW(), NOW())
        "#,
    )
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("insert user profile");

    // Create personal workspace for user
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (
            id, owner_user_id, workspace_type, name, created_at, updated_at
        )
        VALUES ($1, $2, 'personal', 'Test Personal Workspace', NOW(), NOW())
        "#,
    )
    .bind(workspace_id)
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("insert personal workspace");

    // Build app with webhook secret
    let app = build_router(contract_state(pool.clone(), secret));

    // Create webhook payload WITHOUT workspace_id
    let event_id = format!("evt_test_no_workspace_{}", Uuid::new_v4().simple());
    let payload = json!({
        "id": event_id,
        "user_id": user_id.to_string(),
        // NO workspace_id field
        "plan_tier": "premium",
        "type": "customer.subscription.updated"
    });

    let payload_bytes = serde_json::to_vec(&payload).unwrap();

    // Compute HMAC signature
    use hmac::{Hmac, Mac};
    use sha2::Sha256;
    type HmacSha256 = Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(webhook_secret.as_bytes()).unwrap();
    mac.update(&payload_bytes);
    let signature = hex::encode(mac.finalize().into_bytes());

    // Send webhook
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/webhooks/billing")
                .method("POST")
                .header(header::CONTENT_TYPE, "application/json")
                .header("X-Toonflow-Signature", signature)
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload_bytes))
                .unwrap(),
        )
        .await
        .unwrap();

    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "webhook response: {body}");
    assert_eq!(body["received"], true);
    assert_eq!(body["profile_updated"], true);

    // Verify user profile was updated
    let user_row: (String,) = sqlx::query_as(
        r#"
        SELECT plan_tier
        FROM app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .expect("fetch user profile");

    assert_eq!(
        user_row.0, "premium",
        "user profile plan_tier should be updated"
    );

    // Verify workspace billing was NOT updated (no workspace_id in webhook)
    let workspace_row: (Option<String>,) = sqlx::query_as(
        r#"
        SELECT plan_tier
        FROM app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_one(&pool)
    .await
    .expect("fetch workspace");

    assert_eq!(
        workspace_row.0, None,
        "workspace plan_tier should remain NULL when webhook has no workspace_id"
    );

    // Cleanup
    sqlx::query("DELETE FROM app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
        .bind(user_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_billing_webhook_event WHERE provider_event_id LIKE 'stripe:evt_test_no_workspace_%'")
        .execute(&pool)
        .await
        .ok();
}

#[tokio::test]
#[ignore = "needs DATABASE_URL + BILLING_WEBHOOK_SECRET and migrated schema; e.g. supabase db reset; cargo test pg_contract_tests -- --ignored"]
async fn billing_webhook_unauthorized_workspace_skips_workspace_update() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");
    let webhook_secret =
        std::env::var("BILLING_WEBHOOK_SECRET").expect("BILLING_WEBHOOK_SECRET for webhook HMAC");

    let pool = PgPoolOptions::new()
        .max_connections(3)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    // Create test user
    let user_id = Uuid::new_v4();
    let _token = jwt_fixture::encode_supabase_style(user_id, secret.as_bytes());

    // Insert user profile
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, plan_tier, created_at, updated_at)
        VALUES ($1, 'free', NOW(), NOW())
        "#,
    )
    .bind(user_id)
    .execute(&pool)
    .await
    .expect("insert user profile");

    // Create workspace owned by DIFFERENT user
    let other_user_id = Uuid::new_v4();
    let workspace_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO public.app_user_profile (user_id, plan_tier, created_at, updated_at)
        VALUES ($1, 'free', NOW(), NOW())
        "#,
    )
    .bind(other_user_id)
    .execute(&pool)
    .await
    .expect("insert other user profile");

    sqlx::query(
        r#"
        INSERT INTO public.app_workspace (
            id, owner_user_id, workspace_type, name, created_at, updated_at
        )
        VALUES ($1, $2, 'personal', 'Other User Workspace', NOW(), NOW())
        "#,
    )
    .bind(workspace_id)
    .bind(other_user_id)
    .execute(&pool)
    .await
    .expect("insert workspace for other user");

    // Build app with webhook secret
    let app = build_router(contract_state(pool.clone(), secret));

    // Create webhook payload with workspace_id that user doesn't own
    let event_id = format!("evt_test_unauthorized_{}", Uuid::new_v4().simple());
    let payload = json!({
        "id": event_id,
        "user_id": user_id.to_string(),
        "workspace_id": workspace_id.to_string(), // workspace owned by other_user_id
        "plan_tier": "enterprise",
        "type": "customer.subscription.updated"
    });

    let payload_bytes = serde_json::to_vec(&payload).unwrap();

    // Compute HMAC signature
    use hmac::{Hmac, Mac};
    use sha2::Sha256;
    type HmacSha256 = Hmac<Sha256>;
    let mut mac = HmacSha256::new_from_slice(webhook_secret.as_bytes()).unwrap();
    mac.update(&payload_bytes);
    let signature = hex::encode(mac.finalize().into_bytes());

    // Send webhook
    let res = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/webhooks/billing")
                .method("POST")
                .header(header::CONTENT_TYPE, "application/json")
                .header("X-Toonflow-Signature", signature)
                .extension(ConnectInfo(test_addr()))
                .body(Body::from(payload_bytes))
                .unwrap(),
        )
        .await
        .unwrap();

    let (status, body) = read_json_response(res).await;
    assert_eq!(status, StatusCode::OK, "webhook response: {body}");
    assert_eq!(body["received"], true);
    assert_eq!(body["profile_updated"], true);

    // Verify user profile was updated
    let user_row: (String,) = sqlx::query_as(
        r#"
        SELECT plan_tier
        FROM app_user_profile
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .expect("fetch user profile");

    assert_eq!(
        user_row.0, "enterprise",
        "user profile plan_tier should be updated"
    );

    // Verify workspace billing was NOT updated (user not authorized)
    let workspace_row: (Option<String>,) = sqlx::query_as(
        r#"
        SELECT plan_tier
        FROM app_workspace
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .fetch_one(&pool)
    .await
    .expect("fetch workspace");

    assert_eq!(
        workspace_row.0, None,
        "workspace plan_tier should remain NULL when user not authorized"
    );

    // Cleanup
    sqlx::query("DELETE FROM app_workspace WHERE id = $1")
        .bind(workspace_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
        .bind(user_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_user_profile WHERE user_id = $1")
        .bind(other_user_id)
        .execute(&pool)
        .await
        .ok();
    sqlx::query("DELETE FROM app_billing_webhook_event WHERE provider_event_id LIKE 'stripe:evt_test_unauthorized_%'")
        .execute(&pool)
        .await
        .ok();
}
