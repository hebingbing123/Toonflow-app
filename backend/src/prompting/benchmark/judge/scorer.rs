//! 自动评分逻辑。

use super::rubric::get_rubric_for_stage;
use super::types::{
    AutoJudgeConfidence, ExperimentScoreSummary, IssueSeverity, QualityDimension,
    RubricDimensionScore, RubricIssue,
};
use crate::prompting::quality::QualityReview;

/// 从质量评审记录生成实验评分汇总
///
/// 将现有的质量评审字段映射到统一量表维度，并应用阶段权重。
pub fn score_experiment_result(
    quality_review: &QualityReview,
    stage: &str,
) -> ExperimentScoreSummary {
    let rubric = get_rubric_for_stage(stage);

    // 从质量评审映射到维度分数
    let dimension_scores = map_quality_review_to_dimensions(quality_review, &rubric);

    // 计算加权总分
    let weighted_total_score = calculate_weighted_score(&dimension_scores);

    // 判断是否通过
    let passed = weighted_total_score >= rubric.pass_threshold;

    // 生成推荐
    let recommend_promotion = weighted_total_score >= rubric.promotion_threshold;
    let recommend_golden_case = weighted_total_score >= rubric.golden_threshold;
    let recommend_bad_case = weighted_total_score < rubric.bad_case_threshold;

    // 评估置信度
    let confidence = assess_confidence(quality_review, &dimension_scores);

    // 判断是否需要人工复核
    let requires_human_review = confidence == AutoJudgeConfidence::Low
        || (recommend_bad_case && !quality_review.is_bad_case)
        || (recommend_golden_case && weighted_total_score < rubric.golden_threshold + 5.0);

    // 生成汇总说明
    let summary = generate_summary(
        weighted_total_score,
        passed,
        &dimension_scores,
        recommend_promotion,
    );

    ExperimentScoreSummary {
        dimension_scores,
        weighted_total_score,
        passed,
        recommend_promotion,
        recommend_bad_case,
        recommend_golden_case,
        confidence,
        requires_human_review,
        summary,
    }
}

/// 将质量评审字段映射到统一维度
fn map_quality_review_to_dimensions(
    review: &QualityReview,
    rubric: &super::rubric::RubricConfig,
) -> Vec<RubricDimensionScore> {
    let mut scores = Vec::new();

    // 人物一致性 <- character_consistency
    if let Some(char_score) = review.character_consistency {
        let weight = rubric
            .dimension_weights
            .get(&QualityDimension::CharacterConsistency)
            .copied()
            .unwrap_or(0.0);
        let issues = extract_issues_from_score(
            char_score,
            "character_consistency",
            review.comments.as_deref(),
        );
        scores.push(RubricDimensionScore {
            dimension: QualityDimension::CharacterConsistency,
            score: normalize_score(char_score),
            weight,
            issues,
            comment: None,
        });
    }

    // 情绪表达 <- 从 overall_score 和 comments 推断（简化实现）
    // 实际应用中可能需要更复杂的映射逻辑
    if let Some(overall) = review.overall_score {
        let weight = rubric
            .dimension_weights
            .get(&QualityDimension::EmotionExpression)
            .copied()
            .unwrap_or(0.0);
        scores.push(RubricDimensionScore {
            dimension: QualityDimension::EmotionExpression,
            score: normalize_score(overall),
            weight,
            issues: Vec::new(),
            comment: None,
        });
    }

    // 镜头真实感 <- visual_quality
    if let Some(visual) = review.visual_quality {
        let weight = rubric
            .dimension_weights
            .get(&QualityDimension::ShotRealism)
            .copied()
            .unwrap_or(0.0);
        let issues = extract_issues_from_score(visual, "shot_realism", review.comments.as_deref());
        scores.push(RubricDimensionScore {
            dimension: QualityDimension::ShotRealism,
            score: normalize_score(visual),
            weight,
            issues,
            comment: None,
        });
    }

    // AI 痕迹 <- 从 bad_case_category 和 comments 推断
    let ai_artifacts_score = if review.is_bad_case
        && review
            .bad_case_category
            .as_deref()
            .is_some_and(|cat| cat.contains("ai") || cat.contains("artifact"))
    {
        30.0 // 低分表示 AI 痕迹明显
    } else {
        80.0 // 默认认为 AI 痕迹不明显
    };
    let weight = rubric
        .dimension_weights
        .get(&QualityDimension::AiArtifacts)
        .copied()
        .unwrap_or(0.0);
    scores.push(RubricDimensionScore {
        dimension: QualityDimension::AiArtifacts,
        score: ai_artifacts_score,
        weight,
        issues: Vec::new(),
        comment: None,
    });

    // 台词自然度 <- dialogue_naturalness
    if let Some(dialogue) = review.dialogue_naturalness {
        let weight = rubric
            .dimension_weights
            .get(&QualityDimension::DialogueNaturalness)
            .copied()
            .unwrap_or(0.0);
        let issues =
            extract_issues_from_score(dialogue, "dialogue_naturalness", review.comments.as_deref());
        scores.push(RubricDimensionScore {
            dimension: QualityDimension::DialogueNaturalness,
            score: normalize_score(dialogue),
            weight,
            issues,
            comment: None,
        });
    }

    // 叙事抓力 <- plot_coherence + pacing
    if let (Some(plot), Some(pacing)) = (review.plot_coherence, review.pacing) {
        let weight = rubric
            .dimension_weights
            .get(&QualityDimension::NarrativeGrip)
            .copied()
            .unwrap_or(0.0);
        let avg_score = (normalize_score(plot) + normalize_score(pacing)) / 2.0;
        scores.push(RubricDimensionScore {
            dimension: QualityDimension::NarrativeGrip,
            score: avg_score,
            weight,
            issues: Vec::new(),
            comment: None,
        });
    }

    // 视觉连续性 <- visual_quality + faithfulness
    if let (Some(visual), Some(faith)) = (review.visual_quality, review.faithfulness) {
        let weight = rubric
            .dimension_weights
            .get(&QualityDimension::VisualContinuity)
            .copied()
            .unwrap_or(0.0);
        let avg_score = (normalize_score(visual) + normalize_score(faith)) / 2.0;
        scores.push(RubricDimensionScore {
            dimension: QualityDimension::VisualContinuity,
            score: avg_score,
            weight,
            issues: Vec::new(),
            comment: None,
        });
    }

    scores
}

/// 归一化分数到 0-100 范围
fn normalize_score(score: i16) -> f64 {
    // 假设输入分数范围是 0-10
    (score as f64 / 10.0) * 100.0
}

/// 从分数提取问题
fn extract_issues_from_score(
    score: i16,
    dimension: &str,
    comments: Option<&str>,
) -> Vec<RubricIssue> {
    let mut issues = Vec::new();

    if score <= 3 {
        issues.push(RubricIssue {
            issue_type: format!("{}_critical", dimension),
            severity: IssueSeverity::Critical,
            description: format!("{}维度得分过低", dimension),
            context: comments.map(|s| s.to_string()),
        });
    } else if score <= 5 {
        issues.push(RubricIssue {
            issue_type: format!("{}_major", dimension),
            severity: IssueSeverity::Major,
            description: format!("{}维度存在明显问题", dimension),
            context: comments.map(|s| s.to_string()),
        });
    } else if score <= 7 {
        issues.push(RubricIssue {
            issue_type: format!("{}_moderate", dimension),
            severity: IssueSeverity::Moderate,
            description: format!("{}维度有待改进", dimension),
            context: comments.map(|s| s.to_string()),
        });
    }

    issues
}

/// 计算加权总分
fn calculate_weighted_score(dimension_scores: &[RubricDimensionScore]) -> f64 {
    let mut weighted_sum = 0.0;
    let mut total_weight = 0.0;

    for dim_score in dimension_scores {
        weighted_sum += dim_score.score * dim_score.weight;
        total_weight += dim_score.weight;
    }

    if total_weight > 0.0 {
        weighted_sum / total_weight
    } else {
        0.0
    }
}

/// 评估自动评测置信度
fn assess_confidence(
    review: &QualityReview,
    dimension_scores: &[RubricDimensionScore],
) -> AutoJudgeConfidence {
    // 如果缺少关键维度数据，置信度降低
    let available_dimensions = dimension_scores.len();
    if available_dimensions < 3 {
        return AutoJudgeConfidence::Low;
    }

    // 如果存在严重问题，置信度降低
    let has_critical_issues = dimension_scores.iter().any(|ds| {
        ds.issues
            .iter()
            .any(|i| i.severity == IssueSeverity::Critical)
    });

    if has_critical_issues {
        return AutoJudgeConfidence::Medium;
    }

    // 如果是人工标记的 bad case，但自动评分较高，置信度降低
    if review.is_bad_case {
        let avg_score = calculate_weighted_score(dimension_scores);
        if avg_score > 70.0 {
            return AutoJudgeConfidence::Low;
        }
    }

    // 如果分数方差很大，置信度降低
    let scores: Vec<f64> = dimension_scores.iter().map(|ds| ds.score).collect();
    if scores.len() > 1 {
        let mean = scores.iter().sum::<f64>() / scores.len() as f64;
        let variance = scores.iter().map(|s| (s - mean).powi(2)).sum::<f64>() / scores.len() as f64;
        if variance > 1000.0 {
            // 标准差 > 31.6
            return AutoJudgeConfidence::Medium;
        }
    }

    AutoJudgeConfidence::High
}

/// 生成汇总说明
fn generate_summary(
    weighted_score: f64,
    passed: bool,
    dimension_scores: &[RubricDimensionScore],
    recommend_promotion: bool,
) -> String {
    let status = if passed { "通过" } else { "未通过" };
    let promotion_note = if recommend_promotion {
        "，建议放行"
    } else {
        ""
    };

    // 找出得分最低的维度
    let lowest_dim = dimension_scores
        .iter()
        .min_by(|a, b| a.score.partial_cmp(&b.score).unwrap());

    let weak_point = if let Some(dim) = lowest_dim {
        if dim.score < 60.0 {
            format!("，{}维度较弱", dim.dimension.display_name())
        } else {
            String::new()
        }
    } else {
        String::new()
    };

    format!(
        "加权总分 {:.1}，{}{}{}",
        weighted_score, status, promotion_note, weak_point
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn create_test_review() -> QualityReview {
        QualityReview {
            id: Uuid::new_v4(),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            user_id: Uuid::new_v4(),
            project_id: Some(1),
            script_id: Some(1),
            job_id: None,
            target_type: "video_prompt".to_string(),
            target_id: Some("test".to_string()),
            source: "auto".to_string(),
            plot_coherence: Some(8),
            character_consistency: Some(9),
            dialogue_naturalness: Some(7),
            pacing: Some(8),
            faithfulness: Some(8),
            visual_quality: Some(8),
            overall_score: Some(8),
            passed: Some(true),
            comments: None,
            skill_version: None,
            model_name: None,
            model_params: None,
            memory_delivery_priority_applied: None,
            reviewer_id: None,
            is_bad_case: false,
            bad_case_category: None,
            stage: Some("video_prompt".to_string()),
            grade: Some("A".to_string()),
            skill_file_path: None,
            skill_version_hash: None,
            next_action: None,
        }
    }

    #[test]
    fn test_score_experiment_result_high_quality() {
        let review = create_test_review();
        let summary = score_experiment_result(&review, "video_prompt");

        assert!(summary.passed);
        assert!(summary.weighted_total_score > 70.0);
        assert!(!summary.dimension_scores.is_empty());
    }

    #[test]
    fn test_score_experiment_result_bad_case() {
        let mut review = create_test_review();
        review.character_consistency = Some(2);
        review.dialogue_naturalness = Some(3);
        review.visual_quality = Some(3);
        review.overall_score = Some(3);
        review.plot_coherence = Some(3);
        review.pacing = Some(3);
        review.faithfulness = Some(3);
        review.is_bad_case = true;
        review.bad_case_category = Some("ai_artifacts".to_string());

        let summary = score_experiment_result(&review, "video_prompt");

        assert!(!summary.passed);
        assert!(summary.recommend_bad_case);
        assert!(summary.requires_human_review || summary.confidence != AutoJudgeConfidence::High);
    }

    #[test]
    fn test_normalize_score() {
        assert_eq!(normalize_score(0), 0.0);
        assert_eq!(normalize_score(5), 50.0);
        assert_eq!(normalize_score(10), 100.0);
    }

    #[test]
    fn test_calculate_weighted_score() {
        let scores = vec![
            RubricDimensionScore {
                dimension: QualityDimension::CharacterConsistency,
                score: 80.0,
                weight: 0.5,
                issues: Vec::new(),
                comment: None,
            },
            RubricDimensionScore {
                dimension: QualityDimension::EmotionExpression,
                score: 60.0,
                weight: 0.5,
                issues: Vec::new(),
                comment: None,
            },
        ];

        let weighted = calculate_weighted_score(&scores);
        assert_eq!(weighted, 70.0);
    }
}
