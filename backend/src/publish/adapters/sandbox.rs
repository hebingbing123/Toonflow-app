//! Sandbox adapter implementation for demo/testing mode

use serde_json::json;

use crate::publish::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};

use super::live::{success_with_receipt, unsupported_platform};
use super::PublishAdapterResult;

pub(crate) fn run_sandbox_adapter(
    job: &PublishJobRow,
    draft: &PublishDraftRow,
    target: &PublishTargetRow,
) -> PublishAdapterResult {
    match target.platform_id.as_str() {
        "douyin" => success_with_receipt(
            "douyin_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"publish_scene": "video_create", "region": "cn"}),
        ),
        "bilibili" => success_with_receipt(
            "bilibili_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"biz": "archive_add", "copyright": 1}),
        ),
        "xiaohongshu" => success_with_receipt(
            "xiaohongshu_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"note_type": "video", "entry": "creator_center"}),
        ),
        "weixin_channels" => success_with_receipt(
            "weixin_channels_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"flow": "finder_media_upload", "app": "channels"}),
        ),
        "kuaishou" => success_with_receipt(
            "kuaishou_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"publish_target": "photo_video", "scene": "short_video"}),
        ),
        "tiktok" => success_with_receipt(
            "tiktok_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"endpoint": "content/post", "market": "global"}),
        ),
        "youtube_shorts" => success_with_receipt(
            "youtube_shorts_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"endpoint": "youtube.videos.insert", "privacy": "private"}),
        ),
        "instagram_reels" => success_with_receipt(
            "instagram_reels_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"endpoint": "ig_container_publish", "surface": "reels"}),
        ),
        "facebook_reels" => success_with_receipt(
            "facebook_reels_sandbox_closure",
            &target.platform_id,
            &target.automation_mode,
            job.id,
            draft.id,
            json!({"endpoint": "graph_video_publish", "surface": "reels"}),
        ),
        _ => unsupported_platform(&target.platform_id),
    }
}
