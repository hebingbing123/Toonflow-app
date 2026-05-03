use std::collections::{BTreeMap, HashMap};

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use serde_json::json;
use uuid::Uuid;

use crate::{auth::require_user_uuid, error::ApiError, state::AppState};

use super::types::{
    BenchmarkTrendPoint, BenchmarkTrendsQuery, BenchmarkTrendsResponse, GateDecisionEnvelope,
    GateDecisionRecord, GateVariantAssessment, SubmitGateDecisionBody,
};

#[derive(Debug, sqlx::FromRow)]
struct VariantRow {
    id: Uuid,
    label: String,
}

#[derive(Debug, sqlx::FromRow)]
struct ResultRow {
    variant_id: Uuid,
    case_type: Option<String>,
    weight: Option<i32>,
    score_summary: Option<serde_json::Value>,
    roi_summary: Option<serde_json::Value>,
    requires_human_review: bool,
}

#[derive(Debug, Clone)]
pub(super) struct VariantMetrics {
    pub(super) total_tokens: i64,
    pub(super) avg_quality_score: f64,
    pub(super) bad_case_recurrence_count: i32,
    pub(super) severe_guard_failures: i32,
    pub(super) requires_human_review_count: i32,
}

impl VariantMetrics {
    fn from_rows(rows: &[&ResultRow]) -> Self {
        if rows.is_empty() {
            return Self {
                total_tokens: 0,
                avg_quality_score: 0.0,
                bad_case_recurrence_count: 0,
                severe_guard_failures: 0,
                requires_human_review_count: 0,
            };
        }

        let mut total_tokens = 0i64;
        let mut total_quality_score = 0.0;
        let mut scored_count = 0f64;
        let mut bad_case_recurrence_count = 0i32;
        let mut severe_guard_failures = 0i32;
        let mut requires_human_review_count = 0i32;

        for row in rows {
            if row.requires_human_review {
                requires_human_review_count += 1;
            }

            let passed = row
                .score_summary
                .as_ref()
                .and_then(|value| value.get("passed"))
                .and_then(|value| value.as_bool())
                .unwrap_or(false);
            let severe_count = row
                .score_summary
                .as_ref()
                .and_then(|value| value.get("severeCount"))
                .and_then(|value| value.as_i64())
                .unwrap_or(0) as i32;

            if let Some(tokens) = row
                .roi_summary
                .as_ref()
                .and_then(|value| value.get("tokensUsed"))
                .and_then(|value| value.as_i64())
            {
                total_tokens += tokens;
            }

            if let Some(score) = row
                .score_summary
                .as_ref()
                .and_then(|value| value.get("overallScore"))
                .and_then(|value| value.as_f64())
            {
                total_quality_score += score;
                scored_count += 1.0;
            }

            if row.case_type.as_deref() == Some("bad_case") && !passed {
                bad_case_recurrence_count += 1;
            }

            if row.case_type.as_deref() == Some("regression_guard")
                && row.weight.unwrap_or(1) >= 3
                && (!passed || severe_count > 0)
            {
                severe_guard_failures += 1;
            }
        }

        Self {
            total_tokens,
            avg_quality_score: if scored_count > 0.0 {
                total_quality_score / scored_count
            } else {
                0.0
            },
            bad_case_recurrence_count,
            severe_guard_failures,
            requires_human_review_count,
        }
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/benchmark/experiments/{id}/gate",
    operation_id = "getPromotionGateV1",
    tag = "benchmark",
    params(("id" = Uuid, Path, description = "Experiment run ID")),
    responses(
        (status = 200, description = "Promotion gate summary", body = GateDecisionEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_promotion_gate(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(experiment_id): Path<Uuid>,
) -> Result<Json<GateDecisionEnvelope>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    ensure_experiment_owner(pool, experiment_id, user_id).await?;

    let envelope = build_gate_envelope(pool, experiment_id).await?;
    Ok(Json(envelope))
}

#[utoipa::path(
    post,
    path = "/api/v1/benchmark/experiments/{id}/gate/decide",
    operation_id = "decidePromotionGateV1",
    tag = "benchmark",
    params(("id" = Uuid, Path, description = "Experiment run ID")),
    request_body(content = SubmitGateDecisionBody, content_type = "application/json"),
    responses(
        (status = 200, description = "Promotion decision stored", body = GateDecisionRecord),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn decide_promotion_gate(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(experiment_id): Path<Uuid>,
    Json(body): Json<SubmitGateDecisionBody>,
) -> Result<Json<GateDecisionRecord>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    ensure_experiment_owner(pool, experiment_id, user_id).await?;
    validate_gate_decision_body(&body)?;

    let envelope = build_gate_envelope(pool, experiment_id).await?;
    let assessment = envelope
        .assessments
        .iter()
        .find(|assessment| assessment.variant_id == body.variant_id)
        .ok_or(ApiError::NotFound)?;

    let decision = body
        .decision
        .clone()
        .unwrap_or_else(|| assessment.auto_decision.clone());
    validate_decision_value(&decision)?;
    validate_promotion_request(&decision, body.promote_to_baseline.unwrap_or(false))?;

    let record = sqlx::query_as::<_, GateDecisionRecord>(
        r#"
        INSERT INTO app_promotion_gate_decision
            (experiment_run_id, variant_id, decision, rationale, decided_by)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, experiment_run_id, variant_id, decision, rationale, decided_by, decided_at
        "#,
    )
    .bind(experiment_id)
    .bind(body.variant_id)
    .bind(&decision)
    .bind(json!({
        "autoDecision": assessment.auto_decision,
        "autoRationale": assessment.rationale,
        "note": body.rationale_note,
        "promotionRestrictions": body.promotion_restrictions,
    }))
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    if body.promote_to_baseline.unwrap_or(false) {
        promote_variant_to_baseline(pool, experiment_id, body.variant_id).await?;
    }

    Ok(Json(record))
}

#[utoipa::path(
    get,
    path = "/api/v1/benchmark/trends",
    operation_id = "getBenchmarkTrendsV1",
    tag = "benchmark",
    params(BenchmarkTrendsQuery),
    responses(
        (status = 200, description = "Benchmark trends", body = BenchmarkTrendsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_benchmark_trends(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<BenchmarkTrendsQuery>,
) -> Result<Json<BenchmarkTrendsResponse>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let limit_weeks = query.limit_weeks.unwrap_or(8).clamp(1, 26);

    #[derive(sqlx::FromRow)]
    struct TrendRow {
        week_start: chrono::NaiveDate,
        score_summary: Option<serde_json::Value>,
        roi_summary: Option<serde_json::Value>,
        case_type: Option<String>,
    }

    let rows = sqlx::query_as::<_, TrendRow>(
        r#"
        SELECT
            DATE_TRUNC('week', r.created_at)::date AS week_start,
            r.score_summary,
            r.roi_summary,
            c.case_type
        FROM app_experiment_result r
        JOIN app_experiment_run run ON run.id = r.experiment_run_id
        LEFT JOIN app_benchmark_case c ON c.id = r.benchmark_case_id
        WHERE run.owner_user_id = $1
          AND r.status = 'completed'
          AND r.created_at >= DATE_TRUNC('week', NOW()) - ($2::int - 1) * INTERVAL '1 week'
        ORDER BY week_start ASC
        "#,
    )
    .bind(user_id)
    .bind(limit_weeks as i32)
    .fetch_all(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    #[derive(Default)]
    struct TrendAggregate {
        completed_results: i32,
        total_quality_score: f64,
        quality_count: f64,
        total_tokens: i64,
        bad_case_failures: i32,
    }

    let mut trend_map: BTreeMap<String, TrendAggregate> = BTreeMap::new();
    for row in rows {
        let key = row.week_start.to_string();
        let aggregate = trend_map.entry(key).or_default();
        aggregate.completed_results += 1;
        if let Some(score) = row
            .score_summary
            .as_ref()
            .and_then(|value| value.get("overallScore"))
            .and_then(|value| value.as_f64())
        {
            aggregate.total_quality_score += score;
            aggregate.quality_count += 1.0;
        }
        if let Some(tokens) = row
            .roi_summary
            .as_ref()
            .and_then(|value| value.get("tokensUsed"))
            .and_then(|value| value.as_i64())
        {
            aggregate.total_tokens += tokens;
        }
        let passed = row
            .score_summary
            .as_ref()
            .and_then(|value| value.get("passed"))
            .and_then(|value| value.as_bool())
            .unwrap_or(false);
        if row.case_type.as_deref() == Some("bad_case") && !passed {
            aggregate.bad_case_failures += 1;
        }
    }

    #[derive(sqlx::FromRow)]
    struct DecisionTrendRow {
        week_start: chrono::NaiveDate,
        decision: String,
    }

    let decisions = sqlx::query_as::<_, DecisionTrendRow>(
        r#"
        SELECT DATE_TRUNC('week', d.decided_at)::date AS week_start, d.decision
        FROM app_promotion_gate_decision d
        JOIN app_experiment_run run ON run.id = d.experiment_run_id
        WHERE run.owner_user_id = $1
          AND d.decided_at >= DATE_TRUNC('week', NOW()) - ($2::int - 1) * INTERVAL '1 week'
        ORDER BY week_start ASC
        "#,
    )
    .bind(user_id)
    .bind(limit_weeks as i32)
    .fetch_all(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    let mut decision_counts: HashMap<String, (i32, i32)> = HashMap::new();
    for row in decisions {
        let entry = decision_counts
            .entry(row.week_start.to_string())
            .or_insert((0, 0));
        match row.decision.as_str() {
            "approved" | "approved_limited" => entry.0 += 1,
            "blocked" => entry.1 += 1,
            _ => {}
        }
    }

    let weeks = trend_map
        .into_iter()
        .map(|(week_start, aggregate)| {
            let (approved_count, blocked_count) =
                decision_counts.get(&week_start).copied().unwrap_or((0, 0));
            BenchmarkTrendPoint {
                week_start,
                completed_results: aggregate.completed_results,
                avg_quality_score: if aggregate.quality_count > 0.0 {
                    aggregate.total_quality_score / aggregate.quality_count
                } else {
                    0.0
                },
                total_tokens: aggregate.total_tokens,
                bad_case_failures: aggregate.bad_case_failures,
                approved_count,
                blocked_count,
            }
        })
        .collect();

    Ok(Json(BenchmarkTrendsResponse { weeks }))
}

async fn ensure_experiment_owner(
    pool: &sqlx::PgPool,
    experiment_id: Uuid,
    user_id: Uuid,
) -> Result<(), ApiError> {
    let owner =
        sqlx::query_scalar::<_, Uuid>("SELECT owner_user_id FROM app_experiment_run WHERE id = $1")
            .bind(experiment_id)
            .fetch_optional(pool)
            .await
            .map_err(|error| ApiError::DatabaseError(error.to_string()))?
            .ok_or(ApiError::NotFound)?;

    if owner != user_id {
        return Err(ApiError::Forbidden("无权访问此实验".to_string()));
    }
    Ok(())
}

async fn build_gate_envelope(
    pool: &sqlx::PgPool,
    experiment_id: Uuid,
) -> Result<GateDecisionEnvelope, ApiError> {
    let baseline_variant_id = sqlx::query_scalar::<_, Option<Uuid>>(
        "SELECT baseline_variant_id FROM app_experiment_run WHERE id = $1",
    )
    .bind(experiment_id)
    .fetch_one(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    let variants = sqlx::query_as::<_, VariantRow>(
        r#"
        SELECT id, label
        FROM app_experiment_variant
        WHERE experiment_run_id = $1
        ORDER BY is_baseline DESC, label ASC
        "#,
    )
    .bind(experiment_id)
    .fetch_all(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    let results = sqlx::query_as::<_, ResultRow>(
        r#"
        SELECT
            r.variant_id,
            c.case_type,
            c.weight,
            r.score_summary,
            r.roi_summary,
            r.requires_human_review
        FROM app_experiment_result r
        LEFT JOIN app_benchmark_case c ON c.id = r.benchmark_case_id
        WHERE r.experiment_run_id = $1
          AND r.status = 'completed'
        "#,
    )
    .bind(experiment_id)
    .fetch_all(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    let mut grouped: HashMap<Uuid, Vec<&ResultRow>> = HashMap::new();
    for row in &results {
        grouped.entry(row.variant_id).or_default().push(row);
    }

    let baseline_metrics = baseline_variant_id
        .and_then(|baseline_id| {
            grouped
                .get(&baseline_id)
                .map(|rows| VariantMetrics::from_rows(rows))
        })
        .unwrap_or(VariantMetrics {
            total_tokens: 0,
            avg_quality_score: 0.0,
            bad_case_recurrence_count: 0,
            severe_guard_failures: 0,
            requires_human_review_count: 0,
        });

    let assessments = variants
        .iter()
        .map(|variant| {
            let rows = grouped.get(&variant.id).cloned().unwrap_or_default();
            let metrics = VariantMetrics::from_rows(rows.as_slice());
            evaluate_variant(
                variant,
                &metrics,
                &baseline_metrics,
                baseline_variant_id == Some(variant.id),
            )
        })
        .collect();

    let latest_decisions = sqlx::query_as::<_, GateDecisionRecord>(
        r#"
        SELECT DISTINCT ON (variant_id)
            id, experiment_run_id, variant_id, decision, rationale, decided_by, decided_at
        FROM app_promotion_gate_decision
        WHERE experiment_run_id = $1
        ORDER BY variant_id, decided_at DESC
        "#,
    )
    .bind(experiment_id)
    .fetch_all(pool)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    Ok(GateDecisionEnvelope {
        experiment_run_id: experiment_id,
        baseline_variant_id,
        assessments,
        latest_decisions,
    })
}

fn evaluate_variant(
    variant: &VariantRow,
    metrics: &VariantMetrics,
    baseline: &VariantMetrics,
    is_baseline: bool,
) -> GateVariantAssessment {
    let quality_score_delta = metrics.avg_quality_score - baseline.avg_quality_score;
    let token_delta_percent = if baseline.total_tokens > 0 {
        ((metrics.total_tokens - baseline.total_tokens) as f64 / baseline.total_tokens as f64)
            * 100.0
    } else {
        0.0
    };
    let bad_case_recurrence_delta =
        metrics.bad_case_recurrence_count - baseline.bad_case_recurrence_count;

    let auto_decision = classify_auto_decision(
        metrics,
        quality_score_delta,
        token_delta_percent,
        bad_case_recurrence_delta,
        is_baseline,
    )
    .to_string();

    let rationale = json!({
        "qualityScoreDelta": quality_score_delta,
        "tokenDeltaPercent": token_delta_percent,
        "badCaseRecurrenceDelta": bad_case_recurrence_delta,
        "severeGuardFailures": metrics.severe_guard_failures,
        "requiresHumanReviewCount": metrics.requires_human_review_count,
        "baselineTokens": baseline.total_tokens,
        "variantTokens": metrics.total_tokens,
    });

    GateVariantAssessment {
        variant_id: variant.id,
        variant_label: variant.label.clone(),
        is_baseline,
        auto_decision,
        severe_guard_failures: metrics.severe_guard_failures,
        requires_human_review_count: metrics.requires_human_review_count,
        avg_quality_score: metrics.avg_quality_score,
        quality_score_delta,
        total_tokens: metrics.total_tokens,
        token_delta_percent,
        bad_case_recurrence_delta,
        rationale,
    }
}

pub(super) fn classify_auto_decision(
    metrics: &VariantMetrics,
    quality_score_delta: f64,
    token_delta_percent: f64,
    bad_case_recurrence_delta: i32,
    is_baseline: bool,
) -> &'static str {
    if is_baseline {
        "approved"
    } else if metrics.severe_guard_failures > 0 || quality_score_delta < -0.1 {
        "blocked"
    } else if metrics.requires_human_review_count > 0 {
        "needs_review"
    } else if quality_score_delta >= 0.1
        && token_delta_percent <= 20.0
        && bad_case_recurrence_delta <= 0
    {
        "approved"
    } else if quality_score_delta >= 0.0
        && token_delta_percent > 20.0
        && bad_case_recurrence_delta < 0
    {
        "approved_limited"
    } else {
        "needs_review"
    }
}

fn validate_gate_decision_body(body: &SubmitGateDecisionBody) -> Result<(), ApiError> {
    if let Some(decision) = &body.decision {
        validate_decision_value(decision)?;
    }
    Ok(())
}

pub(super) fn validate_promotion_request(
    decision: &str,
    promote_to_baseline: bool,
) -> Result<(), ApiError> {
    if promote_to_baseline && decision != "approved" && decision != "approved_limited" {
        return Err(ApiError::BadRequest(
            "只有 approved 或 approved_limited 的变体才能提升为新基线".to_string(),
        ));
    }
    Ok(())
}

pub(super) fn validate_decision_value(decision: &str) -> Result<(), ApiError> {
    match decision {
        "blocked" | "needs_review" | "approved" | "approved_limited" => Ok(()),
        _ => Err(ApiError::BadRequest(
            "decision must be one of: blocked, needs_review, approved, approved_limited"
                .to_string(),
        )),
    }
}

async fn promote_variant_to_baseline(
    pool: &sqlx::PgPool,
    experiment_id: Uuid,
    variant_id: Uuid,
) -> Result<(), ApiError> {
    let mut tx = pool
        .begin()
        .await
        .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    sqlx::query(
        r#"
        UPDATE app_experiment_variant
        SET is_baseline = CASE WHEN id = $2 THEN TRUE ELSE FALSE END
        WHERE experiment_run_id = $1
        "#,
    )
    .bind(experiment_id)
    .bind(variant_id)
    .execute(&mut *tx)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    sqlx::query(
        r#"
        UPDATE app_experiment_run
        SET baseline_variant_id = $1
        WHERE id = $2
        "#,
    )
    .bind(variant_id)
    .bind(experiment_id)
    .execute(&mut *tx)
    .await
    .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    tx.commit()
        .await
        .map_err(|error| ApiError::DatabaseError(error.to_string()))?;

    Ok(())
}
