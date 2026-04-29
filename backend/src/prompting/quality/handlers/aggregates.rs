use axum::{extract::State, http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use axum::extract::Query;

use super::super::types::{
    QualityScopeInsightResponse, QualityStatsResponse, QualityTokenEfficiencyResponse,
    QualityTokenEfficiencySample, StagePassRateItem,
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
pub struct ScopeInsightsQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub limit: Option<i64>,
}

/// GET /api/v1/quality/scope-insights - scope aggregated quality hotspots for project/script triage.
#[utoipa::path(
    get,
    path = "/api/v1/quality/scope-insights",
    operation_id = "getQualityScopeInsightsV1",
    tag = "quality",
    params(ScopeInsightsQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_scope_insights(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ScopeInsightsQuery>,
) -> Result<Json<Vec<QualityScopeInsightResponse>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(5).clamp(1, 20);

    let rows = sqlx::query_as::<_, QualityScopeInsightResponse>(
        r#"
        SELECT
            CASE
                WHEN project_id IS NOT NULL AND script_id IS NOT NULL THEN 'P' || project_id::text || '/S' || script_id::text
                WHEN project_id IS NOT NULL THEN 'P' || project_id::text
                WHEN script_id IS NOT NULL THEN 'S' || script_id::text
                ELSE target_type
            END as scope_label,
            project_id,
            script_id,
            COUNT(*) as total_reviews,
            COUNT(*) FILTER (WHERE source = 'auto') as auto_reviews,
            COUNT(*) FILTER (WHERE passed = true) as passed_count,
            COUNT(*) FILTER (WHERE is_bad_case = true) as bad_case_count,
            COALESCE(ROUND(
                COUNT(*) FILTER (WHERE passed = true) * 100.0 / NULLIF(COUNT(*), 0),
                2
            ), 0) as pass_rate_percent,
            COALESCE(AVG(overall_score), 0) as avg_overall_score,
            COUNT(*) FILTER (
                WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                   OR comments ILIKE '%生硬%'
                   OR comments ILIKE '%朗读%'
                   OR comments ILIKE '%没情绪%'
                   OR comments ILIKE '%无情绪%'
            ) as dialogue_risk_count,
            COUNT(*) FILTER (
                WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                   OR comments ILIKE '%穿帮%'
                   OR comments ILIKE '%不自然%'
                   OR comments ILIKE '%ai%'
                   OR comments ILIKE '%假%'
            ) as visual_risk_count,
            COALESCE(AVG(
                CASE
                    WHEN source = 'auto' AND model_params ? 'diagnostics'
                    THEN COALESCE((model_params->'diagnostics'->>'promptChars')::int, 0)
                    ELSE NULL
                END
            ), 0) as avg_prompt_chars,
            COALESCE(AVG(
                CASE
                    WHEN source = 'auto' AND model_params ? 'diagnostics'
                    THEN COALESCE((model_params->'diagnostics'->>'memoryStyleChars')::int, 0)
                    ELSE NULL
                END
            ), 0) as avg_memory_chars,
            COALESCE(AVG(
                CASE
                    WHEN source = 'auto' AND model_params ? 'diagnostics'
                    THEN COALESCE((model_params->'diagnostics'->>'memoryDeliveryChars')::int, 0)
                    ELSE NULL
                END
            ), 0) as avg_memory_delivery_chars,
            COALESCE(ROUND(AVG(
                CASE
                    WHEN source = 'auto' AND model_params ? 'diagnostics'
                    THEN CASE
                        WHEN COALESCE((model_params->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean, false) THEN 1
                        ELSE 0
                    END
                    ELSE NULL
                END
            ) * 100.0, 2), 0) as delivery_priority_hit_rate_percent,
            COALESCE(SUM(
                CASE
                    WHEN source = 'auto' AND model_params ? 'diagnostics'
                    THEN COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
                    ELSE 0
                END
            ), 0) as memory_removed_chars,
            COALESCE(SUM(
                CASE
                    WHEN source = 'auto' AND model_params ? 'diagnostics'
                    THEN COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedRows')::int, 0)
                    ELSE 0
                END
            ), 0) as memory_removed_rows,
            COUNT(*) FILTER (
                WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) as feedback_selected_memory_promotions,
            COUNT(*) FILTER (
                WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) as feedback_rejected_memory_writes,
            COUNT(*) FILTER (
                WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'replaced_summary_memory'
            ) as feedback_summary_memory_writes,
            COALESCE(SUM(
                CASE
                    WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                    THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                    ELSE 0
                END
            ), 0) as feedback_memory_removed_chars,
            COALESCE(SUM(
                CASE
                    WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                    THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedRows')::int, 0)
                    ELSE 0
                END
            ), 0) as feedback_memory_removed_rows,
            CASE
                WHEN COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                       OR comments ILIKE '%生硬%'
                       OR comments ILIKE '%朗读%'
                       OR comments ILIKE '%没情绪%'
                       OR comments ILIKE '%无情绪%'
                ) > 0
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) > 0
                THEN 'keep_delivery_memory'
                WHEN COUNT(*) FILTER (
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                       OR comments ILIKE '%穿帮%'
                       OR comments ILIKE '%不自然%'
                       OR comments ILIKE '%ai%'
                       OR comments ILIKE '%假%'
                ) > 0
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
                ) > 0
                THEN 'reuse_negative_memory'
                WHEN COALESCE(AVG(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryStyleChars')::int, 0)
                        ELSE NULL
                    END
                ), 0) >= 96
                OR COALESCE(SUM(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
                        ELSE 0
                    END
                ), 0) >= 80
                OR COALESCE(SUM(
                    CASE
                        WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                        THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                        ELSE 0
                    END
                ), 0) >= 80
                THEN 'trim_generic_style_memory'
                WHEN COUNT(*) FILTER (WHERE passed = true) > 0
                AND COALESCE(AVG(overall_score), 0) >= 85
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) = 0
                THEN 'promote_selected_memory'
                ELSE 'observe'
            END as memory_action,
            CASE
                WHEN COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                       OR comments ILIKE '%生硬%'
                       OR comments ILIKE '%朗读%'
                       OR comments ILIKE '%没情绪%'
                       OR comments ILIKE '%无情绪%'
                ) > 0
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) > 0
                THEN 'selected_video_memory'
                WHEN COUNT(*) FILTER (
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                       OR comments ILIKE '%穿帮%'
                       OR comments ILIKE '%不自然%'
                       OR comments ILIKE '%ai%'
                       OR comments ILIKE '%假%'
                ) > 0
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
                ) > 0
                THEN 'rejected_video_negative_memory'
                WHEN COALESCE(AVG(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryStyleChars')::int, 0)
                        ELSE NULL
                    END
                ), 0) >= 96
                OR COALESCE(SUM(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
                        ELSE 0
                    END
                ), 0) >= 80
                OR COALESCE(SUM(
                    CASE
                        WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                        THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                        ELSE 0
                    END
                ), 0) >= 80
                THEN 'project_video_style_memory'
                WHEN COUNT(*) FILTER (WHERE passed = true) > 0
                AND COALESCE(AVG(overall_score), 0) >= 85
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) = 0
                THEN 'selected_video_memory'
                ELSE 'observe'
            END as memory_focus,
            CASE
                WHEN COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                       OR comments ILIKE '%生硬%'
                       OR comments ILIKE '%朗读%'
                       OR comments ILIKE '%没情绪%'
                       OR comments ILIKE '%无情绪%'
                ) > 0
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) > 0
                THEN 'Keep scoped acting memory and keep trimming generic style first.'
                WHEN COUNT(*) FILTER (
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                       OR comments ILIKE '%穿帮%'
                       OR comments ILIKE '%不自然%'
                       OR comments ILIKE '%ai%'
                       OR comments ILIKE '%假%'
                ) > 0
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
                ) > 0
                THEN 'Reuse isolated bad-case constraints before adding more prompt text.'
                WHEN COALESCE(AVG(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryStyleChars')::int, 0)
                        ELSE NULL
                    END
                ), 0) >= 96
                OR COALESCE(SUM(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
                        ELSE 0
                    END
                ), 0) >= 80
                OR COALESCE(SUM(
                    CASE
                        WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                        THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                        ELSE 0
                    END
                ), 0) >= 80
                THEN 'Project-wide style memory is eating budget; trim generic visual/style lines first.'
                WHEN COUNT(*) FILTER (WHERE passed = true) > 0
                AND COALESCE(AVG(overall_score), 0) >= 85
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) = 0
                THEN 'Promote one approved scoped sample into selected memory for later reuse.'
                ELSE 'Memory is already scoped; keep observing review quality before changing it.'
            END as memory_reason
        FROM app_quality_review
        WHERE user_id = $1
          AND (project_id IS NOT NULL OR script_id IS NOT NULL)
          AND ($2::int IS NULL OR project_id = $2)
          AND ($3::int IS NULL OR script_id = $3)
        GROUP BY project_id, script_id, target_type
        ORDER BY
            (
                COUNT(*) FILTER (WHERE is_bad_case = true) * 100
                + COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                       OR comments ILIKE '%生硬%'
                       OR comments ILIKE '%朗读%'
                       OR comments ILIKE '%没情绪%'
                       OR comments ILIKE '%无情绪%'
                ) * 30
                + COUNT(*) FILTER (
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                       OR comments ILIKE '%穿帮%'
                       OR comments ILIKE '%不自然%'
                       OR comments ILIKE '%ai%'
                       OR comments ILIKE '%假%'
                ) * 30
                + COALESCE(SUM(
                    CASE
                        WHEN source = 'auto' AND model_params ? 'diagnostics'
                        THEN COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
                        ELSE 0
                    END
                ), 0)
            ) DESC,
            COUNT(*) DESC,
            MAX(created_at) DESC
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

    Ok(Json(rows))
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

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct TokenEfficiencyQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
}

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct TokenEfficiencySamplesQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub limit: Option<i64>,
    pub target_type: Option<String>,
    pub memory_delivery_priority_applied: Option<bool>,
}

/// GET /api/v1/quality/token-efficiency - token usage aggregates (from `model_params.diagnostics`).
#[utoipa::path(
    get,
    path = "/api/v1/quality/token-efficiency",
    operation_id = "getQualityTokenEfficiencyV1",
    tag = "quality",
    params(TokenEfficiencyQuery),
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
    Query(query): Query<TokenEfficiencyQuery>,
) -> Result<Json<Vec<QualityTokenEfficiencyResponse>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let rows = sqlx::query_as::<_, QualityTokenEfficiencyResponse>(
        r#"
        SELECT
          target_type,
          COUNT(*) as sample_count,
          COALESCE(AVG(((model_params->'diagnostics'->>'promptChars')::int)), 0) as avg_prompt_chars,
          COALESCE(AVG(
            GREATEST(
              ((model_params->'diagnostics'->>'promptChars')::int)
              - ((model_params->'diagnostics'->>'memoryStyleChars')::int),
              0
            )
          ), 0) as avg_non_memory_prompt_chars,
          COALESCE(AVG(((model_params->'diagnostics'->>'memoryStyleChars')::int)), 0) as avg_memory_style_chars,
          COALESCE(AVG(((model_params->'diagnostics'->>'memoryVisualChars')::int)), 0) as avg_memory_visual_chars,
          COALESCE(AVG(((model_params->'diagnostics'->>'memoryDeliveryChars')::int)), 0) as avg_memory_delivery_chars,
          COALESCE(ROUND(AVG(
            CASE
              WHEN ((model_params->'diagnostics'->>'promptChars')::int) > 0 THEN
                (((model_params->'diagnostics'->>'memoryStyleChars')::int) * 100.0)
                / ((model_params->'diagnostics'->>'promptChars')::int)
              ELSE 0
            END
          ), 2), 0) as avg_memory_share_percent,
          COALESCE(ROUND(AVG(
            CASE
              WHEN ((model_params->'diagnostics'->>'promptChars')::int) > 0 THEN
                (((model_params->'diagnostics'->>'memoryDeliveryChars')::int) * 100.0)
                / ((model_params->'diagnostics'->>'promptChars')::int)
              ELSE 0
            END
          ), 2), 0) as avg_delivery_memory_share_percent,
          COALESCE(ROUND(AVG(CASE WHEN (model_params->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean THEN 1 ELSE 0 END) * 100.0, 2), 0)
            as delivery_priority_hit_rate_percent,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                 OR comments ILIKE '%生硬%'
                 OR comments ILIKE '%朗读%'
                 OR comments ILIKE '%没情绪%'
                 OR comments ILIKE '%无情绪%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) > 0
            THEN 'keep_delivery_memory'
            WHEN COUNT(*) FILTER (
              WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                 OR comments ILIKE '%穿帮%'
                 OR comments ILIKE '%不自然%'
                 OR comments ILIKE '%ai%'
                 OR comments ILIKE '%假%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) > 0
            THEN 'reuse_negative_memory'
            WHEN COALESCE(AVG(((model_params->'diagnostics'->>'memoryStyleChars')::int)), 0) >= 96
              OR COALESCE(SUM(
                COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
              ), 0) >= 80
              OR COALESCE(SUM(
                CASE
                  WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                  THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                  ELSE 0
                END
              ), 0) >= 80
            THEN 'trim_generic_style_memory'
            WHEN COUNT(*) FILTER (WHERE passed = true) > 0
            AND COALESCE(AVG(overall_score), 0) >= 85
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) = 0
            THEN 'promote_selected_memory'
            ELSE 'observe'
          END as memory_action,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                 OR comments ILIKE '%生硬%'
                 OR comments ILIKE '%朗读%'
                 OR comments ILIKE '%没情绪%'
                 OR comments ILIKE '%无情绪%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) > 0
            THEN 'selected_video_memory'
            WHEN COUNT(*) FILTER (
              WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                 OR comments ILIKE '%穿帮%'
                 OR comments ILIKE '%不自然%'
                 OR comments ILIKE '%ai%'
                 OR comments ILIKE '%假%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) > 0
            THEN 'rejected_video_negative_memory'
            WHEN COALESCE(AVG(((model_params->'diagnostics'->>'memoryStyleChars')::int)), 0) >= 96
              OR COALESCE(SUM(
                COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
              ), 0) >= 80
              OR COALESCE(SUM(
                CASE
                  WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                  THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                  ELSE 0
                END
              ), 0) >= 80
            THEN 'project_video_style_memory'
            WHEN COUNT(*) FILTER (WHERE passed = true) > 0
            AND COALESCE(AVG(overall_score), 0) >= 85
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) = 0
            THEN 'selected_video_memory'
            ELSE 'observe'
          END as memory_focus,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 80)
                 OR comments ILIKE '%生硬%'
                 OR comments ILIKE '%朗读%'
                 OR comments ILIKE '%没情绪%'
                 OR comments ILIKE '%无情绪%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) > 0
            THEN 'Keep scoped acting memory and keep trimming generic style first.'
            WHEN COUNT(*) FILTER (
              WHERE (visual_quality IS NOT NULL AND visual_quality < 80)
                 OR comments ILIKE '%穿帮%'
                 OR comments ILIKE '%不自然%'
                 OR comments ILIKE '%ai%'
                 OR comments ILIKE '%假%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) > 0
            THEN 'Reuse isolated bad-case constraints before adding more prompt text.'
            WHEN COALESCE(AVG(((model_params->'diagnostics'->>'memoryStyleChars')::int)), 0) >= 96
              OR COALESCE(SUM(
                COALESCE((model_params->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
              ), 0) >= 80
              OR COALESCE(SUM(
                CASE
                  WHEN model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                  THEN COALESCE((model_params->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                  ELSE 0
                END
              ), 0) >= 80
            THEN 'Project-wide style memory is eating budget; trim generic visual/style lines first.'
            WHEN COUNT(*) FILTER (WHERE passed = true) > 0
            AND COALESCE(AVG(overall_score), 0) >= 85
            AND COUNT(*) FILTER (
              WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) = 0
            THEN 'Promote one approved scoped sample into selected memory for later reuse.'
            ELSE 'Memory is already scoped; keep observing review quality before changing it.'
          END as memory_reason
        FROM app_quality_review
        WHERE user_id = $1
          AND source = 'auto'
          AND model_params ? 'diagnostics'
          AND ($2::int IS NULL OR project_id = $2)
          AND ($3::int IS NULL OR script_id = $3)
        GROUP BY target_type
        ORDER BY sample_count DESC
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}

/// GET /api/v1/quality/token-efficiency/samples - sample token usage rows.
#[utoipa::path(
    get,
    path = "/api/v1/quality/token-efficiency/samples",
    operation_id = "getQualityTokenEfficiencySamplesV1",
    tag = "quality",
    params(TokenEfficiencySamplesQuery),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_token_efficiency_samples(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<TokenEfficiencySamplesQuery>,
) -> Result<Json<Vec<QualityTokenEfficiencySample>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(200).clamp(1, 1000);

    let rows = sqlx::query_as::<_, QualityTokenEfficiencySample>(
        r#"
        SELECT
          created_at,
          target_type,
          COALESCE(((model_params->'diagnostics'->>'promptChars')::int), 0) as prompt_chars,
          GREATEST(
            COALESCE(((model_params->'diagnostics'->>'promptChars')::int), 0)
            - COALESCE(((model_params->'diagnostics'->>'memoryStyleChars')::int), 0),
            0
          ) as non_memory_prompt_chars,
          COALESCE(((model_params->'diagnostics'->>'memoryStyleChars')::int), 0) as memory_style_chars,
          COALESCE(((model_params->'diagnostics'->>'memoryVisualChars')::int), 0) as memory_visual_chars,
          COALESCE(((model_params->'diagnostics'->>'memoryDeliveryChars')::int), 0) as memory_delivery_chars,
          COALESCE(
            ROUND(
              CASE
                WHEN COALESCE(((model_params->'diagnostics'->>'promptChars')::int), 0) > 0 THEN
                  (
                    COALESCE(((model_params->'diagnostics'->>'memoryStyleChars')::int), 0) * 100.0
                  ) / ((model_params->'diagnostics'->>'promptChars')::int)
                ELSE 0
              END,
              2
            ),
            0
          ) as memory_share_percent,
          COALESCE(
            ROUND(
              CASE
                WHEN COALESCE(((model_params->'diagnostics'->>'promptChars')::int), 0) > 0 THEN
                  (
                    COALESCE(((model_params->'diagnostics'->>'memoryDeliveryChars')::int), 0) * 100.0
                  ) / ((model_params->'diagnostics'->>'promptChars')::int)
                ELSE 0
              END,
              2
            ),
            0
          ) as delivery_memory_share_percent,
          COALESCE(((model_params->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean), false)
            as memory_delivery_priority_applied
        FROM app_quality_review
        WHERE user_id = $1
          AND source = 'auto'
          AND model_params ? 'diagnostics'
          AND ($2::int IS NULL OR project_id = $2)
          AND ($3::int IS NULL OR script_id = $3)
          AND ($4::text IS NULL OR target_type = $4)
          AND (
            $5::boolean IS NULL
            OR COALESCE(((model_params->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean), false) = $5
          )
        ORDER BY created_at DESC
        LIMIT $6
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .bind(query.target_type.as_deref())
    .bind(query.memory_delivery_priority_applied)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}
