//! GET /api/v1/quality/bad-case-stats — bad case 按类别聚合 top-N（需求 2.1）。

use axum::{extract::State, http::HeaderMap, Json};
use serde::Serialize;
use sqlx::FromRow;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use axum::extract::Query;

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct BadCaseStatsQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub limit: Option<i64>,
}

#[derive(Debug, Serialize, FromRow)]
#[serde(rename_all = "camelCase")]
pub struct BadCaseStatItem {
    pub bad_case_category: Option<String>,
    pub count: i64,
    pub pass_rate_percent: f64,
    pub avg_score: f64,
}

/// GET /api/v1/quality/bad-case-stats
///
/// 按 bad_case_category 聚合 top-N，返回各类别数量、通过率和平均分。
#[utoipa::path(
    get,
    path = "/api/v1/quality/bad-case-stats",
    operation_id = "getQualityBadCaseStatsV1",
    tag = "quality",
    params(BadCaseStatsQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_bad_case_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<BadCaseStatsQuery>,
) -> Result<Json<Vec<BadCaseStatItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(5).clamp(1, 20);

    let items = sqlx::query_as::<_, BadCaseStatItem>(
        r#"
        SELECT
            bad_case_category,
            COUNT(*) as count,
            COALESCE(ROUND(
                COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                2
            ), 0) as pass_rate_percent,
            COALESCE(ROUND(AVG(overall_score), 2), 0) as avg_score
        FROM app_quality_review
        WHERE user_id = $1
          AND is_bad_case = true
          AND ($2::int IS NULL OR project_id = $2)
          AND ($3::int IS NULL OR script_id = $3)
        GROUP BY bad_case_category
        ORDER BY count DESC, bad_case_category
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}
