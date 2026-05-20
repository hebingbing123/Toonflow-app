//! Creator journey telemetry (T7): ingest client events into [super::super::super::audit::append_project_audit].

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::projects::routes::audit::append_project_audit;
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::state::AppState;

pub(crate) const CREATOR_JOURNEY_AUDIT_ACTION: &str = "creator_journey";

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreatorJourneyEventInput {
    pub name: String,
    #[serde(default)]
    pub properties: Map<String, Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct IngestCreatorJourneyEventsBody {
    pub events: Vec<CreatorJourneyEventInput>,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct IngestCreatorJourneyEventsResponse {
    pub accepted: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CreatorJourneyEventCount {
    pub name: String,
    pub count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CreatorJourneyStepCount {
    pub step: String,
    pub count: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CreatorJourneySummaryResponse {
    pub top_events: Vec<CreatorJourneyEventCount>,
    pub step_selections: Vec<CreatorJourneyStepCount>,
    pub retry_event_count: i64,
    pub total_events: i64,
}

#[derive(Debug, Clone, Deserialize, Default, IntoParams, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
#[into_params(parameter_in = Query)]
pub struct CreatorJourneySummaryQuery {
    /// Lookback window in days (default 7, max 90).
    #[serde(default)]
    pub days: Option<i32>,
}

fn validate_event_name(name: &str) -> Result<(), ApiError> {
    let trimmed = name.trim();
    if trimmed.is_empty() || trimmed.len() > 64 {
        return Err(bad_request_i18n(
            "event name must be 1-64 characters",
            "事件名称长度须在 1–64 字符之间",
        ));
    }
    if !trimmed
        .chars()
        .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '.')
    {
        return Err(bad_request_i18n(
            "event name must be alphanumeric, underscore, or dot",
            "事件名称仅允许字母、数字、下划线或点",
        ));
    }
    Ok(())
}

fn event_details(input: &CreatorJourneyEventInput) -> Value {
    json!({
        "event": input.name.trim(),
        "properties": Value::Object(input.properties.clone()),
    })
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/creator-journey-events",
    operation_id = "postProjectCreatorJourneyEventsByProjectIdV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    request_body = IngestCreatorJourneyEventsBody,
    responses(
        (status = 200, description = "OK", body = IngestCreatorJourneyEventsResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_project_creator_journey_events(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<IngestCreatorJourneyEventsBody>,
) -> Result<Json<IngestCreatorJourneyEventsResponse>, ApiError> {
    if body.events.is_empty() {
        return Err(bad_request_i18n(
            "events must not be empty",
            "events 不能为空",
        ));
    }
    if body.events.len() > 32 {
        return Err(bad_request_i18n(
            "at most 32 events per request",
            "单次最多提交 32 条事件",
        ));
    }

    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_write_scope(&state, uid, project_id).await?;

    let mut accepted = 0usize;
    for event in &body.events {
        validate_event_name(&event.name)?;
        append_project_audit(
            pool,
            crate::projects::routes::audit::AppendProjectAudit {
                project_id: scope.id,
                workspace_id: scope.workspace_id,
                project_numeric_id: None,
                actor_user_id: uid,
                action: CREATOR_JOURNEY_AUDIT_ACTION,
                target_user_id: None,
                details: event_details(event),
            },
        )
        .await?;
        accepted += 1;
    }

    Ok(Json(IngestCreatorJourneyEventsResponse { accepted }))
}

#[derive(sqlx::FromRow)]
struct EventCountRow {
    name: String,
    count: i64,
}

#[derive(sqlx::FromRow)]
struct StepCountRow {
    step: String,
    count: i64,
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/creator-journey-summary",
    operation_id = "getProjectCreatorJourneySummaryByProjectIdV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        CreatorJourneySummaryQuery
    ),
    responses(
        (status = 200, description = "OK", body = CreatorJourneySummaryResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_project_creator_journey_summary(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Query(q): Query<CreatorJourneySummaryQuery>,
) -> Result<Json<CreatorJourneySummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;

    let days = q.days.unwrap_or(7).clamp(1, 90);

    let top_events: Vec<EventCountRow> = sqlx::query_as(
        r#"
        SELECT
          details->>'event' AS name,
          COUNT(*)::bigint AS count
        FROM public.app_project_audit
        WHERE project_id = $1
          AND workspace_id = $2
          AND action = $3
          AND created_at >= (NOW() AT TIME ZONE 'utc') - ($4::int * INTERVAL '1 day')
          AND details ? 'event'
        GROUP BY details->>'event'
        ORDER BY count DESC, name ASC
        LIMIT 10
        "#,
    )
    .bind(scope.id)
    .bind(scope.workspace_id)
    .bind(CREATOR_JOURNEY_AUDIT_ACTION)
    .bind(days)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let step_selections: Vec<StepCountRow> = sqlx::query_as(
        r#"
        SELECT
          COALESCE(details->'properties'->>'step', 'unknown') AS step,
          COUNT(*)::bigint AS count
        FROM public.app_project_audit
        WHERE project_id = $1
          AND workspace_id = $2
          AND action = $3
          AND created_at >= (NOW() AT TIME ZONE 'utc') - ($4::int * INTERVAL '1 day')
          AND details->>'event' = 'step_selected'
        GROUP BY step
        ORDER BY count DESC, step ASC
        "#,
    )
    .bind(scope.id)
    .bind(scope.workspace_id)
    .bind(CREATOR_JOURNEY_AUDIT_ACTION)
    .bind(days)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let retry_event_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_project_audit
        WHERE project_id = $1
          AND workspace_id = $2
          AND action = $3
          AND created_at >= (NOW() AT TIME ZONE 'utc') - ($4::int * INTERVAL '1 day')
          AND (
            details->>'event' LIKE '%retry%'
            OR details->>'event' = 'failed_jobs_open_tasks'
          )
        "#,
    )
    .bind(scope.id)
    .bind(scope.workspace_id)
    .bind(CREATOR_JOURNEY_AUDIT_ACTION)
    .bind(days)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_events: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_project_audit
        WHERE project_id = $1
          AND workspace_id = $2
          AND action = $3
          AND created_at >= (NOW() AT TIME ZONE 'utc') - ($4::int * INTERVAL '1 day')
        "#,
    )
    .bind(scope.id)
    .bind(scope.workspace_id)
    .bind(CREATOR_JOURNEY_AUDIT_ACTION)
    .bind(days)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(CreatorJourneySummaryResponse {
        top_events: top_events
            .into_iter()
            .map(|row| CreatorJourneyEventCount {
                name: row.name,
                count: row.count,
            })
            .collect(),
        step_selections: step_selections
            .into_iter()
            .map(|row| CreatorJourneyStepCount {
                step: row.step,
                count: row.count,
            })
            .collect(),
        retry_event_count,
        total_events,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn validate_event_name_accepts_dotted_names() {
        validate_event_name("review_pack_load_ok").expect("valid");
    }

    #[test]
    fn validate_event_name_rejects_empty() {
        assert!(validate_event_name("  ").is_err());
    }
}
