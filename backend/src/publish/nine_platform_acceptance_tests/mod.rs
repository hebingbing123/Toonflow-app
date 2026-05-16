//! **L.1** — Nine-platform matrix acceptance tests with real capability checks.
//!
//! This test suite validates the publish workflow across all nine supported platforms
//! with real capability detection (not mocks). Tests cover:
//! - Platform capability detection (sandbox/live/manual_bridge)
//! - Publish job creation and queueing
//! - Draft-to-platform mapping
//! - Platform-specific validation rules
//! - Error handling for unsupported capabilities
//! - All delivery modes

#[cfg(test)]
pub(super) mod tests {
    use crate::publish::adapters::{fetch_platform_metrics, run_target_adapter};
    use crate::publish::platform_registry::{capability_matrix, spec_for_platform, ALL};
    use crate::publish::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};
    use crate::publish::validation::validate_automation_mode;
    use chrono::Utc;
    use serde_json::Value;
    use sqlx::types::Json;
    use uuid::Uuid;

    // ============================================================================
    // Shared Test Fixtures
    // ============================================================================

    pub(super) fn sample_job() -> PublishJobRow {
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

    pub(super) fn sample_draft() -> PublishDraftRow {
        PublishDraftRow {
            id: Uuid::new_v4(),
            project_id: Uuid::new_v4(),
            profile_id: None,
            script_id: None,
            video_asset_key: Some("video/demo.mp4".to_string()),
            cover_asset_key: Some("cover/demo.png".to_string()),
            title: "Test Video".to_string(),
            description: "Test Description".to_string(),
            tags: vec!["test".to_string()],
            platform_copy: Json(Value::Object(Default::default())),
            scheduled_at: None,
            draft_status: "ready".to_string(),
            metadata: Json(Value::Object(Default::default())),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    pub(super) fn sample_target(platform_id: &str, automation_mode: &str) -> PublishTargetRow {
        PublishTargetRow {
            id: Uuid::new_v4(),
            draft_id: Uuid::new_v4(),
            platform_id: platform_id.to_string(),
            automation_mode: automation_mode.to_string(),
            serial_order: 0,
            extra: Json(Value::Object(Default::default())),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        }
    }

    // Import test modules
    mod adapters;
    mod automation;
    mod coverage;
    mod delivery_modes;
    mod draft_mapping;
    mod error_handling;
    mod evidence;
    mod metrics;
    mod p12_production_acceptance;
    mod registry;
    mod validation;
}
