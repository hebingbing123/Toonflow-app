use axum::extract::{Query, State};
use axum::{http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{
    QualityDashboardResponse, QualityStatsResponse, StagePassRateItem,
};

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
            'user'::text as scope,
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

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct QualityDashboardQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
}

/// GET /api/v1/quality/dashboard - 主面板聚合读模型
#[utoipa::path(
    get,
    path = "/api/v1/quality/dashboard",
    operation_id = "getQualityDashboardV1",
    tag = "quality",
    params(QualityDashboardQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_dashboard(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<QualityDashboardQuery>,
) -> Result<Json<QualityDashboardResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let payload = sqlx::query_scalar::<_, serde_json::Value>(
        r#"
        WITH filtered_reviews AS MATERIALIZED (
            SELECT *
            FROM app_quality_review
            WHERE user_id = $1
              AND ($2::int IS NULL OR project_id = $2)
              AND ($3::int IS NULL OR script_id = $3)
        ),
        filtered_auto_reviews AS MATERIALIZED (
            SELECT *
            FROM filtered_reviews
            WHERE source = 'auto'
              AND model_params ? 'diagnostics'
        ),
        filtered_token_usage AS MATERIALIZED (
            SELECT
                usage.*,
                qr.target_type,
                qr.stage,
                qr.overall_score,
                qr.passed,
                qr.dialogue_naturalness,
                qr.visual_quality,
                qr.comments,
                qr.model_params
            FROM app_llm_usage_log usage
            INNER JOIN filtered_auto_reviews qr ON qr.id = usage.quality_review_id
            WHERE usage.user_id = $1
              AND usage.quality_review_id IS NOT NULL
              AND ($2::int IS NULL OR usage.project_id = $2)
              AND ($3::int IS NULL OR usage.script_id = $3)
        )
        SELECT jsonb_build_object(
            'stats',
            COALESCE((
                SELECT jsonb_agg(to_jsonb(s))
                FROM (
                    SELECT
                        'user'::text as scope,
                        fr.target_type as "targetType",
                        COUNT(*)::bigint as "totalReviews",
                        COALESCE(ROUND(
                            COUNT(*) FILTER (WHERE fr.passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                            2
                        ), 0)::float8 as "passRatePercent",
                        COALESCE(ROUND(AVG(fr.overall_score), 2), 0)::float8 as "avgOverallScore"
                    FROM filtered_reviews fr
                    WHERE (
                        fr.passed IS NOT NULL
                        OR fr.overall_score IS NOT NULL
                        OR fr.is_bad_case = true
                        OR fr.bad_case_category IS NOT NULL
                        OR fr.grade IS NOT NULL
                    )
                    GROUP BY fr.target_type
                    ORDER BY COUNT(*) DESC, fr.target_type
                    LIMIT 4
                ) s
            ), '[]'::jsonb),
            'stagePassRate',
            COALESCE((
                SELECT jsonb_agg(to_jsonb(s))
                FROM (
                    SELECT
                        'user'::text as scope,
                        fr.target_type as "targetType",
                        DATE_TRUNC('day', fr.created_at) as "reviewDate",
                        COUNT(*)::bigint as "totalReviews",
                        COALESCE(ROUND(
                            COUNT(*) FILTER (WHERE fr.passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                            2
                        ), 0)::float8 as "passRatePercent"
                    FROM filtered_reviews fr
                    WHERE (
                        fr.passed IS NOT NULL
                        OR fr.overall_score IS NOT NULL
                        OR fr.is_bad_case = true
                        OR fr.bad_case_category IS NOT NULL
                        OR fr.grade IS NOT NULL
                    )
                    GROUP BY fr.target_type, DATE_TRUNC('day', fr.created_at)
                    ORDER BY DATE_TRUNC('day', fr.created_at) DESC, COUNT(*) DESC
                    LIMIT 6
                ) s
            ), '[]'::jsonb),
            'stageGradeDistribution',
            COALESCE((
                SELECT jsonb_agg(to_jsonb(s))
                FROM (
                    SELECT
                        'user'::text as scope,
                        fr.stage as stage,
                        COUNT(*) FILTER (WHERE fr.grade = 'A')::bigint as "gradeACount",
                        COUNT(*) FILTER (WHERE fr.grade = 'B')::bigint as "gradeBCount",
                        COUNT(*) FILTER (WHERE fr.grade = 'C')::bigint as "gradeCCount",
                        COUNT(*) FILTER (WHERE fr.grade = 'D')::bigint as "gradeDCount",
                        COUNT(*)::bigint as "totalCount",
                        COALESCE(ROUND(
                            COUNT(*) FILTER (WHERE fr.grade IN ('A', 'B')) * 100.0 / NULLIF(COUNT(*), 0),
                            2
                        ), 0)::float8 as "passRatePercent"
                    FROM filtered_reviews fr
                    WHERE fr.stage IS NOT NULL
                      AND fr.grade IS NOT NULL
                    GROUP BY fr.stage
                    ORDER BY
                        CASE fr.stage
                            WHEN 'story_skeleton' THEN 1
                            WHEN 'adaptation_strategy' THEN 2
                            WHEN 'director_planning' THEN 3
                            WHEN 'storyboard_table' THEN 4
                            WHEN 'storyboard_panel' THEN 5
                            WHEN 'video_prompt' THEN 6
                            ELSE 7
                        END
                    LIMIT 6
                ) s
            ), '[]'::jsonb),
            'scopeInsights',
            COALESCE((
                SELECT jsonb_agg(to_jsonb(s))
                FROM (
                    SELECT
                        'user'::text as scope,
                        CASE
                            WHEN fr.project_id IS NOT NULL AND fr.script_id IS NOT NULL THEN 'P' || fr.project_id::text || '/S' || fr.script_id::text
                            WHEN fr.project_id IS NOT NULL THEN 'P' || fr.project_id::text
                            WHEN fr.script_id IS NOT NULL THEN 'S' || fr.script_id::text
                            ELSE fr.target_type
                        END as "scopeLabel",
                        COUNT(*)::bigint as "totalReviews",
                        COUNT(*) FILTER (WHERE fr.is_bad_case = true)::bigint as "badCaseCount",
                        COALESCE(ROUND(
                            COUNT(*) FILTER (WHERE fr.passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                            2
                        ), 0)::float8 as "passRatePercent"
                    FROM filtered_reviews fr
                    GROUP BY 2
                    ORDER BY COUNT(*) DESC, COUNT(*) FILTER (WHERE fr.is_bad_case = true) DESC
                    LIMIT 4
                ) s
            ), '[]'::jsonb),
            'tokenEfficiency',
            COALESCE((
                SELECT jsonb_agg(to_jsonb(s))
                FROM (
                    SELECT
                        'user'::text as scope,
                        ftu.target_type as "targetType",
                        COUNT(*)::bigint as "sampleCount",
                        COALESCE(AVG((COALESCE(ftu.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int), 0)::float8 as "avgPromptChars",
                        COALESCE(AVG((COALESCE(ftu.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int), 0)::float8 as "avgMemoryStyleChars",
                        COALESCE(AVG((COALESCE(ftu.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryChars')::int), 0)::float8 as "avgMemoryDeliveryChars",
                        CASE
                            WHEN COUNT(*) FILTER (
                                WHERE (ftu.dialogue_naturalness IS NOT NULL AND ftu.dialogue_naturalness < 8)
                                   OR ftu.comments ILIKE '%生硬%'
                                   OR ftu.comments ILIKE '%朗读%'
                                   OR ftu.comments ILIKE '%没情绪%'
                                   OR ftu.comments ILIKE '%无情绪%'
                            ) > 0 THEN 'keep_delivery_memory'
                            WHEN COUNT(*) FILTER (
                                WHERE (ftu.visual_quality IS NOT NULL AND ftu.visual_quality < 8)
                                   OR ftu.comments ILIKE '%穿帮%'
                                   OR ftu.comments ILIKE '%不自然%'
                                   OR ftu.comments ILIKE '%ai%'
                                   OR ftu.comments ILIKE '%假%'
                            ) > 0 THEN 'reuse_negative_memory'
                            WHEN COALESCE(AVG((COALESCE(ftu.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int), 0) >= 96
                            THEN 'trim_generic_style_memory'
                            WHEN COUNT(*) FILTER (WHERE ftu.passed = true) > 0
                            THEN 'promote_selected_memory'
                            ELSE 'observe'
                        END as "memoryAction"
                    FROM filtered_token_usage ftu
                    GROUP BY ftu.target_type
                    ORDER BY COUNT(*) DESC, AVG(ftu.total_tokens) DESC
                    LIMIT 4
                ) s
            ), '[]'::jsonb),
            'badCaseStats',
            COALESCE((
                SELECT jsonb_agg(to_jsonb(s))
                FROM (
                    SELECT
                        'user'::text as scope,
                        fr.bad_case_category as "badCaseCategory",
                        COUNT(*)::bigint as count,
                        COALESCE(ROUND(
                            COUNT(*) FILTER (WHERE fr.passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                            2
                        ), 0)::float8 as "passRatePercent",
                        COALESCE(ROUND(AVG(fr.overall_score), 2), 0)::float8 as "avgScore"
                    FROM filtered_reviews fr
                    WHERE fr.is_bad_case = true
                    GROUP BY fr.bad_case_category
                    ORDER BY COUNT(*) DESC, fr.bad_case_category
                    LIMIT 5
                ) s
            ), '[]'::jsonb)
        )
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let dashboard: QualityDashboardResponse =
        serde_json::from_value(payload).map_err(|_| ApiError::Internal)?;
    Ok(Json(dashboard))
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
            'user'::text as scope,
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
            'user'::text as scope,
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
