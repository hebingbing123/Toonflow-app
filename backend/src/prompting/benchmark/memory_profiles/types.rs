//! 记忆预算档与 ROI 证据数据模型。

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

/// 记忆预算档快照
///
/// 描述某种记忆预算配置的完整快照，包括预算层级、压缩规则、保留桶等策略。
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MemoryBudgetProfileSnapshot {
    /// 预算层级：lean（精简）或 expanded（扩展）
    pub budget_tier: String,

    /// 压缩规则配置
    pub compression_rules: CompressionRules,

    /// 保留桶配置
    pub retention_buckets: RetentionBuckets,

    /// 观察笔记字符上限
    pub observation_note_limit: Option<i32>,

    /// 角色记忆优先级配置
    pub character_memory_priority: Option<serde_json::Value>,

    /// 档案版本标识
    pub profile_version: Option<String>,
}

/// 压缩规则
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CompressionRules {
    /// 是否启用静默压缩（低风险场景）
    pub compact_silent_low_risk: bool,

    /// 连续性笔记最大字符数
    pub continuity_note_max_chars: Option<i32>,

    /// 记忆笔记最大字符数
    pub memory_note_max_chars: Option<i32>,

    /// 风格片段保留策略
    pub style_fragment_retention: Option<String>,
}

/// 保留桶配置
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RetentionBuckets {
    /// 项目级记忆保留数量
    pub project_scope_retention: Option<i32>,

    /// 脚本级记忆保留数量
    pub script_scope_retention: Option<i32>,

    /// 场景级记忆保留数量
    pub scene_scope_retention: Option<i32>,

    /// 情绪记忆优先保留
    pub prioritize_emotional_memory: bool,

    /// 对话表演记忆优先保留
    pub prioritize_dialogue_performance: bool,
}

/// ROI 证据摘要
///
/// 说明某次优化在 token 成本、通过率、返工率、坏例复发率上的收益证据。
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RoiEvidenceSummary {
    /// 实验运行 ID
    pub experiment_run_id: Uuid,

    /// 变体对比列表
    pub variant_comparisons: Vec<VariantRoiComparison>,

    /// 样本集统计
    pub sample_set_stats: SampleSetStats,

    /// 总体结论
    pub overall_conclusion: RoiConclusion,
}

/// 变体 ROI 对比
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct VariantRoiComparison {
    /// 变体 ID
    pub variant_id: Uuid,

    /// 变体标签
    pub variant_label: String,

    /// 是否为基线变体
    pub is_baseline: bool,

    /// 记忆预算档
    pub memory_budget_profile: MemoryBudgetProfileSnapshot,

    /// 成本增量（相对基线）
    pub cost_delta: VariantCostDelta,

    /// 质量指标
    pub quality_metrics: QualityMetrics,

    /// 按样本的详细 ROI
    pub sample_details: Vec<SampleRoiDetail>,

    /// 按阶段的 ROI 分解
    pub stage_breakdown: Vec<StageRoiBreakdown>,
}

/// 变体成本增量
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct VariantCostDelta {
    /// Token 总消耗
    pub total_tokens: i64,

    /// 相对基线的 Token 增量
    pub token_delta: i64,

    /// 相对基线的 Token 增量百分比
    pub token_delta_percent: f64,

    /// 估算成本（美元）
    pub estimated_cost_usd: f64,

    /// 相对基线的成本增量（美元）
    pub cost_delta_usd: f64,
}

/// 质量指标
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct QualityMetrics {
    /// 平均质量得分
    pub avg_quality_score: f64,

    /// 相对基线的质量得分变化
    pub quality_score_delta: f64,

    /// 通过率（无严重问题的样本比例）
    pub pass_rate: f64,

    /// 相对基线的通过率变化
    pub pass_rate_delta: f64,

    /// 返工率
    pub rework_rate: f64,

    /// 相对基线的返工率变化
    pub rework_rate_delta: f64,

    /// 坏例复发数量
    pub bad_case_recurrence_count: i32,

    /// 相对基线的坏例复发变化
    pub bad_case_recurrence_delta: i32,
}

/// 样本 ROI 详情
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SampleRoiDetail {
    /// 基线样本 ID
    pub benchmark_case_id: Uuid,

    /// 样本类型
    pub case_type: String,

    /// 样本权重
    pub weight: i32,

    /// Token 消耗
    pub tokens_used: i64,

    /// 质量得分
    pub quality_score: f64,

    /// 是否通过
    pub passed: bool,

    /// 是否需要返工
    pub requires_rework: bool,

    /// 关键问题标签
    pub issue_tags: Vec<String>,
}

/// 阶段 ROI 分解
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct StageRoiBreakdown {
    /// 阶段名称
    pub stage: String,

    /// 该阶段 Token 消耗
    pub tokens_used: i64,

    /// 相对基线的 Token 增量
    pub token_delta: i64,

    /// 该阶段平均质量得分
    pub avg_quality_score: f64,

    /// 相对基线的质量得分变化
    pub quality_score_delta: f64,

    /// 该阶段样本数量
    pub sample_count: i32,
}

/// 样本集统计
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct SampleSetStats {
    /// 总样本数
    pub total_samples: i32,

    /// Golden case 数量
    pub golden_count: i32,

    /// Bad case 数量
    pub bad_case_count: i32,

    /// Regression guard 数量
    pub regression_guard_count: i32,

    /// 覆盖的阶段列表
    pub stages_covered: Vec<String>,
}

/// ROI 总体结论
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RoiConclusion {
    /// 推荐的变体 ID
    pub recommended_variant_id: Option<Uuid>,

    /// 结论类型
    pub conclusion_type: RoiConclusionType,

    /// 结论说明
    pub rationale: String,

    /// 是否建议放行
    pub recommend_promotion: bool,

    /// 放行限制（如果有）
    pub promotion_restrictions: Option<String>,
}

/// ROI 结论类型
#[derive(Debug, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum RoiConclusionType {
    /// 高 Token 低收益：不建议推广
    HighCostLowBenefit,

    /// 高 Token 高价值守卫：建议限定场景使用
    HighCostHighValueGuard,

    /// 低成本高收益：建议全量推广
    LowCostHighBenefit,

    /// 成本收益平衡：可考虑推广
    Balanced,

    /// 质量退化：阻断推广
    QualityRegression,

    /// 数据不足：需要更多证据
    InsufficientData,
}

/// 记忆预算档列表查询参数
#[derive(Debug, Deserialize, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
#[into_params(parameter_in = Query, rename_all = "camelCase")]
pub struct ListMemoryProfilesQuery {
    /// 预算层级过滤
    pub budget_tier: Option<String>,

    /// 档案版本过滤
    pub profile_version: Option<String>,

    /// 分页限制
    pub limit: Option<i64>,

    /// 分页偏移
    pub offset: Option<i64>,
}

/// 记忆预算档列表响应
#[derive(Debug, Serialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct MemoryProfilesResponse {
    /// 预算档列表
    pub profiles: Vec<MemoryBudgetProfileSnapshot>,

    /// 总数
    pub total: i64,
}
