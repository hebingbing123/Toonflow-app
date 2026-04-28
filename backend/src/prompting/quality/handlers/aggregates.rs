use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use super::super::types::{
    ListQualityTokenEfficiencySamplesQuery, QualityStatsResponse, QualityTokenEfficiencyResponse,
    QualityTokenEfficiencySample, StagePassRateItem,
};
use super::super::validate::validate_token_efficiency_samples_query;

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
        GROUP BY target_type
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(stats))
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
        GROUP BY target_type, DATE_TRUNC('day', created_at)
        ORDER BY review_date DESC
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}

/// GET /api/v1/quality/token-efficiency - 质量 / token 效率聚合
#[utoipa::path(
    get,
    path = "/api/v1/quality/token-efficiency",
    operation_id = "getQualityTokenEfficiencyV1",
    tag = "quality",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_token_efficiency(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Vec<QualityTokenEfficiencyResponse>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let items = sqlx::query_as::<_, QualityTokenEfficiencyResponse>(
        r#"
        WITH usage_per_review AS (
            SELECT
                quality_review_id,
                SUM(total_tokens)::double precision AS total_tokens
            FROM app_llm_usage_log
            WHERE user_id = $1
              AND quality_review_id IS NOT NULL
            GROUP BY quality_review_id
        )
        SELECT
            qr.target_type,
            COUNT(*) AS total_reviews,
            COUNT(*) FILTER (WHERE upr.quality_review_id IS NOT NULL) AS linked_llm_review_count,
            COALESCE(ROUND(AVG(qr.overall_score)::numeric, 2), 0) AS avg_overall_score,
            COALESCE(ROUND(AVG(((qr.model_params->'diagnostics'->>'promptChars')::double precision))::numeric, 2), 0) AS avg_prompt_chars,
            COALESCE(ROUND(AVG(((qr.model_params->'diagnostics'->>'memoryDeliveryChars')::double precision))::numeric, 2), 0) AS avg_memory_delivery_chars,
            COALESCE(ROUND(AVG(((qr.model_params->'diagnostics'->>'memoryVisualChars')::double precision))::numeric, 2), 0) AS avg_memory_visual_chars,
            COALESCE(ROUND(AVG(((qr.model_params->'diagnostics'->>'memoryScriptScopeChars')::double precision))::numeric, 2), 0) AS avg_memory_script_scope_chars,
            COALESCE(ROUND(AVG(((qr.model_params->'diagnostics'->>'memoryProjectScopeChars')::double precision))::numeric, 2), 0) AS avg_memory_project_scope_chars,
            COALESCE(ROUND(AVG(((qr.model_params->'diagnostics'->>'memoryMixedScopeChars')::double precision))::numeric, 2), 0) AS avg_memory_mixed_scope_chars,
            COALESCE(ROUND(AVG(upr.total_tokens)::numeric, 2), 0) AS avg_linked_total_tokens,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN qr.overall_score IS NOT NULL AND qr.overall_score > 0
                    THEN ((qr.model_params->'diagnostics'->>'promptChars')::double precision) / qr.overall_score
                    ELSE NULL
                END
            )::numeric, 2), 0) AS avg_prompt_chars_per_score_point,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN qr.overall_score IS NOT NULL AND qr.overall_score > 0
                    THEN upr.total_tokens / qr.overall_score
                    ELSE NULL
                END
            )::numeric, 2), 0) AS avg_linked_tokens_per_score_point,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN qr.memory_delivery_priority_applied = true
                     AND qr.overall_score IS NOT NULL
                     AND qr.overall_score > 0
                    THEN ((qr.model_params->'diagnostics'->>'promptChars')::double precision) / qr.overall_score
                    ELSE NULL
                END
            )::numeric, 2), 0) AS delivery_priority_avg_prompt_chars_per_score_point,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN qr.memory_delivery_priority_applied = true
                     AND qr.overall_score IS NOT NULL
                     AND qr.overall_score > 0
                    THEN upr.total_tokens / qr.overall_score
                    ELSE NULL
                END
            )::numeric, 2), 0) AS delivery_priority_avg_linked_tokens_per_score_point,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN qr.memory_delivery_priority_applied IS DISTINCT FROM true
                     AND qr.overall_score IS NOT NULL
                     AND qr.overall_score > 0
                    THEN ((qr.model_params->'diagnostics'->>'promptChars')::double precision) / qr.overall_score
                    ELSE NULL
                END
            )::numeric, 2), 0) AS non_delivery_priority_avg_prompt_chars_per_score_point,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN qr.memory_delivery_priority_applied IS DISTINCT FROM true
                     AND qr.overall_score IS NOT NULL
                     AND qr.overall_score > 0
                    THEN upr.total_tokens / qr.overall_score
                    ELSE NULL
                END
            )::numeric, 2), 0) AS non_delivery_priority_avg_linked_tokens_per_score_point
        FROM app_quality_review qr
        LEFT JOIN usage_per_review upr ON upr.quality_review_id = qr.id
        WHERE qr.user_id = $1
        GROUP BY qr.target_type
        "#,
    )
    .bind(user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}

/// GET /api/v1/quality/token-efficiency/samples - 质量 / token 低效样本下钻
#[utoipa::path(
    get,
    path = "/api/v1/quality/token-efficiency/samples",
    operation_id = "getQualityTokenEfficiencySamplesV1",
    tag = "quality",
    params(ListQualityTokenEfficiencySamplesQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_token_efficiency_samples(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListQualityTokenEfficiencySamplesQuery>,
) -> Result<Json<Vec<QualityTokenEfficiencySample>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_token_efficiency_samples_query(&query)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(12).clamp(1, 50);

    let items = sqlx::query_as::<_, QualityTokenEfficiencySample>(
        r#"
        WITH usage_per_review AS (
            SELECT
                quality_review_id,
                SUM(total_tokens)::double precision AS total_tokens
            FROM app_llm_usage_log
            WHERE user_id = $1
              AND quality_review_id IS NOT NULL
            GROUP BY quality_review_id
        ),
        sample_rows AS (
            SELECT
                qr.id AS review_id,
                qr.created_at,
                qr.project_id,
                qr.script_id,
                qr.job_id,
                qr.target_type,
                qr.target_id,
                qr.source,
                qr.overall_score,
                qr.passed,
                qr.is_bad_case,
                qr.memory_delivery_priority_applied,
                COALESCE((qr.model_params->'diagnostics'->>'promptChars')::double precision, 0) AS prompt_chars,
                COALESCE(upr.total_tokens, 0) AS linked_total_tokens,
                COALESCE((qr.model_params->'diagnostics'->>'memoryDeliveryChars')::double precision, 0) AS memory_delivery_chars,
                COALESCE((qr.model_params->'diagnostics'->>'memoryVisualChars')::double precision, 0) AS memory_visual_chars,
                COALESCE((qr.model_params->'diagnostics'->>'memoryScriptScopeChars')::double precision, 0) AS memory_script_scope_chars,
                COALESCE((qr.model_params->'diagnostics'->>'memoryProjectScopeChars')::double precision, 0) AS memory_project_scope_chars,
                COALESCE((qr.model_params->'diagnostics'->>'memoryMixedScopeChars')::double precision, 0) AS memory_mixed_scope_chars,
                CASE
                    WHEN qr.overall_score IS NOT NULL AND qr.overall_score > 0
                    THEN COALESCE((qr.model_params->'diagnostics'->>'promptChars')::double precision, 0) / qr.overall_score
                    ELSE 0
                END AS prompt_chars_per_score_point,
                CASE
                    WHEN qr.overall_score IS NOT NULL AND qr.overall_score > 0
                    THEN COALESCE(upr.total_tokens, 0) / qr.overall_score
                    ELSE 0
                END AS linked_tokens_per_score_point
            FROM app_quality_review qr
            LEFT JOIN usage_per_review upr ON upr.quality_review_id = qr.id
            WHERE qr.user_id = $1
              AND ($2::text IS NULL OR qr.target_type = $2)
              AND (
                qr.overall_score IS NOT NULL
                OR upr.total_tokens IS NOT NULL
                OR qr.model_params->'diagnostics'->>'promptChars' IS NOT NULL
              )
        ),
        ranked_rows AS (
            SELECT
                *,
                CASE
                    WHEN GREATEST(
                        memory_script_scope_chars,
                        memory_project_scope_chars,
                        memory_mixed_scope_chars
                    ) <= 0 THEN 'none'
                    WHEN memory_script_scope_chars >= memory_project_scope_chars
                     AND memory_script_scope_chars >= memory_mixed_scope_chars THEN 'script'
                    WHEN memory_project_scope_chars >= memory_mixed_scope_chars THEN 'project'
                    ELSE 'mixed'
                END AS dominant_memory_scope
            FROM sample_rows
        )
        SELECT
            review_id,
            created_at,
            project_id,
            script_id,
            job_id,
            target_type,
            target_id,
            source,
            overall_score,
            passed,
            is_bad_case,
            memory_delivery_priority_applied,
            prompt_chars,
            linked_total_tokens,
            memory_delivery_chars,
            memory_visual_chars,
            memory_script_scope_chars,
            memory_project_scope_chars,
            memory_mixed_scope_chars,
            ROUND(prompt_chars_per_score_point::numeric, 2)::double precision AS prompt_chars_per_score_point,
            ROUND(linked_tokens_per_score_point::numeric, 2)::double precision AS linked_tokens_per_score_point,
            dominant_memory_scope,
            CASE
                WHEN memory_delivery_priority_applied IS DISTINCT FROM true
                 AND (is_bad_case = true OR passed = false)
                    THEN 'shift_to_delivery_memory'
                WHEN dominant_memory_scope = 'project'
                    THEN 'trim_project_memory'
                WHEN dominant_memory_scope = 'mixed'
                    THEN 'split_mixed_memory'
                WHEN dominant_memory_scope = 'script'
                 AND memory_delivery_priority_applied = true
                    THEN 'trim_script_memory_keep_delivery'
                WHEN dominant_memory_scope = 'script'
                    THEN 'trim_script_memory'
                ELSE 'tighten_core_prompt'
            END AS recommended_action,
            CASE
                WHEN memory_delivery_priority_applied IS DISTINCT FROM true
                 AND (is_bad_case = true OR passed = false)
                    THEN '先把预算从泛设定移到情绪、动作和语气约束'
                WHEN dominant_memory_scope = 'project'
                    THEN 'project 级记忆占主导，先压缩通用设定'
                WHEN dominant_memory_scope = 'mixed'
                    THEN 'mixed 记忆占主导，先拆回 project/script 再裁剪'
                WHEN dominant_memory_scope = 'script'
                 AND memory_delivery_priority_applied = true
                    THEN '表演优先已命中，优先删减剧情复述'
                WHEN dominant_memory_scope = 'script'
                    THEN 'script 级记忆占主导，保留当前镜头强约束即可'
                ELSE '不是记忆在烧预算，先收紧核心 prompt'
            END AS recommended_action_reason
        FROM ranked_rows
        ORDER BY
            GREATEST(prompt_chars_per_score_point, linked_tokens_per_score_point) DESC,
            is_bad_case DESC,
            prompt_chars DESC,
            created_at DESC
        LIMIT $3
        "#,
    )
    .bind(user_id)
    .bind(query.target_type.as_deref())
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(items))
}
