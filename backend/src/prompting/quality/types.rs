//! 质量审查 HTTP 层数据模型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

/// 质量评估记录
#[derive(Debug, FromRow, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityReview {
    pub id: Uuid,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
    pub user_id: Uuid,
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub job_id: Option<Uuid>,
    pub target_type: String,
    pub target_id: Option<String>,
    pub source: String,
    pub plot_coherence: Option<i16>,
    pub character_consistency: Option<i16>,
    pub dialogue_naturalness: Option<i16>,
    pub pacing: Option<i16>,
    pub faithfulness: Option<i16>,
    pub visual_quality: Option<i16>,
    pub overall_score: Option<i16>,
    pub passed: Option<bool>,
    pub comments: Option<String>,
    pub skill_version: Option<String>,
    pub model_name: Option<String>,
    pub model_params: Option<serde_json::Value>,
    pub memory_delivery_priority_applied: Option<bool>,
    pub reviewer_id: Option<Uuid>,
    pub is_bad_case: bool,
    pub bad_case_category: Option<String>,
}

/// 创建质量评估请求体
#[derive(Debug, Deserialize, Default)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct CreateQualityReviewBody {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub job_id: Option<Uuid>,
    pub target_type: String,
    pub target_id: Option<String>,
    pub source: Option<String>,
    pub plot_coherence: Option<i16>,
    pub character_consistency: Option<i16>,
    pub dialogue_naturalness: Option<i16>,
    pub pacing: Option<i16>,
    pub faithfulness: Option<i16>,
    pub visual_quality: Option<i16>,
    pub overall_score: Option<i16>,
    pub passed: Option<bool>,
    pub comments: Option<String>,
    pub skill_version: Option<String>,
    pub model_name: Option<String>,
    pub model_params: Option<serde_json::Value>,
    pub memory_delivery_priority_applied: Option<bool>,
    pub is_bad_case: Option<bool>,
    pub bad_case_category: Option<String>,
}

/// 质量评估列表查询参数
#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct ListQualityReviewsQuery {
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub target_type: Option<String>,
    pub target_id: Option<String>,
    pub job_id: Option<Uuid>,
    pub source: Option<String>,
    pub is_bad_case: Option<bool>,
    pub memory_delivery_priority_applied: Option<bool>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 质量统计响应
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityStatsResponse {
    pub target_type: String,
    pub total_reviews: i64,
    pub passed_count: i64,
    pub failed_count: i64,
    pub bad_case_count: i64,
    pub pass_rate_percent: f64,
    pub avg_overall_score: f64,
    pub delivery_priority_total_reviews: i64,
    pub delivery_priority_passed_count: i64,
    pub delivery_priority_bad_case_count: i64,
    pub delivery_priority_pass_rate_percent: f64,
    pub non_delivery_priority_total_reviews: i64,
    pub non_delivery_priority_passed_count: i64,
    pub non_delivery_priority_bad_case_count: i64,
    pub non_delivery_priority_pass_rate_percent: f64,
}

/// Scope-level quality insight row aggregated by project/script scope.
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityScopeInsightResponse {
    pub scope_label: String,
    pub project_id: Option<i32>,
    pub script_id: Option<i32>,
    pub total_reviews: i64,
    pub auto_reviews: i64,
    pub passed_count: i64,
    pub bad_case_count: i64,
    pub pass_rate_percent: f64,
    pub avg_overall_score: f64,
    pub dialogue_risk_count: i64,
    pub visual_risk_count: i64,
    pub avg_prompt_chars: f64,
    pub avg_memory_chars: f64,
    pub avg_memory_delivery_chars: f64,
    pub delivery_priority_hit_rate_percent: f64,
    pub memory_removed_chars: i64,
    pub memory_removed_rows: i64,
    pub feedback_selected_memory_promotions: i64,
    pub feedback_rejected_memory_writes: i64,
    pub feedback_summary_memory_writes: i64,
    pub feedback_memory_removed_chars: i64,
    pub feedback_memory_removed_rows: i64,
    pub memory_action: String,
    pub memory_focus: String,
    pub memory_reason: String,
}

/// 分环节通过率条目
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StagePassRateItem {
    pub target_type: String,
    pub review_date: chrono::DateTime<chrono::Utc>,
    pub total_reviews: i64,
    pub passed_count: i64,
    pub bad_case_count: i64,
    pub pass_rate_percent: Option<f64>,
    pub avg_score: Option<f64>,
    pub delivery_priority_total_reviews: i64,
    pub delivery_priority_passed_count: i64,
    pub delivery_priority_bad_case_count: i64,
    pub delivery_priority_pass_rate_percent: f64,
    pub non_delivery_priority_total_reviews: i64,
    pub non_delivery_priority_passed_count: i64,
    pub non_delivery_priority_bad_case_count: i64,
    pub non_delivery_priority_pass_rate_percent: f64,
}

/// Token efficiency aggregate response (derived from auto quality reviews).
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityTokenEfficiencyResponse {
    pub target_type: String,
    pub sample_count: i64,
    pub avg_prompt_chars: f64,
    pub avg_non_memory_prompt_chars: f64,
    pub avg_memory_style_chars: f64,
    pub avg_memory_visual_chars: f64,
    pub avg_memory_delivery_chars: f64,
    pub avg_memory_share_percent: f64,
    pub avg_delivery_memory_share_percent: f64,
    pub delivery_priority_hit_rate_percent: f64,
}

/// Token efficiency sample row.
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityTokenEfficiencySample {
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub target_type: String,
    pub prompt_chars: i32,
    pub non_memory_prompt_chars: i32,
    pub memory_style_chars: i32,
    pub memory_visual_chars: i32,
    pub memory_delivery_chars: i32,
    pub memory_share_percent: f64,
    pub delivery_memory_share_percent: f64,
    pub memory_delivery_priority_applied: bool,
}
