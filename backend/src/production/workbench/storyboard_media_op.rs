//! Unified storyboard-scoped media actions (J2): select current video, enqueue export, production patch.
//!
//! Clients SHOULD prefer this endpoint over ad-hoc `POST /api/v1/jobs` for **`video.export`** from the workbench.

use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use serde_json::json;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_EXPORT};
use crate::production::patch::models::{ModelTier, PatchRequest, PatchScope};
use crate::production::patch::run_production_patch_core;
use crate::scope::http::{
    require_owned_numeric_script_scope_user_pool, require_owned_numeric_storyboard_scope,
};
use crate::settings::agent_memory::ensure_project_owned;
use crate::state::AppState;

use super::track::common::validate_positive_id;
use super::track::videos::{run_workbench_select_video, SelectVideoBody};

#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "camelCase", rename_all_fields = "camelCase")]
pub(in crate::production) enum StoryboardMediaOpRequest {
    SelectVideo {
        project_id: i32,
        script_id: i32,
        storyboard_id: i32,
        video_url: String,
    },
    EnqueueVideoExport {
        project_id: i32,
        script_id: i32,
        storyboard_id: i32,
        source_url: String,
        #[serde(default)]
        format: Option<String>,
    },
    PatchRegeneration {
        project_id: i32,
        #[serde(default)]
        episodes_id: Option<i32>,
        scope: PatchScope,
        ids: Vec<i64>,
        reason: String,
        model_tier: ModelTier,
    },
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct StoryboardMediaOpResponse {
    pub op: StoryboardMediaOpKind,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub select_video: Option<super::track::videos::SelectVideoResponse>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub enqueue_video_export: Option<EnqueueVideoExportPayload>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub patch_regeneration: Option<crate::production::patch::models::PatchResponse>,
}

#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) enum StoryboardMediaOpKind {
    SelectVideo,
    EnqueueVideoExport,
    PatchRegeneration,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct EnqueueVideoExportPayload {
    pub job: JobRow,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/storyboard-media-op",
    operation_id = "postProductionWorkbenchStoryboardMediaOpV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_storyboard_media_op(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<StoryboardMediaOpRequest>,
) -> Result<JsonResponse<StoryboardMediaOpResponse>, ApiError> {
    match req {
        StoryboardMediaOpRequest::SelectVideo {
            project_id,
            script_id,
            storyboard_id,
            video_url,
        } => {
            let body = SelectVideoBody {
                project_id,
                script_id,
                storyboard_id,
                video_url,
            };
            let select_video = Some(run_workbench_select_video(&state, &headers, body).await?);
            Ok(JsonResponse(StoryboardMediaOpResponse {
                op: StoryboardMediaOpKind::SelectVideo,
                select_video,
                enqueue_video_export: None,
                patch_regeneration: None,
            }))
        }
        StoryboardMediaOpRequest::EnqueueVideoExport {
            project_id,
            script_id,
            storyboard_id,
            source_url,
            format,
        } => {
            validate_positive_id("storyboardId", storyboard_id)?;
            let source_url = source_url.trim();
            if source_url.is_empty() {
                return Err(ApiError::BadRequest("sourceUrl must not be empty".into()));
            }
            let parsed = reqwest::Url::parse(source_url)
                .map_err(|e| ApiError::BadRequest(format!("sourceUrl is not a valid URL: {e}")))?;
            match parsed.scheme() {
                "http" | "https" => {}
                other => {
                    return Err(ApiError::BadRequest(format!(
                        "sourceUrl scheme must be http or https (got {other})"
                    )));
                }
            }

            let format_norm = format
                .as_deref()
                .unwrap_or("mp4")
                .trim()
                .to_ascii_lowercase();
            if !matches!(format_norm.as_str(), "mp4" | "mov" | "webm") {
                return Err(ApiError::BadRequest(format!(
                    "format must be mp4, mov, or webm (got {format_norm})"
                )));
            }

            let (uid, pool) = require_owned_numeric_script_scope_user_pool(
                &state, &headers, project_id, script_id,
            )
            .await?;

            require_owned_numeric_storyboard_scope(
                &state,
                &headers,
                project_id,
                script_id,
                storyboard_id,
            )
            .await?;

            let payload = json!({
                "source": "production.workbench.storyboard-media-op",
                "source_url": source_url,
                "format": format_norm,
                "project_numeric_id": project_id,
                "script_numeric_id": script_id,
                "storyboard_numeric_id": storyboard_id,
            });
            let job =
                enqueue_generation_job(pool, uid, JOB_KIND_VIDEO_EXPORT, payload, Some(&headers))
                    .await?;
            Ok(JsonResponse(StoryboardMediaOpResponse {
                op: StoryboardMediaOpKind::EnqueueVideoExport,
                select_video: None,
                enqueue_video_export: Some(EnqueueVideoExportPayload { job }),
                patch_regeneration: None,
            }))
        }
        StoryboardMediaOpRequest::PatchRegeneration {
            project_id,
            episodes_id,
            scope,
            ids,
            reason,
            model_tier,
        } => {
            let patch_req = PatchRequest {
                project_id,
                episodes_id,
                scope,
                ids,
                reason,
                model_tier,
            };
            let uid = require_user_uuid(&state, &headers)?;
            let pool = state.require_pool()?;
            ensure_project_owned(pool, uid, patch_req.project_id).await?;
            let patch_regeneration = Some(run_production_patch_core(pool, uid, &patch_req).await?);
            Ok(JsonResponse(StoryboardMediaOpResponse {
                op: StoryboardMediaOpKind::PatchRegeneration,
                select_video: None,
                enqueue_video_export: None,
                patch_regeneration,
            }))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::StoryboardMediaOpRequest;

    #[test]
    fn smoke_request_deserializes_internally_tagged() {
        let s = r#"{"op":"selectVideo","projectId":1,"scriptId":1,"storyboardId":1,"videoUrl":"https://example.com/p.mp4"}"#;
        let req: StoryboardMediaOpRequest = serde_json::from_str(s).unwrap();
        match req {
            StoryboardMediaOpRequest::SelectVideo {
                project_id,
                storyboard_id,
                ..
            } => {
                assert_eq!(project_id, 1);
                assert_eq!(storyboard_id, 1);
            }
            _ => panic!("wrong variant"),
        }
    }
}
