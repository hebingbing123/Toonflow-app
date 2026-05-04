use axum::extract::{Query, State};
use axum::{http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{QualityStatsResponse, StagePassRateItem};

mod utils;

#[allow(unused_imports)]
pub(crate) use utils::{
    __path_get_scope_insights, __path_get_token_efficiency, __path_get_token_efficiency_samples,
    get_scope_insights, get_token_efficiency, get_token_efficiency_samples, TokenEfficiencyQuery,
    TokenEfficiencySamplesQuery,
};

/// GET /api/v1/quality/stats - 获取质量统计
#[utoipa::path(
    get,
    path = "/api/v1/quality/stats",
    operation_id = "getQualityStatsV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<QualityStatsResponse>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let stats = sqlx::query_as::<_, QualityStatsResponse>(
        r#"
        SELECT
            target_type,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE passed = false) as failed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            ROUND(COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0), 2) as pass_rate_percent,
            COALESCE(AVG(overall_score), 0) as avg_overall_score,
            COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true) as delivery_priority_total_reviews,
            COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true AND passed = true) as delivery_priority_passed_count,
            COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true AND is_bad_case = true) as delivery_priority_bad_case_count,
            COALESCE(ROUND(
                COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true AND passed = true) * 100.0
                / NULLIF(COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true), 0),
                2
            ), 0) as delivery_priority_pass_rate_percent,
            COUNT(*) FILTER (
                WHERE memory_delivery_priority_applied IS DISTINCT FROM true
            ) as non_delivery_priority_total_reviews,
            COUNT(*) FILTER (
                WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                  AND passed = true
            ) as non_delivery_priority_passed_count,
            COUNT(*) FILTER (
                WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                  AND is_bad_case = true
            ) as non_delivery_priority_bad_case_count,
            COALESCE(ROUND(
                COUNT(*) FILTER (
                    WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                      AND passed = true
                ) * 100.0
                / NULLIF(
                    COUNT(*) FILTER (
                        WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                    ),
                    0
                ),
                2
            ), 0) as non_delivery_priority_pass_rate_percent
        FROM app_quality_review
        WHERE user_id = $1
          AND (
            passed IS NOT NULL
            OR overall_score IS NOT NULL
            OR is_bad_case = true
            OR bad_case_category IS NOT NULL
            OR grade IS NOT NULL
          )
        GROUP BY target_type
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(stats))
}

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct StagePassRateQuery {
    /// 按技能版本哈希过滤（可选，用于版本变更前后对比）
    pub skill_version_hash: Option<String>,
}

/// GET /api/v1/quality/stage-pass-rate - 分环节通过率（按日期聚合）
#[utoipa::path(
    get,
    path = "/api/v1/quality/stage-pass-rate",
    operation_id = "getQualityStagePassRateV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_stage_pass_rate(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<StagePassRateQuery>,
) -> Result<Json<Vec<StagePassRateItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let items = sqlx::query_as::<_, StagePassRateItem>(
        r#"
        SELECT
            target_type,
            DATE_TRUNC('day', created_at) as review_date,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            ROUND(COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0), 2) as pass_rate_percent,
            AVG(overall_score) as avg_score,
            COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true) as delivery_priority_total_reviews,
            COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true AND passed = true) as delivery_priority_passed_count,
            COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true AND is_bad_case = true) as delivery_priority_bad_case_count,
            COALESCE(ROUND(
                COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true AND passed = true) * 100.0
                / NULLIF(COUNT(*) FILTER (WHERE memory_delivery_priority_applied = true), 0),
                2
            ), 0) as delivery_priority_pass_rate_percent,
            COUNT(*) FILTER (
                WHERE memory_delivery_priority_applied IS DISTINCT FROM true
            ) as non_delivery_priority_total_reviews,
            COUNT(*) FILTER (
                WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                  AND passed = true
            ) as non_delivery_priority_passed_count,
            COUNT(*) FILTER (
                WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                  AND is_bad_case = true
            ) as non_delivery_priority_bad_case_count,
            COALESCE(ROUND(
                COUNT(*) FILTER (
                    WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                      AND passed = true
                ) * 100.0
                / NULLIF(
                    COUNT(*) FILTER (
                        WHERE memory_delivery_priority_applied IS DISTINCT FROM true
                    ),
                    0
                ),
                2
            ), 0) as non_delivery_priority_pass_rate_percent
        FROM app_quality_review
        WHERE user_id = $1
          AND ($2::text IS NULL OR skill_version_hash = $2)
          AND (
            passed IS NOT NULL
            OR overall_score IS NOT NULL
            OR is_bad_case = true
            OR bad_case_category IS NOT NULL
            OR grade IS NOT NULL
          )
        GROUP BY target_type, DATE_TRUNC('day', created_at)
        ORDER BY review_date DESC
        "#,
    )
    .bind(user_id)
    .bind(query.skill_version_hash.as_deref())
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}

/// GET /api/v1/quality/stage-grade-distribution - 按 stage + grade 分布统计（需求 6.4）
///
/// 返回各生成阶段（story_skeleton / adaptation_strategy / director_planning /
/// storyboard_table / storyboard_panel / video_prompt）的 A/B/C/D 评分分布和通过率（A+B 占比）。
#[utoipa::path(
    get,
    path = "/api/v1/quality/stage-grade-distribution",
    operation_id = "getQualityStageGradeDistributionV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_stage_grade_distribution(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<super::super::types::StageGradeDistributionItem>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let items = sqlx::query_as::<_, super::super::types::StageGradeDistributionItem>(
        r#"
        SELECT
            stage,
            COUNT(*) FILTER (WHERE grade = 'A') as grade_a_count,
            COUNT(*) FILTER (WHERE grade = 'B') as grade_b_count,
            COUNT(*) FILTER (WHERE grade = 'C') as grade_c_count,
            COUNT(*) FILTER (WHERE grade = 'D') as grade_d_count,
            COUNT(*) as total_count,
            COALESCE(ROUND(
                (COUNT(*) FILTER (WHERE grade IN ('A', 'B'))) * 100.0
                / NULLIF(COUNT(*), 0),
                2
            ), 0) as pass_rate_percent
        FROM app_quality_review
        WHERE user_id = $1
          AND stage IS NOT NULL
          AND grade IS NOT NULL
        GROUP BY stage
        ORDER BY
            CASE stage
                WHEN 'story_skeleton' THEN 1
                WHEN 'adaptation_strategy' THEN 2
                WHEN 'director_planning' THEN 3
                WHEN 'storyboard_table' THEN 4
                WHEN 'storyboard_panel' THEN 5
                WHEN 'video_prompt' THEN 6
                ELSE 7
            END
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}
