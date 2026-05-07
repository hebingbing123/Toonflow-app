use axum::extract::{Query, State};
use axum::{http::HeaderMap, Json};

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;

use crate::prompting::quality::types::{
    QualityScopeInsightResponse, QualityTokenEfficiencyResponse, QualityTokenEfficiencySample,
};

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
            'user'::text as scope,
            CASE
                WHEN qr.project_id IS NOT NULL AND qr.script_id IS NOT NULL THEN 'P' || qr.project_id::text || '/S' || qr.script_id::text
                WHEN qr.project_id IS NOT NULL THEN 'P' || qr.project_id::text
                WHEN qr.script_id IS NOT NULL THEN 'S' || qr.script_id::text
                ELSE qr.target_type
            END as scope_label,
            qr.project_id,
            qr.script_id,
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
                WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 8)
                   OR comments ILIKE '%生硬%'
                   OR comments ILIKE '%朗读%'
                   OR comments ILIKE '%没情绪%'
                   OR comments ILIKE '%无情绪%'
            ) as dialogue_risk_count,
            COUNT(*) FILTER (
                WHERE (visual_quality IS NOT NULL AND visual_quality < 8)
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
            COALESCE((
                SELECT ARRAY_AGG(ranked.tag ORDER BY ranked.tag_count DESC, ranked.tag)
                FROM (
                    SELECT feedback_tags.tag, COUNT(*) as tag_count
                    FROM (
                        SELECT jsonb_array_elements_text(
                            COALESCE(
                                qr_feedback.model_params->'diagnostics'->'feedbackMemory'->'focusTags',
                                '[]'::jsonb
                            )
                        ) as tag
                        FROM app_quality_review qr_feedback
                        WHERE qr_feedback.user_id = $1
                          AND qr_feedback.project_id IS NOT DISTINCT FROM qr.project_id
                          AND qr_feedback.script_id IS NOT DISTINCT FROM qr.script_id
                          AND qr_feedback.target_type = qr.target_type
                    ) feedback_tags
                    GROUP BY feedback_tags.tag
                    ORDER BY tag_count DESC, feedback_tags.tag
                    LIMIT 3
                ) ranked
            ), ARRAY[]::text[]) as feedback_focus_tags,
            CASE
                WHEN COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 8)
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
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 8)
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
                AND COALESCE(AVG(overall_score), 0) >= 8
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) = 0
                THEN 'promote_selected_memory'
                ELSE 'observe'
            END as memory_action,
            CASE
                WHEN COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 8)
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
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 8)
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
                AND COALESCE(AVG(overall_score), 0) >= 8
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) = 0
                THEN 'selected_video_memory'
                ELSE 'observe'
            END as memory_focus,
            CASE
                WHEN COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 8)
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
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 8)
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
                AND COALESCE(AVG(overall_score), 0) >= 8
                AND COUNT(*) FILTER (
                    WHERE model_params->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                ) = 0
                THEN 'Promote one approved scoped sample into selected memory for later reuse.'
                ELSE 'Memory is already scoped; keep observing review quality before changing it.'
            END as memory_reason
        FROM app_quality_review qr
        WHERE qr.user_id = $1
          AND (qr.project_id IS NOT NULL OR qr.script_id IS NOT NULL)
          AND ($2::int IS NULL OR qr.project_id = $2)
          AND ($3::int IS NULL OR qr.script_id = $3)
          AND (
            qr.passed IS NOT NULL
            OR qr.overall_score IS NOT NULL
            OR qr.is_bad_case = true
            OR qr.bad_case_category IS NOT NULL
            OR qr.grade IS NOT NULL
          )
        GROUP BY qr.project_id, qr.script_id, qr.target_type
        ORDER BY
            (
                COUNT(*) FILTER (WHERE is_bad_case = true) * 100
                + COUNT(*) FILTER (
                    WHERE (dialogue_naturalness IS NOT NULL AND dialogue_naturalness < 8)
                       OR comments ILIKE '%生硬%'
                       OR comments ILIKE '%朗读%'
                       OR comments ILIKE '%没情绪%'
                       OR comments ILIKE '%无情绪%'
                ) * 30
                + COUNT(*) FILTER (
                    WHERE (visual_quality IS NOT NULL AND visual_quality < 8)
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

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct TokenEfficiencyQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub stage: Option<String>,
    pub model_name: Option<String>,
    pub call_type: Option<String>,
}

#[derive(Debug, serde::Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct TokenEfficiencySamplesQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub limit: Option<i64>,
    pub target_type: Option<String>,
    pub stage: Option<String>,
    pub model_name: Option<String>,
    pub call_type: Option<String>,
    pub memory_delivery_priority_applied: Option<bool>,
}

/// GET /api/v1/quality/token-efficiency - token usage + quality ROI aggregates.
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
          'user'::text as scope,
          COALESCE(qr.target_type, usage.meta->'qualityReview'->>'targetType', 'unknown') as target_type,
          qr.stage as stage,
          COALESCE(qr.model_name, usage.meta->'qualityReview'->>'modelName') as review_model_name,
          usage.call_type as call_type,
          COUNT(*) as sample_count,
          COALESCE(AVG(usage.total_tokens), 0) as avg_total_tokens,
          COALESCE(AVG(usage.prompt_tokens), 0) as avg_prompt_tokens,
          COALESCE(AVG(usage.completion_tokens), 0) as avg_completion_tokens,
          COALESCE(ROUND(AVG(COALESCE(qr.overall_score, 0)), 2), 0) as avg_overall_score,
          COALESCE(
            ROUND(AVG(CASE WHEN qr.passed = true THEN 1 ELSE 0 END) * 100.0, 2),
            0
          ) as pass_rate_percent,
          COUNT(*) FILTER (
            WHERE COALESCE(usage.total_tokens, 0) >= 4000
              AND (
                COALESCE(qr.overall_score, 0) < 8
                OR COALESCE(qr.passed, false) = false
              )
          ) as high_token_low_quality_sample_count,
          COALESCE(
            ROUND(
              (
                COUNT(*) FILTER (
                  WHERE COALESCE(usage.total_tokens, 0) >= 4000
                    AND (
                      COALESCE(qr.overall_score, 0) < 8
                      OR COALESCE(qr.passed, false) = false
                    )
                ) * 100.0
              ) / NULLIF(COUNT(*), 0),
              2
            ),
            0
          ) as high_token_low_quality_rate_percent,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE COALESCE(usage.total_tokens, 0) >= 4000
                AND (
                  COALESCE(qr.overall_score, 0) < 8
                  OR COALESCE(qr.passed, false) = false
                )
            ) > 0
            THEN 'high_token_low_quality'
            WHEN COALESCE(AVG(COALESCE(qr.overall_score, 0)), 0) >= 8
              AND COALESCE(AVG(CASE WHEN qr.passed = true THEN 1 ELSE 0 END), 0) >= 0.8
            THEN 'efficient'
            ELSE 'observe'
          END as roi_band,
          COALESCE(AVG((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int), 0) as avg_prompt_chars,
          COALESCE(AVG(
            GREATEST(
              ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int)
              - ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int),
              0
            )
          ), 0) as avg_non_memory_prompt_chars,
          COALESCE(AVG(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int)), 0) as avg_memory_style_chars,
          COALESCE(AVG(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryVisualChars')::int)), 0) as avg_memory_visual_chars,
          COALESCE(AVG(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryChars')::int)), 0) as avg_memory_delivery_chars,
          COALESCE(AVG(COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)), 0)
            as avg_memory_optimization_removed_chars,
          COALESCE(AVG(COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryProjectScopeRowCount')::int, 0)), 0)
            as avg_project_scope_row_count,
          COALESCE(AVG(COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryScriptScopeRowCount')::int, 0)), 0)
            as avg_script_scope_row_count,
          COALESCE(AVG(COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryRoleScopeRowCount')::int, 0)), 0)
            as avg_role_scope_row_count,
          COALESCE(ROUND(AVG(
            CASE
              WHEN ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int) > 0 THEN
                (((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int) * 100.0)
                / ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int)
              ELSE 0
            END
          ), 2), 0) as avg_memory_share_percent,
          COALESCE(ROUND(AVG(
            CASE
              WHEN ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int) > 0 THEN
                (((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryChars')::int) * 100.0)
                / ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int)
              ELSE 0
            END
          ), 2), 0) as avg_delivery_memory_share_percent,
          COALESCE(ROUND(AVG(CASE WHEN (COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean THEN 1 ELSE 0 END) * 100.0, 2), 0)
            as delivery_priority_hit_rate_percent,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE (qr.dialogue_naturalness IS NOT NULL AND qr.dialogue_naturalness < 8)
                 OR qr.comments ILIKE '%生硬%'
                 OR qr.comments ILIKE '%朗读%'
                 OR qr.comments ILIKE '%没情绪%'
                 OR qr.comments ILIKE '%无情绪%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) > 0
            THEN 'keep_delivery_memory'
            WHEN COUNT(*) FILTER (
              WHERE (qr.visual_quality IS NOT NULL AND qr.visual_quality < 8)
                 OR qr.comments ILIKE '%穿帮%'
                 OR qr.comments ILIKE '%不自然%'
                 OR qr.comments ILIKE '%ai%'
                 OR qr.comments ILIKE '%假%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) > 0
            THEN 'reuse_negative_memory'
            WHEN COALESCE(AVG(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int)), 0) >= 96
              OR COALESCE(SUM(
                COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
              ), 0) >= 80
              OR COALESCE(SUM(
                CASE
                  WHEN COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                  THEN COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                  ELSE 0
                END
              ), 0) >= 80
            THEN 'trim_generic_style_memory'
            WHEN COUNT(*) FILTER (WHERE qr.passed = true) > 0
            AND COALESCE(AVG(qr.overall_score), 0) >= 8
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) = 0
            THEN 'promote_selected_memory'
            ELSE 'observe'
          END as memory_action,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE (qr.dialogue_naturalness IS NOT NULL AND qr.dialogue_naturalness < 8)
                 OR qr.comments ILIKE '%生硬%'
                 OR qr.comments ILIKE '%朗读%'
                 OR qr.comments ILIKE '%没情绪%'
                 OR qr.comments ILIKE '%无情绪%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) > 0
            THEN 'selected_video_memory'
            WHEN COUNT(*) FILTER (
              WHERE (qr.visual_quality IS NOT NULL AND qr.visual_quality < 8)
                 OR qr.comments ILIKE '%穿帮%'
                 OR qr.comments ILIKE '%不自然%'
                 OR qr.comments ILIKE '%ai%'
                 OR qr.comments ILIKE '%假%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) > 0
            THEN 'rejected_video_negative_memory'
            WHEN COALESCE(AVG(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int)), 0) >= 96
              OR COALESCE(SUM(
                COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
              ), 0) >= 80
              OR COALESCE(SUM(
                CASE
                  WHEN COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                  THEN COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                  ELSE 0
                END
              ), 0) >= 80
            THEN 'project_video_style_memory'
            WHEN COUNT(*) FILTER (WHERE qr.passed = true) > 0
            AND COALESCE(AVG(qr.overall_score), 0) >= 8
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) = 0
            THEN 'selected_video_memory'
            ELSE 'observe'
          END as memory_focus,
          CASE
            WHEN COUNT(*) FILTER (
              WHERE (qr.dialogue_naturalness IS NOT NULL AND qr.dialogue_naturalness < 8)
                 OR qr.comments ILIKE '%生硬%'
                 OR qr.comments ILIKE '%朗读%'
                 OR qr.comments ILIKE '%没情绪%'
                 OR qr.comments ILIKE '%无情绪%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) > 0
            THEN 'Keep scoped acting memory and keep trimming generic style first.'
            WHEN COUNT(*) FILTER (
              WHERE (qr.visual_quality IS NOT NULL AND qr.visual_quality < 8)
                 OR qr.comments ILIKE '%穿帮%'
                 OR qr.comments ILIKE '%不自然%'
                 OR qr.comments ILIKE '%ai%'
                 OR qr.comments ILIKE '%假%'
            ) > 0
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'persisted_rejected_memory'
            ) > 0
            THEN 'Reuse isolated bad-case constraints before adding more prompt text.'
            WHEN COALESCE(AVG(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int)), 0) >= 96
              OR COALESCE(SUM(
                COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryOptimizationRemovedChars')::int, 0)
              ), 0) >= 80
              OR COALESCE(SUM(
                CASE
                  WHEN COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
                  THEN COALESCE((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'removedChars')::int, 0)
                  ELSE 0
                END
              ), 0) >= 80
            THEN 'Project-wide style memory is eating budget; trim generic visual/style lines first.'
            WHEN COUNT(*) FILTER (WHERE qr.passed = true) > 0
            AND COALESCE(AVG(qr.overall_score), 0) >= 8
            AND COUNT(*) FILTER (
              WHERE COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->'feedbackMemory'->>'action' = 'promoted_selected_memory'
            ) = 0
            THEN 'Promote one approved scoped sample into selected memory for later reuse.'
            ELSE 'Memory is already scoped; keep observing review quality before changing it.'
          END as memory_reason
        FROM app_llm_usage_log usage
        INNER JOIN app_quality_review qr ON qr.id = usage.quality_review_id
        WHERE usage.user_id = $1
          AND usage.quality_review_id IS NOT NULL
          AND qr.source = 'auto'
          AND qr.model_params ? 'diagnostics'
          AND ($2::int IS NULL OR usage.project_id = $2)
          AND ($3::int IS NULL OR usage.script_id = $3)
          AND ($4::text IS NULL OR qr.stage = $4)
          AND ($5::text IS NULL OR COALESCE(qr.model_name, usage.meta->'qualityReview'->>'modelName') = $5)
          AND ($6::text IS NULL OR usage.call_type = $6)
        GROUP BY
          COALESCE(qr.target_type, usage.meta->'qualityReview'->>'targetType', 'unknown'),
          qr.stage,
          COALESCE(qr.model_name, usage.meta->'qualityReview'->>'modelName'),
          usage.call_type
        ORDER BY sample_count DESC, avg_total_tokens DESC
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .bind(query.stage.as_deref())
    .bind(query.model_name.as_deref())
    .bind(query.call_type.as_deref())
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
          'user'::text as scope,
          usage.created_at,
          COALESCE(qr.target_type, usage.meta->'qualityReview'->>'targetType', 'unknown') as target_type,
          qr.stage as stage,
          COALESCE(qr.model_name, usage.meta->'qualityReview'->>'modelName') as review_model_name,
          usage.call_type,
          COALESCE(usage.total_tokens, 0)::int as total_tokens,
          COALESCE(usage.prompt_tokens, 0)::int as prompt_tokens,
          COALESCE(usage.completion_tokens, 0)::int as completion_tokens,
          qr.overall_score,
          usage.meta->'qualityReview'->>'memoryBudgetTier' as memory_budget_tier,
          usage.meta->'qualityReview'->>'autoNegativeSource' as auto_negative_source,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int), 0) as prompt_chars,
          GREATEST(
            COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int), 0)
            - COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int), 0),
            0
          ) as non_memory_prompt_chars,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int), 0) as memory_style_chars,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryVisualChars')::int), 0) as memory_visual_chars,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryChars')::int), 0) as memory_delivery_chars,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryOptimizationRemovedChars')::int), 0)
            as memory_optimization_removed_chars,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryProjectScopeRowCount')::int), 0)
            as project_scope_row_count,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryScriptScopeRowCount')::int), 0)
            as script_scope_row_count,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryRoleScopeRowCount')::int), 0)
            as role_scope_row_count,
          COALESCE(
            ROUND(
              CASE
                WHEN COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int), 0) > 0 THEN
                  (
                    COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryStyleChars')::int), 0) * 100.0
                  ) / ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int)
                ELSE 0
              END,
              2
            ),
            0
          ) as memory_share_percent,
          COALESCE(
            ROUND(
              CASE
                WHEN COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int), 0) > 0 THEN
                  (
                    COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryChars')::int), 0) * 100.0
                  ) / ((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'promptChars')::int)
                ELSE 0
              END,
              2
            ),
            0
          ) as delivery_memory_share_percent,
          COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean), false)
            as memory_delivery_priority_applied
        FROM app_llm_usage_log usage
        INNER JOIN app_quality_review qr ON qr.id = usage.quality_review_id
        WHERE usage.user_id = $1
          AND usage.quality_review_id IS NOT NULL
          AND qr.source = 'auto'
          AND qr.model_params ? 'diagnostics'
          AND ($2::int IS NULL OR usage.project_id = $2)
          AND ($3::int IS NULL OR usage.script_id = $3)
          AND ($4::text IS NULL OR COALESCE(qr.target_type, usage.meta->'qualityReview'->>'targetType', 'unknown') = $4)
          AND (
            $5::boolean IS NULL
            OR COALESCE(((COALESCE(qr.model_params, '{}'::jsonb)->'diagnostics'->>'memoryDeliveryPriorityApplied')::boolean), false) = $5
          )
          AND ($6::text IS NULL OR qr.stage = $6)
          AND ($7::text IS NULL OR COALESCE(qr.model_name, usage.meta->'qualityReview'->>'modelName') = $7)
          AND ($8::text IS NULL OR usage.call_type = $8)
        ORDER BY usage.created_at DESC
        LIMIT $9
        "#,
    )
    .bind(user_id)
    .bind(query.project_id)
    .bind(query.script_id)
    .bind(query.target_type.as_deref())
    .bind(query.memory_delivery_priority_applied)
    .bind(query.stage.as_deref())
    .bind(query.model_name.as_deref())
    .bind(query.call_type.as_deref())
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(rows))
}
