//! 质量评审问题类型规范化映射（需求 14.2）。

use serde::Serialize;

use super::types::QualityReview;

/// 规范化问题类型枚举（6 类）。
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum IssueType {
    /// 人物一致性（角色穿帮、脸崩、服装突变）
    CharacterConsistency,
    /// 情绪表达（情绪平、木、僵、无起伏）
    EmotionExpression,
    /// 镜头节奏（节奏过平、镜头逻辑断裂）
    ShotRhythm,
    /// 视觉连续性（场景物理错乱、光影假、闪烁）
    VisualContinuity,
    /// 台词生硬（读文章感、口型不自然、机械朗读）
    DialogueStiffness,
    /// AI 痕迹（一眼 AI、塑料感、不自然动作）
    AiArtifact,
}

impl IssueType {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::CharacterConsistency => "character_consistency",
            Self::EmotionExpression => "emotion_expression",
            Self::ShotRhythm => "shot_rhythm",
            Self::VisualContinuity => "visual_continuity",
            Self::DialogueStiffness => "dialogue_stiffness",
            Self::AiArtifact => "ai_artifact",
        }
    }
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|n| text.contains(n))
}

/// 从评审记录推断问题类型列表（纯函数，无 DB 依赖）。
pub fn infer_issue_types(review: &QualityReview) -> Vec<IssueType> {
    let comment = review
        .comments
        .as_deref()
        .map(str::to_lowercase)
        .unwrap_or_default();
    let category = review.bad_case_category.as_deref().unwrap_or("");
    let mut types = Vec::new();

    // CharacterConsistency
    let cc_score_bad = review.character_consistency.is_some_and(|s| s <= 5);
    if cc_score_bad
        || category == "character_break"
        || contains_any(
            &comment,
            &[
                "穿帮",
                "串脸",
                "脸崩",
                "角色不一致",
                "服装不一致",
                "五官不一致",
            ],
        )
        || contains_any(category, &["character", "identity", "consistency"])
    {
        types.push(IssueType::CharacterConsistency);
    }

    // EmotionExpression
    let pacing_bad = review.pacing.is_some_and(|s| s <= 5);
    if pacing_bad
        || contains_any(
            &comment,
            &[
                "没情绪",
                "情绪平",
                "木",
                "僵",
                "无起伏",
                "blank expression",
                "emotionless",
                "情绪单一",
            ],
        )
        || contains_any(category, &["emotion", "performance"])
    {
        types.push(IssueType::EmotionExpression);
    }

    // ShotRhythm
    if pacing_bad
        || contains_any(
            &comment,
            &["节奏", "镜头逻辑", "断裂", "过平", "空镜", "shot"],
        )
        || category == "pacing_issue"
    {
        types.push(IssueType::ShotRhythm);
    }

    // VisualContinuity
    let vq_bad = review.visual_quality.is_some_and(|s| s <= 5);
    if vq_bad
        || contains_any(
            &comment,
            &["光影假", "闪烁", "物理", "场景错乱", "连续性", "continuity"],
        )
        || contains_any(category, &["visual_error", "continuity", "lighting"])
    {
        types.push(IssueType::VisualContinuity);
    }

    // DialogueStiffness
    let dn_bad = review.dialogue_naturalness.is_some_and(|s| s <= 5);
    if dn_bad
        || contains_any(
            &comment,
            &["读文章", "生硬", "朗读", "口型", "机械", "没情绪", "干念"],
        )
        || category == "dialogue_issue"
        || contains_any(category, &["dialogue", "delivery", "lip"])
    {
        types.push(IssueType::DialogueStiffness);
    }

    // AiArtifact
    if vq_bad
        || contains_any(
            &comment,
            &[
                "ai感",
                "像ai",
                "一眼ai",
                "塑料",
                "不自然",
                "假脸",
                "出戏",
                "ai痕迹",
            ],
        )
        || contains_any(category, &["ai_artifact", "visual_error"])
    {
        types.push(IssueType::AiArtifact);
    }

    types.dedup();
    types
}
