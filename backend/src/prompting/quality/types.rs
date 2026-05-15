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
    /// 生成阶段（需求 6.3）：story_skeleton / adaptation_strategy / director_planning /
    /// storyboard_table / storyboard_panel / video_prompt
    pub stage: Option<String>,
    /// 监督层评分等级（需求 6.3）：A / B / C / D
    pub grade: Option<String>,
    /// 评审时使用的技能文件路径（需求 6.5）
    pub skill_file_path: Option<String>,
    /// 评审时使用的技能文件 SHA256 哈希（需求 6.5）
    pub skill_version_hash: Option<String>,
    /// 下一步修复动作（需求 I.4）：typed field for rework action
    pub next_action: Option<String>,
    /// 基于 bad_case_category 的规则化建议动作（需求 2.1）
    pub suggested_action: Option<String>,
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
    /// 生成阶段（需求 6.3）
    pub stage: Option<String>,
    /// 监督层评分等级（需求 6.3）：A / B / C / D
    pub grade: Option<String>,
    /// 评审时使用的技能文件路径（需求 6.5）
    pub skill_file_path: Option<String>,
    /// 评审时使用的技能文件 SHA256 哈希（需求 6.5）
    pub skill_version_hash: Option<String>,
    /// 下一步修复动作（需求 I.4）：typed field for rework action
    pub next_action: Option<String>,
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
    /// 按生成阶段过滤（需求 6.6）
    pub stage: Option<String>,
    /// 按评分等级过滤（需求 6.6）：A / B / C / D
    pub grade: Option<String>,
    /// 按下一步动作过滤（需求 I.4）
    pub next_action: Option<String>,
    /// 按规则化建议动作过滤（需求 2.1）
    pub suggested_action: Option<String>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

/// 质量统计响应
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityStatsResponse {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
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
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityScopeInsightResponse {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
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
    pub feedback_focus_tags: Vec<String>,
    pub memory_action: String,
    pub memory_focus: String,
    pub memory_reason: String,
}

/// 分环节通过率条目
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StagePassRateItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
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

/// 按 stage + grade 分布的统计条目（需求 6.4）
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct StageGradeDistributionItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    /// 生成阶段（story_skeleton / adaptation_strategy / director_planning / storyboard_table / storyboard_panel / video_prompt）
    pub stage: String,
    /// A 级数量
    pub grade_a_count: i64,
    /// B 级数量
    pub grade_b_count: i64,
    /// C 级数量
    pub grade_c_count: i64,
    /// D 级数量
    pub grade_d_count: i64,
    /// 总数
    pub total_count: i64,
    /// A+B 通过率（百分比）
    pub pass_rate_percent: f64,
}

/// Token efficiency aggregate response (derived from auto quality reviews).
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityTokenEfficiencyResponse {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub target_type: String,
    pub stage: Option<String>,
    pub review_model_name: Option<String>,
    pub call_type: Option<String>,
    pub sample_count: i64,
    pub avg_total_tokens: f64,
    pub avg_prompt_tokens: f64,
    pub avg_completion_tokens: f64,
    pub avg_overall_score: f64,
    pub pass_rate_percent: f64,
    pub high_token_low_quality_sample_count: i64,
    pub high_token_low_quality_rate_percent: f64,
    pub roi_band: String,
    pub avg_prompt_chars: f64,
    pub avg_non_memory_prompt_chars: f64,
    pub avg_memory_style_chars: f64,
    pub avg_memory_visual_chars: f64,
    pub avg_memory_delivery_chars: f64,
    pub avg_memory_optimization_removed_chars: f64,
    pub avg_project_scope_row_count: f64,
    pub avg_script_scope_row_count: f64,
    pub avg_role_scope_row_count: f64,
    pub avg_memory_share_percent: f64,
    pub avg_delivery_memory_share_percent: f64,
    pub delivery_priority_hit_rate_percent: f64,
    pub memory_action: String,
    pub memory_focus: String,
    pub memory_reason: String,
}

/// Token efficiency sample row.
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityTokenEfficiencySample {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub target_type: String,
    pub stage: Option<String>,
    pub review_model_name: Option<String>,
    pub call_type: String,
    pub total_tokens: i32,
    pub prompt_tokens: i32,
    pub completion_tokens: i32,
    pub overall_score: Option<i16>,
    pub memory_budget_tier: Option<String>,
    pub auto_negative_source: Option<String>,
    pub prompt_chars: i32,
    pub non_memory_prompt_chars: i32,
    pub memory_style_chars: i32,
    pub memory_visual_chars: i32,
    pub memory_delivery_chars: i32,
    pub memory_optimization_removed_chars: i32,
    pub project_scope_row_count: i32,
    pub script_scope_row_count: i32,
    pub role_scope_row_count: i32,
    pub memory_share_percent: f64,
    pub delivery_memory_share_percent: f64,
    pub memory_delivery_priority_applied: bool,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardTargetStat {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub target_type: String,
    pub total_reviews: i64,
    pub pass_rate_percent: f64,
    pub avg_overall_score: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardStagePassRateItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub target_type: String,
    pub review_date: chrono::DateTime<chrono::Utc>,
    pub total_reviews: i64,
    pub pass_rate_percent: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardStageGradeItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub stage: String,
    pub grade_a_count: i64,
    pub grade_b_count: i64,
    pub grade_c_count: i64,
    pub grade_d_count: i64,
    pub total_count: i64,
    pub pass_rate_percent: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardScopeInsightItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub scope_label: String,
    pub total_reviews: i64,
    pub bad_case_count: i64,
    pub pass_rate_percent: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardTokenEfficiencyItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub target_type: String,
    pub sample_count: i64,
    pub avg_prompt_chars: f64,
    pub avg_memory_style_chars: f64,
    pub avg_memory_delivery_chars: f64,
    pub memory_action: String,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct QualityBadCaseStatResponse {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub bad_case_category: Option<String>,
    pub count: i64,
    pub pass_rate_percent: f64,
    pub avg_score: f64,
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardResponse {
    pub meta: QualityDashboardMeta,
    pub stats: Vec<QualityDashboardTargetStat>,
    pub stage_pass_rate: Vec<QualityDashboardStagePassRateItem>,
    pub stage_grade_distribution: Vec<QualityDashboardStageGradeItem>,
    pub scope_insights: Vec<QualityDashboardScopeInsightItem>,
    pub token_efficiency: Vec<QualityDashboardTokenEfficiencyItem>,
    pub bad_case_stats: Vec<QualityBadCaseStatResponse>,
}

#[derive(Debug, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardMeta {
    pub refreshed_at: Option<chrono::DateTime<chrono::Utc>>,
    pub snapshot_row_count: i64,
    pub source_review_count: i64,
    pub source_usage_count: i64,
    pub source_max_review_created_at: Option<chrono::DateTime<chrono::Utc>>,
    pub source_max_usage_created_at: Option<chrono::DateTime<chrono::Utc>>,
    pub age_seconds: Option<i64>,
    pub stale: bool,
    pub stale_reason: Option<String>,
    pub refresh_mode: String,
}

#[derive(Debug, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct QualityDashboardRefreshResponse {
    pub refreshed_at: chrono::DateTime<chrono::Utc>,
    pub row_count: i64,
    pub mode: String,
    pub performed: bool,
    pub stale_before_refresh: bool,
    pub source_review_count: i64,
    pub source_usage_count: i64,
    pub source_max_review_created_at: Option<chrono::DateTime<chrono::Utc>>,
    pub source_max_usage_created_at: Option<chrono::DateTime<chrono::Utc>>,
}

/// 高频 bad case 统计条目（需求 14.3）
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BadCaseFrequencyItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    /// 规范化问题类型（snake_case）
    pub issue_type: String,
    /// 原始 bad_case_category 值
    pub raw_category: Option<String>,
    /// 近 20 条 bad case 中出现次数
    pub count: i64,
    /// 是否高频（count >= 3）
    pub is_high_frequency: bool,
    /// 最多 3 条样本评论（截断到 80 字）
    pub sample_comments: Vec<String>,
}

/// 技能版本变更前后评审分布对比条目（需求 14.4）
#[derive(Debug, Serialize, sqlx::FromRow)]
#[serde(rename_all = "camelCase")]
pub struct SkillVersionComparisonItem {
    /// Aggregation scope: 'user' indicates user-level aggregation. Workspace-level aggregation pending product finalization.
    pub scope: String,
    pub skill_file_path: String,
    pub skill_version_hash: String,
    pub total_count: i64,
    pub pass_rate_percent: f64,
    pub avg_score: f64,
    pub bad_case_rate_percent: f64,
    pub grade_a_count: i64,
    pub grade_b_count: i64,
    pub grade_c_count: i64,
    pub grade_d_count: i64,
}
