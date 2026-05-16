//! 实验运行与变体快照单元测试。

#[cfg(test)]
mod cases {
    use super::super::cost_optimization::{
        calculate_full_replay_cost, calculate_stage_scope_savings, calculate_tier_savings,
        estimate_artifact_reuse_savings, ArtifactReuse, SampleTier, Stage, TokenSavingsEstimate,
    };
    use super::super::types::*;
    use super::super::validation::*;
    use proptest::prelude::*;

    #[test]
    fn test_validate_sample_tier_valid() {
        assert!(validate_sample_tier("smoke").is_ok());
        assert!(validate_sample_tier("core").is_ok());
        assert!(validate_sample_tier("full").is_ok());
    }

    #[test]
    fn test_validate_sample_tier_invalid() {
        assert!(validate_sample_tier("invalid").is_err());
        assert!(validate_sample_tier("").is_err());
    }

    #[test]
    fn test_validate_stage_scope_valid() {
        assert!(validate_stage_scope(&["story_skeleton".to_string()]).is_ok());
        assert!(validate_stage_scope(&[
            "storyboard_table".to_string(),
            "storyboard_panel".to_string()
        ])
        .is_ok());
    }

    #[test]
    fn test_validate_stage_scope_empty() {
        assert!(validate_stage_scope(&[]).is_err());
    }

    #[test]
    fn test_validate_stage_scope_invalid() {
        assert!(validate_stage_scope(&["invalid_stage".to_string()]).is_err());
    }

    #[test]
    fn test_validate_stage_scope_duplicate() {
        assert!(
            validate_stage_scope(&["video_prompt".to_string(), "video_prompt".to_string()])
                .is_err()
        );
    }

    #[test]
    fn test_validate_variant_snapshot_complete() {
        let variant = CreateVariantBody {
            label: "test-variant".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "test.md".to_string(),
                    hash: "abc123".to_string(),
                    content: None,
                }],
                version_tag: Some("v1.0".to_string()),
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "video_prompt".to_string(),
                    template_content: "test template".to_string(),
                    hash: "def456".to_string(),
                }],
                version_tag: Some("v1.0".to_string()),
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec!["constraint1".to_string()],
                observation_note_limit: 100,
                auto_negative_source: Some("auto".to_string()),
                policy_version: Some("v1.0".to_string()),
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: Some(0.7),
                max_tokens: Some(2000),
                routing_rules: None,
            },
            notes: Some("Test variant".to_string()),
        };

        assert!(validate_variant_snapshot(&variant).is_ok());
    }

    #[test]
    fn test_validate_variant_snapshot_missing_skills() {
        let variant = CreateVariantBody {
            label: "test-variant".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "video_prompt".to_string(),
                    template_content: "test".to_string(),
                    hash: "abc".to_string(),
                }],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 100,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };

        let result = validate_variant_snapshot(&variant);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("skill_snapshot.skill_files"));
    }

    #[test]
    fn test_validate_variant_snapshot_missing_prompts() {
        let variant = CreateVariantBody {
            label: "test-variant".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "test.md".to_string(),
                    hash: "abc".to_string(),
                    content: None,
                }],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 100,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };

        let result = validate_variant_snapshot(&variant);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("prompt_snapshot.templates"));
    }

    #[test]
    fn test_validate_variant_snapshot_invalid_observation_limit() {
        let variant = CreateVariantBody {
            label: "test-variant".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "test.md".to_string(),
                    hash: "abc".to_string(),
                    content: None,
                }],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "video_prompt".to_string(),
                    template_content: "test".to_string(),
                    hash: "abc".to_string(),
                }],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 0,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };

        let result = validate_variant_snapshot(&variant);
        assert!(result.is_err());
        let err_msg = result.unwrap_err().to_string();
        assert!(err_msg.contains("observation_policy_snapshot.observation_note_limit"));
    }

    #[test]
    fn test_validate_variant_snapshot_empty_label() {
        let variant = CreateVariantBody {
            label: "   ".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "test.md".to_string(),
                    hash: "abc".to_string(),
                    content: None,
                }],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "video_prompt".to_string(),
                    template_content: "test".to_string(),
                    hash: "abc".to_string(),
                }],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 1,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };

        let result = validate_variant_snapshot(&variant);
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("label"));
    }

    #[test]
    fn test_validate_variant_labels_duplicate_and_missing_baseline() {
        let variant_a = CreateVariantBody {
            label: "baseline".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "test.md".to_string(),
                    hash: "abc123".to_string(),
                    content: None,
                }],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "video_prompt".to_string(),
                    template_content: "test".to_string(),
                    hash: "abc".to_string(),
                }],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 1,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };
        let variant_b = CreateVariantBody {
            label: "baseline".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "other.md".to_string(),
                    hash: "def456".to_string(),
                    content: None,
                }],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "storyboard_panel".to_string(),
                    template_content: "other".to_string(),
                    hash: "def".to_string(),
                }],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "expanded".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(120),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 2,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4o-mini".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };

        assert!(validate_variant_labels(&[variant_a], Some("missing")).is_err());
        let variant_c = CreateVariantBody {
            label: "baseline".to_string(),
            skill_snapshot: SkillSnapshot {
                skill_files: vec![SkillFileSnapshot {
                    path: "test.md".to_string(),
                    hash: "abc123".to_string(),
                    content: None,
                }],
                version_tag: None,
            },
            prompt_snapshot: PromptSnapshot {
                templates: vec![PromptTemplateSnapshot {
                    stage: "video_prompt".to_string(),
                    template_content: "test".to_string(),
                    hash: "abc".to_string(),
                }],
                version_tag: None,
            },
            memory_budget_snapshot: MemoryBudgetSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: serde_json::json!({}),
                retention_buckets: serde_json::json!({}),
                observation_note_limit: Some(100),
                character_memory_priority: None,
            },
            observation_policy_snapshot: ObservationPolicySnapshot {
                negative_constraints: vec![],
                observation_note_limit: 1,
                auto_negative_source: None,
                policy_version: None,
            },
            model_route_snapshot: ModelRouteSnapshot {
                model_name: "gpt-4".to_string(),
                temperature: None,
                max_tokens: None,
                routing_rules: None,
            },
            notes: None,
        };
        assert!(validate_variant_labels(&[variant_c, variant_b], None).is_err());
    }

    proptest! {
        #[test]
        fn prop_variant_snapshot_with_required_payload_is_complete(
            skill_path in "[a-z]{3,8}\\.md",
            skill_hash in "[a-f0-9]{6,12}",
            prompt_hash in "[a-f0-9]{6,12}",
            observation_limit in 1i32..=500,
            max_tokens in 128i32..=4096,
        ) {
            let variant = CreateVariantBody {
                label: "candidate".to_string(),
                skill_snapshot: SkillSnapshot {
                    skill_files: vec![SkillFileSnapshot {
                        path: skill_path,
                        hash: skill_hash,
                        content: None,
                    }],
                    version_tag: Some("v-prop".to_string()),
                },
                prompt_snapshot: PromptSnapshot {
                    templates: vec![PromptTemplateSnapshot {
                        stage: "video_prompt".to_string(),
                        template_content: "template".to_string(),
                        hash: prompt_hash,
                    }],
                    version_tag: Some("p-prop".to_string()),
                },
                memory_budget_snapshot: MemoryBudgetSnapshot {
                    budget_tier: "lean".to_string(),
                    compression_rules: serde_json::json!({}),
                    retention_buckets: serde_json::json!({}),
                    observation_note_limit: Some(observation_limit),
                    character_memory_priority: None,
                },
                observation_policy_snapshot: ObservationPolicySnapshot {
                    negative_constraints: vec!["keep emotion natural".to_string()],
                    observation_note_limit: observation_limit,
                    auto_negative_source: Some("prop".to_string()),
                    policy_version: Some("v-prop".to_string()),
                },
                model_route_snapshot: ModelRouteSnapshot {
                    model_name: "gpt-4o-mini".to_string(),
                    temperature: Some(0.5),
                    max_tokens: Some(max_tokens),
                    routing_rules: None,
                },
                notes: None,
            };

            prop_assert!(validate_variant_snapshot(&variant).is_ok());
        }
    }

    // ========== 成本优化测试 ==========

    #[test]
    fn test_sample_tier_parsing() {
        assert_eq!("smoke".parse::<SampleTier>().unwrap(), SampleTier::Smoke);
        assert_eq!("core".parse::<SampleTier>().unwrap(), SampleTier::Core);
        assert_eq!("full".parse::<SampleTier>().unwrap(), SampleTier::Full);
        assert!("invalid".parse::<SampleTier>().is_err());
    }

    #[test]
    fn test_sample_tier_ratios() {
        assert_eq!(SampleTier::Smoke.sample_ratio(), 0.05);
        assert_eq!(SampleTier::Core.sample_ratio(), 0.20);
        assert_eq!(SampleTier::Full.sample_ratio(), 1.0);
    }

    #[test]
    fn test_sample_tier_suggested_counts() {
        assert_eq!(SampleTier::Smoke.suggested_sample_count(), 5);
        assert_eq!(SampleTier::Core.suggested_sample_count(), 20);
        assert_eq!(SampleTier::Full.suggested_sample_count(), 100);
    }

    #[test]
    fn test_stage_parsing() {
        assert_eq!(
            "story_skeleton".parse::<Stage>().unwrap(),
            Stage::StorySkeleton
        );
        assert_eq!("video_prompt".parse::<Stage>().unwrap(), Stage::VideoPrompt);
        assert!("invalid_stage".parse::<Stage>().is_err());
    }

    #[test]
    fn test_stage_order() {
        assert_eq!(Stage::StorySkeleton.order_index(), 0);
        assert_eq!(Stage::AdaptationStrategy.order_index(), 1);
        assert_eq!(Stage::VideoPrompt.order_index(), 5);
    }

    #[test]
    fn test_stage_token_costs() {
        assert!(
            Stage::VideoPrompt.estimated_token_cost() > Stage::StorySkeleton.estimated_token_cost()
        );
        assert!(
            Stage::StoryboardPanel.estimated_token_cost()
                > Stage::StoryboardTable.estimated_token_cost()
        );
    }

    #[test]
    fn test_calculate_tier_savings() {
        let stages = vec![Stage::StoryboardTable, Stage::VideoPrompt];
        let total_samples = 100;

        let smoke_savings = calculate_tier_savings(&SampleTier::Smoke, total_samples, &stages);
        let core_savings = calculate_tier_savings(&SampleTier::Core, total_samples, &stages);
        let full_savings = calculate_tier_savings(&SampleTier::Full, total_samples, &stages);

        // Smoke 应该比 Core 节省更多
        assert!(smoke_savings > core_savings);
        // Full 不应该有节省
        assert_eq!(full_savings, 0);
        // 所有节省都应该是非负数
        assert!(smoke_savings > 0);
        assert!(core_savings > 0);
    }

    #[test]
    fn test_calculate_stage_scope_savings() {
        let selected_stages = vec![Stage::VideoPrompt];
        let sample_count = 10;

        let savings = calculate_stage_scope_savings(&selected_stages, sample_count);

        // 只选一个阶段应该比全阶段节省很多
        assert!(savings > 0);

        // 选择所有阶段应该没有节省
        let all_stages = vec![
            Stage::StorySkeleton,
            Stage::AdaptationStrategy,
            Stage::DirectorPlanning,
            Stage::StoryboardTable,
            Stage::StoryboardPanel,
            Stage::VideoPrompt,
        ];
        let no_savings = calculate_stage_scope_savings(&all_stages, sample_count);
        assert_eq!(no_savings, 0);
    }

    #[test]
    fn test_calculate_full_replay_cost() {
        let stages = vec![Stage::StoryboardTable, Stage::VideoPrompt];
        let total_samples = 10;

        let cost = calculate_full_replay_cost(total_samples, &stages);

        let expected_cost = (Stage::StoryboardTable.estimated_token_cost()
            + Stage::VideoPrompt.estimated_token_cost())
            * total_samples as u64;

        assert_eq!(cost, expected_cost);
    }

    #[test]
    fn test_estimate_artifact_reuse_savings() {
        let stages = vec![Stage::StoryboardTable];
        let sample_count = 10;
        let reuse_ratio = 0.3;

        let savings = estimate_artifact_reuse_savings(sample_count, &stages, reuse_ratio);

        let total_cost = Stage::StoryboardTable.estimated_token_cost() * sample_count as u64;
        let expected_savings = (total_cost as f64 * reuse_ratio) as u64;

        assert_eq!(savings, expected_savings);
    }

    #[test]
    fn test_token_savings_estimate_calculation() {
        use uuid::Uuid;

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
    fn test_token_savings_estimate_with_reuse_details() {
        use uuid::Uuid;

        let mut estimate = TokenSavingsEstimate::new(Uuid::new_v4(), Uuid::new_v4());

        let reuse1 = ArtifactReuse {
            benchmark_case_id: Uuid::new_v4(),
            stage: "storyboard_table".to_string(),
            reused: true,
            reuse_source: Some("previous_run".to_string()),
            tokens_saved: 15000,
        };

        let reuse2 = ArtifactReuse {
            benchmark_case_id: Uuid::new_v4(),
            stage: "video_prompt".to_string(),
            reused: false,
            reuse_source: None,
            tokens_saved: 0,
        };

        estimate.add_reuse_detail(reuse1);
        estimate.add_reuse_detail(reuse2);
        estimate.update_total_savings();

        assert_eq!(estimate.artifact_reuse_savings, 15000);
        assert_eq!(estimate.reuse_details.len(), 2);
    }

    #[test]
    fn test_cost_optimization_config_default() {
        let config = super::super::cost_optimization::CostOptimizationConfig::default();

        assert!(config.enable_artifact_reuse);
        assert!(config.enable_snapshot_reuse);
        assert_eq!(config.max_reuse_window_hours, 72);
    }
}
