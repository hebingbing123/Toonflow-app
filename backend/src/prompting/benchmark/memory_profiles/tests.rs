//! 记忆预算档与 ROI 证据单元测试。

#[cfg(test)]
mod cases {
    use super::super::types::*;

    #[test]
    fn memory_budget_profile_snapshot_serialization() {
        let profile = MemoryBudgetProfileSnapshot {
            budget_tier: "lean".to_string(),
            compression_rules: CompressionRules {
                compact_silent_low_risk: true,
                continuity_note_max_chars: Some(120),
                memory_note_max_chars: Some(80),
                style_fragment_retention: Some("best_only".to_string()),
            },
            retention_buckets: RetentionBuckets {
                project_scope_retention: Some(2),
                script_scope_retention: Some(3),
                scene_scope_retention: Some(1),
                prioritize_emotional_memory: false,
                prioritize_dialogue_performance: false,
            },
            observation_note_limit: Some(100),
            character_memory_priority: None,
            profile_version: Some("v1".to_string()),
        };

        let json = serde_json::to_string(&profile).expect("序列化失败");
        assert!(json.contains("lean"));
        assert!(json.contains("budgetTier"));

        let deserialized: MemoryBudgetProfileSnapshot =
            serde_json::from_str(&json).expect("反序列化失败");
        assert_eq!(deserialized.budget_tier, "lean");
        assert_eq!(
            deserialized.compression_rules.continuity_note_max_chars,
            Some(120)
        );
    }

    #[test]
    fn roi_conclusion_type_serialization() {
        let conclusion_types = vec![
            RoiConclusionType::HighCostLowBenefit,
            RoiConclusionType::HighCostHighValueGuard,
            RoiConclusionType::LowCostHighBenefit,
            RoiConclusionType::Balanced,
            RoiConclusionType::QualityRegression,
            RoiConclusionType::InsufficientData,
        ];

        for ct in conclusion_types {
            let json = serde_json::to_string(&ct).expect("序列化失败");
            let deserialized: RoiConclusionType =
                serde_json::from_str(&json).expect("反序列化失败");
            assert_eq!(
                std::mem::discriminant(&ct),
                std::mem::discriminant(&deserialized)
            );
        }
    }

    #[test]
    fn variant_cost_delta_calculation() {
        let delta = VariantCostDelta {
            total_tokens: 15000,
            token_delta: 3000,
            token_delta_percent: 25.0,
            estimated_cost_usd: 0.15,
            cost_delta_usd: 0.03,
        };

        assert_eq!(delta.total_tokens, 15000);
        assert_eq!(delta.token_delta, 3000);
        assert!((delta.token_delta_percent - 25.0).abs() < 0.01);
    }

    #[test]
    fn quality_metrics_delta_tracking() {
        let metrics = QualityMetrics {
            avg_quality_score: 8.5,
            quality_score_delta: 0.5,
            pass_rate: 0.85,
            pass_rate_delta: 0.05,
            rework_rate: 0.10,
            rework_rate_delta: -0.02,
            bad_case_recurrence_count: 2,
            bad_case_recurrence_delta: -3,
        };

        assert!(metrics.quality_score_delta > 0.0);
        assert!(metrics.pass_rate_delta > 0.0);
        assert!(metrics.rework_rate_delta < 0.0);
        assert!(metrics.bad_case_recurrence_delta < 0);
    }

    #[test]
    fn sample_roi_detail_structure() {
        let detail = SampleRoiDetail {
            benchmark_case_id: uuid::Uuid::new_v4(),
            case_type: "bad_case".to_string(),
            weight: 3,
            tokens_used: 5000,
            quality_score: 7.5,
            passed: true,
            requires_rework: false,
            issue_tags: vec!["人物一致性".to_string(), "情绪表达".to_string()],
        };

        assert_eq!(detail.case_type, "bad_case");
        assert_eq!(detail.weight, 3);
        assert_eq!(detail.issue_tags.len(), 2);
    }

    #[test]
    fn stage_roi_breakdown_aggregation() {
        let breakdown = StageRoiBreakdown {
            stage: "video_prompt".to_string(),
            tokens_used: 8000,
            token_delta: 1500,
            avg_quality_score: 8.2,
            quality_score_delta: 0.3,
            sample_count: 10,
        };

        assert_eq!(breakdown.stage, "video_prompt");
        assert!(breakdown.token_delta > 0);
        assert!(breakdown.quality_score_delta > 0.0);
    }

    #[test]
    fn compression_rules_defaults() {
        let rules = CompressionRules {
            compact_silent_low_risk: true,
            continuity_note_max_chars: Some(120),
            memory_note_max_chars: Some(80),
            style_fragment_retention: Some("best_only".to_string()),
        };

        assert!(rules.compact_silent_low_risk);
        assert_eq!(rules.continuity_note_max_chars, Some(120));
    }

    #[test]
    fn retention_buckets_priority_flags() {
        let buckets = RetentionBuckets {
            project_scope_retention: Some(5),
            script_scope_retention: Some(8),
            scene_scope_retention: Some(3),
            prioritize_emotional_memory: true,
            prioritize_dialogue_performance: true,
        };

        assert!(buckets.prioritize_emotional_memory);
        assert!(buckets.prioritize_dialogue_performance);
        assert_eq!(buckets.script_scope_retention, Some(8));
    }

    #[test]
    fn roi_evidence_summary_structure() {
        let summary = RoiEvidenceSummary {
            experiment_run_id: uuid::Uuid::new_v4(),
            variant_comparisons: vec![],
            sample_set_stats: SampleSetStats {
                total_samples: 20,
                golden_count: 8,
                bad_case_count: 7,
                regression_guard_count: 5,
                stages_covered: vec!["video_prompt".to_string(), "storyboard_table".to_string()],
            },
            overall_conclusion: RoiConclusion {
                recommended_variant_id: None,
                conclusion_type: RoiConclusionType::InsufficientData,
                rationale: "测试数据".to_string(),
                recommend_promotion: false,
                promotion_restrictions: None,
            },
        };

        assert_eq!(summary.sample_set_stats.total_samples, 20);
        assert_eq!(summary.sample_set_stats.golden_count, 8);
        assert_eq!(summary.sample_set_stats.stages_covered.len(), 2);
    }

    #[test]
    fn memory_profiles_response_pagination() {
        let response = MemoryProfilesResponse {
            profiles: vec![MemoryBudgetProfileSnapshot {
                budget_tier: "lean".to_string(),
                compression_rules: CompressionRules {
                    compact_silent_low_risk: true,
                    continuity_note_max_chars: Some(120),
                    memory_note_max_chars: Some(80),
                    style_fragment_retention: Some("best_only".to_string()),
                },
                retention_buckets: RetentionBuckets {
                    project_scope_retention: Some(2),
                    script_scope_retention: Some(3),
                    scene_scope_retention: Some(1),
                    prioritize_emotional_memory: false,
                    prioritize_dialogue_performance: false,
                },
                observation_note_limit: Some(100),
                character_memory_priority: None,
                profile_version: Some("v1".to_string()),
            }],
            total: 1,
        };

        assert_eq!(response.total, 1);
        assert_eq!(response.profiles.len(), 1);
        assert_eq!(response.profiles[0].budget_tier, "lean");
    }
}
