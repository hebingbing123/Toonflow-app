//! 实验运行与变体快照单元测试。

#[cfg(test)]
mod tests {
    use super::super::types::*;
    use super::super::validation::*;

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
}
