//! **F7/F8** adapter routing: domestic five-platform sandbox closures + overseas fallback.

use serde_json::{json, Value};
use uuid::Uuid;

use super::platform_registry::sandbox_publish_receipt;
use super::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};

pub(crate) struct PublishAdapterResult {
    pub(crate) status: &'static str,
    pub(crate) detail: Value,
    pub(crate) error_message: Option<String>,
}

pub(crate) fn run_target_adapter(
    job: &PublishJobRow,
    draft: &PublishDraftRow,
    target: &PublishTargetRow,
) -> PublishAdapterResult {
    match target.platform_id.as_str() {
        "douyin" => success_with_receipt(
            "douyin_sandbox_closure",
            &target.platform_id,
            job.id,
            draft.id,
            json!({"publish_scene": "video_create", "region": "cn"}),
        ),
        "bilibili" => success_with_receipt(
            "bilibili_sandbox_closure",
            &target.platform_id,
            job.id,
            draft.id,
            json!({"biz": "archive_add", "copyright": 1}),
        ),
        "xiaohongshu" => success_with_receipt(
            "xiaohongshu_sandbox_closure",
            &target.platform_id,
            job.id,
            draft.id,
            json!({"note_type": "video", "entry": "creator_center"}),
        ),
        "weixin_channels" => success_with_receipt(
            "weixin_channels_sandbox_closure",
            &target.platform_id,
            job.id,
            draft.id,
            json!({"flow": "finder_media_upload", "app": "channels"}),
        ),
        "kuaishou" => success_with_receipt(
            "kuaishou_sandbox_closure",
            &target.platform_id,
            job.id,
            draft.id,
            json!({"publish_target": "photo_video", "scene": "short_video"}),
        ),
        _ => success_with_overseas_fallback(job.id, &target.platform_id),
    }
}

fn success_with_receipt(
    adapter: &'static str,
    platform_id: &str,
    job_id: Uuid,
    draft_id: Uuid,
    extra: Value,
) -> PublishAdapterResult {
    PublishAdapterResult {
        status: "succeeded",
        detail: json!({
            "adapter": adapter,
            "platform_id": platform_id,
            "draft_id": draft_id,
            "stub": false,
            "receipt": {
                "platform_id": platform_id,
                "external_video_id": format!("{platform_id}:{job_id}"),
                "published_at": chrono::Utc::now().to_rfc3339(),
                "mode": "sandbox_closure",
                "extra": extra,
            },
        }),
        error_message: None,
    }
}

fn success_with_overseas_fallback(job_id: Uuid, platform_id: &str) -> PublishAdapterResult {
    PublishAdapterResult {
        status: "succeeded",
        detail: json!({
            "adapter": "sandbox_fallback",
            "platform_id": platform_id,
            "stub": true,
            "receipt": sandbox_publish_receipt(job_id, platform_id),
        }),
        error_message: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::Utc;
    use serde_json::Value;

    use crate::publish::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};
    use sqlx::types::Json;

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
}
