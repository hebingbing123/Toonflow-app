use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use utoipa::{IntoParams, ToSchema};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct GateVariantAssessment {
    pub variant_id: Uuid,
    pub variant_label: String,
    pub is_baseline: bool,
    pub auto_decision: String,
    pub severe_guard_failures: i32,
    pub requires_human_review_count: i32,
    pub avg_quality_score: f64,
    pub quality_score_delta: f64,
    pub total_tokens: i64,
    pub token_delta_percent: f64,
    pub bad_case_recurrence_delta: i32,
    pub rationale: serde_json::Value,
}

#[derive(Debug, Clone, FromRow, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct GateDecisionRecord {
    pub id: Uuid,
    pub experiment_run_id: Uuid,
    pub variant_id: Uuid,
    pub decision: String,
    pub rationale: serde_json::Value,
    pub decided_by: Option<Uuid>,
    pub decided_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct GateDecisionEnvelope {
    pub experiment_run_id: Uuid,
    pub baseline_variant_id: Option<Uuid>,
    pub assessments: Vec<GateVariantAssessment>,
    pub latest_decisions: Vec<GateDecisionRecord>,
}

#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct SubmitGateDecisionBody {
    pub variant_id: Uuid,
    pub decision: Option<String>,
    pub rationale_note: Option<String>,
    pub promotion_restrictions: Option<String>,
    pub promote_to_baseline: Option<bool>,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct BenchmarkTrendPoint {
    pub week_start: String,
    pub completed_results: i32,
    pub avg_quality_score: f64,
    pub total_tokens: i64,
    pub bad_case_failures: i32,
    pub approved_count: i32,
    pub blocked_count: i32,
}

#[derive(Debug, Clone, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct BenchmarkTrendsResponse {
    pub weeks: Vec<BenchmarkTrendPoint>,
}

#[derive(Debug, Deserialize, IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct BenchmarkTrendsQuery {
    pub limit_weeks: Option<i64>,
}
