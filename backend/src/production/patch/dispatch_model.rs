// Feature: ai-drama-quality-optimization
//! 分级模型策略（需求 35.4）

use super::models::{ModelTier, PatchScope};

/// 根据返工粒度和原因，推荐模型层级（需求 35.4）
#[allow(dead_code)]
pub fn recommend_model_tier(scope: &PatchScope, reason: &str) -> ModelTier {
    let structural_keywords = [
        "格式",
        "编号",
        "字段",
        "缺失",
        "空值",
        "重复",
        "顺序",
        "连续性",
        "format",
        "missing",
        "empty",
        "duplicate",
        "order",
    ];
    let is_structural = structural_keywords.iter().any(|kw| reason.contains(kw));
    if is_structural {
        return ModelTier::Low;
    }
    match scope {
        PatchScope::VideoPrompt | PatchScope::DeriveAsset => ModelTier::Low,
        PatchScope::StoryboardItem => ModelTier::Low,
        PatchScope::Scene | PatchScope::Episode => ModelTier::High,
    }
}
