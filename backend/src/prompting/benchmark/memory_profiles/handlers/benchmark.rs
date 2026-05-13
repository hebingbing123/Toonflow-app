//! 基准测试与 ROI 分析处理器。

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::{
    auth::require_user_uuid,
    error::{bad_request_i18n, ApiError},
    state::AppState,
};

use super::super::types::{
    MemoryBudgetProfileSnapshot, QualityMetrics, RoiConclusion, RoiConclusionType,
    RoiEvidenceSummary, SampleRoiDetail, SampleSetStats, StageRoiBreakdown, VariantCostDelta,
    VariantRoiComparison,
};

use super::profile::create_default_memory_profile;

/// 获取实验的 ROI 对比
///
/// 返回指定实验运行的 ROI 证据摘要，包括各变体的成本、质量和收益对比。
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/experiments/{id}/roi",
    params(
        ("id" = Uuid, Path, description = "实验运行 ID")
    ),
    responses(
        (status = 200, description = "成功返回 ROI 证据摘要", body = RoiEvidenceSummary),
        (status = 401, description = "未授权"),
        (status = 404, description = "实验不存在"),
        (status = 500, description = "服务器内部错误")
    ),
    security(("bearer" = []))
)]
pub async fn get_experiment_roi(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(experiment_id): Path<Uuid>,
) -> Result<Json<RoiEvidenceSummary>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    // 1. 验证实验存在且属于当前用户
    let experiment: (Uuid, Uuid, String) = sqlx::query_as(
        r#"
        SELECT id, owner_user_id, status
        FROM app_experiment_run
        WHERE id = $1
        "#,
    )
    .bind(experiment_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    if experiment.1 != user_id {
        return Err(ApiError::Forbidden("无权访问此实验".to_string()));
    }

    // 2. 获取实验的所有变体
    let variants: Vec<(Uuid, String, bool, serde_json::Value)> = sqlx::query_as(
        r#"
        SELECT id, label, is_baseline, memory_budget_snapshot
        FROM app_experiment_variant
        WHERE experiment_run_id = $1
        ORDER BY is_baseline DESC, label
        "#,
    )
    .bind(experiment_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if variants.is_empty() {
        return Err(bad_request_i18n("Experiment has no variants", "实验无变体"));
    }

    // 3. 获取基线变体（用于计算增量）
    let baseline_variant = variants
        .iter()
        .find(|v| v.2)
        .ok_or_else(|| bad_request_i18n("Experiment has no baseline variant", "实验无基线变体"))?;

    let results: Vec<ExperimentResultRow> = sqlx::query_as(
        r#"
        SELECT 
            r.id,
            r.variant_id,
            r.benchmark_case_id,
            r.score_summary,
            r.roi_summary,
            c.case_type,
            c.weight,
            c.stage,
            c.issue_tags
        FROM app_experiment_result r
        JOIN app_benchmark_case c ON r.benchmark_case_id = c.id
        WHERE r.experiment_run_id = $1 AND r.status = 'completed'
        "#,
    )
    .bind(experiment_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 5. 计算基线变体的统计数据
    let baseline_results: Vec<_> = results
        .iter()
        .filter(|r| r.variant_id == baseline_variant.0)
        .collect();

    let baseline_stats = calculate_variant_stats(baseline_results.as_slice());

    // 6. 为每个变体计算 ROI 对比
    let mut variant_comparisons = Vec::new();

    for variant in &variants {
        let variant_results: Vec<_> = results
            .iter()
            .filter(|r| r.variant_id == variant.0)
            .collect();

        if variant_results.is_empty() {
            continue;
        }

        let variant_stats = calculate_variant_stats(variant_results.as_slice());

        // 解析记忆预算快照
        let memory_budget_profile: MemoryBudgetProfileSnapshot =
            serde_json::from_value(variant.3.clone())
                .unwrap_or_else(|_| create_default_memory_profile("unknown"));

        // 计算成本增量
        let cost_delta = VariantCostDelta {
            total_tokens: variant_stats.total_tokens,
            token_delta: variant_stats.total_tokens - baseline_stats.total_tokens,
            token_delta_percent: if baseline_stats.total_tokens > 0 {
                ((variant_stats.total_tokens - baseline_stats.total_tokens) as f64
                    / baseline_stats.total_tokens as f64)
                    * 100.0
            } else {
                0.0
            },
            estimated_cost_usd: variant_stats.total_tokens as f64 * 0.00001, // 假设每 token $0.00001
            cost_delta_usd: (variant_stats.total_tokens - baseline_stats.total_tokens) as f64
                * 0.00001,
        };

        // 计算质量指标
        let quality_metrics = QualityMetrics {
            avg_quality_score: variant_stats.avg_quality_score,
            quality_score_delta: variant_stats.avg_quality_score - baseline_stats.avg_quality_score,
            pass_rate: variant_stats.pass_rate,
            pass_rate_delta: variant_stats.pass_rate - baseline_stats.pass_rate,
            rework_rate: variant_stats.rework_rate,
            rework_rate_delta: variant_stats.rework_rate - baseline_stats.rework_rate,
            bad_case_recurrence_count: variant_stats.bad_case_recurrence_count,
            bad_case_recurrence_delta: variant_stats.bad_case_recurrence_count
                - baseline_stats.bad_case_recurrence_count,
        };

        // 构建样本详情
        let sample_details: Vec<SampleRoiDetail> = variant_results
            .iter()
            .map(|r| SampleRoiDetail {
                benchmark_case_id: r.benchmark_case_id,
                case_type: r.case_type.clone().unwrap_or_default(),
                weight: r.weight.unwrap_or(1),
                tokens_used: r
                    .roi_summary
                    .as_ref()
                    .and_then(|v| v.get("tokensUsed"))
                    .and_then(|v| v.as_i64())
                    .unwrap_or(0),
                quality_score: r
                    .score_summary
                    .as_ref()
                    .and_then(|v| v.get("overallScore"))
                    .and_then(|v| v.as_f64())
                    .unwrap_or(0.0),
                passed: r
                    .score_summary
                    .as_ref()
                    .and_then(|v| v.get("passed"))
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false),
                requires_rework: r
                    .score_summary
                    .as_ref()
                    .and_then(|v| v.get("requiresRework"))
                    .and_then(|v| v.as_bool())
                    .unwrap_or(false),
                issue_tags: r
                    .issue_tags
                    .as_ref()
                    .and_then(|v| v.as_array())
                    .map(|arr| {
                        arr.iter()
                            .filter_map(|v| v.as_str().map(String::from))
                            .collect()
                    })
                    .unwrap_or_default(),
            })
            .collect();

        // 按阶段分解 ROI
        let stage_breakdown =
            calculate_stage_breakdown(variant_results.as_slice(), baseline_results.as_slice());

        variant_comparisons.push(VariantRoiComparison {
            variant_id: variant.0,
            variant_label: variant.1.clone(),
            is_baseline: variant.2,
            memory_budget_profile,
            cost_delta,
            quality_metrics,
            sample_details,
            stage_breakdown,
        });
    }

    // 7. 计算样本集统计
    let sample_set_stats = calculate_sample_set_stats(results.as_slice());

    // 8. 生成总体结论
    let overall_conclusion = generate_roi_conclusion(&variant_comparisons, &baseline_variant.0);

    Ok(Json(RoiEvidenceSummary {
        experiment_run_id: experiment_id,
        variant_comparisons,
        sample_set_stats,
        overall_conclusion,
    }))
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 变体统计数据
struct VariantStats {
    total_tokens: i64,
    avg_quality_score: f64,
    pass_rate: f64,
    rework_rate: f64,
    bad_case_recurrence_count: i32,
}

/// 计算变体统计数据
fn calculate_variant_stats(results: &[&ExperimentResultRow]) -> VariantStats {
    if results.is_empty() {
        return VariantStats {
            total_tokens: 0,
            avg_quality_score: 0.0,
            pass_rate: 0.0,
            rework_rate: 0.0,
            bad_case_recurrence_count: 0,
        };
    }

    let mut total_tokens = 0i64;
    let mut total_quality_score = 0.0;
    let mut scored_count = 0usize;
    let mut passed_count = 0;
    let mut verdict_count = 0usize;
    let mut rework_count = 0;
    let mut bad_case_recurrence_count = 0;

    for result in results {
        // 从 roi_summary 提取 token 数据
        if let Some(ref roi_summary) = result.roi_summary {
            if let Some(tokens) = roi_summary.get("tokensUsed").and_then(|v| v.as_i64()) {
                total_tokens += tokens;
            }
        }

        // 从 score_summary 提取质量数据
        if let Some(ref score_summary) = result.score_summary {
            if let Some(score) = score_summary.get("overallScore").and_then(|v| v.as_f64()) {
                total_quality_score += score;
                scored_count += 1;
            }

            if let Some(passed) = score_summary.get("passed").and_then(|v| v.as_bool()) {
                verdict_count += 1;
                if passed {
                    passed_count += 1;
                }
            }

            if let Some(requires_rework) = score_summary
                .get("requiresRework")
                .and_then(|v| v.as_bool())
            {
                if requires_rework {
                    rework_count += 1;
                }
            }
        }

        // 统计 bad case 复发
        if let Some(ref case_type) = result.case_type {
            if case_type == "bad_case" {
                if let Some(ref score_summary) = result.score_summary {
                    if score_summary.get("passed").and_then(|v| v.as_bool()) == Some(false) {
                        bad_case_recurrence_count += 1;
                    }
                }
            }
        }
    }

    VariantStats {
        total_tokens,
        avg_quality_score: if scored_count > 0 {
            total_quality_score / scored_count as f64
        } else {
            0.0
        },
        pass_rate: if verdict_count > 0 {
            passed_count as f64 / verdict_count as f64
        } else {
            0.0
        },
        rework_rate: if verdict_count > 0 {
            rework_count as f64 / verdict_count as f64
        } else {
            0.0
        },
        bad_case_recurrence_count,
    }
}

#[derive(sqlx::FromRow)]
pub(super) struct ExperimentResultRow {
    #[allow(dead_code)]
    id: Uuid,
    variant_id: Uuid,
    benchmark_case_id: Uuid,
    score_summary: Option<serde_json::Value>,
    roi_summary: Option<serde_json::Value>,
    case_type: Option<String>,
    weight: Option<i32>,
    stage: Option<String>,
    issue_tags: Option<serde_json::Value>,
}

/// 按阶段分解 ROI
fn calculate_stage_breakdown(
    variant_results: &[&ExperimentResultRow],
    baseline_results: &[&ExperimentResultRow],
) -> Vec<StageRoiBreakdown> {
    use std::collections::HashMap;

    let mut stage_map: HashMap<String, (i64, f64, i32)> = HashMap::new();
    let mut baseline_stage_map: HashMap<String, (i64, f64, i32)> = HashMap::new();

    // 收集基线数据
    for result in baseline_results {
        if let Some(ref stage) = result.stage {
            let tokens = result
                .roi_summary
                .as_ref()
                .and_then(|v| v.get("tokensUsed"))
                .and_then(|v| v.as_i64())
                .unwrap_or(0);

            let entry = baseline_stage_map
                .entry(stage.clone())
                .or_insert((0, 0.0, 0));
            entry.0 += tokens;
            if let Some(score) = result
                .score_summary
                .as_ref()
                .and_then(|v| v.get("overallScore"))
                .and_then(|v| v.as_f64())
            {
                entry.1 += score;
                entry.2 += 1;
            }
        }
    }

    // 收集变体数据
    for result in variant_results {
        if let Some(ref stage) = result.stage {
            let tokens = result
                .roi_summary
                .as_ref()
                .and_then(|v| v.get("tokensUsed"))
                .and_then(|v| v.as_i64())
                .unwrap_or(0);

            let entry = stage_map.entry(stage.clone()).or_insert((0, 0.0, 0));
            entry.0 += tokens;
            if let Some(score) = result
                .score_summary
                .as_ref()
                .and_then(|v| v.get("overallScore"))
                .and_then(|v| v.as_f64())
            {
                entry.1 += score;
                entry.2 += 1;
            }
        }
    }

    // 生成分解结果
    stage_map
        .into_iter()
        .map(|(stage, (tokens, total_score, count))| {
            let baseline_tokens = baseline_stage_map
                .get(&stage)
                .map(|(t, _, _)| *t)
                .unwrap_or(0);

            let baseline_score = baseline_stage_map
                .get(&stage)
                .map(|(_, s, baseline_count)| {
                    if *baseline_count > 0 {
                        *s / *baseline_count as f64
                    } else {
                        0.0
                    }
                })
                .unwrap_or(0.0);

            let avg_score = if count > 0 {
                total_score / count as f64
            } else {
                0.0
            };

            StageRoiBreakdown {
                stage,
                tokens_used: tokens,
                token_delta: tokens - baseline_tokens,
                avg_quality_score: avg_score,
                quality_score_delta: avg_score - baseline_score,
                sample_count: count,
            }
        })
        .collect()
}

/// 计算样本集统计
fn calculate_sample_set_stats(results: &[ExperimentResultRow]) -> SampleSetStats {
    use std::collections::{HashMap, HashSet};

    let mut unique_case_types: HashMap<Uuid, String> = HashMap::new();
    let mut stages: HashSet<String> = HashSet::new();

    for result in results {
        if let Some(ref case_type) = result.case_type {
            unique_case_types
                .entry(result.benchmark_case_id)
                .or_insert_with(|| case_type.clone());
        }

        if let Some(ref stage) = result.stage {
            stages.insert(stage.clone());
        }
    }

    let golden_count = unique_case_types
        .values()
        .filter(|kind| kind.as_str() == "golden")
        .count() as i32;
    let bad_case_count = unique_case_types
        .values()
        .filter(|kind| kind.as_str() == "bad_case")
        .count() as i32;
    let regression_guard_count = unique_case_types
        .values()
        .filter(|kind| kind.as_str() == "regression_guard")
        .count() as i32;

    SampleSetStats {
        total_samples: unique_case_types.len() as i32,
        golden_count,
        bad_case_count,
        regression_guard_count,
        stages_covered: stages.into_iter().collect(),
    }
}

/// 生成 ROI 总体结论
fn generate_roi_conclusion(
    comparisons: &[VariantRoiComparison],
    baseline_id: &Uuid,
) -> RoiConclusion {
    // 找出非基线变体中的最佳候选
    let candidates: Vec<_> = comparisons
        .iter()
        .filter(|c| c.variant_id != *baseline_id)
        .collect();

    if candidates.is_empty() {
        return RoiConclusion {
            recommended_variant_id: Some(*baseline_id),
            conclusion_type: RoiConclusionType::InsufficientData,
            rationale: "无候选变体可供比较".to_string(),
            recommend_promotion: false,
            promotion_restrictions: None,
        };
    }

    // 找出质量提升最大的候选
    let best_quality = candidates.iter().max_by(|a, b| {
        a.quality_metrics
            .quality_score_delta
            .partial_cmp(&b.quality_metrics.quality_score_delta)
            .unwrap_or(std::cmp::Ordering::Equal)
    });

    if let Some(best) = best_quality {
        let quality_delta = best.quality_metrics.quality_score_delta;
        let cost_delta_percent = best.cost_delta.token_delta_percent;
        let bad_case_delta = best.quality_metrics.bad_case_recurrence_delta;

        // 判断是否有质量退化
        if quality_delta < -0.1 || bad_case_delta > 2 {
            return RoiConclusion {
                recommended_variant_id: Some(*baseline_id),
                conclusion_type: RoiConclusionType::QualityRegression,
                rationale: format!(
                    "变体 {} 出现质量退化（质量分变化: {:.2}，坏例复发增加: {}），建议阻断推广",
                    best.variant_label, quality_delta, bad_case_delta
                ),
                recommend_promotion: false,
                promotion_restrictions: None,
            };
        }

        // 判断 ROI 类型
        if quality_delta > 0.2 && cost_delta_percent < 10.0 {
            // 低成本高收益
            return RoiConclusion {
                recommended_variant_id: Some(best.variant_id),
                conclusion_type: RoiConclusionType::LowCostHighBenefit,
                rationale: format!(
                    "变体 {} 质量提升明显（+{:.2}），成本增加可控（+{:.1}%），建议全量推广",
                    best.variant_label, quality_delta, cost_delta_percent
                ),
                recommend_promotion: true,
                promotion_restrictions: None,
            };
        } else if quality_delta > 0.3 && bad_case_delta < -2 && cost_delta_percent < 30.0 {
            // 高 Token 高价值守卫
            return RoiConclusion {
                recommended_variant_id: Some(best.variant_id),
                conclusion_type: RoiConclusionType::HighCostHighValueGuard,
                rationale: format!(
                    "变体 {} 显著降低坏例复发（{}），质量提升明显（+{:.2}），虽然成本增加（+{:.1}%），但建议在高风险场景使用",
                    best.variant_label, bad_case_delta, quality_delta, cost_delta_percent
                ),
                recommend_promotion: true,
                promotion_restrictions: Some("建议仅在高风险项目或关键阶段启用".to_string()),
            };
        } else if quality_delta < 0.05 && cost_delta_percent > 20.0 {
            // 高成本低收益
            return RoiConclusion {
                recommended_variant_id: Some(*baseline_id),
                conclusion_type: RoiConclusionType::HighCostLowBenefit,
                rationale: format!(
                    "变体 {} 质量提升不明显（+{:.2}），但成本显著增加（+{:.1}%），不建议推广",
                    best.variant_label, quality_delta, cost_delta_percent
                ),
                recommend_promotion: false,
                promotion_restrictions: None,
            };
        } else {
            // 成本收益平衡
            return RoiConclusion {
                recommended_variant_id: Some(best.variant_id),
                conclusion_type: RoiConclusionType::Balanced,
                rationale: format!(
                    "变体 {} 质量与成本变化均在合理范围内（质量: +{:.2}，成本: +{:.1}%），可考虑推广",
                    best.variant_label, quality_delta, cost_delta_percent
                ),
                recommend_promotion: true,
                promotion_restrictions: Some("建议先在部分项目试用，观察稳定性后再全量推广".to_string()),
            };
        }
    }

    RoiConclusion {
        recommended_variant_id: Some(*baseline_id),
        conclusion_type: RoiConclusionType::InsufficientData,
        rationale: "无法生成有效结论".to_string(),
        recommend_promotion: false,
        promotion_restrictions: None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    fn build_result_row(case_id: Uuid, case_type: &str, stage: &str) -> ExperimentResultRow {
        ExperimentResultRow {
            id: Uuid::new_v4(),
            variant_id: Uuid::new_v4(),
            benchmark_case_id: case_id,
            score_summary: None,
            roi_summary: None,
            case_type: Some(case_type.to_string()),
            weight: Some(1),
            stage: Some(stage.to_string()),
            issue_tags: None,
        }
    }

    fn build_scored_result_row(stage: &str, score: f64, tokens: i64) -> ExperimentResultRow {
        ExperimentResultRow {
            id: Uuid::new_v4(),
            variant_id: Uuid::new_v4(),
            benchmark_case_id: Uuid::new_v4(),
            score_summary: Some(serde_json::json!({ "overallScore": score })),
            roi_summary: Some(serde_json::json!({ "tokensUsed": tokens })),
            case_type: Some("golden".into()),
            weight: Some(1),
            stage: Some(stage.into()),
            issue_tags: None,
        }
    }

    #[test]
    fn variant_stats_ignore_unscored_rows_in_quality_and_verdict_rates() {
        let scored = build_scored_result_row("video_prompt", 9.0, 120);
        let unscored = ExperimentResultRow {
            id: Uuid::new_v4(),
            variant_id: Uuid::new_v4(),
            benchmark_case_id: Uuid::new_v4(),
            score_summary: None,
            roi_summary: Some(serde_json::json!({ "tokensUsed": 30 })),
            case_type: Some("bad_case".into()),
            weight: Some(3),
            stage: Some("video_prompt".into()),
            issue_tags: None,
        };

        let stats = calculate_variant_stats(&[&scored, &unscored]);

        assert!((stats.avg_quality_score - 9.0).abs() < f64::EPSILON);
        assert!((stats.pass_rate - 0.0).abs() < f64::EPSILON);
        assert_eq!(stats.bad_case_recurrence_count, 0);
    }

    #[test]
    fn stage_breakdown_uses_baseline_stage_sample_count_for_average() {
        let baseline_a = build_scored_result_row("video_prompt", 10.0, 100);
        let baseline_b = build_scored_result_row("video_prompt", 6.0, 120);
        let variant = build_scored_result_row("video_prompt", 9.0, 140);

        let breakdown = calculate_stage_breakdown(&[&variant], &[&baseline_a, &baseline_b]);
        let video_prompt = breakdown
            .iter()
            .find(|row| row.stage == "video_prompt")
            .expect("video_prompt breakdown");

        assert!((video_prompt.avg_quality_score - 9.0).abs() < f64::EPSILON);
        assert!((video_prompt.quality_score_delta - 1.0).abs() < f64::EPSILON);
        assert_eq!(video_prompt.token_delta, -80);
    }

    #[test]
    fn stage_breakdown_ignores_unscored_rows_in_stage_average() {
        let baseline_scored = build_scored_result_row("video_prompt", 8.0, 100);
        let baseline_unscored = ExperimentResultRow {
            id: Uuid::new_v4(),
            variant_id: Uuid::new_v4(),
            benchmark_case_id: Uuid::new_v4(),
            score_summary: None,
            roi_summary: Some(serde_json::json!({ "tokensUsed": 40 })),
            case_type: Some("golden".into()),
            weight: Some(1),
            stage: Some("video_prompt".into()),
            issue_tags: None,
        };
        let variant_scored = build_scored_result_row("video_prompt", 9.0, 110);

        let breakdown =
            calculate_stage_breakdown(&[&variant_scored], &[&baseline_scored, &baseline_unscored]);
        let video_prompt = breakdown
            .iter()
            .find(|row| row.stage == "video_prompt")
            .expect("video_prompt breakdown");

        assert!((video_prompt.avg_quality_score - 9.0).abs() < f64::EPSILON);
        assert!((video_prompt.quality_score_delta - 1.0).abs() < f64::EPSILON);
    }

    proptest! {
        #[test]
        fn prop_roi_stats_use_unique_benchmark_cases(
            duplicates in proptest::collection::vec(0u8..5, 1..12)
        ) {
            let case_ids: Vec<Uuid> = duplicates
                .iter()
                .map(|seed| {
                    let mut bytes = [0u8; 16];
                    bytes[0] = *seed;
                    Uuid::from_bytes(bytes)
                })
                .collect();
            let unique_expected = case_ids.iter().copied().collect::<std::collections::HashSet<_>>().len() as i32;
            let rows: Vec<ExperimentResultRow> = case_ids
                .iter()
                .enumerate()
                .map(|(index, case_id)| {
                    let case_type = if index % 2 == 0 { "golden" } else { "bad_case" };
                    build_result_row(*case_id, case_type, "video_prompt")
                })
                .collect();
            let stats = calculate_sample_set_stats(rows.as_slice());
            prop_assert_eq!(stats.total_samples, unique_expected);
        }
    }
}
