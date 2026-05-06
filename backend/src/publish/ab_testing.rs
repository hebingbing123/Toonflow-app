//! **L.3** — A/B testing framework for validating token optimizations without quality regression.
//!
//! This module provides infrastructure to compare token-optimized implementations
//! against baseline implementations to ensure token savings don't compromise quality.

use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::collections::HashMap;
use uuid::Uuid;

use crate::error::ApiError;

/// Variant identifier for A/B testing
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ABVariant {
    /// Baseline implementation (pre-optimization)
    Baseline,
    /// Token-optimized implementation (Phase J optimizations)
    Optimized,
}

impl ABVariant {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Baseline => "baseline",
            Self::Optimized => "optimized",
        }
    }
}

/// Quality metrics for A/B comparison
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct QualityMetrics {
    /// Overall quality score (0-100)
    pub overall_score: Option<f64>,
    /// Character consistency score (0-100)
    pub character_consistency: Option<f64>,
    /// Dialogue naturalness score (0-100)
    pub dialogue_naturalness: Option<f64>,
    /// Visual quality score (0-100)
    pub visual_quality: Option<f64>,
    /// Plot coherence score (0-100)
    pub plot_coherence: Option<f64>,
    /// Quality grade (A, B, C, D)
    pub grade: Option<String>,
    /// Whether quality check passed
    pub passed: bool,
}

/// Token usage metrics for A/B comparison
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TokenMetrics {
    /// Total prompt tokens
    pub prompt_tokens: i64,
    /// Total completion tokens
    pub completion_tokens: i64,
    /// Total tokens (prompt + completion)
    pub total_tokens: i64,
    /// Number of LLM calls made
    pub call_count: i64,
    /// Cache hit count (for optimized variant)
    pub cache_hits: i64,
    /// Incremental mode usage count (for optimized variant)
    pub incremental_hits: i64,
}

/// A/B test result for a single test case
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ABTestResult {
    /// Test case identifier
    pub test_case_id: String,
    /// Variant being tested
    pub variant: ABVariant,
    /// Quality metrics
    pub quality: QualityMetrics,
    /// Token usage metrics
    pub tokens: TokenMetrics,
    /// Test execution timestamp
    pub timestamp: chrono::DateTime<chrono::Utc>,
    /// Additional metadata
    pub metadata: serde_json::Value,
}

/// Comparison result between baseline and optimized variants
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ABComparison {
    /// Test case identifier
    pub test_case_id: String,
    /// Baseline result
    pub baseline: ABTestResult,
    /// Optimized result
    pub optimized: ABTestResult,
    /// Quality regression detected
    pub quality_regression: bool,
    /// Token reduction percentage (positive = savings)
    pub token_reduction_pct: f64,
    /// Quality score difference (optimized - baseline)
    pub quality_score_diff: Option<f64>,
    /// Statistical significance (p-value)
    pub p_value: Option<f64>,
    /// Pass/fail verdict
    pub passed: bool,
    /// Failure reasons (if any)
    pub failure_reasons: Vec<String>,
}

/// A/B test configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ABTestConfig {
    /// Minimum token reduction required (percentage)
    pub min_token_reduction_pct: f64,
    /// Maximum allowed quality score drop (absolute points)
    pub max_quality_drop: f64,
    /// Minimum quality score to pass
    pub min_quality_score: f64,
    /// Statistical significance threshold (p-value)
    pub significance_threshold: f64,
}

impl Default for ABTestConfig {
    fn default() -> Self {
        Self {
            min_token_reduction_pct: 10.0, // Expect at least 10% token reduction
            max_quality_drop: 5.0,         // Allow max 5 point quality drop
            min_quality_score: 70.0,       // Minimum acceptable quality score
            significance_threshold: 0.05,  // Standard p-value threshold
        }
    }
}

/// Compare baseline and optimized variants
pub fn compare_variants(
    baseline: &ABTestResult,
    optimized: &ABTestResult,
    config: &ABTestConfig,
) -> ABComparison {
    let mut failure_reasons = Vec::new();

    // Calculate token reduction
    let token_reduction_pct = if baseline.tokens.total_tokens > 0 {
        ((baseline.tokens.total_tokens - optimized.tokens.total_tokens) as f64
            / baseline.tokens.total_tokens as f64)
            * 100.0
    } else {
        0.0
    };

    // Check token reduction meets minimum
    if token_reduction_pct < config.min_token_reduction_pct {
        failure_reasons.push(format!(
            "Token reduction {:.1}% below minimum {:.1}%",
            token_reduction_pct, config.min_token_reduction_pct
        ));
    }

    // Calculate quality score difference
    let quality_score_diff = match (
        baseline.quality.overall_score,
        optimized.quality.overall_score,
    ) {
        (Some(b), Some(o)) => Some(o - b),
        _ => None,
    };

    // Check for quality regression
    let mut quality_regression = false;
    if let Some(diff) = quality_score_diff {
        if diff < -config.max_quality_drop {
            quality_regression = true;
            failure_reasons.push(format!(
                "Quality dropped by {:.1} points (max allowed: {:.1})",
                -diff, config.max_quality_drop
            ));
        }
    }

    // Check minimum quality score
    if let Some(score) = optimized.quality.overall_score {
        if score < config.min_quality_score {
            quality_regression = true;
            failure_reasons.push(format!(
                "Quality score {:.1} below minimum {:.1}",
                score, config.min_quality_score
            ));
        }
    }

    // Check grade regression (A > B > C > D)
    if let (Some(baseline_grade), Some(optimized_grade)) =
        (&baseline.quality.grade, &optimized.quality.grade)
    {
        let grade_order = |g: &str| match g {
            "A" => 4,
            "B" => 3,
            "C" => 2,
            "D" => 1,
            _ => 0,
        };
        if grade_order(optimized_grade) < grade_order(baseline_grade) {
            quality_regression = true;
            failure_reasons.push(format!(
                "Grade regressed from {} to {}",
                baseline_grade, optimized_grade
            ));
        }
    }

    // Check pass/fail status
    if !optimized.quality.passed && baseline.quality.passed {
        quality_regression = true;
        failure_reasons.push("Quality check failed (baseline passed)".to_string());
    }

    // TODO: Calculate statistical significance (requires multiple samples)
    let p_value = None;

    let passed = failure_reasons.is_empty();

    ABComparison {
        test_case_id: baseline.test_case_id.clone(),
        baseline: baseline.clone(),
        optimized: optimized.clone(),
        quality_regression,
        token_reduction_pct,
        quality_score_diff,
        p_value,
        passed,
        failure_reasons,
    }
}

/// Fetch quality metrics from database for a given job
pub async fn fetch_quality_metrics(
    pool: &PgPool,
    job_id: Uuid,
) -> Result<QualityMetrics, ApiError> {
    let row = sqlx::query_as::<
        _,
        (
            Option<i32>,
            Option<i32>,
            Option<i32>,
            Option<i32>,
            Option<i32>,
            Option<String>,
            Option<bool>,
        ),
    >(
        r#"
        SELECT
            overall_score,
            character_consistency,
            dialogue_naturalness,
            visual_quality,
            plot_coherence,
            grade,
            passed
        FROM app_quality_reviews
        WHERE job_id = $1
        ORDER BY created_at DESC
        LIMIT 1
        "#,
    )
    .bind(job_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    match row {
        Some((
            overall_score,
            character_consistency,
            dialogue_naturalness,
            visual_quality,
            plot_coherence,
            grade,
            passed,
        )) => Ok(QualityMetrics {
            overall_score: overall_score.map(|s| s as f64),
            character_consistency: character_consistency.map(|s| s as f64),
            dialogue_naturalness: dialogue_naturalness.map(|s| s as f64),
            visual_quality: visual_quality.map(|s| s as f64),
            plot_coherence: plot_coherence.map(|s| s as f64),
            grade,
            passed: passed.unwrap_or(false),
        }),
        None => Ok(QualityMetrics {
            overall_score: None,
            character_consistency: None,
            dialogue_naturalness: None,
            visual_quality: None,
            plot_coherence: None,
            grade: None,
            passed: false,
        }),
    }
}

/// Fetch token usage metrics from database for a given job
pub async fn fetch_token_metrics(pool: &PgPool, job_id: Uuid) -> Result<TokenMetrics, ApiError> {
    let row = sqlx::query_as::<_, (i64, i64, i64, i64, i64, i64)>(
        r#"
        SELECT
            COALESCE(SUM(prompt_tokens), 0) as prompt_tokens,
            COALESCE(SUM(completion_tokens), 0) as completion_tokens,
            COALESCE(SUM(total_tokens), 0) as total_tokens,
            COUNT(*) as call_count,
            COALESCE(SUM(CASE WHEN meta->>'source' = 'cache' THEN 1 ELSE 0 END), 0) as cache_hits,
            COALESCE(SUM(CASE WHEN meta->>'source' = 'incremental' THEN 1 ELSE 0 END), 0) as incremental_hits
        FROM app_llm_usage_log
        WHERE job_id = $1
        "#
    )
    .bind(job_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(TokenMetrics {
        prompt_tokens: row.0,
        completion_tokens: row.1,
        total_tokens: row.2,
        call_count: row.3,
        cache_hits: row.4,
        incremental_hits: row.5,
    })
}

/// Aggregate comparison results across multiple test cases
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ABTestSummary {
    /// Total test cases
    pub total_cases: usize,
    /// Passed test cases
    pub passed_cases: usize,
    /// Failed test cases
    pub failed_cases: usize,
    /// Average token reduction percentage
    pub avg_token_reduction_pct: f64,
    /// Average quality score difference
    pub avg_quality_diff: f64,
    /// Quality regression count
    pub quality_regressions: usize,
    /// Individual comparisons
    pub comparisons: Vec<ABComparison>,
    /// Overall pass/fail
    pub passed: bool,
}

/// Aggregate multiple A/B test comparisons into a summary
pub fn aggregate_comparisons(comparisons: Vec<ABComparison>) -> ABTestSummary {
    let total_cases = comparisons.len();
    let passed_cases = comparisons.iter().filter(|c| c.passed).count();
    let failed_cases = total_cases - passed_cases;

    let avg_token_reduction_pct = if total_cases > 0 {
        comparisons
            .iter()
            .map(|c| c.token_reduction_pct)
            .sum::<f64>()
            / total_cases as f64
    } else {
        0.0
    };

    let quality_diffs: Vec<f64> = comparisons
        .iter()
        .filter_map(|c| c.quality_score_diff)
        .collect();
    let avg_quality_diff = if !quality_diffs.is_empty() {
        quality_diffs.iter().sum::<f64>() / quality_diffs.len() as f64
    } else {
        0.0
    };

    let quality_regressions = comparisons.iter().filter(|c| c.quality_regression).count();

    let passed = failed_cases == 0;

    ABTestSummary {
        total_cases,
        passed_cases,
        failed_cases,
        avg_token_reduction_pct,
        avg_quality_diff,
        quality_regressions,
        comparisons,
        passed,
    }
}

/// Store A/B test result in database for audit trail
pub async fn store_ab_test_result(pool: &PgPool, result: &ABTestResult) -> Result<Uuid, ApiError> {
    let id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO app_ab_test_results (
            id, test_case_id, variant, quality_metrics, token_metrics, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        "#,
    )
    .bind(id)
    .bind(&result.test_case_id)
    .bind(result.variant.as_str())
    .bind(serde_json::to_value(&result.quality).unwrap())
    .bind(serde_json::to_value(&result.tokens).unwrap())
    .bind(&result.metadata)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(id)
}

/// Fetch A/B test results for a test case
pub async fn fetch_ab_test_results(
    pool: &PgPool,
    test_case_id: &str,
) -> Result<HashMap<ABVariant, ABTestResult>, ApiError> {
    let rows = sqlx::query_as::<
        _,
        (
            String,
            String,
            serde_json::Value,
            serde_json::Value,
            serde_json::Value,
            chrono::DateTime<chrono::Utc>,
        ),
    >(
        r#"
        SELECT
            test_case_id,
            variant,
            quality_metrics,
            token_metrics,
            metadata,
            created_at
        FROM app_ab_test_results
        WHERE test_case_id = $1
        ORDER BY created_at DESC
        "#,
    )
    .bind(test_case_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut results = HashMap::new();
    for row in rows {
        let variant = match row.1.as_str() {
            "baseline" => ABVariant::Baseline,
            "optimized" => ABVariant::Optimized,
            _ => continue,
        };

        let quality: QualityMetrics = serde_json::from_value(row.2).map_err(|e| {
            ApiError::DatabaseError(format!("Failed to parse quality metrics: {}", e))
        })?;
        let tokens: TokenMetrics = serde_json::from_value(row.3).map_err(|e| {
            ApiError::DatabaseError(format!("Failed to parse token metrics: {}", e))
        })?;

        let result = ABTestResult {
            test_case_id: row.0,
            variant,
            quality,
            tokens,
            timestamp: row.5,
            metadata: row.4,
        };

        results.insert(variant, result);
    }

    Ok(results)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn create_test_result(
        variant: ABVariant,
        total_tokens: i64,
        overall_score: f64,
        grade: &str,
        passed: bool,
    ) -> ABTestResult {
        ABTestResult {
            test_case_id: "test-001".to_string(),
            variant,
            quality: QualityMetrics {
                overall_score: Some(overall_score),
                character_consistency: Some(80.0),
                dialogue_naturalness: Some(75.0),
                visual_quality: Some(85.0),
                plot_coherence: Some(78.0),
                grade: Some(grade.to_string()),
                passed,
            },
            tokens: TokenMetrics {
                prompt_tokens: total_tokens * 7 / 10,
                completion_tokens: total_tokens * 3 / 10,
                total_tokens,
                call_count: 5,
                cache_hits: if variant == ABVariant::Optimized {
                    2
                } else {
                    0
                },
                incremental_hits: if variant == ABVariant::Optimized {
                    1
                } else {
                    0
                },
            },
            timestamp: chrono::Utc::now(),
            metadata: json!({}),
        }
    }

    #[test]
    fn test_compare_variants_success() {
        let baseline = create_test_result(ABVariant::Baseline, 10000, 80.0, "B", true);
        let optimized = create_test_result(ABVariant::Optimized, 7000, 78.0, "B", true);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(
            comparison.passed,
            "Should pass with 30% token reduction and 2 point quality drop"
        );
        assert_eq!(comparison.token_reduction_pct, 30.0);
        assert_eq!(comparison.quality_score_diff, Some(-2.0));
        assert!(!comparison.quality_regression);
    }

    #[test]
    fn test_compare_variants_quality_regression() {
        let baseline = create_test_result(ABVariant::Baseline, 10000, 80.0, "B", true);
        let optimized = create_test_result(ABVariant::Optimized, 7000, 65.0, "C", true);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed, "Should fail with 15 point quality drop");
        assert!(comparison.quality_regression);
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
    fn test_compare_variants_insufficient_token_reduction() {
        let baseline = create_test_result(ABVariant::Baseline, 10000, 80.0, "B", true);
        let optimized = create_test_result(ABVariant::Optimized, 9500, 80.0, "B", true);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(
            !comparison.passed,
            "Should fail with only 5% token reduction"
        );
        assert_eq!(comparison.token_reduction_pct, 5.0);
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Token reduction")));
    }

    #[test]
    fn test_compare_variants_quality_below_minimum() {
        let baseline = create_test_result(ABVariant::Baseline, 10000, 75.0, "B", true);
        let optimized = create_test_result(ABVariant::Optimized, 7000, 65.0, "C", true);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed);
        assert!(comparison.quality_regression);
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("below minimum")));
    }

    #[test]
    fn test_compare_variants_pass_fail_regression() {
        let baseline = create_test_result(ABVariant::Baseline, 10000, 75.0, "B", true);
        let optimized = create_test_result(ABVariant::Optimized, 7000, 72.0, "B", false);
        let config = ABTestConfig::default();

        let comparison = compare_variants(&baseline, &optimized, &config);

        assert!(!comparison.passed);
        assert!(comparison.quality_regression);
        assert!(comparison
            .failure_reasons
            .iter()
            .any(|r| r.contains("Quality check failed")));
    }

    #[test]
    fn test_aggregate_comparisons() {
        let comparisons = vec![
            ABComparison {
                test_case_id: "test-001".to_string(),
                baseline: create_test_result(ABVariant::Baseline, 10000, 80.0, "B", true),
                optimized: create_test_result(ABVariant::Optimized, 7000, 78.0, "B", true),
                quality_regression: false,
                token_reduction_pct: 30.0,
                quality_score_diff: Some(-2.0),
                p_value: None,
                passed: true,
                failure_reasons: vec![],
            },
            ABComparison {
                test_case_id: "test-002".to_string(),
                baseline: create_test_result(ABVariant::Baseline, 8000, 85.0, "A", true),
                optimized: create_test_result(ABVariant::Optimized, 5600, 83.0, "A", true),
                quality_regression: false,
                token_reduction_pct: 30.0,
                quality_score_diff: Some(-2.0),
                p_value: None,
                passed: true,
                failure_reasons: vec![],
            },
        ];

        let summary = aggregate_comparisons(comparisons);

        assert_eq!(summary.total_cases, 2);
        assert_eq!(summary.passed_cases, 2);
        assert_eq!(summary.failed_cases, 0);
        assert_eq!(summary.avg_token_reduction_pct, 30.0);
        assert_eq!(summary.avg_quality_diff, -2.0);
        assert_eq!(summary.quality_regressions, 0);
        assert!(summary.passed);
    }

    #[test]
    fn test_ab_variant_serialization() {
        let baseline = ABVariant::Baseline;
        let optimized = ABVariant::Optimized;

        assert_eq!(baseline.as_str(), "baseline");
        assert_eq!(optimized.as_str(), "optimized");

        let baseline_json = serde_json::to_string(&baseline).unwrap();
        let optimized_json = serde_json::to_string(&optimized).unwrap();

        assert_eq!(baseline_json, r#""baseline""#);
        assert_eq!(optimized_json, r#""optimized""#);
    }
}
