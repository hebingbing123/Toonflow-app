// Feature: ai-drama-quality-optimization
//! 局部返工派发逻辑（barrel）：最小修复范围判断 + 分级模型策略（需求 35.1, 35.2, 35.4, 35.7）

pub use dispatch_attribution::{
    build_attribution_plan, generate_attribution_summary, should_enter_attribution_mode,
};
#[allow(unused_imports)]
pub use dispatch_model::recommend_model_tier;
pub use dispatch_scope::resolve_minimal_scope;

use super::dispatch_attribution::{consecutive_relevant_failures, estimate_saved_tokens};
use super::models::{PatchAttempt, PatchRequest, PatchResponse};
use super::{dispatch_attribution, dispatch_model, dispatch_scope};

/// 构建 PatchResponse（整合所有派发逻辑）
pub fn build_patch_response(
    request: &PatchRequest,
    history: &[PatchAttempt],
) -> Result<PatchResponse, String> {
    let processed_ids = resolve_minimal_scope(request)?;
    let attribution_mode = should_enter_attribution_mode(history, request);
    let attribution_summary = if attribution_mode {
        Some(generate_attribution_summary(history, request))
    } else {
        None
    };
    let attribution_plan = attribution_mode.then(|| build_attribution_plan(history, request));
    let model_tier = request.model_tier.clone();
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
    use super::super::models::{ModelTier, PatchScope};
    use super::*;
    use proptest::prelude::*;

    fn make_request(scope: PatchScope, ids: Vec<i64>, reason: &str) -> PatchRequest {
        PatchRequest {
            project_id: Some(1),
            project_uuid: None,
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
                PatchAttempt { scope: scope.clone(), ids: vec![overlap_id], reason: "第一次相关失败".to_string(), model_tier: ModelTier::Low, succeeded: false },
                PatchAttempt { scope: scope.clone(), ids: vec![overlap_id, current_ids[current_ids.len() - 1]], reason: "第二次相关失败".to_string(), model_tier: ModelTier::High, succeeded: false },
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
