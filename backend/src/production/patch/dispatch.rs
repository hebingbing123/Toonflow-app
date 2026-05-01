// Feature: ai-drama-quality-optimization
//! 局部返工派发逻辑：最小修复范围判断 + 分级模型策略（需求 35.1, 35.2, 35.4, 35.7）

use super::models::{ModelTier, PatchAttempt, PatchRequest, PatchResponse, PatchScope};

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

    fn label(self) -> &'static str {
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

/// 根据返工粒度和原因，判断最小修复范围（需求 35.2）
///
/// 规则：
/// - 如果 `ids` 为空，返回错误
/// - 如果 `ids` 数量超过粒度上限，建议升级到更粗粒度
/// - 返回实际需要处理的 ID 列表（去重后）
pub fn resolve_minimal_scope(request: &PatchRequest) -> Result<Vec<i64>, String> {
    if request.ids.is_empty() {
        return Err(format!(
            "ids 不能为空：{} 粒度的返工需要至少一个目标 ID",
            request.scope.label()
        ));
    }

    // 去重并排序
    let mut ids = request.ids.clone();
    ids.sort_unstable();
    ids.dedup();

    // 粒度上限检查（防止误用局部返工做全量重跑）
    let max_ids = match request.scope {
        PatchScope::Episode => 3,
        PatchScope::Scene => 10,
        PatchScope::StoryboardItem => 20,
        PatchScope::VideoPrompt => 20,
        PatchScope::DeriveAsset => 10,
    };

    if ids.len() > max_ids {
        return Err(format!(
            "{} 粒度单次最多处理 {} 个对象，当前请求 {} 个。建议升级到更粗粒度或分批处理。",
            request.scope.label(),
            max_ids,
            ids.len()
        ));
    }

    Ok(ids)
}

/// 根据返工粒度和原因，推荐模型层级（需求 35.4）
///
/// 分级策略：
/// - `Low`（低成本模型）：结构化提取、格式修复、范围压缩
///   适用场景：格式错误、字段缺失、编号不连续等结构性问题
/// - `High`（高能力模型）：剧情改写、情绪强化、关键镜头提示词
///   适用场景：内容质量问题、情绪不符、视觉连续性违规等
#[allow(dead_code)]
pub fn recommend_model_tier(scope: &PatchScope, reason: &str) -> ModelTier {
    // 关键词匹配：结构性问题 → Low
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

    // 粒度推断：细粒度优先用 Low，粗粒度用 High
    match scope {
        PatchScope::VideoPrompt | PatchScope::DeriveAsset => ModelTier::Low,
        PatchScope::StoryboardItem => ModelTier::Low,
        PatchScope::Scene | PatchScope::Episode => ModelTier::High,
    }
}

/// 检查是否需要进入「问题归因模式」（需求 35.7）
///
/// 规则：同一对象（相同 scope + ids 交集非空）连续 2 次局部返工未达标，
/// 升级为「问题归因模式」，输出失败原因分类。
pub fn should_enter_attribution_mode(history: &[PatchAttempt], current: &PatchRequest) -> bool {
    consecutive_relevant_failures(history, current) >= 2
}

fn consecutive_relevant_failures(history: &[PatchAttempt], current: &PatchRequest) -> usize {
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

fn estimate_saved_tokens(current_scope: &PatchScope, local_scope: &PatchScope) -> u32 {
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

/// 生成归因分析摘要（需求 35.7）
///
/// 当连续 2 次局部返工未达标时，分析失败原因并给出分类建议。
pub fn generate_attribution_summary(history: &[PatchAttempt], current: &PatchRequest) -> String {
    build_attribution_plan(history, current).summary
}

/// 构建 PatchResponse（整合所有派发逻辑）
pub fn build_patch_response(
    request: &PatchRequest,
    history: &[PatchAttempt],
) -> Result<PatchResponse, String> {
    // 1. 解析最小修复范围
    let processed_ids = resolve_minimal_scope(request)?;

    // 2. 检查是否进入归因模式
    let attribution_mode = should_enter_attribution_mode(history, request);
    let attribution_summary = if attribution_mode {
        Some(generate_attribution_summary(history, request))
    } else {
        None
    };
    let attribution_plan = attribution_mode.then(|| build_attribution_plan(history, request));

    // 3. 确定实际使用的模型层级（请求中指定的优先，否则推荐）
    let model_tier = request.model_tier.clone();

    // 4. 统计连续失败次数
    let consecutive_failures = consecutive_relevant_failures(history, request) as u32;

    Ok(PatchResponse {
        patch_id: uuid::Uuid::new_v4(),
        scope: request.scope.clone(),
        processed_ids,
        model_tier,
        status: "queued".to_string(),
        consecutive_failures,
        attribution_mode,
        attribution_summary,
        attribution_category: attribution_plan
            .as_ref()
            .map(|plan| plan.category.as_str().to_string()),
        suggested_upstream_stage: attribution_plan
            .as_ref()
            .and_then(|plan| plan.suggested_upstream_stage.map(str::to_string)),
        suggested_upstream_scope: attribution_plan
            .as_ref()
            .and_then(|plan| plan.suggested_upstream_scope.clone()),
        repair_priority: attribution_plan
            .as_ref()
            .map(|plan| plan.repair_priority.clone())
            .unwrap_or_else(|| {
                vec![format!(
                    "P1 先按 {} 粒度做最小修复，确认问题是否只存在当前对象。",
                    request.scope.label()
                )]
            }),
        saved_token_estimate: attribution_plan
            .as_ref()
            .map(|plan| plan.saved_token_estimate)
            .unwrap_or_else(|| estimate_saved_tokens(&request.scope, &request.scope)),
        memory_written: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    fn make_request(scope: PatchScope, ids: Vec<i64>, reason: &str) -> PatchRequest {
        PatchRequest {
            project_id: 1,
            episodes_id: Some(2),
            scope,
            ids,
            reason: reason.to_string(),
            model_tier: ModelTier::Low,
        }
    }

    fn scope_limit(scope: &PatchScope) -> usize {
        match scope {
            PatchScope::Episode => 3,
            PatchScope::Scene => 10,
            PatchScope::StoryboardItem => 20,
            PatchScope::VideoPrompt => 20,
            PatchScope::DeriveAsset => 10,
        }
    }

    fn patch_scope_strategy() -> impl Strategy<Value = PatchScope> {
        prop_oneof![
            Just(PatchScope::Episode),
            Just(PatchScope::Scene),
            Just(PatchScope::StoryboardItem),
            Just(PatchScope::VideoPrompt),
            Just(PatchScope::DeriveAsset),
        ]
    }

    #[test]
    fn resolve_minimal_scope_deduplicates_and_sorts() {
        let req = make_request(PatchScope::StoryboardItem, vec![3, 1, 2, 1, 3], "格式错误");
        let ids = resolve_minimal_scope(&req).unwrap();
        assert_eq!(ids, vec![1, 2, 3]);
    }

    #[test]
    fn resolve_minimal_scope_rejects_empty_ids() {
        let req = make_request(PatchScope::StoryboardItem, vec![], "格式错误");
        assert!(resolve_minimal_scope(&req).is_err());
    }

    #[test]
    fn resolve_minimal_scope_rejects_over_limit() {
        // StoryboardItem 上限 20
        let ids: Vec<i64> = (1..=25).collect();
        let req = make_request(PatchScope::StoryboardItem, ids, "格式错误");
        assert!(resolve_minimal_scope(&req).is_err());
    }

    #[test]
    fn recommend_model_tier_structural_reason_returns_low() {
        let tier = recommend_model_tier(&PatchScope::Episode, "格式错误，字段缺失");
        assert_eq!(tier, ModelTier::Low);
    }

    #[test]
    fn recommend_model_tier_episode_scope_returns_high() {
        let tier = recommend_model_tier(&PatchScope::Episode, "情绪不符，需要重写");
        assert_eq!(tier, ModelTier::High);
    }

    #[test]
    fn recommend_model_tier_video_prompt_returns_low() {
        let tier = recommend_model_tier(&PatchScope::VideoPrompt, "画面描述不够生动");
        assert_eq!(tier, ModelTier::Low);
    }

    #[test]
    fn should_enter_attribution_mode_after_two_failures() {
        let history = vec![
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![1, 2],
                reason: "第一次失败".to_string(),
                model_tier: ModelTier::Low,
                succeeded: false,
            },
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![1, 3],
                reason: "第二次失败".to_string(),
                model_tier: ModelTier::Low,
                succeeded: false,
            },
        ];
        let req = make_request(PatchScope::StoryboardItem, vec![1], "第三次");
        assert!(should_enter_attribution_mode(&history, &req));
    }

    #[test]
    fn should_not_enter_attribution_mode_after_one_failure() {
        let history = vec![PatchAttempt {
            scope: PatchScope::StoryboardItem,
            ids: vec![1],
            reason: "第一次失败".to_string(),
            model_tier: ModelTier::Low,
            succeeded: false,
        }];
        let req = make_request(PatchScope::StoryboardItem, vec![1], "第二次");
        assert!(!should_enter_attribution_mode(&history, &req));
    }

    #[test]
    fn should_not_enter_attribution_mode_if_different_scope() {
        let history = vec![
            PatchAttempt {
                scope: PatchScope::Episode,
                ids: vec![1],
                reason: "失败".to_string(),
                model_tier: ModelTier::High,
                succeeded: false,
            },
            PatchAttempt {
                scope: PatchScope::Episode,
                ids: vec![1],
                reason: "失败".to_string(),
                model_tier: ModelTier::High,
                succeeded: false,
            },
        ];
        // 不同 scope → 不触发
        let req = make_request(PatchScope::StoryboardItem, vec![1], "失败");
        assert!(!should_enter_attribution_mode(&history, &req));
    }

    #[test]
    fn should_not_enter_attribution_mode_when_relevant_success_resets_streak() {
        let history = vec![
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![1],
                reason: "第一次失败".to_string(),
                model_tier: ModelTier::Low,
                succeeded: false,
            },
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![1],
                reason: "第二次已修复".to_string(),
                model_tier: ModelTier::Low,
                succeeded: true,
            },
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![1],
                reason: "第三次又失败".to_string(),
                model_tier: ModelTier::Low,
                succeeded: false,
            },
        ];
        let req = make_request(PatchScope::StoryboardItem, vec![1], "当前返工");
        assert!(!should_enter_attribution_mode(&history, &req));
        assert_eq!(consecutive_relevant_failures(&history, &req), 1);
    }

    #[test]
    fn attribution_summary_classifies_emotion_error_and_prefers_local_fix_first() {
        let history = vec![
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![7],
                reason: "表情不对，情绪没有起伏".to_string(),
                model_tier: ModelTier::High,
                succeeded: false,
            },
            PatchAttempt {
                scope: PatchScope::StoryboardItem,
                ids: vec![7],
                reason: "台词很生硬，角色没情绪".to_string(),
                model_tier: ModelTier::High,
                succeeded: false,
            },
        ];
        let req = make_request(
            PatchScope::StoryboardItem,
            vec![7],
            "第三次返工，还是情绪不对",
        );
        let response = build_patch_response(&req, &history).unwrap();
        assert_eq!(
            response.attribution_category.as_deref(),
            Some("emotion_error")
        );
        assert_eq!(response.suggested_upstream_stage.as_deref(), Some("script"));
        assert_eq!(response.repair_priority.len(), 3);
        assert!(response.repair_priority[0].contains("先局部修复"));
        assert!(response.saved_token_estimate > 0);
    }

    #[test]
    fn attribution_summary_classifies_visual_continuity() {
        let history = vec![
            PatchAttempt {
                scope: PatchScope::VideoPrompt,
                ids: vec![11],
                reason: "服装连续性穿帮，站位和视线也乱了".to_string(),
                model_tier: ModelTier::High,
                succeeded: false,
            },
            PatchAttempt {
                scope: PatchScope::VideoPrompt,
                ids: vec![11],
                reason: "角色长相漂移，动作衔接不连贯".to_string(),
                model_tier: ModelTier::High,
                succeeded: false,
            },
        ];
        let req = make_request(PatchScope::VideoPrompt, vec![11], "继续修复角色连续性");
        let summary = generate_attribution_summary(&history, &req);
        assert!(summary.contains("视觉连续性错误"));
        assert!(summary.contains("storyboard_panel"));
    }

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(20))]

        // Feature: drama-platform-completion, Property 4: 局部返工对象上限约束
        // 验证：需求 4.2, 13.4
        #[test]
        fn prop_patch_scope_respects_object_limit(
            scope in patch_scope_strategy(),
            ids in proptest::collection::vec(1i64..40, 0..35usize),
        ) {
            let req = make_request(scope.clone(), ids.clone(), "局部返工测试");
            let unique_ids = {
                let mut deduped = ids;
                deduped.sort_unstable();
                deduped.dedup();
                deduped
            };
            let result = resolve_minimal_scope(&req);

            if unique_ids.is_empty() || unique_ids.len() > scope_limit(&scope) {
                prop_assert!(result.is_err());
            } else {
                let processed = result.expect("expected valid local patch scope");
                prop_assert_eq!(processed.as_slice(), unique_ids.as_slice());
                prop_assert!(processed.len() <= scope_limit(&scope));
            }
        }

        // Feature: drama-platform-completion, Property 5: 连续失败进入归因模式
        // 验证：需求 13.1
        #[test]
        fn prop_consecutive_relevant_failures_trigger_attribution_mode(
            scope in patch_scope_strategy(),
            current_ids in proptest::collection::vec(1i64..30, 1..6usize),
            noise_ids in proptest::collection::vec(31i64..60, 1..4usize),
            trailing_noise_count in 0usize..3usize,
        ) {
            let current_ids = {
                let mut ids = current_ids;
                ids.sort_unstable();
                ids.dedup();
                ids
            };
            let overlap_id = current_ids[0];
            let req = make_request(scope.clone(), current_ids.clone(), "角色情绪仍然生硬");

            let mut history = vec![
                PatchAttempt {
                    scope: scope.clone(),
                    ids: vec![overlap_id],
                    reason: "第一次相关失败".to_string(),
                    model_tier: ModelTier::Low,
                    succeeded: false,
                },
                PatchAttempt {
                    scope: scope.clone(),
                    ids: vec![overlap_id, current_ids[current_ids.len() - 1]],
                    reason: "第二次相关失败".to_string(),
                    model_tier: ModelTier::High,
                    succeeded: false,
                },
            ];

            for index in 0..trailing_noise_count {
                history.push(PatchAttempt {
                    scope: PatchScope::Episode,
                    ids: vec![noise_ids[index % noise_ids.len()]],
                    reason: format!("无关噪声 {}", index),
                    model_tier: ModelTier::Low,
                    succeeded: index % 2 == 0,
                });
            }

            prop_assert_eq!(consecutive_relevant_failures(&history, &req), 2);
            prop_assert!(should_enter_attribution_mode(&history, &req));
        }
    }
}
