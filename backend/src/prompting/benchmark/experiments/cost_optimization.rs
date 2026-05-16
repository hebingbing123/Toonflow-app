//! 实验成本优化策略：分层回放、中间产物复用、token 节省估算。

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

/// 样本分层策略
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "lowercase")]
pub enum SampleTier {
    /// 快速验证：最小样本集，用于快速验证变更
    Smoke,
    /// 核心样本集：覆盖关键场景和高权重守卫样本
    Core,
    /// 完整样本集：全量样本，用于正式放行前的完整验证
    Full,
}

impl SampleTier {
    /// 获取样本数量建议
    pub fn suggested_sample_count(&self) -> usize {
        match self {
            SampleTier::Smoke => 5,
            SampleTier::Core => 20,
            SampleTier::Full => 100,
        }
    }

    /// 获取相对全量的样本比例
    pub fn sample_ratio(&self) -> f64 {
        match self {
            SampleTier::Smoke => 0.05,
            SampleTier::Core => 0.20,
            SampleTier::Full => 1.0,
        }
    }
}

impl std::str::FromStr for SampleTier {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "smoke" => Ok(SampleTier::Smoke),
            "core" => Ok(SampleTier::Core),
            "full" => Ok(SampleTier::Full),
            _ => Err(format!(
                "Invalid sample tier: {} | 无效的 sample tier：{}",
                s, s
            )),
        }
    }
}

impl std::fmt::Display for SampleTier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            SampleTier::Smoke => write!(f, "smoke"),
            SampleTier::Core => write!(f, "core"),
            SampleTier::Full => write!(f, "full"),
        }
    }
}

/// 阶段范围
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum Stage {
    StorySkeleton,
    AdaptationStrategy,
    DirectorPlanning,
    StoryboardTable,
    StoryboardPanel,
    VideoPrompt,
}

impl Stage {
    /// 获取阶段的估算 token 消耗（基于历史数据）
    pub fn estimated_token_cost(&self) -> u64 {
        match self {
            Stage::StorySkeleton => 5000,
            Stage::AdaptationStrategy => 8000,
            Stage::DirectorPlanning => 10000,
            Stage::StoryboardTable => 15000,
            Stage::StoryboardPanel => 20000,
            Stage::VideoPrompt => 25000,
        }
    }

    /// 获取阶段顺序索引
    pub fn order_index(&self) -> usize {
        match self {
            Stage::StorySkeleton => 0,
            Stage::AdaptationStrategy => 1,
            Stage::DirectorPlanning => 2,
            Stage::StoryboardTable => 3,
            Stage::StoryboardPanel => 4,
            Stage::VideoPrompt => 5,
        }
    }

    /// 判断是否可以复用中间产物
    pub fn supports_artifact_reuse(&self) -> bool {
        // 所有阶段都支持复用，但早期阶段复用价值更高
        true
    }
}

impl std::str::FromStr for Stage {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "story_skeleton" => Ok(Stage::StorySkeleton),
            "adaptation_strategy" => Ok(Stage::AdaptationStrategy),
            "director_planning" => Ok(Stage::DirectorPlanning),
            "storyboard_table" => Ok(Stage::StoryboardTable),
            "storyboard_panel" => Ok(Stage::StoryboardPanel),
            "video_prompt" => Ok(Stage::VideoPrompt),
            _ => Err(format!("Invalid stage: {} | 无效的 stage：{}", s, s)),
        }
    }
}

impl std::fmt::Display for Stage {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Stage::StorySkeleton => write!(f, "story_skeleton"),
            Stage::AdaptationStrategy => write!(f, "adaptation_strategy"),
            Stage::DirectorPlanning => write!(f, "director_planning"),
            Stage::StoryboardTable => write!(f, "storyboard_table"),
            Stage::StoryboardPanel => write!(f, "storyboard_panel"),
            Stage::VideoPrompt => write!(f, "video_prompt"),
        }
    }
}

/// 中间产物复用记录
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct ArtifactReuse {
    /// 样本 ID
    pub benchmark_case_id: Uuid,
    /// 阶段
    pub stage: String,
    /// 是否复用了中间产物
    pub reused: bool,
    /// 复用来源（如果复用）
    pub reuse_source: Option<String>,
    /// 节省的 token 数量
    pub tokens_saved: u64,
}

/// Token 节省估算
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct TokenSavingsEstimate {
    /// 实验运行 ID
    pub experiment_run_id: Uuid,
    /// 变体 ID
    pub variant_id: Uuid,
    /// 全量重跑估算 token 消耗
    pub full_replay_tokens: u64,
    /// 实际 token 消耗
    pub actual_tokens: u64,
    /// 节省的 token 数量
    pub tokens_saved: u64,
    /// 节省比例
    pub savings_ratio: f64,
    /// 样本分层带来的节省
    pub tier_savings: u64,
    /// 阶段范围限制带来的节省
    pub stage_scope_savings: u64,
    /// 中间产物复用带来的节省
    pub artifact_reuse_savings: u64,
    /// 复用详情
    pub reuse_details: Vec<ArtifactReuse>,
}

impl TokenSavingsEstimate {
    /// 创建新的 token 节省估算
    pub fn new(experiment_run_id: Uuid, variant_id: Uuid) -> Self {
        Self {
            experiment_run_id,
            variant_id,
            full_replay_tokens: 0,
            actual_tokens: 0,
            tokens_saved: 0,
            savings_ratio: 0.0,
            tier_savings: 0,
            stage_scope_savings: 0,
            artifact_reuse_savings: 0,
            reuse_details: Vec::new(),
        }
    }

    /// 计算节省比例
    pub fn calculate_savings_ratio(&mut self) {
        if self.full_replay_tokens > 0 {
            self.savings_ratio = self.tokens_saved as f64 / self.full_replay_tokens as f64;
        }
    }

    /// 添加复用详情
    pub fn add_reuse_detail(&mut self, detail: ArtifactReuse) {
        if detail.reused {
            self.artifact_reuse_savings += detail.tokens_saved;
        }
        self.reuse_details.push(detail);
    }

    /// 更新总节省量
    pub fn update_total_savings(&mut self) {
        self.tokens_saved =
            self.tier_savings + self.stage_scope_savings + self.artifact_reuse_savings;
        self.calculate_savings_ratio();
    }
}

/// 成本优化策略配置
#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct CostOptimizationConfig {
    /// 是否启用中间产物复用
    pub enable_artifact_reuse: bool,
    /// 是否启用结构化快照复用
    pub enable_snapshot_reuse: bool,
    /// 最大复用时间窗口（小时）
    pub max_reuse_window_hours: u32,
    /// 是否优先复用高成本阶段
    pub prioritize_expensive_stages: bool,
}

impl Default for CostOptimizationConfig {
    fn default() -> Self {
        Self {
            enable_artifact_reuse: true,
            enable_snapshot_reuse: true,
            max_reuse_window_hours: 72, // 3 天
            prioritize_expensive_stages: true,
        }
    }
}

/// 计算样本分层带来的 token 节省
pub fn calculate_tier_savings(
    sample_tier: &SampleTier,
    total_samples: usize,
    stages: &[Stage],
) -> u64 {
    let full_cost = calculate_full_replay_cost(total_samples, stages);
    let tier_ratio = sample_tier.sample_ratio();
    let tier_cost = (full_cost as f64 * tier_ratio) as u64;
    full_cost.saturating_sub(tier_cost)
}

/// 计算阶段范围限制带来的 token 节省
pub fn calculate_stage_scope_savings(selected_stages: &[Stage], sample_count: usize) -> u64 {
    let all_stages = [
        Stage::StorySkeleton,
        Stage::AdaptationStrategy,
        Stage::DirectorPlanning,
        Stage::StoryboardTable,
        Stage::StoryboardPanel,
        Stage::VideoPrompt,
    ];

    let full_cost: u64 = all_stages
        .iter()
        .map(|s| s.estimated_token_cost())
        .sum::<u64>()
        * sample_count as u64;

    let selected_cost: u64 = selected_stages
        .iter()
        .map(|s| s.estimated_token_cost())
        .sum::<u64>()
        * sample_count as u64;

    full_cost.saturating_sub(selected_cost)
}

/// 计算全量重跑成本
pub fn calculate_full_replay_cost(total_samples: usize, stages: &[Stage]) -> u64 {
    let stage_cost: u64 = stages.iter().map(|s| s.estimated_token_cost()).sum();
    stage_cost * total_samples as u64
}

/// 估算中间产物复用带来的节省
pub fn estimate_artifact_reuse_savings(
    sample_count: usize,
    stages: &[Stage],
    reuse_ratio: f64,
) -> u64 {
    let total_cost: u64 =
        stages.iter().map(|s| s.estimated_token_cost()).sum::<u64>() * sample_count as u64;

    (total_cost as f64 * reuse_ratio) as u64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sample_tier_ratios() {
        assert_eq!(SampleTier::Smoke.sample_ratio(), 0.05);
        assert_eq!(SampleTier::Core.sample_ratio(), 0.20);
        assert_eq!(SampleTier::Full.sample_ratio(), 1.0);
    }

    #[test]
    fn test_stage_order() {
        assert_eq!(Stage::StorySkeleton.order_index(), 0);
        assert_eq!(Stage::VideoPrompt.order_index(), 5);
    }

    #[test]
    fn test_tier_savings_calculation() {
        let stages = vec![Stage::StoryboardTable, Stage::VideoPrompt];
        let total_samples = 100;

        let smoke_savings = calculate_tier_savings(&SampleTier::Smoke, total_samples, &stages);
        let core_savings = calculate_tier_savings(&SampleTier::Core, total_samples, &stages);

        // Smoke 应该比 Core 节省更多
        assert!(smoke_savings > core_savings);
        assert!(smoke_savings > 0);
    }

    #[test]
    fn test_stage_scope_savings() {
        let selected_stages = vec![Stage::VideoPrompt];
        let sample_count = 10;

        let savings = calculate_stage_scope_savings(&selected_stages, sample_count);

        // 只选一个阶段应该比全阶段节省很多
        assert!(savings > 0);
    }

    #[test]
    fn test_token_savings_estimate() {
        let mut estimate = TokenSavingsEstimate::new(Uuid::new_v4(), Uuid::new_v4());

        estimate.full_replay_tokens = 1000000;
        estimate.tier_savings = 500000;
        estimate.stage_scope_savings = 200000;
        estimate.artifact_reuse_savings = 100000;

        estimate.update_total_savings();

        assert_eq!(estimate.tokens_saved, 800000);
        assert_eq!(estimate.savings_ratio, 0.8);
    }

    #[test]
    fn test_artifact_reuse_detail() {
        let mut estimate = TokenSavingsEstimate::new(Uuid::new_v4(), Uuid::new_v4());

        let reuse = ArtifactReuse {
            benchmark_case_id: Uuid::new_v4(),
            stage: "storyboard_table".to_string(),
            reused: true,
            reuse_source: Some("previous_run".to_string()),
            tokens_saved: 15000,
        };

        estimate.add_reuse_detail(reuse);
        estimate.update_total_savings();

        assert_eq!(estimate.artifact_reuse_savings, 15000);
        assert_eq!(estimate.reuse_details.len(), 1);
    }
}
