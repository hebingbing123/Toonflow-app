//! 评测量表数据模型。

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

/// 质量维度枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum QualityDimension {
    /// 人物一致性
    CharacterConsistency,
    /// 情绪表达
    EmotionExpression,
    /// 镜头真实感
    ShotRealism,
    /// AI 痕迹（反向指标）
    AiArtifacts,
    /// 台词自然度
    DialogueNaturalness,
    /// 叙事抓力
    NarrativeGrip,
    /// 视觉连续性
    VisualContinuity,
}

impl QualityDimension {
    /// 获取维度的显示名称
    pub fn display_name(&self) -> &'static str {
        match self {
            Self::CharacterConsistency => "人物一致性",
            Self::EmotionExpression => "情绪表达",
            Self::ShotRealism => "镜头真实感",
            Self::AiArtifacts => "AI 痕迹",
            Self::DialogueNaturalness => "台词自然度",
            Self::NarrativeGrip => "叙事抓力",
            Self::VisualContinuity => "视觉连续性",
        }
    }

    /// 获取所有维度
    pub fn all() -> Vec<Self> {
        vec![
            Self::CharacterConsistency,
            Self::EmotionExpression,
            Self::ShotRealism,
            Self::AiArtifacts,
            Self::DialogueNaturalness,
            Self::NarrativeGrip,
            Self::VisualContinuity,
        ]
    }
}

/// 问题严重等级
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum IssueSeverity {
    /// 致命问题（必须修复）
    Critical,
    /// 严重问题（强烈建议修复）
    Major,
    /// 中等问题（建议修复）
    Moderate,
    /// 轻微问题（可选修复）
    Minor,
}

impl IssueSeverity {
    /// 获取严重等级的权重（用于汇总计算）
    pub fn weight(&self) -> f64 {
        match self {
            Self::Critical => 4.0,
            Self::Major => 3.0,
            Self::Moderate => 2.0,
            Self::Minor => 1.0,
        }
    }
}

/// 单个维度的评分
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RubricDimensionScore {
    /// 质量维度
    pub dimension: QualityDimension,
    /// 分值（0-100）
    pub score: f64,
    /// 该维度在当前阶段的权重
    pub weight: f64,
    /// 发现的问题列表
    pub issues: Vec<RubricIssue>,
    /// 文字说明
    pub comment: Option<String>,
}

/// 评测发现的问题
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RubricIssue {
    /// 问题类型标签
    pub issue_type: String,
    /// 严重等级
    pub severity: IssueSeverity,
    /// 问题描述
    pub description: String,
    /// 相关位置或上下文
    pub context: Option<String>,
}

/// 实验结果评分汇总
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ExperimentScoreSummary {
    /// 各维度评分
    pub dimension_scores: Vec<RubricDimensionScore>,
    /// 加权总分（0-100）
    pub weighted_total_score: f64,
    /// 是否通过（基于阈值）
    pub passed: bool,
    /// 是否建议放行
    pub recommend_promotion: bool,
    /// 是否建议升为 bad case
    pub recommend_bad_case: bool,
    /// 是否建议升为 golden case
    pub recommend_golden_case: bool,
    /// 自动评测置信度
    pub confidence: AutoJudgeConfidence,
    /// 是否需要人工复核
    pub requires_human_review: bool,
    /// 汇总说明
    pub summary: String,
}

/// 自动评测置信度
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum AutoJudgeConfidence {
    /// 高置信（可直接使用）
    High,
    /// 中等置信（建议复核）
    Medium,
    /// 低置信（必须人工复核）
    Low,
}

/// 评分预览请求体
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ScorePreviewRequest {
    /// 生成阶段
    pub stage: String,
    /// 质量评审 ID（可选，用于从现有评审生成预览）
    pub quality_review_id: Option<uuid::Uuid>,
    /// 手动提供的维度分数（用于模拟）
    pub manual_scores: Option<Vec<ManualDimensionScore>>,
}

/// 手动提供的维度分数
#[derive(Debug, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ManualDimensionScore {
    pub dimension: QualityDimension,
    pub score: f64,
    #[allow(dead_code)]
    pub issues: Option<Vec<RubricIssue>>,
}
