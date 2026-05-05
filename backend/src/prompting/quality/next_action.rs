//! 基于评审结果推断最小修复动作建议（需求 14.5）。

use serde::{Deserialize, Serialize};
use std::str::FromStr;

use super::issue_type::IssueType;
use super::types::QualityReview;

/// 最小修复动作建议枚举。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "text")]
#[serde(rename_all = "snake_case")]
pub enum NextAction {
    /// 定点修复若干分镜条目（局部返工）
    PatchStoryboardItems,
    /// 回退到导演规划阶段重做
    RollbackToDirectorPlanning,
    /// 更新角色锚点后重生成
    UpdateCharacterAnchor,
    /// 继续观察，暂不干预
    Observe,
    /// 重新生成分镜
    RegenerateStoryboard,
    /// 调整视频提示词
    AdjustVideoPrompt,
    /// 重试视频生成
    RetryVideoGeneration,
    /// 需要人工审核
    ManualReview,
}

impl NextAction {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::PatchStoryboardItems => "patch_storyboard_items",
            Self::RollbackToDirectorPlanning => "rollback_to_director_planning",
            Self::UpdateCharacterAnchor => "update_character_anchor",
            Self::Observe => "observe",
            Self::RegenerateStoryboard => "regenerate_storyboard",
            Self::AdjustVideoPrompt => "adjust_video_prompt",
            Self::RetryVideoGeneration => "retry_video_generation",
            Self::ManualReview => "manual_review",
        }
    }
}

impl FromStr for NextAction {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "patch_storyboard_items" => Ok(Self::PatchStoryboardItems),
            "rollback_to_director_planning" => Ok(Self::RollbackToDirectorPlanning),
            "update_character_anchor" => Ok(Self::UpdateCharacterAnchor),
            "observe" => Ok(Self::Observe),
            "regenerate_storyboard" => Ok(Self::RegenerateStoryboard),
            "adjust_video_prompt" => Ok(Self::AdjustVideoPrompt),
            "retry_video_generation" => Ok(Self::RetryVideoGeneration),
            "manual_review" => Ok(Self::ManualReview),
            _ => Err(format!("Invalid next_action value: {}", s)),
        }
    }
}

/// 从评审记录和已推断的问题类型推断下一步动作（纯函数，无 DB 依赖）。
pub fn infer_next_action(review: &QualityReview, issue_types: &[IssueType]) -> NextAction {
    let grade_d = review.grade.as_deref() == Some("D");
    let severe = review.overall_score.is_some_and(|s| s < 4);

    if grade_d || severe {
        return NextAction::RollbackToDirectorPlanning;
    }

    if issue_types.contains(&IssueType::CharacterConsistency) {
        return NextAction::UpdateCharacterAnchor;
    }

    let needs_patch = review.is_bad_case
        || review.overall_score.is_some_and(|s| s < 6)
        || review.passed == Some(false);

    if needs_patch {
        return NextAction::PatchStoryboardItems;
    }

    NextAction::Observe
}
