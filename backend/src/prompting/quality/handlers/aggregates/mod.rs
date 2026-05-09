use axum::extract::{Query, State};
use axum::{http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{
    QualityDashboardRefreshResponse, QualityDashboardResponse, QualityStatsResponse,
    StagePassRateItem,
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

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct QualityDashboardRefreshQuery {
    pub only_if_stale: Option<bool>,
}

#[derive(sqlx::FromRow)]
struct DashboardRefreshMeta {
    refreshed_at: chrono::DateTime<chrono::Utc>,
    row_count: i64,
    source_review_count: i64,
    source_usage_count: i64,
    source_max_review_created_at: Option<chrono::DateTime<chrono::Utc>>,
    source_max_usage_created_at: Option<chrono::DateTime<chrono::Utc>>,
}

const QUALITY_DASHBOARD_REFRESH_LOCK_ID: i64 = 641_003_201;
const QUALITY_DASHBOARD_STATE_KEY: &str = "quality_main_panel";
const QUALITY_DASHBOARD_STALE_AFTER_SECONDS: i64 = 15 * 60;

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
            FROM app_quality_dashboard_review_fact
            WHERE user_id = $1
              AND ($2::int IS NULL OR project_id = $2)
              AND ($3::int IS NULL OR script_id = $3)
        ),
        filtered_signal_reviews AS MATERIALIZED (
            SELECT *
            FROM filtered_reviews
            WHERE has_quality_signal = true
        ),
        filtered_auto_reviews AS MATERIALIZED (
            SELECT *
            FROM filtered_reviews
            WHERE has_diagnostics = true
              AND has_token_usage = true
        )
        SELECT jsonb_build_object(
            'meta',
            (
                WITH state_row AS (
                    SELECT
                        refreshed_at,
                        row_count,
                        source_review_count,
                        source_usage_count,
                        source_max_review_created_at,
                        source_max_usage_created_at
                    FROM app_dashboard_refresh_state
                    WHERE dashboard_key = 'quality_main_panel'
                )
                SELECT jsonb_build_object(
                    'refreshedAt', state_row.refreshed_at,
                    'snapshotRowCount', COALESCE(state_row.row_count, (SELECT COUNT(*)::bigint FROM filtered_reviews)),
                    'sourceReviewCount', COALESCE(state_row.source_review_count, 0),
                    'sourceUsageCount', COALESCE(state_row.source_usage_count, 0),
                    'sourceMaxReviewCreatedAt', state_row.source_max_review_created_at,
                    'sourceMaxUsageCreatedAt', state_row.source_max_usage_created_at,
                    'ageSeconds',
                        CASE
                            WHEN state_row.refreshed_at IS NULL THEN NULL
                            ELSE GREATEST(
                                FLOOR(EXTRACT(EPOCH FROM (NOW() - state_row.refreshed_at)))::bigint,
                                0
                            )
                        END,
                    'stale',
                        CASE
                            WHEN state_row.refreshed_at IS NULL THEN true
                            WHEN state_row.source_max_review_created_at IS NOT NULL
                                 AND state_row.source_max_review_created_at > state_row.refreshed_at THEN true
                            WHEN state_row.source_max_usage_created_at IS NOT NULL
                                 AND state_row.source_max_usage_created_at > state_row.refreshed_at THEN true
                            WHEN FLOOR(EXTRACT(EPOCH FROM (NOW() - state_row.refreshed_at)))::bigint > $4 THEN true
                            ELSE false
                        END,
                    'staleReason',
                        CASE
                            WHEN state_row.refreshed_at IS NULL THEN 'never_refreshed'
                            WHEN state_row.source_max_review_created_at IS NOT NULL
                                 AND state_row.source_max_review_created_at > state_row.refreshed_at
                            THEN 'new_reviews_after_snapshot'
                            WHEN state_row.source_max_usage_created_at IS NOT NULL
                                 AND state_row.source_max_usage_created_at > state_row.refreshed_at
                            THEN 'new_usage_after_snapshot'
                            WHEN FLOOR(EXTRACT(EPOCH FROM (NOW() - state_row.refreshed_at)))::bigint > $4
                            THEN 'snapshot_age_exceeded'
                            ELSE NULL
                        END,
                    'refreshMode', 'materialized_view_concurrent_refresh'
                )
                FROM state_row
                RIGHT JOIN (SELECT 1 AS present) sentinel ON true
                LIMIT 1
            ),
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
                    FROM filtered_signal_reviews fr
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
                    FROM filtered_signal_reviews fr
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
                    FROM filtered_signal_reviews fr
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
                        far.target_type as "targetType",
                        COUNT(*)::bigint as "sampleCount",
                        COALESCE(AVG(far.diagnostics_prompt_chars), 0)::float8 as "avgPromptChars",
                        COALESCE(AVG(far.diagnostics_memory_style_chars), 0)::float8 as "avgMemoryStyleChars",
                        COALESCE(AVG(far.diagnostics_memory_delivery_chars), 0)::float8 as "avgMemoryDeliveryChars",
                        CASE
                            WHEN COUNT(*) FILTER (
                                WHERE (far.dialogue_naturalness IS NOT NULL AND far.dialogue_naturalness < 8)
                                   OR far.comments ILIKE '%生硬%'
                                   OR far.comments ILIKE '%朗读%'
                                   OR far.comments ILIKE '%没情绪%'
                                   OR far.comments ILIKE '%无情绪%'
                            ) > 0 THEN 'keep_delivery_memory'
                            WHEN COUNT(*) FILTER (
                                WHERE (far.visual_quality IS NOT NULL AND far.visual_quality < 8)
                                   OR far.comments ILIKE '%穿帮%'
                                   OR far.comments ILIKE '%不自然%'
                                   OR far.comments ILIKE '%ai%'
                                   OR far.comments ILIKE '%假%'
                            ) > 0 THEN 'reuse_negative_memory'
                            WHEN COALESCE(AVG(far.diagnostics_memory_style_chars), 0) >= 96
                            THEN 'trim_generic_style_memory'
                            WHEN COUNT(*) FILTER (WHERE far.passed = true) > 0
                            THEN 'promote_selected_memory'
                            ELSE 'observe'
                        END as "memoryAction"
                    FROM filtered_auto_reviews far
                    GROUP BY far.target_type
                    ORDER BY COUNT(*) DESC, AVG(far.avg_total_tokens) DESC NULLS LAST
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
    .bind(QUALITY_DASHBOARD_STALE_AFTER_SECONDS)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let dashboard: QualityDashboardResponse =
        serde_json::from_value(payload).map_err(|_| ApiError::Internal)?;
    Ok(Json(dashboard))
}

/// POST /api/v1/quality/dashboard - 刷新主面板物化读模型
#[utoipa::path(
    post,
    path = "/api/v1/quality/dashboard",
    operation_id = "refreshQualityDashboardV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = crate::prompting::quality::QualityDashboardRefreshResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    params(QualityDashboardRefreshQuery),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_dashboard_refresh(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<QualityDashboardRefreshQuery>,
) -> Result<Json<QualityDashboardRefreshResponse>, ApiError> {
    let _user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let mut conn = pool
        .acquire()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let lock_acquired = sqlx::query_scalar::<_, bool>("SELECT pg_try_advisory_lock($1)")
        .bind(QUALITY_DASHBOARD_REFRESH_LOCK_ID)
        .fetch_one(&mut *conn)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !lock_acquired {
        return Err(ApiError::Conflict(
            "quality dashboard refresh already in progress".into(),
        ));
    }

    let stale_before_refresh = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT
            CASE
                WHEN refreshed_at IS NULL THEN true
                WHEN source_max_review_created_at IS NOT NULL
                     AND source_max_review_created_at > refreshed_at THEN true
                WHEN source_max_usage_created_at IS NOT NULL
                     AND source_max_usage_created_at > refreshed_at THEN true
                WHEN FLOOR(EXTRACT(EPOCH FROM (NOW() - refreshed_at)))::bigint > $2 THEN true
                ELSE false
            END as stale
        FROM app_dashboard_refresh_state
        WHERE dashboard_key = $1
        "#,
    )
    .bind(QUALITY_DASHBOARD_STATE_KEY)
    .bind(QUALITY_DASHBOARD_STALE_AFTER_SECONDS)
    .fetch_optional(&mut *conn)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .unwrap_or(true);

    if query.only_if_stale.unwrap_or(false) && !stale_before_refresh {
        let current = sqlx::query_as::<_, DashboardRefreshMeta>(
            r#"
            SELECT
                refreshed_at,
                row_count,
                source_review_count,
                source_usage_count,
                source_max_review_created_at,
                source_max_usage_created_at
            FROM app_dashboard_refresh_state
            WHERE dashboard_key = $1
            "#,
        )
        .bind(QUALITY_DASHBOARD_STATE_KEY)
        .fetch_one(&mut *conn)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let unlock_result = sqlx::query_scalar::<_, bool>("SELECT pg_advisory_unlock($1)")
            .bind(QUALITY_DASHBOARD_REFRESH_LOCK_ID)
            .fetch_one(&mut *conn)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if !unlock_result {
            return Err(ApiError::DatabaseError(
                "quality dashboard refresh advisory lock was not released".into(),
            ));
        }

        return Ok(Json(QualityDashboardRefreshResponse {
            refreshed_at: current.refreshed_at,
            row_count: current.row_count,
            mode: "skipped_fresh_snapshot".into(),
            performed: false,
            stale_before_refresh: false,
            source_review_count: current.source_review_count,
            source_usage_count: current.source_usage_count,
            source_max_review_created_at: current.source_max_review_created_at,
            source_max_usage_created_at: current.source_max_usage_created_at,
        }));
    }

    let refresh_result = async {
        sqlx::query("REFRESH MATERIALIZED VIEW CONCURRENTLY app_quality_dashboard_review_fact")
            .execute(&mut *conn)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        sqlx::query_as::<_, DashboardRefreshMeta>(
            r#"
            WITH source_meta AS (
                SELECT
                    (SELECT COUNT(*)::bigint FROM app_quality_review) as source_review_count,
                    (SELECT COUNT(*)::bigint FROM app_llm_usage_log WHERE quality_review_id IS NOT NULL) as source_usage_count,
                    (SELECT MAX(created_at) FROM app_quality_review) as source_max_review_created_at,
                    (SELECT MAX(created_at) FROM app_llm_usage_log WHERE quality_review_id IS NOT NULL) as source_max_usage_created_at
            ),
            upserted AS (
                INSERT INTO app_dashboard_refresh_state (
                    dashboard_key,
                    refreshed_at,
                    row_count,
                    source_review_count,
                    source_usage_count,
                    source_max_review_created_at,
                    source_max_usage_created_at,
                    updated_at
                )
                SELECT
                    $1,
                    NOW(),
                    (SELECT COUNT(*)::bigint FROM app_quality_dashboard_review_fact),
                    source_meta.source_review_count,
                    source_meta.source_usage_count,
                    source_meta.source_max_review_created_at,
                    source_meta.source_max_usage_created_at,
                    NOW()
                FROM source_meta
                ON CONFLICT (dashboard_key) DO UPDATE SET
                    refreshed_at = EXCLUDED.refreshed_at,
                    row_count = EXCLUDED.row_count,
                    source_review_count = EXCLUDED.source_review_count,
                    source_usage_count = EXCLUDED.source_usage_count,
                    source_max_review_created_at = EXCLUDED.source_max_review_created_at,
                    source_max_usage_created_at = EXCLUDED.source_max_usage_created_at,
                    updated_at = NOW()
                RETURNING
                    refreshed_at,
                    row_count,
                    source_review_count,
                    source_usage_count,
                    source_max_review_created_at,
                    source_max_usage_created_at
            )
            SELECT
                refreshed_at,
                row_count,
                source_review_count,
                source_usage_count,
                source_max_review_created_at,
                source_max_usage_created_at
            FROM upserted
            "#,
        )
        .bind(QUALITY_DASHBOARD_STATE_KEY)
        .fetch_one(&mut *conn)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))
    }
    .await;

    let unlock_result = sqlx::query_scalar::<_, bool>("SELECT pg_advisory_unlock($1)")
        .bind(QUALITY_DASHBOARD_REFRESH_LOCK_ID)
        .fetch_one(&mut *conn)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !unlock_result {
        return Err(ApiError::DatabaseError(
            "quality dashboard refresh advisory lock was not released".into(),
        ));
    }

    let meta = refresh_result?;
    Ok(Json(QualityDashboardRefreshResponse {
        refreshed_at: meta.refreshed_at,
        row_count: meta.row_count,
        mode: "materialized_view_concurrent_refresh".into(),
        performed: true,
        stale_before_refresh,
        source_review_count: meta.source_review_count,
        source_usage_count: meta.source_usage_count,
        source_max_review_created_at: meta.source_max_review_created_at,
        source_max_usage_created_at: meta.source_max_usage_created_at,
    }))
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
