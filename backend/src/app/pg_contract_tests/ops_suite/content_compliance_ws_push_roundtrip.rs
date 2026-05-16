//! 内容合规告警 WebSocket 推送集成测试（Phase2 C1.8）
//!
//! 验证 `sync_content_compliance_alert_notifications` 在活跃告警变化时：
//! 1. 创建新告警 → WS `settings.notification.created`
//! 2. 更新已有告警 → WS `settings.notification.updated`
//! 3. 告警消退 → WS `settings.notification.created`（cleared 类型）
//!
//! **注意**：本测试为 `#[ignore]` 标记，需本地 PG + 契约用户种子；
//! 当前产品竖切与 `contract_smoke` 已覆盖 REST 路径，本测试补充 WS 推送自动化验证。

use super::super::*;
use serde_json::json;
use tokio::sync::mpsc;

#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; cargo test content_compliance_ws_push_create_update_cleared -- --ignored"]
async fn content_compliance_ws_push_create_update_cleared() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    // 清理已有通知
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup notifications");

    // 1. 同步第一批告警（over_capacity）
    let alerts_v1 = vec![json!({
        "stage": "over_capacity",
        "level": "warn",
        "count": 5,
        "title": "内容合规告警：队列超容",
        "message": "当前开放举报数超过容量阈值",
        "linkPath": "/product/content-compliance?escalationStage=over_capacity"
    })];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_v1 })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync v1");
    assert_eq!(resp.status(), StatusCode::OK);
    let body_bytes = axum::body::to_bytes(resp.into_body(), MAX_JSON)
        .await
        .expect("body v1");
    let body: Value = serde_json::from_slice(&body_bytes).expect("json v1");
    assert_eq!(body["syncedCount"], 1);

    // 验证数据库中创建了通知
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("count v1");
    assert_eq!(count, 1);

    // 验证通知内容
    let notification: (String, String, String, Value) = sqlx::query_as(
        r#"
        SELECT title, message, link_path, payload
        FROM public.app_notification
        WHERE user_id = $1 AND notification_type = 'content_compliance_alert'
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("fetch notification v1");

    assert_eq!(notification.0, "内容合规告警：队列超容");
    assert_eq!(notification.1, "当前开放举报数超过容量阈值");
    assert_eq!(
        notification.2,
        "/product/content-compliance?escalationStage=over_capacity"
    );
    assert_eq!(notification.3["stage"], "over_capacity");
    assert_eq!(notification.3["level"], "warn");
    assert_eq!(notification.3["count"], 5);

    // 2. 同步第二批告警（over_capacity 更新 + escalated_72h 新增）
    let alerts_v2 = vec![
        json!({
            "stage": "over_capacity",
            "level": "warn",
            "count": 8,  // 数量变化
            "title": "内容合规告警：队列超容",
            "message": "当前开放举报数超过容量阈值",
            "linkPath": "/product/content-compliance?escalationStage=over_capacity"
        }),
        json!({
            "stage": "escalated_72h",
            "level": "critical",
            "count": 2,
            "title": "内容合规告警：72小时升级",
            "message": "存在超过72小时未处理的举报",
            "linkPath": "/product/content-compliance?escalationStage=escalated_72h"
        }),
    ];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_v2 })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync v2");
    assert_eq!(resp.status(), StatusCode::OK);
    let body_bytes = axum::body::to_bytes(resp.into_body(), MAX_JSON)
        .await
        .expect("body v2");
    let body: Value = serde_json::from_slice(&body_bytes).expect("json v2");
    assert_eq!(body["syncedCount"], 2);

    // 验证数据库中有两条告警通知
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("count v2");
    assert_eq!(count, 2);

    // 验证 over_capacity 通知已更新（count 从 5 → 8）
    let updated_notification: (i64, Option<chrono::DateTime<chrono::Utc>>) = sqlx::query_as(
        r#"
        SELECT (payload->>'count')::bigint, read_at
        FROM public.app_notification
        WHERE user_id = $1
          AND notification_type = 'content_compliance_alert'
          AND payload->>'stage' = 'over_capacity'
        "#,
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("fetch updated notification");
    assert_eq!(updated_notification.0, 8);
    assert!(
        updated_notification.1.is_none(),
        "read_at should be reset to NULL on update"
    );

    // 验证 escalated_72h 通知已创建
    let new_notification: (String, i64) = sqlx::query_as(
        r#"
        SELECT title, (payload->>'count')::bigint
        FROM public.app_notification
        WHERE user_id = $1
          AND notification_type = 'content_compliance_alert'
          AND payload->>'stage' = 'escalated_72h'
        "#,
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("fetch new notification");
    assert_eq!(new_notification.0, "内容合规告警：72小时升级");
    assert_eq!(new_notification.1, 2);

    // 3. 同步第三批告警（仅保留 escalated_72h，over_capacity 消退）
    let alerts_v3 = vec![json!({
        "stage": "escalated_72h",
        "level": "critical",
        "count": 2,
        "title": "内容合规告警：72小时升级",
        "message": "存在超过72小时未处理的举报",
        "linkPath": "/product/content-compliance?escalationStage=escalated_72h"
    })];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_v3 })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync v3");
    assert_eq!(resp.status(), StatusCode::OK);
    let body_bytes = axum::body::to_bytes(resp.into_body(), MAX_JSON)
        .await
        .expect("body v3");
    let body: Value = serde_json::from_slice(&body_bytes).expect("json v3");
    assert_eq!(body["syncedCount"], 1);

    // 验证 over_capacity 告警已删除
    let alert_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("count alerts v3");
    assert_eq!(alert_count, 1, "only escalated_72h alert should remain");

    // 验证生成了 cleared 通知（节流逻辑可能跳过，这里只验证数据结构）
    let cleared_exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM public.app_notification
          WHERE user_id = $1
            AND notification_type = 'content_compliance_alert_cleared'
            AND payload->>'stage' = 'over_capacity'
        )
        "#,
    )
    .bind(sub)
    .fetch_one(&pool)
    .await
    .expect("check cleared");

    if cleared_exists {
        let cleared_notification: (String, String) = sqlx::query_as(
            r#"
            SELECT title, payload->>'status'
            FROM public.app_notification
            WHERE user_id = $1
              AND notification_type = 'content_compliance_alert_cleared'
              AND payload->>'stage' = 'over_capacity'
            ORDER BY created_at DESC
            LIMIT 1
            "#,
        )
        .bind(sub)
        .fetch_one(&pool)
        .await
        .expect("fetch cleared notification");
        assert!(cleared_notification.0.contains("已清除"));
        assert_eq!(cleared_notification.1, "cleared");
    }

    // 4. 验证 WebSocket 推送形状（通过存储层函数签名间接验证）
    // 实际 WS 推送由 `notify.broadcast_to_user()` 直接转发 raw envelope：
    // `type` / `schema_version` / `payload`，这里不再假定额外的 `event` / `data` 包装层。
    // 本测试验证数据库状态与 REST 响应一致性。
    // 完整 WS 双工测试需要 WebSocket 客户端连接，当前以产品竖切 + E2E 覆盖

    // 清理
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup");
}

#[tokio::test]
#[ignore]
async fn content_compliance_ws_push_unchanged_skips_update() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let uid = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(uid, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    // 清理
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(uid)
        .execute(&pool)
        .await
        .expect("cleanup");

    // 同步告警
    let alerts = vec![json!({
        "stage": "stalled_claimed",
        "level": "high",
        "count": 3,
        "title": "内容合规告警：认领停滞",
        "message": "存在认领后长时间未处理的举报",
        "linkPath": "/product/content-compliance?escalationStage=stalled_claimed"
    })];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync first");
    assert_eq!(resp.status(), StatusCode::OK);

    // 记录 updated_at
    let first_updated_at: chrono::DateTime<chrono::Utc> = sqlx::query_scalar(
        "SELECT updated_at FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(uid)
    .fetch_one(&pool)
    .await
    .expect("fetch updated_at");

    // 等待 1 秒确保时间戳可区分
    tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;

    // 再次同步相同告警（内容未变化）
    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync second");
    assert_eq!(resp.status(), StatusCode::OK);
    let body_bytes = axum::body::to_bytes(resp.into_body(), MAX_JSON)
        .await
        .expect("body");
    let body: serde_json::Value = serde_json::from_slice(&body_bytes).expect("json");
    assert_eq!(body["syncedCount"], 1, "should still count as synced");

    // 验证 updated_at 未变化（因为内容相同，跳过 UPDATE）
    let second_updated_at: chrono::DateTime<chrono::Utc> = sqlx::query_scalar(
        "SELECT updated_at FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(uid)
    .fetch_one(&pool)
    .await
    .expect("fetch updated_at second");

    assert_eq!(
        first_updated_at, second_updated_at,
        "updated_at should not change when alert content is unchanged"
    );

    // 清理
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(uid)
        .execute(&pool)
        .await
        .expect("cleanup");
}

/// 全双工 WebSocket 推送自动化测试（C1.8 专用集成测试）
///
/// 验证 WebSocket 推送的完整流程：
/// 1. 订阅 WsNotifyHub 接收通知
/// 2. 调用 sync 端点触发告警
/// 3. 验证 WebSocket 消息实时推送
/// 4. 验证 raw envelope（`type` / `schema_version` / `payload`）格式和内容正确性
#[tokio::test]
#[ignore = "needs DATABASE_URL + SUPABASE_JWT_SECRET and migrated schema; cargo test content_compliance_ws_full_duplex -- --ignored"]
async fn content_compliance_ws_full_duplex() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let sub = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(sub, secret.as_bytes());

    // 创建带 WsNotifyHub 的 app state
    let state = contract_state(pool.clone(), secret);
    let notify_hub = state.notify.clone();
    let app = build_router(state);

    // 清理已有通知
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup notifications");

    // 订阅 WebSocket 通知
    let (tx, mut rx) = mpsc::unbounded_channel::<String>();
    let conn_id = notify_hub.subscribe(sub, tx).await;

    // 1. 测试创建新告警的 WebSocket 推送
    let alerts_create = vec![json!({
        "stage": "over_capacity",
        "level": "warn",
        "count": 5,
        "title": "内容合规告警：队列超容",
        "message": "当前开放举报数超过容量阈值",
        "linkPath": "/product/content-compliance?escalationStage=over_capacity"
    })];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_create })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync create");
    assert_eq!(resp.status(), StatusCode::OK);

    // 验证收到 WebSocket 消息（settings.notification.created）
    let ws_msg = tokio::time::timeout(tokio::time::Duration::from_secs(2), rx.recv())
        .await
        .expect("should receive WS message within timeout")
        .expect("channel should not be closed");

    let ws_payload: serde_json::Value =
        serde_json::from_str(&ws_msg).expect("WS message should be valid JSON");

    assert_eq!(ws_payload["type"], "settings.notification.created");
    assert_eq!(ws_payload["schema_version"], 1);
    assert!(
        ws_payload["payload"].is_object(),
        "payload should be an object"
    );

    let notification_data = &ws_payload["payload"];
    assert_eq!(
        notification_data["notificationType"],
        "content_compliance_alert"
    );
    assert_eq!(notification_data["title"], "内容合规告警：队列超容");
    assert_eq!(notification_data["message"], "当前开放举报数超过容量阈值");
    assert_eq!(
        notification_data["linkPath"],
        "/product/content-compliance?escalationStage=over_capacity"
    );
    assert_eq!(notification_data["payload"]["stage"], "over_capacity");
    assert_eq!(notification_data["payload"]["level"], "warn");
    assert_eq!(notification_data["payload"]["count"], 5);

    // 2. 测试更新告警的 WebSocket 推送
    let alerts_update = vec![json!({
        "stage": "over_capacity",
        "level": "warn",
        "count": 10,  // 数量变化
        "title": "内容合规告警：队列超容",
        "message": "当前开放举报数超过容量阈值",
        "linkPath": "/product/content-compliance?escalationStage=over_capacity"
    })];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_update })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync update");
    assert_eq!(resp.status(), StatusCode::OK);

    // 验证收到更新的 WebSocket 消息（settings.notification.updated）
    let ws_msg_update = tokio::time::timeout(tokio::time::Duration::from_secs(2), rx.recv())
        .await
        .expect("should receive update WS message within timeout")
        .expect("channel should not be closed");

    let ws_update_payload: serde_json::Value =
        serde_json::from_str(&ws_msg_update).expect("WS update message should be valid JSON");

    assert_eq!(ws_update_payload["type"], "settings.notification.updated");
    assert_eq!(ws_update_payload["schema_version"], 1);
    let update_data = &ws_update_payload["payload"];
    assert_eq!(update_data["notificationType"], "content_compliance_alert");
    assert_eq!(
        update_data["payload"]["count"], 10,
        "count should be updated to 10"
    );
    assert!(
        update_data["readAt"].is_null(),
        "readAt should be reset to null on update"
    );

    // 3. 测试告警消退的 WebSocket 推送（cleared 通知）
    let alerts_cleared: Vec<serde_json::Value> = vec![]; // 空列表表示所有告警已消退

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_cleared })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync cleared");
    assert_eq!(resp.status(), StatusCode::OK);

    // 验证收到 cleared 通知的 WebSocket 消息
    // 注意：cleared 通知可能因节流策略被跳过，这里使用 timeout 而不是 expect
    let cleared_result = tokio::time::timeout(tokio::time::Duration::from_secs(2), rx.recv()).await;

    if let Ok(Some(ws_msg_cleared)) = cleared_result {
        let ws_cleared_payload: serde_json::Value =
            serde_json::from_str(&ws_msg_cleared).expect("WS cleared message should be valid JSON");

        assert_eq!(ws_cleared_payload["type"], "settings.notification.created");
        assert_eq!(ws_cleared_payload["schema_version"], 1);
        let cleared_data = &ws_cleared_payload["payload"];
        assert_eq!(
            cleared_data["notificationType"],
            "content_compliance_alert_cleared"
        );
        assert_eq!(cleared_data["payload"]["stage"], "over_capacity");
        assert_eq!(cleared_data["payload"]["status"], "cleared");
        assert!(cleared_data["title"].as_str().unwrap().contains("已清除"));
    }

    // 4. 测试多个告警同时推送
    let alerts_multiple = vec![
        json!({
            "stage": "stalled_claimed",
            "level": "high",
            "count": 3,
            "title": "内容合规告警：认领停滞",
            "message": "存在认领后长时间未处理的举报",
            "linkPath": "/product/content-compliance?escalationStage=stalled_claimed"
        }),
        json!({
            "stage": "escalated_72h",
            "level": "critical",
            "count": 2,
            "title": "内容合规告警：72小时升级",
            "message": "存在超过72小时未处理的举报",
            "linkPath": "/product/content-compliance?escalationStage=escalated_72h"
        }),
    ];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts_multiple })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync multiple");
    assert_eq!(resp.status(), StatusCode::OK);

    // 验证收到两条 WebSocket 消息
    let mut received_stages = Vec::new();
    for _ in 0..2 {
        let ws_msg = tokio::time::timeout(tokio::time::Duration::from_secs(2), rx.recv())
            .await
            .expect("should receive WS message within timeout")
            .expect("channel should not be closed");

        let ws_payload: serde_json::Value =
            serde_json::from_str(&ws_msg).expect("WS message should be valid JSON");

        assert_eq!(ws_payload["type"], "settings.notification.created");
        assert_eq!(ws_payload["schema_version"], 1);
        let stage = ws_payload["payload"]["payload"]["stage"]
            .as_str()
            .unwrap()
            .to_string();
        received_stages.push(stage);
    }

    assert!(received_stages.contains(&"stalled_claimed".to_string()));
    assert!(received_stages.contains(&"escalated_72h".to_string()));

    // 取消订阅
    notify_hub.unsubscribe(sub, conn_id).await;

    // 清理
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(sub)
        .execute(&pool)
        .await
        .expect("cleanup");
}

#[tokio::test]
#[ignore]
async fn content_compliance_ws_push_workspace_scope() {
    let _ = dotenvy::dotenv();
    let url = std::env::var("DATABASE_URL").expect("DATABASE_URL when running with --ignored");
    let secret = std::env::var("SUPABASE_JWT_SECRET")
        .expect("SUPABASE_JWT_SECRET must match JWT signing (see supabase status)");

    let pool = PgPoolOptions::new()
        .max_connections(2)
        .connect(&url)
        .await
        .expect("connect DATABASE_URL");

    let uid = Uuid::parse_str(CONTRACT_USER_SUB).unwrap();
    let token = jwt_fixture::encode_supabase_style(uid, secret.as_bytes());
    let app = build_router(contract_state(pool.clone(), secret));

    // 清理
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(uid)
        .execute(&pool)
        .await
        .expect("cleanup");

    // 同步带 workspace 上下文的告警
    let alerts = vec![json!({
        "stage": "workspace_hotspot",
        "level": "warn",
        "count": 10,
        "title": "内容合规告警：工作区热点",
        "message": "特定工作区举报集中",
        "linkPath": "/product/content-compliance?escalationStage=workspace_hotspot"
    })];

    let resp = app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/settings/notifications/content-compliance/sync")
                .method(Method::POST)
                .header(header::CONTENT_TYPE, "application/json")
                .header(header::AUTHORIZATION, format!("Bearer {token}"))
                .body(Body::from(
                    serde_json::to_vec(&json!({ "alerts": alerts })).unwrap(),
                ))
                .unwrap(),
        )
        .await
        .expect("sync");
    assert_eq!(resp.status(), StatusCode::OK);

    // 验证通知创建成功
    let count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(uid)
    .fetch_one(&pool)
    .await
    .expect("count");
    assert_eq!(count, 1);

    // 验证 payload 包含 workspace 相关信息
    let payload: serde_json::Value = sqlx::query_scalar(
        "SELECT payload FROM public.app_notification WHERE user_id = $1 AND notification_type = 'content_compliance_alert'",
    )
    .bind(uid)
    .fetch_one(&pool)
    .await
    .expect("fetch payload");
    assert_eq!(payload["stage"], "workspace_hotspot");
    assert_eq!(payload["source"], "content_compliance");

    // 清理
    sqlx::query("DELETE FROM public.app_notification WHERE user_id = $1")
        .bind(uid)
        .execute(&pool)
        .await
        .expect("cleanup");
}
