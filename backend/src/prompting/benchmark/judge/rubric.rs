//! 量表定义与阶段权重配置。

use super::types::QualityDimension;
use std::collections::HashMap;

/// 量表配置
#[derive(Debug, Clone)]
pub struct RubricConfig {
    /// 各维度的权重
    pub dimension_weights: HashMap<QualityDimension, f64>,
    /// 通过阈值（加权总分）
    pub pass_threshold: f64,
    /// 推荐放行阈值
    pub promotion_threshold: f64,
    /// 推荐 golden case 阈值
    pub golden_threshold: f64,
    /// 推荐 bad case 阈值（低于此值）
    pub bad_case_threshold: f64,
}

impl RubricConfig {
    /// 创建默认配置（均等权重）
    pub fn default_config() -> Self {
        let mut weights = HashMap::new();
        for dim in QualityDimension::all() {
            weights.insert(dim, 1.0);
        }

        Self {
            dimension_weights: weights,
            pass_threshold: 70.0,
            promotion_threshold: 80.0,
            golden_threshold: 90.0,
            bad_case_threshold: 50.0,
        }
    }

    /// 归一化权重（确保总和为 1.0）
    pub fn normalize_weights(&mut self) {
        let total: f64 = self.dimension_weights.values().sum();
        if total > 0.0 {
            for weight in self.dimension_weights.values_mut() {
                *weight /= total;
            }
        }
    }
}

/// 获取指定阶段的量表配置
///
/// 不同阶段对质量维度的关注点不同：
/// - story_skeleton / adaptation_strategy: 更关注叙事抓力、台词自然度
/// - director_planning / storyboard_table: 更关注视觉连续性、镜头真实感
/// - storyboard_panel / video_prompt: 更关注人物一致性、情绪表达、AI 痕迹
pub fn get_rubric_for_stage(stage: &str) -> RubricConfig {
    let mut config = match stage {
        "story_skeleton" | "adaptation_strategy" => {
            let mut weights = HashMap::new();
            weights.insert(QualityDimension::NarrativeGrip, 3.0);
            weights.insert(QualityDimension::DialogueNaturalness, 3.0);
            weights.insert(QualityDimension::CharacterConsistency, 2.0);
            weights.insert(QualityDimension::EmotionExpression, 1.5);
            weights.insert(QualityDimension::ShotRealism, 0.5);
            weights.insert(QualityDimension::AiArtifacts, 1.0);
            weights.insert(QualityDimension::VisualContinuity, 1.0);

            RubricConfig {
                dimension_weights: weights,
                pass_threshold: 70.0,
                promotion_threshold: 80.0,
                golden_threshold: 90.0,
                bad_case_threshold: 50.0,
            }
        }
        "director_planning" | "storyboard_table" => {
            let mut weights = HashMap::new();
            weights.insert(QualityDimension::VisualContinuity, 3.0);
            weights.insert(QualityDimension::ShotRealism, 2.5);
            weights.insert(QualityDimension::NarrativeGrip, 2.0);
            weights.insert(QualityDimension::CharacterConsistency, 2.0);
            weights.insert(QualityDimension::EmotionExpression, 1.5);
            weights.insert(QualityDimension::DialogueNaturalness, 1.0);
            weights.insert(QualityDimension::AiArtifacts, 1.0);

            RubricConfig {
                dimension_weights: weights,
                pass_threshold: 70.0,
                promotion_threshold: 80.0,
                golden_threshold: 90.0,
                bad_case_threshold: 50.0,
            }
        }
        "storyboard_panel" | "video_prompt" => {
            let mut weights = HashMap::new();
            weights.insert(QualityDimension::CharacterConsistency, 3.5);
            weights.insert(QualityDimension::EmotionExpression, 3.0);
            weights.insert(QualityDimension::AiArtifacts, 2.5);
            weights.insert(QualityDimension::ShotRealism, 2.0);
            weights.insert(QualityDimension::VisualContinuity, 2.0);
            weights.insert(QualityDimension::DialogueNaturalness, 1.0);
            weights.insert(QualityDimension::NarrativeGrip, 1.0);

            RubricConfig {
                dimension_weights: weights,
                pass_threshold: 75.0,
                promotion_threshold: 85.0,
                golden_threshold: 92.0,
                bad_case_threshold: 55.0,
            }
        }
        _ => RubricConfig::default_config(),
    };

    config.normalize_weights();
    config
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config_weights_sum_to_one() {
        let mut config = RubricConfig::default_config();
        config.normalize_weights();
        let sum: f64 = config.dimension_weights.values().sum();
        assert!((sum - 1.0).abs() < 0.0001);
    }

    #[test]
    fn test_stage_specific_weights_normalized() {
        let stages = vec![
            "story_skeleton",
            "adaptation_strategy",
            "director_planning",
            "storyboard_table",
            "storyboard_panel",
            "video_prompt",
        ];

        for stage in stages {
            let config = get_rubric_for_stage(stage);
            let sum: f64 = config.dimension_weights.values().sum();
            assert!(
                (sum - 1.0).abs() < 0.0001,
                "Stage {} weights sum to {}, expected 1.0",
                stage,
                sum
            );
        }
    }

    #[test]
    fn test_video_prompt_emphasizes_character_and_emotion() {
        let config = get_rubric_for_stage("video_prompt");
        let char_weight = config
            .dimension_weights
            .get(&QualityDimension::CharacterConsistency)
            .unwrap();
        let emotion_weight = config
            .dimension_weights
            .get(&QualityDimension::EmotionExpression)
            .unwrap();
        let dialogue_weight = config
            .dimension_weights
            .get(&QualityDimension::DialogueNaturalness)
            .unwrap();

        assert!(
            char_weight > dialogue_weight,
            "video_prompt should emphasize character consistency over dialogue"
        );
        assert!(
            emotion_weight > dialogue_weight,
            "video_prompt should emphasize emotion expression over dialogue"
        );
    }

    #[test]
    fn test_story_skeleton_emphasizes_narrative() {
        let config = get_rubric_for_stage("story_skeleton");
        let narrative_weight = config
            .dimension_weights
            .get(&QualityDimension::NarrativeGrip)
            .unwrap();
        let shot_weight = config
            .dimension_weights
            .get(&QualityDimension::ShotRealism)
            .unwrap();

        assert!(
            narrative_weight > shot_weight,
            "story_skeleton should emphasize narrative grip over shot realism"
        );
    }
}
