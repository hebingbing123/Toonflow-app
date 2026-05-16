//! Manual bridge adapter implementation for human-assisted delivery

use serde_json::json;

use crate::publish::types::{PublishDraftRow, PublishJobRow, PublishTargetRow};

use super::routing::evidence_for_mode;
use super::PublishAdapterResult;

pub(crate) fn run_manual_bridge_adapter(
    job: &PublishJobRow,
    draft: &PublishDraftRow,
    target: &PublishTargetRow,
) -> PublishAdapterResult {
    // P3: Manual bridge delivery - requires human confirmation and manual steps
    let (delivery_mode, evidence) =
        evidence_for_mode(&target.automation_mode, job.id, &target.platform_id);

    PublishAdapterResult {
        status: "succeeded",
        detail: json!({
            "adapter": format!("{}_manual_bridge", target.platform_id),
            "delivery_mode": delivery_mode,
            "automation_mode": &target.automation_mode,
            "delivery_route": "manual_bridge",
            "evidence": evidence,
            "platform_id": &target.platform_id,
            "draft_id": draft.id,
            "stub": false,
            "manual_steps_required": true,
            "manual_workflow": {
                "step_1": "Review draft content and metadata",
                "step_2": "Manually upload to platform",
                "step_3": "Confirm publication and record external_video_id",
                "step_4": "Submit confirmation callback"
            },
            "receipt": {
                "platform_id": &target.platform_id,
                "external_video_id": format!("{}_manual:{}", target.platform_id, job.id),
                "published_at": chrono::Utc::now().to_rfc3339(),
                "mode": "manual_bridge",
                "path": "adapter.manual.bridge",
                "requires_callback": true,
            },
        }),
        error_message: None,
    }
}
