// Feature: ai-drama-quality-optimization
//! 局部返工派发逻辑：最小修复范围判断 + 分级模型策略（需求 35.1, 35.2, 35.4, 35.7）

use super::models::{ModelTier, PatchAttempt, PatchRequest, PatchResponse, PatchScope};

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
        "格式", "编号", "字段", "缺失", "空值", "重复", "顺序", "连续性",
        "format", "missing", "empty", "duplicate", "order",
    ];
    let is_structural = structural_keywords
        .iter()
        .any(|kw| reason.contains(kw));

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
    // 找出与当前请求 scope 相同且 ids 有交集的历史记录
    let relevant_failures: Vec<&PatchAttempt> = history
        .iter()
        .filter(|attempt| {
            attempt.scope == current.scope
                && !attempt.succeeded
                && attempt.ids.iter().any(|id| current.ids.contains(id))
        })
        .collect();

    // 连续 2 次失败 → 进入归因模式
    relevant_failures.len() >= 2
}

/// 生成归因分析摘要（需求 35.7）
///
/// 当连续 2 次局部返工未达标时，分析失败原因并给出分类建议。
pub fn generate_attribution_summary(
    history: &[PatchAttempt],
    current: &PatchRequest,
) -> String {
    let failure_reasons: Vec<&str> = history
        .iter()
        .filter(|a| a.scope == current.scope && !a.succeeded)
        .map(|a| a.reason.as_str())
        .collect();

    let scope_label = current.scope.label();
    let reason_list = failure_reasons.join("；");

    // 根据失败原因分类给出建议
    let suggestion = if current.scope == PatchScope::StoryboardItem
        || current.scope == PatchScope::VideoPrompt
    {
        "建议升级到 Scene 粒度重新生成，或检查上游剧本/资产数据是否存在根本性问题。"
    } else if current.scope == PatchScope::Scene {
        "建议升级到 Episode 粒度重新生成，或检查故事骨架设计是否存在结构性问题。"
    } else {
        "建议检查原著章节数据和项目配置，确认资产包和风格技能包是否完整。"
    };

    format!(
        "【问题归因模式】{} 粒度连续 2 次返工未达标。\n\
         历史失败原因：{}\n\
         当前失败原因：{}\n\
         建议：{}",
        scope_label,
        if reason_list.is_empty() { "（无记录）" } else { &reason_list },
        current.reason,
        suggestion
    )
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

    // 3. 确定实际使用的模型层级（请求中指定的优先，否则推荐）
    let model_tier = request.model_tier.clone();

    // 4. 统计连续失败次数
    let consecutive_failures = history
        .iter()
        .rev()
        .take_while(|a| a.scope == request.scope && !a.succeeded)
        .count() as u32;

    Ok(PatchResponse {
        patch_id: uuid::Uuid::new_v4(),
        scope: request.scope.clone(),
        processed_ids,
        model_tier,
        status: "queued".to_string(),
        consecutive_failures,
        attribution_mode,
        attribution_summary,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_request(scope: PatchScope, ids: Vec<i64>, reason: &str) -> PatchRequest {
        PatchRequest {
            scope,
            ids,
            reason: reason.to_string(),
            model_tier: ModelTier::Low,
        }
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
}
