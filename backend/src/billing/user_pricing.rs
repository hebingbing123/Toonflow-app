//! User-facing billing estimate and spend summary.

use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};
use serde::Deserialize;
use sqlx::PgPool;
use utoipa::IntoParams;
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::ApiError;
use crate::state::AppState;
use crate::vendor::catalog::pricing::{
    build_estimate, composite_id_for_model_name, lookup_pricing, pricing_disclaimer,
    BillingEstimateRequest, BillingEstimateResponse, BillingSpendSummaryResponse, ModelSpendRow,
};

#[utoipa::path(
    post,
    path = "/api/v1/billing/estimate",
    operation_id = "postBillingEstimateV1",
    tag = "billing",
    request_body = BillingEstimateRequest,
    responses(
        (status = 200, description = "OK", body = BillingEstimateResponse),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Model not found", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_billing_estimate(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<BillingEstimateRequest>,
) -> Result<Json<BillingEstimateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let mut response = build_estimate(&body)?;
    if let Ok(pool) = state.require_pool() {
        if let Err(e) =
            super::estimate_enrich::enrich_estimate_response(pool, uid, &mut response).await
        {
            tracing::warn!(error = %e, "billing estimate enrich failed (returning base estimate)");
        }
    }
    Ok(Json(response))
}

#[derive(Debug, Deserialize, IntoParams, utoipa::ToSchema)]
pub(crate) struct SpendSummaryQuery {
    #[serde(default = "default_days")]
    pub(crate) days: u32,
}

fn default_days() -> u32 {
    7
}

#[derive(Debug, sqlx::FromRow)]
struct SpendAggRow {
    model_name: String,
    total_tokens: Option<i64>,
    estimated_cost_cents: Option<i64>,
    call_count: i64,
    avg_quality_score: Option<f64>,
}

#[utoipa::path(
    get,
    path = "/api/v1/billing/spend-summary",
    operation_id = "getBillingSpendSummaryV1",
    tag = "billing",
    params(SpendSummaryQuery),
    responses(
        (status = 200, description = "OK", body = BillingSpendSummaryResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Database not configured", body = crate::error::ErrorBody),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_billing_spend_summary(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<SpendSummaryQuery>,
) -> Result<Json<BillingSpendSummaryResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let days = query.days.clamp(1, 90);
    let rows = load_spend_rows(pool, uid, days).await?;
    Ok(Json(BillingSpendSummaryResponse {
        days,
        disclaimer: pricing_disclaimer().to_string(),
        rows,
    }))
}

async fn load_spend_rows(
    pool: &PgPool,
    user_id: Uuid,
    days: u32,
) -> Result<Vec<ModelSpendRow>, ApiError> {
    let agg: Vec<SpendAggRow> = sqlx::query_as(
        r#"
        SELECT
            model_name,
            COALESCE(SUM(total_tokens), 0)::bigint AS total_tokens,
            COALESCE(SUM(estimated_cost_cents), 0)::bigint AS estimated_cost_cents,
            COUNT(*)::bigint AS call_count,
            AVG(overall_score::float8) FILTER (WHERE overall_score IS NOT NULL) AS avg_quality_score
        FROM app_llm_usage_log
        WHERE user_id = $1
          AND created_at >= NOW() - make_interval(days => $2::int)
        GROUP BY model_name
        ORDER BY estimated_cost_cents DESC, call_count DESC
        "#,
    )
    .bind(user_id)
    .bind(i32::try_from(days).unwrap_or(7))
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    const MIN_SAMPLES: i64 = 5;
    let roi_by_model = load_token_efficiency_roi_by_model(pool, user_id, days).await?;

    Ok(agg
        .into_iter()
        .map(|r| {
            let model_id = composite_id_for_model_name(&r.model_name);
            let value_tier = model_id
                .as_ref()
                .and_then(|id| lookup_pricing(id))
                .map(|p| p.value_tier.clone());
            let roi = roi_by_model.get(&r.model_name);
            ModelSpendRow {
                model_name: r.model_name.clone(),
                model_id,
                total_tokens: r.total_tokens.unwrap_or(0),
                estimated_cost_cents: r.estimated_cost_cents.unwrap_or(0),
                call_count: r.call_count,
                avg_quality_score: r.avg_quality_score,
                value_tier: value_tier.clone(),
                sample_sufficient: r.call_count >= MIN_SAMPLES,
                token_efficiency_roi_band: roi.map(|x| x.roi_band.clone()),
                token_efficiency_sample_count: roi.map(|x| x.sample_count),
            }
        })
        .collect())
}

#[derive(Debug)]
struct ModelRoiAgg {
    roi_band: String,
    sample_count: i64,
}

async fn load_token_efficiency_roi_by_model(
    pool: &PgPool,
    user_id: Uuid,
    days: u32,
) -> Result<std::collections::HashMap<String, ModelRoiAgg>, ApiError> {
    #[derive(sqlx::FromRow)]
    struct Row {
        model_name: String,
        sample_count: i64,
        avg_score: f64,
        pass_rate: f64,
        high_token_low_quality_count: i64,
    }

    let rows: Vec<Row> = sqlx::query_as(
        r#"
        SELECT
            usage.model_name,
            COUNT(*)::bigint AS sample_count,
            COALESCE(AVG(COALESCE(qr.overall_score, usage.overall_score, 0)), 0) AS avg_score,
            COALESCE(AVG(CASE WHEN COALESCE(qr.passed, false) THEN 1.0 ELSE 0.0 END), 0) AS pass_rate,
            COUNT(*) FILTER (
                WHERE COALESCE(usage.total_tokens, 0) >= 4000
                  AND (
                    COALESCE(qr.overall_score, usage.overall_score, 0) < 8
                    OR COALESCE(qr.passed, false) = false
                  )
            )::bigint AS high_token_low_quality_count
        FROM app_llm_usage_log usage
        LEFT JOIN app_quality_review qr ON qr.id = usage.quality_review_id
        WHERE usage.user_id = $1
          AND usage.created_at >= NOW() - make_interval(days => $2::int)
        GROUP BY usage.model_name
        "#,
    )
    .bind(user_id)
    .bind(i32::try_from(days).unwrap_or(7))
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut out = std::collections::HashMap::new();
    for row in rows {
        let roi_band = if row.high_token_low_quality_count > 0 {
            "high_token_low_quality".to_string()
        } else if row.avg_score >= 8.0 && row.pass_rate >= 0.8 {
            "efficient".to_string()
        } else {
            "observe".to_string()
        };
        out.insert(
            row.model_name,
            ModelRoiAgg {
                roi_band,
                sample_count: row.sample_count,
            },
        );
    }
    Ok(out)
}
