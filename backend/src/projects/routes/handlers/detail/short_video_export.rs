//! **POST …/short-video-export** — enqueue project-level **`video.export`** after export-check gate.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use serde::Deserialize;
use utoipa::ToSchema;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_EXPORT};
use crate::projects::routes::common::require_project_workspace_member_scope;
use crate::publish::export_check_facets::load_publish_export_facet_evaluation;
use crate::short_video::assembly_query::{
    fetch_project_assembly_flat_rows, fetch_project_assembly_header,
};
use crate::short_video::export_gaps::evaluate_export_gap_issues;
use crate::state::AppState;

use super::short_video_export_check::row_to_gap_input;

#[derive(Debug, Deserialize, Default, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct ShortVideoExportBody {
    #[serde(default)]
    pub format: Option<String>,
    #[serde(default)]
    pub script_numeric_id: Option<i32>,
}

#[derive(Debug, serde::Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub(crate) struct ShortVideoExportEnqueueResponse {
    pub schema_version: i32,
    pub job_id: Uuid,
    pub source_url: String,
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/short-video-export",
    operation_id = "postProjectShortVideoExportByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID")
    ),
    request_body = ShortVideoExportBody,
    responses(
        (status = 200, description = "OK", body = ShortVideoExportEnqueueResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_export_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ShortVideoExportBody>,
) -> Result<Json<ShortVideoExportEnqueueResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let resolved_project_id = scope.id;

    let header = fetch_project_assembly_header(pool, resolved_project_id)
        .await?
        .ok_or(ApiError::NotFound)?;

    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;

    let mut blocking_issue_count = 0i64;
    for row in &flat {
        if body
            .script_numeric_id
            .is_some_and(|sid| sid != row.script_numeric_id)
        {
            continue;
        }
        let gap_input = row_to_gap_input(row);
        for gap_issue in evaluate_export_gap_issues(&gap_input) {
            if gap_issue.severity == "blocking" {
                blocking_issue_count += 1;
            }
        }
    }
    if blocking_issue_count > 0 {
        return Err(crate::error::bad_request_i18n(
            "export blocked: resolve export-check issues first",
            "导出被阻断：请先解决导出前检查中的问题",
        ));
    }

    let publish_eval = load_publish_export_facet_evaluation(pool, resolved_project_id).await?;
    let publish_blocking = publish_eval
        .issues
        .iter()
        .filter(|i| i.severity == "blocking")
        .count();
    if publish_blocking > 0 {
        return Err(crate::error::bad_request_i18n(
            "export blocked: resolve publish cover/platform issues first",
            "导出被阻断：请先配置封面与发布平台信息",
        ));
    }

    let source_url = flat
        .iter()
        .filter(|r| {
            body.script_numeric_id
                .is_none_or(|sid| sid == r.script_numeric_id)
        })
        .find_map(|r| {
            r.file_path
                .as_deref()
                .map(str::trim)
                .filter(|s| !s.is_empty())
                .map(str::to_string)
        })
        .ok_or_else(|| {
            crate::error::bad_request_i18n(
                "no selected video URL available for export",
                "没有可用于导出的已选视频",
            )
        })?;

    let format_norm = body
        .format
        .as_deref()
        .unwrap_or("mp4")
        .trim()
        .to_ascii_lowercase();
    if !matches!(format_norm.as_str(), "mp4" | "mov" | "webm") {
        return Err(crate::error::bad_request_i18n(
            &format!("format must be mp4, mov, or webm (got {format_norm})"),
            &format!("format 必须是 mp4、mov 或 webm（当前为 {format_norm}）"),
        ));
    }

    let project_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT numeric_id FROM app_project WHERE id = $1"#)
            .bind(header.id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let payload = serde_json::json!({
        "source": "short_video_space.export",
        "source_url": source_url,
        "format": format_norm,
        "project_uuid": header.id,
        "project_numeric_id": project_numeric_id,
        "script_numeric_id": body.script_numeric_id,
    });

    let job: JobRow = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_VIDEO_EXPORT,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;

    Ok(Json(ShortVideoExportEnqueueResponse {
        schema_version: 1,
        job_id: job.id,
        source_url,
    }))
}
