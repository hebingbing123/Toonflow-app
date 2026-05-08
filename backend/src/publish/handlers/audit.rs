//! Audit and performance handlers

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::state::AppState;

use super::super::platform_registry::capability_matrix;
use super::super::store::{
    list_attempt_audit, list_low_performance_alerts, ListAttemptAuditFilter,
};
use super::super::types::{
    ListPublishAuditQuery, ListPublishPerformanceAlertsQuery, PublishAttemptAuditResponse,
    PublishPerformanceAlertResponse, PublishPlatformMatrixResponse,
};
use super::super::{attempt_audit_from_row, performance_alert_from_row};

pub(super) fn platform_matrix_body() -> PublishPlatformMatrixResponse {
    PublishPlatformMatrixResponse {
        platforms: capability_matrix(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/platform-matrix",
    operation_id = "getPublishPlatformMatrixV1",
    tag = "publish",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = PublishPlatformMatrixResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn publish_platform_matrix(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<PublishPlatformMatrixResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let _pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    Ok(Json(platform_matrix_body()))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/audit",
    operation_id = "listPublishAuditV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("draft_id" = Option<Uuid>, Query, description = "Optional draft filter"),
        ("job_id" = Option<Uuid>, Query, description = "Optional job filter"),
        ("delivery_mode" = Option<String>, Query, description = "Optional delivery-mode filter: sandbox/live/manual_bridge/unknown"),
        ("evidence_key" = Option<String>, Query, description = "Optional evidence key filter: request_id/manual_step_id/callback_id"),
        ("limit" = Option<i64>, Query, description = "1..200, default 50")
    ),
    responses(
        (status = 200, description = "OK", body = Vec<PublishAttemptAuditResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_audit(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(q): Query<ListPublishAuditQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishAttemptAuditResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let rows = list_attempt_audit(
        pool,
        project_id,
        ListAttemptAuditFilter {
            draft_id: q.draft_id,
            job_id: q.job_id,
            delivery_mode: q.delivery_mode.as_deref(),
            evidence_key: q.evidence_key.as_deref(),
            limit: q.limit,
        },
    )
    .await?;
    Ok(Json(rows.into_iter().map(attempt_audit_from_row).collect()))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/publish/performance-alerts",
    operation_id = "listPublishPerformanceAlertsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("views_lt" = Option<i64>, Query, description = "Low-performance views threshold"),
        ("completion_rate_lt" = Option<f64>, Query, description = "Low-performance completion-rate threshold"),
        ("limit" = Option<i64>, Query, description = "1..200, default 50")
    ),
    responses(
        (status = 200, description = "OK", body = Vec<PublishPerformanceAlertResponse>),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_publish_performance_alerts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(q): Query<ListPublishPerformanceAlertsQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<PublishPerformanceAlertResponse>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let rows =
        list_low_performance_alerts(pool, project_id, q.views_lt, q.completion_rate_lt, q.limit)
            .await?;
    Ok(Json(
        rows.into_iter().map(performance_alert_from_row).collect(),
    ))
}

/// Process low-performance alerts and create quality reviews (I.5)
#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/publish/performance-alerts/process",
    operation_id = "processPerformanceAlertsV1",
    tag = "publish",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ("views_lt" = Option<i64>, Query, description = "Low-performance views threshold (default: 100)"),
        ("completion_rate_lt" = Option<f64>, Query, description = "Low-performance completion-rate threshold (default: 0.3)"),
        ("engagement_rate_lt" = Option<f64>, Query, description = "Low-performance engagement-rate threshold (default: 0.01)"),
        ("limit" = Option<i64>, Query, description = "1..200, default 50")
    ),
    responses(
        (status = 200, description = "Quality reviews created", body = Vec<serde_json::Value>),
        (status = 404, description = "Not found")
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn process_performance_alerts(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ListPublishPerformanceAlertsQuery>,
    headers: HeaderMap,
) -> Result<Json<Vec<crate::prompting::quality::QualityReview>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let _scope = require_project_write_scope(&state, uid, project_id).await?;

    let thresholds = super::super::performance_rework::PerformanceThresholds {
        min_views: query.views_lt,
        min_completion_rate: query.completion_rate_lt,
        min_engagement_rate: 0.01, // Default engagement rate threshold
        platform_overrides: std::collections::HashMap::new(), // P5: No overrides by default
    };

    let limit = query.limit;

    let reviews = super::super::performance_rework::process_low_performance_alerts(
        pool,
        project_id,
        uid,
        &thresholds,
        limit,
    )
    .await?;

    Ok(Json(reviews))
}
