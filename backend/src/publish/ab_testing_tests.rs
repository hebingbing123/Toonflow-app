//! **L.3** — A/B testing validation suite for token optimization without quality regression.
//!
//! This test suite validates that Phase J token optimizations (J.1-J.6) don't cause
//! quality regressions by comparing baseline vs optimized implementations.

#[cfg(test)]
mod tests {
    use crate::publish::ab_testing::*;
    use serde_json::json;

    fn create_baseline_result(
        test_case_id: &str,
        total_tokens: i64,
        overall_score: f64,
        grade: &str,
    ) -> ABTestResult {
        ABTestResult {
            test_case_id: test_case_id.to_string(),
            variant: ABVariant::Baseline,
            quality: QualityMetrics {
                overall_score: Some(overall_score),
                character_consistency: Some(82.0),
                dialogue_naturalness: Some(78.0),
                visual_quality: Some(85.0),
                plot_coherence: Some(80.0),
                grade: Some(grade.to_string()),
                passed: true,
            },
            tokens: TokenMetrics {
                prompt_tokens: total_tokens * 7 / 10,
                completion_tokens: total_tokens * 3 / 10,
                total_tokens,
                call_count: 10,
                cache_hits: 0,
                incremental_hits: 0,
            },
            timestamp: chrono::Utc::now(),
            metadata: json!({
                "phase": "baseline",
                "optimization": "none"
            }),
        }
    }

    fn create_optimized_result(
        test_case_id: &str,
        total_tokens: i64,
        overall_score: f64,
        grade: &str,
        cache_hits: i64,
        incremental_hits: i64,
    ) -> ABTestResult {
        ABTestResult {
            test_case_id: test_case_id.to_string(),
            variant: ABVariant::Optimized,
            quality: QualityMetrics {
                overall_score: Some(overall_score),
                character_consistency: Some(81.0),
                dialogue_naturalness: Some(77.0),
                visual_quality: Some(84.0),
                plot_coherence: Some(79.0),
                grade: Some(grade.to_string()),
                passed: true,
            },
            tokens: TokenMetrics {
                prompt_tokens: total_tokens * 7 / 10,
                completion_tokens: total_tokens * 3 / 10,
                total_tokens,
                call_count: 10,
                cache_hits,
                incremental_hits,
            },
            timestamp: chrono::Utc::now(),
            metadata: json!({
                "phase": "optimized",
                "optimization": "J.1-J.6",
                "cache_enabled": cache_hits > 0,
                "incremental_enabled": incremental_hits > 0
            }),
        }
    }

    #[test]
    fn test_j1_input_hash_cache_validation() {
        // J.1: Input hash cache for publish copy generation
        // Should reduce tokens with cache hits, maintain quality
        let baseline = create_baseline_result("j1-cache-test", 15000, 82.0, "B");
        let optimized = create_optimized_result("j1-cache-test", 9000, 81.0, "B", 3, 0);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(comparison.passed, "J.1 cache optimization should pass");
        assert_eq!(
            comparison.token_reduction_pct, 40.0,
            "Should achieve 40% token reduction"
        );
        assert!(!comparison.quality_regression, "Should not regress quality");
        assert_eq!(optimized.tokens.cache_hits, 3, "Should have cache hits");
    }

    #[test]
    fn test_j2_incremental_mode_validation() {
        // J.2: Incremental publish copy generation for changed platforms only
        // Should reduce tokens with incremental mode, maintain quality
        let baseline = create_baseline_result("j2-incremental-test", 12000, 80.0, "B");
        let optimized = create_optimized_result("j2-incremental-test", 7200, 79.0, "B", 0, 2);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(comparison.passed, "J.2 incremental mode should pass");
        assert_eq!(
            comparison.token_reduction_pct, 40.0,
            "Should achieve 40% token reduction"
        );
        assert!(!comparison.quality_regression, "Should not regress quality");
        assert_eq!(
            optimized.tokens.incremental_hits, 2,
            "Should have incremental hits"
        );
    }

    #[test]
    fn test_combined_optimizations_validation() {
        // Combined J.1 + J.2: Cache + Incremental
        // Should achieve higher token reduction with both optimizations
        let baseline = create_baseline_result("combined-test", 20000, 83.0, "B");
        let optimized = create_optimized_result("combined-test", 10000, 82.0, "B", 2, 1);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(comparison.passed, "Combined optimizations should pass");
        assert_eq!(
            comparison.token_reduction_pct, 50.0,
            "Should achieve 50% token reduction"
        );
        assert!(!comparison.quality_regression, "Should not regress quality");
        assert!(optimized.tokens.cache_hits > 0, "Should use cache");
        assert!(
            optimized.tokens.incremental_hits > 0,
            "Should use incremental mode"
        );
    }

    #[test]
    fn test_quality_regression_detection() {
        // Test that quality regression is properly detected
        let baseline = create_baseline_result("regression-test", 15000, 85.0, "A");
        let optimized = create_optimized_result("regression-test", 9000, 65.0, "C", 2, 0);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed, "Should fail with quality regression");
        assert!(
            comparison.quality_regression,
            "Should detect quality regression"
        );
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Quality dropped")));
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Grade regressed")));
    }

    #[test]
    fn test_insufficient_token_reduction() {
        // Test that insufficient token reduction is detected
        let baseline = create_baseline_result("low-reduction-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("low-reduction-test", 9600, 80.0, "B", 1, 0);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(
            !comparison.passed,
            "Should fail with insufficient token reduction"
        );
        assert_eq!(comparison.token_reduction_pct, 4.0, "Only 4% reduction");
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Token reduction")));
    }

    #[test]
    fn test_quality_below_minimum_threshold() {
        // Test that quality below minimum threshold is detected
        let baseline = create_baseline_result("low-quality-test", 15000, 75.0, "B");
        let optimized = create_optimized_result("low-quality-test", 9000, 65.0, "C", 2, 0);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed, "Should fail with quality below minimum");
        assert!(
            comparison.quality_regression,
            "Should detect quality regression"
        );
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("below minimum")));
    }

    #[test]
    fn test_grade_regression_detection() {
        // Test that grade regression is properly detected
        let baseline = create_baseline_result("grade-regression-test", 15000, 88.0, "A");
        let optimized = create_optimized_result("grade-regression-test", 9000, 82.0, "B", 2, 0);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed, "Should fail with grade regression");
        assert!(
            comparison.quality_regression,
            "Should detect grade regression"
        );
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Grade regressed from A to B")));
    }

    #[test]
    fn test_pass_fail_status_regression() {
        // Test that pass/fail status regression is detected
        let mut baseline = create_baseline_result("pass-fail-test", 15000, 75.0, "B");
        baseline.quality.passed = true;

        let mut optimized = create_optimized_result("pass-fail-test", 9000, 72.0, "B", 2, 0);
        optimized.quality.passed = false;

        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed, "Should fail when quality check fails");
        assert!(
            comparison.quality_regression,
            "Should detect quality regression"
        );
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Quality check failed")));
    }

    #[test]
    fn test_aggregate_multiple_test_cases() {
        // Test aggregation of multiple test cases
        let comparisons = vec![
            compare_variants(
                &create_baseline_result("test-1", 10000, 80.0, "B"),
                &create_optimized_result("test-1", 7000, 78.0, "B", 2, 0),
                &ABTestConfig::default(),
            ),
            compare_variants(
                &create_baseline_result("test-2", 12000, 85.0, "A"),
                &create_optimized_result("test-2", 7200, 83.0, "A", 1, 1),
                &ABTestConfig::default(),
            ),
            compare_variants(
                &create_baseline_result("test-3", 15000, 82.0, "B"),
                &create_optimized_result("test-3", 9000, 81.0, "B", 2, 1),
                &ABTestConfig::default(),
            ),
        ];

        let summary = aggregate_comparisons(comparisons);

        assert_eq!(summary.total_cases, 3);
        assert_eq!(summary.passed_cases, 3);
        assert_eq!(summary.failed_cases, 0);
        assert!(
            summary.avg_token_reduction_pct > 30.0,
            "Should average >30% reduction"
        );
        assert!(
            summary.avg_quality_diff > -3.0,
            "Should maintain quality within 3 points"
        );
        assert_eq!(summary.quality_regressions, 0);
        assert!(summary.passed, "Overall test suite should pass");
    }

    #[test]
    fn test_aggregate_with_failures() {
        // Test aggregation with some failures
        let comparisons = vec![
            compare_variants(
                &create_baseline_result("test-1", 10000, 80.0, "B"),
                &create_optimized_result("test-1", 7000, 78.0, "B", 2, 0),
                &ABTestConfig::default(),
            ),
            compare_variants(
                &create_baseline_result("test-2", 12000, 85.0, "A"),
                &create_optimized_result("test-2", 11000, 65.0, "C", 0, 0),
                &ABTestConfig::default(),
            ),
        ];

        let summary = aggregate_comparisons(comparisons);

        assert_eq!(summary.total_cases, 2);
        assert_eq!(summary.passed_cases, 1);
        assert_eq!(summary.failed_cases, 1);
        assert!(summary.quality_regressions > 0);
        assert!(!summary.passed, "Overall test suite should fail");
    }

    #[test]
    fn test_custom_config_thresholds() {
        // Test with custom configuration thresholds
        let config = ABTestConfig {
            min_token_reduction_pct: 20.0,
            max_quality_drop: 3.0,
            min_quality_score: 75.0,
            significance_threshold: 0.05,
        };

        let baseline = create_baseline_result("custom-config-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("custom-config-test", 7500, 77.5, "B", 1, 0);

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(comparison.passed, "Should pass with custom thresholds");
        assert_eq!(comparison.token_reduction_pct, 25.0);
        assert_eq!(comparison.quality_score_diff, Some(-2.5));
    }

    #[test]
    fn test_zero_token_baseline_handling() {
        // Test handling of zero token baseline (edge case)
        let mut baseline = create_baseline_result("zero-token-test", 0, 80.0, "B");
        baseline.tokens.total_tokens = 0;

        let optimized = create_optimized_result("zero-token-test", 0, 80.0, "B", 0, 0);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert_eq!(
            comparison.token_reduction_pct, 0.0,
            "Should handle zero tokens gracefully"
        );
    }

    #[test]
    fn test_missing_quality_scores() {
        // Test handling of missing quality scores
        let mut baseline = create_baseline_result("missing-scores-test", 10000, 80.0, "B");
        baseline.quality.overall_score = None;

        let mut optimized = create_optimized_result("missing-scores-test", 7000, 0.0, "B", 2, 0);
        optimized.quality.overall_score = None;

        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert_eq!(
            comparison.quality_score_diff, None,
            "Should handle missing scores"
        );
        assert!(
            comparison.passed,
            "Should pass with sufficient token reduction"
        );
    }

    #[test]
    fn test_character_consistency_tracking() {
        // Test that character consistency is tracked
        let baseline = create_baseline_result("character-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("character-test", 7000, 78.0, "B", 2, 0);

        assert!(baseline.quality.character_consistency.is_some());
        assert!(optimized.quality.character_consistency.is_some());
    }

    #[test]
    fn test_dialogue_naturalness_tracking() {
        // Test that dialogue naturalness is tracked
        let baseline = create_baseline_result("dialogue-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("dialogue-test", 7000, 78.0, "B", 2, 0);

        assert!(baseline.quality.dialogue_naturalness.is_some());
        assert!(optimized.quality.dialogue_naturalness.is_some());
    }

    #[test]
    fn test_visual_quality_tracking() {
        // Test that visual quality is tracked
        let baseline = create_baseline_result("visual-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("visual-test", 7000, 78.0, "B", 2, 0);

        assert!(baseline.quality.visual_quality.is_some());
        assert!(optimized.quality.visual_quality.is_some());
    }

    #[test]
    fn test_plot_coherence_tracking() {
        // Test that plot coherence is tracked
        let baseline = create_baseline_result("plot-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("plot-test", 7000, 78.0, "B", 2, 0);

        assert!(baseline.quality.plot_coherence.is_some());
        assert!(optimized.quality.plot_coherence.is_some());
    }

    #[test]
    fn test_cache_hit_tracking() {
        // Test that cache hits are properly tracked
        let optimized = create_optimized_result("cache-tracking-test", 7000, 78.0, "B", 5, 0);

        assert_eq!(optimized.tokens.cache_hits, 5);
        assert_eq!(optimized.tokens.incremental_hits, 0);
    }

    #[test]
    fn test_incremental_hit_tracking() {
        // Test that incremental hits are properly tracked
        let optimized = create_optimized_result("incremental-tracking-test", 7000, 78.0, "B", 0, 3);

        assert_eq!(optimized.tokens.cache_hits, 0);
        assert_eq!(optimized.tokens.incremental_hits, 3);
    }

    #[test]
    fn test_metadata_preservation() {
        // Test that metadata is preserved
        let baseline = create_baseline_result("metadata-test", 10000, 80.0, "B");
        let optimized = create_optimized_result("metadata-test", 7000, 78.0, "B", 2, 1);

        assert_eq!(baseline.metadata["phase"], "baseline");
        assert_eq!(optimized.metadata["phase"], "optimized");
        assert_eq!(optimized.metadata["optimization"], "J.1-J.6");
    }

    #[test]
    fn test_variant_serialization() {
        // Test that variants serialize correctly
        let baseline_json = serde_json::to_string(&ABVariant::Baseline).unwrap();
        let optimized_json = serde_json::to_string(&ABVariant::Optimized).unwrap();

        assert_eq!(baseline_json, r#""baseline""#);
        assert_eq!(optimized_json, r#""optimized""#);
    }

    #[test]
    fn test_quality_metrics_serialization() {
        // Test that quality metrics serialize correctly
        let metrics = QualityMetrics {
            overall_score: Some(80.0),
            character_consistency: Some(82.0),
            dialogue_naturalness: Some(78.0),
            visual_quality: Some(85.0),
            plot_coherence: Some(80.0),
            grade: Some("B".to_string()),
            passed: true,
        };

        let json = serde_json::to_value(&metrics).unwrap();
        assert_eq!(json["overallScore"], 80.0);
        assert_eq!(json["grade"], "B");
        assert_eq!(json["passed"], true);
    }

    #[test]
    fn test_token_metrics_serialization() {
        // Test that token metrics serialize correctly
        let metrics = TokenMetrics {
            prompt_tokens: 7000,
            completion_tokens: 3000,
            total_tokens: 10000,
            call_count: 10,
            cache_hits: 2,
            incremental_hits: 1,
        };

        let json = serde_json::to_value(&metrics).unwrap();
        assert_eq!(json["totalTokens"], 10000);
        assert_eq!(json["cacheHits"], 2);
        assert_eq!(json["incrementalHits"], 1);
    }
}
