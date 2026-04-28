//! 质量审查 HTTP 层数据模型。

use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

/// 质量评估记录
#[derive(Debug, Clone, FromRow, Serialize)]
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

/// 质量 / token 效率统计响应
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityTokenEfficiencyResponse {
    pub target_type: String,
    pub total_reviews: i64,
    pub linked_llm_review_count: i64,
    pub avg_overall_score: f64,
    pub avg_prompt_chars: f64,
    pub avg_memory_delivery_chars: f64,
    pub avg_memory_visual_chars: f64,
    pub avg_linked_total_tokens: f64,
    pub avg_prompt_chars_per_score_point: f64,
    pub avg_linked_tokens_per_score_point: f64,
    pub delivery_priority_avg_prompt_chars_per_score_point: f64,
    pub delivery_priority_avg_linked_tokens_per_score_point: f64,
    pub non_delivery_priority_avg_prompt_chars_per_score_point: f64,
    pub non_delivery_priority_avg_linked_tokens_per_score_point: f64,
}
