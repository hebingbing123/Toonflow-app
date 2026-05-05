use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

use crate::{
    auth::require_user_uuid,
    error::ApiError,
    http_kit::request_dedupe::{dedupe_project_overview, RequestDedupeKey},
    projects::routes::types::{
        ProjectAssetsOverviewResponse, ProjectProductionOverviewResponse, ProjectStatsResponse,
    },
    publish::require_project_owned,
    state::AppState,
};

#[derive(Debug, Deserialize, IntoParams, ToSchema)]
pub struct ProjectOverviewQuery {
    /// Include quality scope insights (default: false)
    #[serde(default)]
    pub include_quality: bool,
    /// Include task center data (default: false)
    #[serde(default)]
    pub include_tasks: bool,
    /// Include bad case stats (default: false)
    #[serde(default)]
    pub include_bad_cases: bool,
}

#[derive(Debug, Serialize, Deserialize, ToSchema)]
pub struct ProjectOverviewResponse {
    /// Project statistics (counts)
    pub stats: ProjectStatsResponse,
    /// Production overview (storyboard status, etc.)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub production_overview: Option<ProjectProductionOverviewResponse>,
    /// Assets overview (scene/clip counts by status)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub assets_overview: Option<ProjectAssetsOverviewResponse>,
    /// Short video assembly data
    #[serde(skip_serializing_if = "Option::is_none")]
    pub short_video_assembly: Option<serde_json::Value>,
    /// Short video export check
    #[serde(skip_serializing_if = "Option::is_none")]
    pub short_video_export_check: Option<serde_json::Value>,
    /// Short video readiness
    #[serde(skip_serializing_if = "Option::is_none")]
    pub short_video_readiness: Option<serde_json::Value>,
    /// Scene asset count
    pub scene_asset_count: i64,
    /// Clip asset count
    pub clip_asset_count: i64,
    /// Quality scope insights (optional)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub quality_scope_insights: Option<Vec<serde_json::Value>>,
    /// Bad case statistics (optional)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub bad_case_stats: Option<Vec<serde_json::Value>>,
    /// Recent tasks (optional)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub recent_tasks: Option<serde_json::Value>,
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/overview",
    operation_id = "getProjectOverviewV1",
    tag = "projects",
    params(
        ("project_id" = Uuid, Path, description = "Project UUID"),
        ProjectOverviewQuery
    ),
    responses(
        (status = 200, description = "OK", body = ProjectOverviewResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_overview_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    Query(query): Query<ProjectOverviewQuery>,
    headers: HeaderMap,
) -> Result<Json<ProjectOverviewResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    require_project_owned(pool, uid, project_id).await?;

    // J.6: Deduplicate concurrent identical requests
    let mut query_flags = Vec::new();
    if query.include_quality {
        query_flags.push("include_quality");
    }
    if query.include_tasks {
        query_flags.push("include_tasks");
    }
    if query.include_bad_cases {
        query_flags.push("include_bad_cases");
    }
    let dedupe_key = RequestDedupeKey::project_overview(uid, project_id, &query_flags);

    let result_json = dedupe_project_overview(dedupe_key, || async {
        // Fetch all core project data in parallel using tokio::try_join!
        let (
            stats_result,
            production_overview_result,
            assets_overview_result,
            assembly_result,
            export_check_result,
            readiness_result,
            scene_count,
            clip_count,
        ) = tokio::try_join!(
            fetch_project_stats(pool, project_id, uid),
            fetch_production_overview(pool, project_id, uid),
            fetch_assets_overview(pool, project_id, uid),
            fetch_short_video_assembly(pool, project_id, uid),
            fetch_short_video_export_check(pool, project_id, uid),
            fetch_short_video_readiness(pool, project_id, uid),
            fetch_asset_count(pool, project_id, uid, "scene"),
            fetch_asset_count(pool, project_id, uid, "clip"),
        )?;

        // Optionally fetch quality, bad cases, and tasks in parallel
        let (quality_scope_insights, bad_case_stats, recent_tasks) =
            if query.include_quality || query.include_bad_cases || query.include_tasks {
                tokio::try_join!(
                    async {
                        if query.include_quality {
                            fetch_quality_scope_insights(pool, project_id, uid, 1).await
                        } else {
                            Ok(None)
                        }
                    },
                    async {
                        if query.include_bad_cases {
                            fetch_bad_case_stats(pool, project_id, uid, 3).await
                        } else {
                            Ok(None)
                        }
                    },
                    async {
                        if query.include_tasks {
                            fetch_recent_tasks(pool, project_id, uid, 6).await
                        } else {
                            Ok(None)
                        }
                    },
                )?
            } else {
                (None, None, None)
            };

        let response = ProjectOverviewResponse {
            stats: stats_result,
            production_overview: production_overview_result,
            assets_overview: assets_overview_result,
            short_video_assembly: assembly_result,
            short_video_export_check: export_check_result,
            short_video_readiness: readiness_result,
            scene_asset_count: scene_count,
            clip_asset_count: clip_count,
            quality_scope_insights,
            bad_case_stats,
            recent_tasks,
        };

        // Serialize to JSON for caching
        serde_json::to_value(&response)
            .map_err(|e| ApiError::BadRequest(format!("Failed to serialize response: {}", e)))
    })
    .await?;

    // Deserialize back to typed response
    let response: ProjectOverviewResponse = serde_json::from_value(result_json)
        .map_err(|e| ApiError::BadRequest(format!("Failed to deserialize response: {}", e)))?;

    Ok(Json(response))
}

async fn fetch_project_stats(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    uid: Uuid,
) -> Result<ProjectStatsResponse, ApiError> {
    let script_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_script
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let storyboard_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        INNER JOIN app_script s ON sb.script_id = s.id
        WHERE s.project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let role_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset
        WHERE project_id = $1 AND asset_type = 'role'
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let novel_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_novel
        WHERE project_id = $1
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let video_count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_generation_job
        WHERE owner_user_id = $2
          AND status = 'succeeded'
          AND (kind ILIKE '%video%' OR kind ILIKE '%workbench%')
          AND payload->>'project_numeric_id' = (
              SELECT numeric_id::text FROM app_project WHERE id = $1
          )
        "#,
    )
    .bind(project_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(ProjectStatsResponse {
        script_count,
        storyboard_count,
        role_count,
        novel_count,
        video_count,
    })
}

async fn fetch_production_overview(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
) -> Result<Option<ProjectProductionOverviewResponse>, ApiError> {
    // Placeholder - actual implementation would call the existing handler logic
    Ok(None)
}

async fn fetch_assets_overview(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
) -> Result<Option<ProjectAssetsOverviewResponse>, ApiError> {
    // Placeholder - actual implementation would call the existing handler logic
    Ok(None)
}

async fn fetch_short_video_assembly(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
) -> Result<Option<serde_json::Value>, ApiError> {
    // Placeholder - actual implementation would call the existing handler logic
    Ok(None)
}

async fn fetch_short_video_export_check(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
) -> Result<Option<serde_json::Value>, ApiError> {
    // Placeholder - actual implementation would call the existing handler logic
    Ok(None)
}

async fn fetch_short_video_readiness(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
) -> Result<Option<serde_json::Value>, ApiError> {
    // Placeholder - actual implementation would call the existing handler logic
    Ok(None)
}

async fn fetch_asset_count(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    _uid: Uuid,
    asset_type: &str,
) -> Result<i64, ApiError> {
    let count: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_asset
        WHERE project_id = $1 AND asset_type = $2
        "#,
    )
    .bind(project_id)
    .bind(asset_type)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(count)
}

async fn fetch_quality_scope_insights(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
    _limit: i64,
) -> Result<Option<Vec<serde_json::Value>>, ApiError> {
    // Placeholder - actual implementation would query the quality tables
    Ok(None)
}

async fn fetch_bad_case_stats(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
    _limit: i64,
) -> Result<Option<Vec<serde_json::Value>>, ApiError> {
    // Placeholder - actual implementation would query the quality tables
    Ok(None)
}

async fn fetch_recent_tasks(
    _pool: &sqlx::PgPool,
    _project_id: Uuid,
    _uid: Uuid,
    _limit: i64,
) -> Result<Option<serde_json::Value>, ApiError> {
    // Placeholder - actual implementation would query the task center
    Ok(None)
}
