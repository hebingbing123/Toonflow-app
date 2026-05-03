//! 基于评审结果推断最小修复动作建议（需求 14.5）。

use serde::Serialize;

use super::issue_type::IssueType;
use super::types::QualityReview;

/// 最小修复动作建议枚举。
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
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
}

impl NextAction {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::PatchStoryboardItems => "patch_storyboard_items",
            Self::RollbackToDirectorPlanning => "rollback_to_director_planning",
            Self::UpdateCharacterAnchor => "update_character_anchor",
            Self::Observe => "observe",
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
