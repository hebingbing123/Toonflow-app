// Feature: ai-drama-quality-optimization
//! 问题归因模式（需求 35.7）

use super::models::{PatchAttempt, PatchRequest, PatchScope};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AttributionCategory {
    MissingSetup,
    EmotionError,
    CameraLanguageError,
    VisualContinuityError,
    PromptExpressionGap,
    UpstreamDataError,
}

impl AttributionCategory {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::MissingSetup => "missing_setup",
            Self::EmotionError => "emotion_error",
            Self::CameraLanguageError => "camera_language_error",
            Self::VisualContinuityError => "visual_continuity_error",
            Self::PromptExpressionGap => "prompt_expression_gap",
            Self::UpstreamDataError => "upstream_data_error",
        }
    }

    pub(super) fn label(self) -> &'static str {
        match self {
            Self::MissingSetup => "设定缺失",
            Self::EmotionError => "情绪错误",
            Self::CameraLanguageError => "镜头语言错误",
            Self::VisualContinuityError => "视觉连续性错误",
            Self::PromptExpressionGap => "提示词表达不足",
            Self::UpstreamDataError => "上游数据错误",
        }
    }
}

#[derive(Debug, Clone)]
pub struct AttributionPlan {
    pub category: AttributionCategory,
    pub suggested_upstream_stage: Option<&'static str>,
    pub suggested_upstream_scope: Option<PatchScope>,
    pub repair_priority: Vec<String>,
    pub saved_token_estimate: u32,
    pub summary: String,
}

pub fn should_enter_attribution_mode(history: &[PatchAttempt], current: &PatchRequest) -> bool {
    consecutive_relevant_failures(history, current) >= 2
}

pub fn consecutive_relevant_failures(history: &[PatchAttempt], current: &PatchRequest) -> usize {
    let mut failures = 0usize;
    for attempt in history.iter().rev() {
        let is_relevant =
            attempt.scope == current.scope && attempt.ids.iter().any(|id| current.ids.contains(id));
        if !is_relevant {
            continue;
        }
        if attempt.succeeded {
            break;
        }
        failures += 1;
    }
    failures
}

fn classify_attribution_category(
    history: &[PatchAttempt],
    current: &PatchRequest,
) -> AttributionCategory {
    let mut corpus = history
        .iter()
        .filter(|attempt| attempt.scope == current.scope && !attempt.succeeded)
        .map(|attempt| attempt.reason.as_str())
        .collect::<Vec<_>>()
        .join("；");
    if !corpus.is_empty() {
        corpus.push('；');
    }
    corpus.push_str(&current.reason);
    let matches = |keywords: &[&str]| keywords.iter().any(|kw| corpus.contains(kw));
    if matches(&[
        "上游",
        "脚本错",
        "剧本错",
        "原著",
        "素材错误",
        "资产错误",
        "数据错误",
        "参考图错误",
        "source",
        "upstream",
    ]) {
        return AttributionCategory::UpstreamDataError;
    }
    if matches(&[
        "设定",
        "人设",
        "角色锚点",
        "锚点",
        "风格包",
        "故事风格",
        "参考图缺失",
        "资产缺失",
        "信息不全",
        "背景缺失",
    ]) {
        return AttributionCategory::MissingSetup;
    }
    if matches(&[
        "情绪",
        "表情",
        "语气",
        "表演",
        "台词生硬",
        "没情绪",
        "情感",
        "呼吸感",
    ]) {
        return AttributionCategory::EmotionError;
    }
    if matches(&[
        "镜头",
        "景别",
        "运镜",
        "构图",
        "轴线",
        "机位",
        "视角",
        "镜头语言",
    ]) {
        return AttributionCategory::CameraLanguageError;
    }
    if matches(&[
        "连续性",
        "穿帮",
        "服装",
        "站位",
        "视线",
        "动作",
        "长相漂移",
        "一致性",
        "肢体",
        "空间关系",
        "表演状态重复",
    ]) {
        return AttributionCategory::VisualContinuityError;
    }
    AttributionCategory::PromptExpressionGap
}

fn local_repair_scope(current_scope: &PatchScope, category: AttributionCategory) -> PatchScope {
    match (current_scope, category) {
        (PatchScope::Episode, _) => PatchScope::Scene,
        (PatchScope::Scene, AttributionCategory::PromptExpressionGap) => PatchScope::StoryboardItem,
        (PatchScope::Scene, _) => PatchScope::Scene,
        (PatchScope::StoryboardItem, AttributionCategory::PromptExpressionGap) => {
            PatchScope::VideoPrompt
        }
        (PatchScope::StoryboardItem, _) => PatchScope::StoryboardItem,
        (PatchScope::VideoPrompt, _) => PatchScope::VideoPrompt,
        (PatchScope::DeriveAsset, _) => PatchScope::DeriveAsset,
    }
}

fn suggested_upstream_recovery(
    current_scope: &PatchScope,
    category: AttributionCategory,
) -> (Option<&'static str>, Option<PatchScope>) {
    match category {
        AttributionCategory::MissingSetup => (Some("derive_assets"), Some(PatchScope::DeriveAsset)),
        AttributionCategory::EmotionError => (Some("script"), Some(PatchScope::Scene)),
        AttributionCategory::CameraLanguageError => {
            (Some("director_plan"), Some(PatchScope::Scene))
        }
        AttributionCategory::VisualContinuityError => {
            (Some("storyboard_panel"), Some(PatchScope::StoryboardItem))
        }
        AttributionCategory::PromptExpressionGap => match current_scope {
            PatchScope::VideoPrompt => (None, None),
            _ => (Some("video_prompt"), Some(PatchScope::VideoPrompt)),
        },
        AttributionCategory::UpstreamDataError => match current_scope {
            PatchScope::DeriveAsset => (Some("derive_assets"), Some(PatchScope::DeriveAsset)),
            PatchScope::Episode | PatchScope::Scene => (Some("script"), Some(PatchScope::Scene)),
            PatchScope::StoryboardItem | PatchScope::VideoPrompt => {
                (Some("script"), Some(PatchScope::Scene))
            }
        },
    }
}

fn estimated_full_rerun_tokens(scope: &PatchScope) -> u32 {
    match scope {
        PatchScope::Episode => 12_000,
        PatchScope::Scene => 5_400,
        PatchScope::StoryboardItem => 2_100,
        PatchScope::VideoPrompt => 1_300,
        PatchScope::DeriveAsset => 1_700,
    }
}

fn estimated_targeted_fix_tokens(scope: &PatchScope) -> u32 {
    match scope {
        PatchScope::Episode => 6_800,
        PatchScope::Scene => 2_400,
        PatchScope::StoryboardItem => 620,
        PatchScope::VideoPrompt => 340,
        PatchScope::DeriveAsset => 450,
    }
}

pub(super) fn estimate_saved_tokens(current_scope: &PatchScope, local_scope: &PatchScope) -> u32 {
    estimated_full_rerun_tokens(current_scope)
        .saturating_sub(estimated_targeted_fix_tokens(local_scope))
}

fn build_repair_priority(
    current_scope: &PatchScope,
    category: AttributionCategory,
    upstream_stage: Option<&'static str>,
    upstream_scope: Option<PatchScope>,
) -> Vec<String> {
    let local_scope = local_repair_scope(current_scope, category);
    let mut items = vec![format!(
        "P1 先局部修复：优先按 {} 粒度修当前对象，避免直接整段重跑。",
        local_scope.label()
    )];
    if let (Some(stage), Some(scope)) = (upstream_stage, upstream_scope) {
        items.push(format!(
            "P2 如局部修复仍失败，最小回退到 {} 阶段，按 {} 粒度补上游信息。",
            stage,
            scope.label()
        ));
    }
    items.push(format!(
        "P3 最后才考虑放大到 {} 或更大范围重跑，只有当 {} 持续无法消除时再升级。",
        current_scope.label(),
        category.label()
    ));
    items
}

pub fn build_attribution_plan(history: &[PatchAttempt], current: &PatchRequest) -> AttributionPlan {
    let category = classify_attribution_category(history, current);
    let (suggested_upstream_stage, suggested_upstream_scope) =
        suggested_upstream_recovery(&current.scope, category);
    let local_scope = local_repair_scope(&current.scope, category);
    let repair_priority = build_repair_priority(
        &current.scope,
        category,
        suggested_upstream_stage,
        suggested_upstream_scope.clone(),
    );
    let saved_token_estimate = estimate_saved_tokens(&current.scope, &local_scope);
    let failure_reasons: Vec<&str> = history
        .iter()
        .filter(|a| a.scope == current.scope && !a.succeeded)
        .map(|a| a.reason.as_str())
        .collect();
    let reason_list = if failure_reasons.is_empty() {
        "（无记录）".to_string()
    } else {
        failure_reasons.join("；")
    };
    let upstream_line = if let (Some(stage), Some(scope)) =
        (suggested_upstream_stage, suggested_upstream_scope.as_ref())
    {
        format!("最小上游回退建议：{} / {}", stage, scope.label())
    } else {
        "最小上游回退建议：当前先不要回退上游，继续做局部修复。".to_string()
    };
    let summary = format!(
        "【问题归因模式】{} 粒度连续返工未达标。\n失败归因：{}。\n历史失败原因：{}\n当前失败原因：{}\n{}\n节省 token 估算：约 {}。",
        current.scope.label(),
        category.label(),
        reason_list,
        current.reason,
        upstream_line,
        saved_token_estimate
    );
    AttributionPlan {
        category,
        suggested_upstream_stage,
        suggested_upstream_scope,
        repair_priority,
        saved_token_estimate,
        summary,
    }
}

pub fn generate_attribution_summary(history: &[PatchAttempt], current: &PatchRequest) -> String {
    build_attribution_plan(history, current).summary
}
