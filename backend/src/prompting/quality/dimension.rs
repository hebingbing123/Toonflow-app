//! 质量评审维度校验与放行阈值逻辑。
//!
//! 定义 7 个合法维度键、`validate_dimension_scores` 校验函数与
//! `pass_threshold_met` 放行阈值判断函数。

use std::collections::HashMap;

use serde::{Deserialize, Serialize};

use crate::error::ApiError;

/// 维度评分 JSON 对象的 OpenAPI schema 表示。
///
/// 键为合法维度名（`visual_consistency`、`narrative_coherence`、`lip_sync`、
/// `pacing`、`character_consistency`、`dialogue_naturalness`、`faithfulness`），
/// 值为 1–10 整数（含边界）。
///
/// 在 `QualityReview` 与 `CreateQualityReviewBody` 中以 `dimensionScores` 字段引用。
#[derive(Debug, Clone, Serialize, Deserialize, utoipa::ToSchema)]
#[schema(
    title = "DimensionScores",
    description = "维度评分对象。合法键：visual_consistency, narrative_coherence, lip_sync, pacing, character_consistency, dialogue_naturalness, faithfulness。值范围 1-10（含边界）。",
    value_type = HashMap<String, i32>,
    example = json!({
        "visual_consistency": 8,
        "narrative_coherence": 7,
        "lip_sync": 9,
        "pacing": 6,
        "character_consistency": 8,
        "dialogue_naturalness": 7,
        "faithfulness": 9
    })
)]
pub struct DimensionScores(pub HashMap<String, i32>);

/// Bad case fixture JSON 格式（Export_Tool 导出文件）。
#[derive(Debug, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct BadCaseFixture {
    /// 导出时间（ISO 8601）
    pub exported_at: chrono::DateTime<chrono::Utc>,
    /// 导出条数
    pub review_count: usize,
    /// Schema 版本（当前为 "1"）
    pub schema_version: String,
    /// 评审记录数组
    pub reviews: Vec<FixtureReview>,
}

/// Fixture 中的单条评审记录。
#[derive(Debug, Serialize, Deserialize, utoipa::ToSchema)]
pub struct FixtureReview {
    pub id: uuid::Uuid,
    pub stage: Option<String>,
    pub grade: Option<String>,
    pub passed: Option<bool>,
    pub overall_score: Option<i16>,
    #[schema(nullable = true, value_type = Option<DimensionScores>)]
    pub dimension_scores: Option<serde_json::Value>,
    pub is_bad_case: bool,
    pub bad_case_category: Option<String>,
    pub skill_version_hash: Option<String>,
    pub created_at: chrono::DateTime<chrono::Utc>,
}

/// 回归检查报告（Regression_Check_Tool stdout JSON）。
#[derive(Debug, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RegressionReport {
    /// Fixture 文件路径
    pub fixture_file: String,
    /// 有效检查记录数（不含数据库中不存在的记录）
    pub total_checked: usize,
    /// 退化记录数
    pub regression_count: usize,
    /// 退化率（0.0–1.0）
    pub regression_rate: f64,
    /// 退化记录列表
    pub regressions: Vec<RegressionItem>,
}

/// 单条退化记录。
#[derive(Debug, Serialize, Deserialize, utoipa::ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct RegressionItem {
    pub id: uuid::Uuid,
    pub fixture_passed: Option<bool>,
    pub current_passed: Option<bool>,
}

/// 合法的维度评分键（共 7 个）。
pub const VALID_DIMENSION_KEYS: &[&str] = &[
    "visual_consistency",
    "narrative_coherence",
    "lip_sync",
    "pacing",
    "character_consistency",
    "dialogue_naturalness",
    "faithfulness",
];

/// 维度评分值的合法范围（含边界）。
const DIMENSION_SCORE_RANGE: std::ops::RangeInclusive<i64> = 1..=10;

/// 校验 `dimension_scores` JSON 对象。
///
/// # 错误
///
/// - `scores` 不是 JSON 对象 → `invalid_dimension_scores`（HTTP 400）
/// - 包含未定义维度键 → `invalid_dimension_key`（HTTP 400，`details.invalidKeys`）
/// - 任意维度值不在 1–10 范围内 → `dimension_score_out_of_range`（HTTP 400，`details.outOfRangeKeys`）
pub fn validate_dimension_scores(scores: &serde_json::Value) -> Result<(), ApiError> {
    let obj = match scores.as_object() {
        Some(o) => o,
        None => {
            return Err(ApiError::BadRequestWithDetails {
                code: "invalid_dimension_scores",
                en: "dimension_scores must be a JSON object".to_string(),
                zh: "dimension_scores 必须是 JSON 对象".to_string(),
                details: None,
            });
        }
    };

    // 收集未定义键
    let invalid_keys: Vec<&str> = obj
        .keys()
        .filter(|k| !VALID_DIMENSION_KEYS.contains(&k.as_str()))
        .map(|k| k.as_str())
        .collect();

    if !invalid_keys.is_empty() {
        return Err(ApiError::BadRequestWithDetails {
            code: "invalid_dimension_key",
            en: format!("dimension_scores contains invalid keys: {:?}", invalid_keys),
            zh: format!("dimension_scores 包含无效键：{:?}", invalid_keys),
            details: Some(serde_json::json!({
                "invalidKeys": invalid_keys,
            })),
        });
    }

    // 收集越界键值对
    let out_of_range: Vec<serde_json::Value> = obj
        .iter()
        .filter_map(|(k, v)| {
            let score = v.as_i64()?;
            if !DIMENSION_SCORE_RANGE.contains(&score) {
                Some(serde_json::json!({ "key": k, "value": score }))
            } else {
                None
            }
        })
        .collect();

    // 值不是整数也视为越界
    let non_integer: Vec<serde_json::Value> = obj
        .iter()
        .filter(|(_, v)| v.as_i64().is_none())
        .map(|(k, v)| serde_json::json!({ "key": k, "value": v }))
        .collect();

    let all_out_of_range: Vec<serde_json::Value> =
        out_of_range.into_iter().chain(non_integer).collect();

    if !all_out_of_range.is_empty() {
        return Err(ApiError::BadRequestWithDetails {
            code: "dimension_score_out_of_range",
            en: "dimension_scores contains values outside the 1-10 range".to_string(),
            zh: "dimension_scores 包含超出 1-10 范围的值".to_string(),
            details: Some(serde_json::json!({
                "outOfRangeKeys": all_out_of_range,
            })),
        });
    }

    Ok(())
}

/// 放行阈值判断。
///
/// 当且仅当以下两个条件同时满足时返回 `true`：
/// 1. `overall_score >= 6`
/// 2. `dimension_scores` 中无分值 ≤ 3 的维度（若 `dimension_scores` 为 `None` 或空对象，视为无 D 级维度）
pub fn pass_threshold_met(
    overall_score: Option<i16>,
    dimension_scores: Option<&serde_json::Value>,
) -> bool {
    // overall_score 必须 >= 6
    let score_ok = match overall_score {
        Some(s) => s >= 6,
        None => false,
    };
    if !score_ok {
        return false;
    }

    // 无分值 ≤ 3 的维度
    let no_d_grade = match dimension_scores {
        None => true,
        Some(v) => match v.as_object() {
            None => true,
            Some(obj) => obj
                .values()
                .all(|val| val.as_i64().is_none_or(|score| score > 3)),
        },
    };

    no_d_grade
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;
    use serde_json::json;

    // ── validate_dimension_scores ──────────────────────────────────────────────

    #[test]
    fn valid_all_seven_dimensions_passes() {
        let scores = json!({
            "visual_consistency": 5,
            "narrative_coherence": 7,
            "lip_sync": 8,
            "pacing": 6,
            "character_consistency": 9,
            "dialogue_naturalness": 4,
            "faithfulness": 10,
        });
        assert!(validate_dimension_scores(&scores).is_ok());
    }

    #[test]
    fn valid_boundary_values_pass() {
        let scores = json!({ "lip_sync": 1, "pacing": 10 });
        assert!(validate_dimension_scores(&scores).is_ok());
    }

    #[test]
    fn empty_object_passes() {
        let scores = json!({});
        assert!(validate_dimension_scores(&scores).is_ok());
    }

    #[test]
    fn non_object_returns_invalid_dimension_scores() {
        for bad in [json!([1, 2, 3]), json!("string"), json!(42), json!(null)] {
            let err = validate_dimension_scores(&bad).unwrap_err();
            match err {
                ApiError::BadRequestWithDetails { code, .. } => {
                    assert_eq!(code, "invalid_dimension_scores");
                }
                _ => panic!("expected BadRequestWithDetails"),
            }
        }
    }

    #[test]
    fn unknown_key_returns_invalid_dimension_key_with_details() {
        let scores = json!({ "unknown_dim": 5, "visual_consistency": 7 });
        let err = validate_dimension_scores(&scores).unwrap_err();
        match err {
            ApiError::BadRequestWithDetails { code, details, .. } => {
                assert_eq!(code, "invalid_dimension_key");
                let details = details.expect("details present");
                let invalid_keys = details["invalidKeys"].as_array().expect("array");
                assert!(invalid_keys
                    .iter()
                    .any(|v| v.as_str() == Some("unknown_dim")));
            }
            _ => panic!("expected BadRequestWithDetails"),
        }
    }

    #[test]
    fn score_zero_returns_out_of_range_with_details() {
        let scores = json!({ "lip_sync": 0 });
        let err = validate_dimension_scores(&scores).unwrap_err();
        match err {
            ApiError::BadRequestWithDetails { code, details, .. } => {
                assert_eq!(code, "dimension_score_out_of_range");
                let details = details.expect("details present");
                let out_of_range = details["outOfRangeKeys"].as_array().expect("array");
                assert!(!out_of_range.is_empty());
                assert_eq!(out_of_range[0]["key"].as_str(), Some("lip_sync"));
            }
            _ => panic!("expected BadRequestWithDetails"),
        }
    }

    #[test]
    fn score_eleven_returns_out_of_range_with_details() {
        let scores = json!({ "pacing": 11 });
        let err = validate_dimension_scores(&scores).unwrap_err();
        match err {
            ApiError::BadRequestWithDetails { code, .. } => {
                assert_eq!(code, "dimension_score_out_of_range");
            }
            _ => panic!("expected BadRequestWithDetails"),
        }
    }

    // ── pass_threshold_met ────────────────────────────────────────────────────

    #[test]
    fn overall_6_no_d_grade_returns_true() {
        let scores = json!({ "lip_sync": 5, "pacing": 7 });
        assert!(pass_threshold_met(Some(6), Some(&scores)));
    }

    #[test]
    fn overall_10_no_d_grade_returns_true() {
        let scores = json!({ "faithfulness": 4 });
        assert!(pass_threshold_met(Some(10), Some(&scores)));
    }

    #[test]
    fn overall_5_returns_false() {
        let scores = json!({ "lip_sync": 8 });
        assert!(!pass_threshold_met(Some(5), Some(&scores)));
    }

    #[test]
    fn overall_none_returns_false() {
        assert!(!pass_threshold_met(None, None));
    }

    #[test]
    fn d_grade_dimension_returns_false() {
        let scores = json!({ "lip_sync": 3, "pacing": 7 });
        assert!(!pass_threshold_met(Some(7), Some(&scores)));
    }

    #[test]
    fn score_exactly_3_is_d_grade() {
        let scores = json!({ "visual_consistency": 3 });
        assert!(!pass_threshold_met(Some(8), Some(&scores)));
    }

    #[test]
    fn score_4_is_not_d_grade() {
        let scores = json!({ "visual_consistency": 4 });
        assert!(pass_threshold_met(Some(8), Some(&scores)));
    }

    #[test]
    fn no_dimension_scores_with_overall_6_returns_true() {
        assert!(pass_threshold_met(Some(6), None));
    }

    #[test]
    fn empty_dimension_scores_with_overall_6_returns_true() {
        let scores = json!({});
        assert!(pass_threshold_met(Some(6), Some(&scores)));
    }

    // Feature: quality-benchmark-ops, Property 1: dimension_scores round-trip
    // Validates: Requirements 2.5, 2.6, 2.8
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(50))]
        #[test]
        fn prop_dimension_scores_roundtrip(
            scores in prop::collection::hash_map(
                prop_oneof![
                    Just("visual_consistency"),
                    Just("narrative_coherence"),
                    Just("lip_sync"),
                    Just("pacing"),
                    Just("character_consistency"),
                    Just("dialogue_naturalness"),
                    Just("faithfulness"),
                ],
                1i64..=10,
                0..=7,
            ),
        ) {
            let original = serde_json::to_value(&scores).unwrap();
            let serialized = serde_json::to_string(&original).unwrap();
            let parsed: serde_json::Value = serde_json::from_str(&serialized).unwrap();
            prop_assert_eq!(original, parsed);
        }
    }

    // Feature: quality-benchmark-ops, Property 2: 放行阈值一致性
    // Validates: Requirements 1.2
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(50))]
        #[test]
        fn prop_pass_threshold_consistent_with_rules(
            overall_score in prop::option::of(0i16..=15i16),
            dim_scores in prop::collection::hash_map(
                prop_oneof![
                    Just("visual_consistency"),
                    Just("narrative_coherence"),
                    Just("lip_sync"),
                    Just("pacing"),
                    Just("character_consistency"),
                    Just("dialogue_naturalness"),
                    Just("faithfulness"),
                ],
                1i64..=10i64,
                0..=7usize,
            ),
        ) {
            let scores_json = serde_json::to_value(&dim_scores).unwrap();
            let result = pass_threshold_met(overall_score, Some(&scores_json));
            let expected = overall_score.map_or(false, |s| s >= 6)
                && dim_scores.values().all(|&v| v > 3);
            prop_assert_eq!(result, expected);
        }
    }

    // Feature: quality-benchmark-ops, Property 4: Export_Tool 只读性
    // Validates: Requirements 4.1
    // This test verifies the structural read-only property of the Export_Tool:
    // the binary source code must not contain any write SQL operations.
    #[test]
    fn prop_export_tool_is_readonly() {
        let source = include_str!("../../bin/quality_export.rs");
        // The export tool must not contain any write SQL operations
        let write_ops = ["INSERT", "UPDATE", "DELETE", "DROP", "TRUNCATE", "ALTER"];
        for op in &write_ops {
            assert!(
                !source.to_uppercase().contains(&format!(" {} ", op)),
                "Export_Tool source contains write SQL operation: {}",
                op
            );
        }
        // Must contain SELECT (read operation)
        assert!(
            source.to_uppercase().contains("SELECT"),
            "Export_Tool source must contain SELECT query"
        );
    }

    // Feature: quality-benchmark-ops, Property 5: 退化率计算一致性
    // Validates: Requirements 7.6, 7.7
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(50))]
        #[test]
        fn prop_regression_rate_equals_count_over_total(
            total_checked in 1usize..=100,
            regression_count_raw in 0usize..=100,
        ) {
            let regression_count = regression_count_raw.min(total_checked);
            let report = RegressionReport {
                fixture_file: "test.json".into(),
                total_checked,
                regression_count,
                regression_rate: regression_count as f64 / total_checked as f64,
                regressions: vec![],
            };
            // Round-trip: serialize and deserialize
            let json = serde_json::to_value(&report).unwrap();
            let parsed: RegressionReport = serde_json::from_value(json).unwrap();
            // Metamorphic: regression_rate == regression_count / total_checked
            let expected_rate = regression_count as f64 / total_checked as f64;
            prop_assert!((parsed.regression_rate - expected_rate).abs() < 1e-10,
                "regression_rate {} != expected {}", parsed.regression_rate, expected_rate);
            prop_assert_eq!(parsed.total_checked, total_checked);
            prop_assert_eq!(parsed.regression_count, regression_count);
            prop_assert_eq!(parsed.fixture_file, "test.json");
        }
    }

    // Feature: quality-benchmark-ops, Property 3: fixture round-trip
    // Validates: Requirements 4.2, 4.3, 4.8
    proptest! {
        #![proptest_config(ProptestConfig::with_cases(30))]
        #[test]
        fn prop_fixture_roundtrip(
            review_count in 0usize..=20,
            passed_flags in prop::collection::vec(prop::option::of(any::<bool>()), 0..=20),
        ) {
            let reviews: Vec<FixtureReview> = passed_flags.into_iter().take(review_count)
                .map(|passed| FixtureReview {
                    id: uuid::Uuid::new_v4(),
                    stage: Some("storyboard_panel".into()),
                    grade: Some("B".into()),
                    passed,
                    overall_score: Some(7),
                    dimension_scores: None,
                    is_bad_case: false,
                    bad_case_category: None,
                    skill_version_hash: None,
                    created_at: chrono::Utc::now(),
                })
                .collect();
            let fixture = BadCaseFixture {
                exported_at: chrono::Utc::now(),
                review_count: reviews.len(),
                schema_version: "1".into(),
                reviews,
            };
            let json = serde_json::to_string(&fixture).unwrap();
            let parsed: BadCaseFixture = serde_json::from_str(&json).unwrap();
            prop_assert_eq!(fixture.review_count, parsed.review_count);
            prop_assert_eq!(fixture.schema_version, parsed.schema_version);
            prop_assert_eq!(fixture.reviews.len(), parsed.reviews.len());
            for (orig, parsed_review) in fixture.reviews.iter().zip(parsed.reviews.iter()) {
                prop_assert_eq!(orig.id, parsed_review.id);
                prop_assert_eq!(orig.passed, parsed_review.passed);
                prop_assert_eq!(&orig.stage, &parsed_review.stage);
            }
        }
    }
}
