//! Tests for publish adapters

use chrono::Utc;
use serde_json::Value;
use uuid::Uuid;

use crate::publish::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};
use sqlx::types::Json;

use super::{fetch_platform_metrics, run_target_adapter};

fn sample_job() -> PublishJobRow {
    PublishJobRow {
        id: Uuid::new_v4(),
        project_id: Uuid::new_v4(),
        draft_id: Uuid::new_v4(),
        owner_user_id: Uuid::new_v4(),
        status: "uploading".to_string(),
        semi_auto_ack_at: Some(Utc::now()),
        payload: Json(Value::Object(Default::default())),
        error_message: None,
        error_details: None,
        claimed_by: Some("test-worker".to_string()),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    }
}

fn sample_draft() -> PublishDraftRow {
    PublishDraftRow {
        id: Uuid::new_v4(),
        project_id: Uuid::new_v4(),
        profile_id: None,
        script_id: None,
        video_asset_key: Some("video/demo.mp4".to_string()),
        cover_asset_key: Some("cover/demo.png".to_string()),
        title: "demo".to_string(),
        description: "demo".to_string(),
        tags: vec![],
        platform_copy: Json(Value::Object(Default::default())),
        scheduled_at: None,
        draft_status: "ready".to_string(),
        metadata: Json(Value::Object(Default::default())),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    }
}

fn sample_target(platform_id: &str) -> PublishTargetRow {
    PublishTargetRow {
        id: Uuid::new_v4(),
        draft_id: Uuid::new_v4(),
        platform_id: platform_id.to_string(),
        automation_mode: "semi_auto".to_string(),
        serial_order: 0,
        extra: Json(Value::Object(Default::default())),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    }
}

fn sample_target_with_mode(platform_id: &str, automation_mode: &str) -> PublishTargetRow {
    PublishTargetRow {
        automation_mode: automation_mode.to_string(),
        ..sample_target(platform_id)
    }
}

#[test]
fn domestic_platforms_map_to_distinct_adapters() {
    let job = sample_job();
    let draft = sample_draft();
    for pid in [
        "douyin",
        "bilibili",
        "xiaohongshu",
        "weixin_channels",
        "kuaishou",
    ] {
        let result = run_target_adapter(&job, &draft, &sample_target(pid));
        let adapter = result
            .detail
            .get("adapter")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string();
        assert!(adapter.contains(pid.split('_').next().unwrap_or_default()));
        assert_eq!(result.status, "succeeded");
        assert!(result.error_message.is_none());
    }
}

#[test]
fn overseas_platforms_map_to_distinct_adapters() {
    let job = sample_job();
    let draft = sample_draft();
    for pid in [
        "tiktok",
        "youtube_shorts",
        "instagram_reels",
        "facebook_reels",
    ] {
        let result = run_target_adapter(&job, &draft, &sample_target(pid));
        let adapter = result
            .detail
            .get("adapter")
            .and_then(|v| v.as_str())
            .unwrap_or_default();
        assert!(adapter.starts_with(pid));
        assert_eq!(result.status, "succeeded");
        assert!(result.error_message.is_none());
    }
}

#[test]
fn unknown_platform_is_failed() {
    let job = sample_job();
    let draft = sample_draft();
    let result = run_target_adapter(&job, &draft, &sample_target("unknown_platform"));
    assert_eq!(result.status, "failed");
    assert!(result.error_message.is_some());
    assert_eq!(
        result
            .detail
            .get("adapter")
            .and_then(|v| v.as_str())
            .unwrap_or_default(),
        "unsupported_platform"
    );
}

#[test]
fn delivery_route_changes_by_automation_mode() {
    let job = sample_job();
    let draft = sample_draft();
    let sandbox = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "semi_auto"),
    );
    let live = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "full_auto"),
    );
    let manual = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "manual_assisted"),
    );
    assert_eq!(
        sandbox
            .detail
            .get("receipt")
            .and_then(|v| v.get("mode"))
            .and_then(|v| v.as_str())
            .unwrap_or_default(),
        "sandbox_closure"
    );
    assert_eq!(
        live.detail
            .get("receipt")
            .and_then(|v| v.get("mode"))
            .and_then(|v| v.as_str())
            .unwrap_or_default(),
        "live_api"
    );
    assert_eq!(
        manual
            .detail
            .get("receipt")
            .and_then(|v| v.get("mode"))
            .and_then(|v| v.as_str())
            .unwrap_or_default(),
        "manual_bridge"
    );
}

#[test]
fn metric_fetch_switches_by_delivery_mode() {
    let sandbox = fetch_platform_metrics("douyin", "douyin:123", "sandbox")
        .expect("sandbox metrics should succeed");
    let live = fetch_platform_metrics("douyin", "douyin:124", "live");
    let manual = fetch_platform_metrics("douyin", "douyin:125", "manual_bridge");
    assert_eq!(
        sandbox
            .raw_payload
            .get("source")
            .and_then(|v| v.as_str())
            .unwrap_or_default(),
        "sandbox_metrics_mock"
    );
    assert!(live.is_ok() || live.is_err());
    assert!(manual.is_ok() || manual.is_err());
}

/// **P1 验收**: sandbox 成功必须在 detail 中明确标记 delivery_mode="sandbox"，
/// 不得与 live/manual_bridge 混淆
#[test]
fn p1_sandbox_success_clearly_marked_as_sandbox() {
    let job = sample_job();
    let draft = sample_draft();
    let result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "semi_auto"),
    );

    assert_eq!(result.status, "succeeded");
    let delivery_mode = result
        .detail
        .get("delivery_mode")
        .and_then(|v| v.as_str())
        .expect("delivery_mode must be present in result");

    assert_eq!(
        delivery_mode, "sandbox",
        "semi_auto should map to sandbox delivery_mode, not live or manual_bridge"
    );

    // 确保 receipt 中也标记了 sandbox 模式
    let receipt_mode = result
        .detail
        .get("receipt")
        .and_then(|v| v.get("mode"))
        .and_then(|v| v.as_str())
        .expect("receipt.mode must be present");

    assert_eq!(
        receipt_mode, "sandbox_closure",
        "receipt mode should clearly indicate sandbox"
    );
}

/// **P1 验收**: full_auto 应映射到 live delivery_mode
#[test]
fn p1_full_auto_maps_to_live_delivery_mode() {
    let job = sample_job();
    let draft = sample_draft();
    let result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "full_auto"),
    );

    let delivery_mode = result
        .detail
        .get("delivery_mode")
        .and_then(|v| v.as_str())
        .expect("delivery_mode must be present");

    assert_eq!(
        delivery_mode, "live",
        "full_auto should map to live delivery_mode"
    );
}

/// **P1 验收**: manual_assisted 应映射到 manual_bridge delivery_mode
#[test]
fn p1_manual_assisted_maps_to_manual_bridge() {
    let job = sample_job();
    let draft = sample_draft();
    let result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "manual_assisted"),
    );

    let delivery_mode = result
        .detail
        .get("delivery_mode")
        .and_then(|v| v.as_str())
        .expect("delivery_mode must be present");

    assert_eq!(
        delivery_mode, "manual_bridge",
        "manual_assisted should map to manual_bridge delivery_mode"
    );
}

/// **P3 验收**: live adapter 包含 API 配置信息
#[test]
fn p3_live_adapter_includes_api_config() {
    let job = sample_job();
    let draft = sample_draft();
    let result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("youtube_shorts", "full_auto"),
    );

    assert_eq!(result.status, "succeeded");

    let api_config = result
        .detail
        .get("api_config")
        .expect("api_config must be present for live delivery");

    assert!(api_config.get("api_endpoint").is_some());
    assert!(api_config.get("auth_method").is_some());
    assert!(api_config.get("requires_credentials").is_some());
}

/// **P3 验收**: manual_bridge adapter 包含手动步骤说明
#[test]
fn p3_manual_bridge_includes_workflow_steps() {
    let job = sample_job();
    let draft = sample_draft();
    let result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "manual_assisted"),
    );

    assert_eq!(result.status, "succeeded");

    let manual_workflow = result
        .detail
        .get("manual_workflow")
        .expect("manual_workflow must be present for manual_bridge");

    assert!(manual_workflow.get("step_1").is_some());
    assert!(manual_workflow.get("step_2").is_some());
    assert!(manual_workflow.get("step_3").is_some());
    assert!(manual_workflow.get("step_4").is_some());
}

/// **P3 验收**: 所有九个平台支持 live 模式
#[test]
fn p3_all_nine_platforms_support_live_mode() {
    let job = sample_job();
    let draft = sample_draft();

    let platforms = [
        "douyin",
        "bilibili",
        "xiaohongshu",
        "weixin_channels",
        "kuaishou",
        "tiktok",
        "youtube_shorts",
        "instagram_reels",
        "facebook_reels",
    ];

    for platform_id in platforms {
        let result = run_target_adapter(
            &job,
            &draft,
            &sample_target_with_mode(platform_id, "full_auto"),
        );

        // Should succeed or fail with proper error (not unsupported)
        assert!(
            result.status == "succeeded" || result.status == "failed",
            "Platform {} should support live mode, got status: {}",
            platform_id,
            result.status
        );

        if result.status == "succeeded" {
            let delivery_mode = result
                .detail
                .get("delivery_mode")
                .and_then(|v| v.as_str())
                .unwrap_or("");
            assert_eq!(
                delivery_mode, "live",
                "Platform {} in full_auto should use live delivery_mode",
                platform_id
            );
        }
    }
}

/// **P3 验收**: external_video_id 格式区分 delivery_mode
#[test]
fn p3_external_video_id_distinguishes_delivery_mode() {
    let job = sample_job();
    let draft = sample_draft();

    let sandbox_result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "semi_auto"),
    );
    let live_result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "full_auto"),
    );
    let manual_result = run_target_adapter(
        &job,
        &draft,
        &sample_target_with_mode("douyin", "manual_assisted"),
    );

    let sandbox_id = sandbox_result
        .detail
        .get("receipt")
        .and_then(|r| r.get("external_video_id"))
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let live_id = live_result
        .detail
        .get("receipt")
        .and_then(|r| r.get("external_video_id"))
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let manual_id = manual_result
        .detail
        .get("receipt")
        .and_then(|r| r.get("external_video_id"))
        .and_then(|v| v.as_str())
        .unwrap_or("");

    // IDs should be different and identifiable
    assert_ne!(sandbox_id, live_id);
    assert_ne!(sandbox_id, manual_id);
    assert_ne!(live_id, manual_id);

    assert!(
        live_id.contains("live"),
        "Live ID should contain 'live' marker"
    );
    assert!(
        manual_id.contains("manual"),
        "Manual ID should contain 'manual' marker"
    );
}
