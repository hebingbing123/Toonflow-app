// Feature: ai-drama-quality-optimization
// MemoryTier 枚举：定义记忆分层类型及其序列化

use serde::{Deserialize, Serialize};

/// 记忆分层枚举，对应数据库 memory_tier 字段
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub(crate) enum MemoryTier {
    /// 项目级风格圣经：角色核心设定、视觉锚点、叙事禁忌（高稳定性）
    StyleBible,
    /// 阶段摘要：阶段名称、完成状态、关键决策点（中稳定性，≤320字）
    StageSummary,
    /// 增量记忆：局部连续性补丁，仅记录相对上一次状态变化（低稳定性，≤200字）
    DeltaMemory,
    /// 普通消息（默认，兼容旧数据）
    #[default]
    Message,
}

impl MemoryTier {
    /// 转换为数据库存储的字符串值
    pub(crate) fn as_db_str(&self) -> &'static str {
        match self {
            MemoryTier::StyleBible => "style_bible",
            MemoryTier::StageSummary => "stage_summary",
            MemoryTier::DeltaMemory => "delta_memory",
            MemoryTier::Message => "message",
        }
    }

    /// 从数据库字符串解析
    #[allow(dead_code)]
    pub(crate) fn from_db_str(s: &str) -> Self {
        match s {
            "style_bible" => MemoryTier::StyleBible,
            "stage_summary" => MemoryTier::StageSummary,
            "delta_memory" => MemoryTier::DeltaMemory,
            _ => MemoryTier::Message,
        }
    }

    /// 验证字符串是否为合法的 memory_tier 值
    pub(crate) fn is_valid(s: &str) -> bool {
        matches!(
            s,
            "style_bible" | "stage_summary" | "delta_memory" | "message"
        )
    }
}

impl std::fmt::Display for MemoryTier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_db_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // Feature: ai-drama-quality-optimization, Property 20: 记忆分层合规性
    // 验证：需求 33.1, 33.3, 33.4
    proptest! {
        #[test]
        fn prop_memory_tier_roundtrip(tier in prop_oneof![
            Just(MemoryTier::StyleBible),
            Just(MemoryTier::StageSummary),
            Just(MemoryTier::DeltaMemory),
            Just(MemoryTier::Message),
        ]) {
            // 序列化后反序列化应得到相同值
            let db_str = tier.as_db_str();
            let parsed = MemoryTier::from_db_str(db_str);
            prop_assert_eq!(tier, parsed);
        }

        #[test]
        fn prop_memory_tier_valid_values(s in prop_oneof![
            Just("style_bible"),
            Just("stage_summary"),
            Just("delta_memory"),
            Just("message"),
        ]) {
            prop_assert!(MemoryTier::is_valid(s));
        }

        #[test]
        fn prop_memory_tier_invalid_values(s in "[a-z_]{1,20}") {
            // 只有4个合法值，随机字符串大概率无效
            if !matches!(
                s.as_str(),
                "style_bible" | "stage_summary" | "delta_memory" | "message"
            ) {
                prop_assert!(!MemoryTier::is_valid(&s));
            }
        }
    }

    #[test]
    fn memory_tier_default_is_message() {
        assert_eq!(MemoryTier::default(), MemoryTier::Message);
    }

    #[test]
    fn memory_tier_display() {
        assert_eq!(MemoryTier::StyleBible.to_string(), "style_bible");
        assert_eq!(MemoryTier::StageSummary.to_string(), "stage_summary");
        assert_eq!(MemoryTier::DeltaMemory.to_string(), "delta_memory");
        assert_eq!(MemoryTier::Message.to_string(), "message");
    }

    #[test]
    fn memory_tier_unknown_db_str_falls_back_to_message() {
        assert_eq!(
            MemoryTier::from_db_str("unknown_value"),
            MemoryTier::Message
        );
        assert_eq!(MemoryTier::from_db_str(""), MemoryTier::Message);
    }
}
