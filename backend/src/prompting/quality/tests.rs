//! prompting/quality 单元测试。

use crate::error::ApiError;
use chrono::{TimeZone, Utc};
use proptest::prelude::*;
use serde_json::json;

use super::handlers::aggregates::{TokenEfficiencyQuery, TokenEfficiencySamplesQuery};
use super::types::{
    CreateQualityReviewBody, ListQualityReviewsQuery, QualityTokenEfficiencyResponse,
    QualityTokenEfficiencySample,
};
use super::validate::{validate_create_review_body, validate_list_reviews_query};

#[test]
fn create_quality_review_body_accepts_valid() {
    let json = json!({
        "targetType": "storyboard",
        "plotCoherence": 8,
        "characterConsistency": 9,
        "dialogueNaturalness": 7,
        "pacing": 8,
        "faithfulness": 9,
        "overallScore": 8,
        "passed": true,
        "comments": "整体质量良好",
        "isBadCase": false
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.target_type, "storyboard");
    assert_eq!(body.plot_coherence, Some(8));
    assert_eq!(body.passed, Some(true));
}

#[test]
fn create_quality_review_body_rejects_unknown_fields() {
    let json = json!({
        "targetType": "storyboard",
        "unknownField": "value"
    });
    let result: Result<CreateQualityReviewBody, _> = serde_json::from_value(json);
    assert!(result.is_err());
}

#[test]
fn create_quality_review_body_accepts_bad_case() {
    let json = json!({
        "targetType": "script",
        "isBadCase": true,
        "badCaseCategory": "plot_hole",
        "comments": "剧情跑题严重",
        "overallScore": 3,
        "passed": false
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.is_bad_case, Some(true));
    assert_eq!(body.bad_case_category, Some("plot_hole".to_string()));
}

#[test]
fn create_quality_review_body_accepts_minimal() {
    let json = json!({
        "targetType": "output"
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.target_type, "output");
    assert_eq!(body.source, None);
}

#[test]
fn validate_create_review_body_rejects_invalid_source() {
    let body = CreateQualityReviewBody {
        target_type: "script".to_string(),
        source: Some("robot".to_string()),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("invalid source");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_rejects_invalid_target_type() {
    let body = CreateQualityReviewBody {
        target_type: "chapter".to_string(),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("invalid target_type");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_rejects_out_of_range_scores() {
    let body = CreateQualityReviewBody {
        target_type: "script".to_string(),
        overall_score: Some(11),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("out of range score");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_requires_project_for_script_scope() {
    let body = CreateQualityReviewBody {
        target_type: "script".to_string(),
        script_id: Some(7),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("script scope must include project");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_requires_positive_storyboard_target_id() {
    let body = CreateQualityReviewBody {
        target_type: "storyboard".to_string(),
        project_id: Some(12),
        target_id: Some("scene-1".to_string()),
        ..Default::default()
    };
    let err = validate_create_review_body(&body)
        .expect_err("storyboard review must carry positive numeric target id");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_requires_project_for_storyboard_target() {
    let body = CreateQualityReviewBody {
        target_type: "storyboard".to_string(),
        target_id: Some("12".to_string()),
        ..Default::default()
    };
    let err =
        validate_create_review_body(&body).expect_err("storyboard review must carry project scope");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_requires_storyboard_numeric_target_for_scoped_output() {
    let body = CreateQualityReviewBody {
        target_type: "output".to_string(),
        project_id: Some(12),
        target_id: Some("probe-output".to_string()),
        ..Default::default()
    };
    let err =
        validate_create_review_body(&body).expect_err("scoped output review must carry shot id");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_requires_project_scope_for_output_reviews() {
    let body = CreateQualityReviewBody {
        target_type: "output".to_string(),
        target_id: Some("12".to_string()),
        ..Default::default()
    };
    let err =
        validate_create_review_body(&body).expect_err("output review must carry project scope");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_list_reviews_query_rejects_invalid_target_type() {
    let query = ListQualityReviewsQuery {
        project_id: None,
        script_id: None,
        target_type: Some("chapter".to_string()),
        target_id: None,
        job_id: None,
        source: None,
        is_bad_case: None,
        memory_delivery_priority_applied: None,
        stage: None,
        grade: None,
        next_action: None,
        limit: None,
        offset: None,
    };
    let err = validate_list_reviews_query(&query).expect_err("invalid target type");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn list_quality_reviews_query_deserializes_scope_filters() {
    let json = json!({
        "projectId": 12,
        "scriptId": 7,
        "targetType": "storyboard"
    });
    let query: ListQualityReviewsQuery = serde_json::from_value(json).unwrap();
    assert_eq!(query.project_id, Some(12));
    assert_eq!(query.script_id, Some(7));
    assert_eq!(query.target_type.as_deref(), Some("storyboard"));
}

#[test]
fn token_efficiency_query_deserializes_scope_filters() {
    let json = json!({
        "projectId": 12,
        "scriptId": 7,
        "stage": "video_prompt",
        "modelName": "gpt-4.1",
        "callType": "quality_review"
    });
    let query: TokenEfficiencyQuery = serde_json::from_value(json).unwrap();
    assert_eq!(query.project_id, Some(12));
    assert_eq!(query.script_id, Some(7));
    assert_eq!(query.stage.as_deref(), Some("video_prompt"));
    assert_eq!(query.model_name.as_deref(), Some("gpt-4.1"));
    assert_eq!(query.call_type.as_deref(), Some("quality_review"));
}

#[test]
fn token_efficiency_samples_query_deserializes_scope_and_priority_filters() {
    let json = json!({
        "projectId": 12,
        "scriptId": 7,
        "targetType": "storyboard",
        "stage": "video_prompt",
        "modelName": "gpt-4.1",
        "callType": "quality_review",
        "memoryDeliveryPriorityApplied": true,
        "limit": 4
    });
    let query: TokenEfficiencySamplesQuery = serde_json::from_value(json).unwrap();
    assert_eq!(query.project_id, Some(12));
    assert_eq!(query.script_id, Some(7));
    assert_eq!(query.target_type.as_deref(), Some("storyboard"));
    assert_eq!(query.stage.as_deref(), Some("video_prompt"));
    assert_eq!(query.model_name.as_deref(), Some("gpt-4.1"));
    assert_eq!(query.call_type.as_deref(), Some("quality_review"));
    assert_eq!(query.memory_delivery_priority_applied, Some(true));
    assert_eq!(query.limit, Some(4));
}

// Feature: ai-drama-quality-optimization, Property 14: 质量评审筛选一致性
// 验证：需求 6.6
#[test]
fn create_quality_review_body_accepts_stage_and_grade() {
    let json = json!({
        "targetType": "storyboard",
        "stage": "storyboard_table",
        "grade": "A",
        "skillFilePath": "production_agent_execution.md",
        "skillVersionHash": "abc123"
    });
    let body: CreateQualityReviewBody = serde_json::from_value(json).unwrap();
    assert_eq!(body.stage.as_deref(), Some("storyboard_table"));
    assert_eq!(body.grade.as_deref(), Some("A"));
    assert_eq!(
        body.skill_file_path.as_deref(),
        Some("production_agent_execution.md")
    );
    assert_eq!(body.skill_version_hash.as_deref(), Some("abc123"));
}

#[test]
fn validate_create_review_body_rejects_invalid_stage() {
    let body = CreateQualityReviewBody {
        target_type: "storyboard".to_string(),
        stage: Some("invalid_stage".to_string()),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("invalid stage");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_rejects_invalid_grade() {
    let body = CreateQualityReviewBody {
        target_type: "storyboard".to_string(),
        grade: Some("E".to_string()),
        ..Default::default()
    };
    let err = validate_create_review_body(&body).expect_err("invalid grade");
    assert!(matches!(err, ApiError::BadRequest(_)));
}

#[test]
fn validate_create_review_body_accepts_all_valid_grades() {
    for grade in &["A", "B", "C", "D"] {
        let body = CreateQualityReviewBody {
            target_type: "storyboard".to_string(),
            project_id: Some(12),
            target_id: Some("7".to_string()),
            grade: Some(grade.to_string()),
            ..Default::default()
        };
        assert!(
            validate_create_review_body(&body).is_ok(),
            "grade {grade} should be valid"
        );
    }
}

#[test]
fn validate_create_review_body_accepts_all_valid_stages() {
    for stage in &[
        "story_skeleton",
        "adaptation_strategy",
        "director_planning",
        "storyboard_table",
        "storyboard_panel",
        "video_prompt",
    ] {
        let body = CreateQualityReviewBody {
            target_type: "storyboard".to_string(),
            project_id: Some(12),
            target_id: Some("7".to_string()),
            stage: Some(stage.to_string()),
            ..Default::default()
        };
        assert!(
            validate_create_review_body(&body).is_ok(),
            "stage {stage} should be valid"
        );
    }
}

#[test]
fn list_reviews_query_accepts_stage_and_grade_filters() {
    let json = json!({
        "projectId": 1,
        "stage": "director_planning",
        "grade": "B"
    });
    let query: ListQualityReviewsQuery = serde_json::from_value(json).unwrap();
    assert_eq!(query.stage.as_deref(), Some("director_planning"));
    assert_eq!(query.grade.as_deref(), Some("B"));
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(20))]

    // Feature: drama-platform-completion, Property 13: token-质量关联显式性
    // 验证：需求 17.2, 17.6
    #[test]
    fn prop_token_efficiency_response_serializes_explicit_roi_fields(
        sample_count in 1i64..50,
        high_token_low_quality_count in 0i64..20,
        stage in prop::option::of(prop_oneof![
            Just("storyboard_panel".to_string()),
            Just("video_prompt".to_string()),
        ]),
        model_name in prop::option::of("[a-z0-9._-]{3,16}"),
        call_type in prop::option::of(prop_oneof![
            Just("quality_review".to_string()),
            Just("video_generate".to_string()),
        ]),
    ) {
        let response = QualityTokenEfficiencyResponse {
            scope: "user".into(),
            target_type: "storyboard".into(),
            stage: stage.clone(),
            review_model_name: model_name.clone(),
            call_type: call_type.clone(),
            sample_count,
            avg_total_tokens: 4321.0,
            avg_prompt_tokens: 2100.0,
            avg_completion_tokens: 2221.0,
            avg_overall_score: 8.6,
            pass_rate_percent: 78.4,
            high_token_low_quality_sample_count: high_token_low_quality_count,
            high_token_low_quality_rate_percent: 33.3,
            roi_band: if high_token_low_quality_count > 0 {
                "high_token_low_quality".into()
            } else {
                "efficient".into()
            },
            avg_prompt_chars: 640.0,
            avg_non_memory_prompt_chars: 510.0,
            avg_memory_style_chars: 96.0,
            avg_memory_visual_chars: 24.0,
            avg_memory_delivery_chars: 48.0,
            avg_memory_optimization_removed_chars: 72.0,
            avg_project_scope_row_count: 2.0,
            avg_script_scope_row_count: 3.0,
            avg_role_scope_row_count: 1.0,
            avg_memory_share_percent: 15.0,
            avg_delivery_memory_share_percent: 7.5,
            delivery_priority_hit_rate_percent: 55.0,
            memory_action: "keep_delivery_memory".into(),
            memory_focus: "delivery".into(),
            memory_reason: "dialogue_naturalness".into(),
        };

        let value = serde_json::to_value(&response).expect("serialize aggregate");

        prop_assert_eq!(value["scope"].as_str(), Some("user"));
        prop_assert_eq!(value["sampleCount"].as_i64(), Some(sample_count));
        prop_assert_eq!(value["highTokenLowQualitySampleCount"].as_i64(), Some(high_token_low_quality_count));
        prop_assert_eq!(value["roiBand"].as_str(), Some(response.roi_band.as_str()));
        prop_assert_eq!(value["avgMemorySharePercent"].as_f64(), Some(15.0));
        prop_assert_eq!(value["deliveryPriorityHitRatePercent"].as_f64(), Some(55.0));
        prop_assert_eq!(value["memoryAction"].as_str(), Some("keep_delivery_memory"));
        prop_assert_eq!(value["memoryFocus"].as_str(), Some("delivery"));
        prop_assert_eq!(value["memoryReason"].as_str(), Some("dialogue_naturalness"));
        prop_assert_eq!(value.get("stage").and_then(serde_json::Value::as_str), stage.as_deref());
        prop_assert_eq!(value.get("reviewModelName").and_then(serde_json::Value::as_str), model_name.as_deref());
        prop_assert_eq!(value.get("callType").and_then(serde_json::Value::as_str), call_type.as_deref());
    }

    #[test]
    fn prop_token_efficiency_sample_serializes_explicit_cost_quality_dimensions(
        total_tokens in 1i32..10000,
        memory_style_chars in 0i32..2000,
        delivery_priority_applied in any::<bool>(),
        budget_tier in prop::option::of(prop_oneof![
            Just("lean".to_string()),
            Just("expanded".to_string()),
        ]),
    ) {
        let sample = QualityTokenEfficiencySample {
            scope: "user".into(),
            created_at: Utc.timestamp_opt(1_715_000_000, 0).single().unwrap(),
            target_type: "storyboard".into(),
            stage: Some("video_prompt".into()),
            review_model_name: Some("gpt-4.1".into()),
            call_type: "quality_review".into(),
            total_tokens,
            prompt_tokens: total_tokens / 2,
            completion_tokens: total_tokens - (total_tokens / 2),
            overall_score: Some(8),
            memory_budget_tier: budget_tier.clone(),
            auto_negative_source: Some("rejected_memory".into()),
            prompt_chars: 640,
            non_memory_prompt_chars: 510,
            memory_style_chars,
            memory_visual_chars: 24,
            memory_delivery_chars: 48,
            memory_optimization_removed_chars: 72,
            project_scope_row_count: 2,
            script_scope_row_count: 3,
            role_scope_row_count: 1,
            memory_share_percent: 15.0,
            delivery_memory_share_percent: 7.5,
            memory_delivery_priority_applied: delivery_priority_applied,
        };

        let value = serde_json::to_value(&sample).expect("serialize sample");

        prop_assert_eq!(value["scope"].as_str(), Some("user"));
        prop_assert_eq!(value["totalTokens"].as_i64(), Some(total_tokens.into()));
        prop_assert_eq!(value["memoryStyleChars"].as_i64(), Some(memory_style_chars.into()));
        prop_assert_eq!(value["memorySharePercent"].as_f64(), Some(15.0));
        prop_assert_eq!(value["deliveryMemorySharePercent"].as_f64(), Some(7.5));
        prop_assert_eq!(value["memoryDeliveryPriorityApplied"].as_bool(), Some(delivery_priority_applied));
        prop_assert_eq!(value["autoNegativeSource"].as_str(), Some("rejected_memory"));
        prop_assert_eq!(value.get("memoryBudgetTier").and_then(serde_json::Value::as_str), budget_tier.as_deref());
    }
}

// Feature: drama-platform-completion, Task 15: quality-review-driven optimization

#[cfg(test)]
mod task15_tests {
    use chrono::Utc;
    use serde_json::json;
    use uuid::Uuid;

    use super::super::issue_type::{infer_issue_types, IssueType};
    use super::super::next_action::{infer_next_action, NextAction};
    use super::super::types::{BadCaseFrequencyItem, QualityReview, SkillVersionComparisonItem};

    fn base_review() -> QualityReview {
        QualityReview {
            id: Uuid::new_v4(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            user_id: Uuid::new_v4(),
            project_id: Some(1),
            script_id: Some(1),
            job_id: None,
            target_type: "storyboard".into(),
            target_id: None,
            source: "manual".into(),
            plot_coherence: None,
            character_consistency: None,
            dialogue_naturalness: None,
            pacing: None,
            faithfulness: None,
            visual_quality: None,
            overall_score: None,
            passed: None,
            comments: None,
            skill_version: None,
            model_name: None,
            model_params: None,
            memory_delivery_priority_applied: None,
            reviewer_id: None,
            is_bad_case: false,
            bad_case_category: None,
            stage: None,
            grade: None,
            skill_file_path: None,
            skill_version_hash: None,
            next_action: None,
        }
    }

    // infer_issue_types: CharacterConsistency via score
    #[test]
    fn infer_issue_types_character_consistency_from_score() {
        let review = QualityReview {
            character_consistency: Some(4),
            ..base_review()
        };
        let types = infer_issue_types(&review);
        assert!(types.contains(&IssueType::CharacterConsistency));
    }

    // infer_issue_types: EmotionExpression via comment
    #[test]
    fn infer_issue_types_emotion_expression_from_comment() {
        let review = QualityReview {
            comments: Some("整体情绪平，没有起伏".into()),
            ..base_review()
        };
        let types = infer_issue_types(&review);
        assert!(types.contains(&IssueType::EmotionExpression));
    }

    // infer_issue_types: DialogueStiffness via category
    #[test]
    fn infer_issue_types_dialogue_stiffness_from_category() {
        let review = QualityReview {
            bad_case_category: Some("dialogue_issue".into()),
            is_bad_case: true,
            ..base_review()
        };
        let types = infer_issue_types(&review);
        assert!(types.contains(&IssueType::DialogueStiffness));
    }

    // infer_issue_types: AiArtifact via comment
    #[test]
    fn infer_issue_types_ai_artifact_from_comment() {
        let review = QualityReview {
            comments: Some("一眼AI，塑料感很强".into()),
            ..base_review()
        };
        let types = infer_issue_types(&review);
        assert!(types.contains(&IssueType::AiArtifact));
    }

    // infer_issue_types: ShotRhythm via pacing_issue category
    #[test]
    fn infer_issue_types_shot_rhythm_from_category() {
        let review = QualityReview {
            bad_case_category: Some("pacing_issue".into()),
            is_bad_case: true,
            ..base_review()
        };
        let types = infer_issue_types(&review);
        assert!(types.contains(&IssueType::ShotRhythm));
    }

    // infer_issue_types: VisualContinuity via visual_quality score
    #[test]
    fn infer_issue_types_visual_continuity_from_score() {
        let review = QualityReview {
            visual_quality: Some(3),
            ..base_review()
        };
        let types = infer_issue_types(&review);
        assert!(types.contains(&IssueType::VisualContinuity));
    }

    // infer_next_action: RollbackToDirectorPlanning for grade D
    #[test]
    fn infer_next_action_rollback_for_grade_d() {
        let review = QualityReview {
            grade: Some("D".into()),
            ..base_review()
        };
        let action = infer_next_action(&review, &[]);
        assert_eq!(action, NextAction::RollbackToDirectorPlanning);
    }

    // infer_next_action: RollbackToDirectorPlanning for severe score
    #[test]
    fn infer_next_action_rollback_for_severe_score() {
        let review = QualityReview {
            overall_score: Some(3),
            ..base_review()
        };
        let action = infer_next_action(&review, &[]);
        assert_eq!(action, NextAction::RollbackToDirectorPlanning);
    }

    // infer_next_action: UpdateCharacterAnchor when CharacterConsistency issue
    #[test]
    fn infer_next_action_update_character_anchor() {
        let review = base_review();
        let action = infer_next_action(&review, &[IssueType::CharacterConsistency]);
        assert_eq!(action, NextAction::UpdateCharacterAnchor);
    }

    // infer_next_action: PatchStoryboardItems for bad case
    #[test]
    fn infer_next_action_patch_for_bad_case() {
        let review = QualityReview {
            is_bad_case: true,
            ..base_review()
        };
        let action = infer_next_action(&review, &[IssueType::EmotionExpression]);
        assert_eq!(action, NextAction::PatchStoryboardItems);
    }

    // infer_next_action: Observe for passing review
    #[test]
    fn infer_next_action_observe_for_passing_review() {
        let review = QualityReview {
            overall_score: Some(8),
            passed: Some(true),
            grade: Some("A".into()),
            ..base_review()
        };
        let action = infer_next_action(&review, &[]);
        assert_eq!(action, NextAction::Observe);
    }

    // BadCaseFrequencyItem serializes correctly
    #[test]
    fn bad_case_frequency_item_serializes() {
        let item = BadCaseFrequencyItem {
            scope: "user".into(),
            issue_type: "dialogue_stiffness".into(),
            raw_category: Some("dialogue_issue".into()),
            count: 4,
            is_high_frequency: true,
            sample_comments: vec!["读文章感很强".into()],
        };
        let v = serde_json::to_value(&item).unwrap();
        assert_eq!(v["scope"], "user");
        assert_eq!(v["issueType"], "dialogue_stiffness");
        assert_eq!(v["count"], 4);
        assert_eq!(v["isHighFrequency"], true);
        assert_eq!(v["rawCategory"], "dialogue_issue");
    }

    // SkillVersionComparisonItem serializes correctly
    #[test]
    fn skill_version_comparison_item_serializes() {
        let item = SkillVersionComparisonItem {
            scope: "user".into(),
            skill_file_path: "art_skills/2D_90s_japanese_anime/art_prompt/art_storyboard_video.md"
                .into(),
            skill_version_hash: "abc12345".into(),
            total_count: 10,
            pass_rate_percent: 80.0,
            avg_score: 7.5,
            bad_case_rate_percent: 10.0,
            grade_a_count: 3,
            grade_b_count: 5,
            grade_c_count: 1,
            grade_d_count: 1,
        };
        let v = serde_json::to_value(&item).unwrap();
        assert_eq!(v["scope"], "user");
        assert_eq!(v["skillVersionHash"], "abc12345");
        assert_eq!(v["passRatePercent"], 80.0);
        assert_eq!(v["gradeACount"], 3);
        assert_eq!(v["badCaseRatePercent"], 10.0);
    }

    // IssueType as_str round-trips
    #[test]
    fn issue_type_as_str_covers_all_variants() {
        let all = [
            (IssueType::CharacterConsistency, "character_consistency"),
            (IssueType::EmotionExpression, "emotion_expression"),
            (IssueType::ShotRhythm, "shot_rhythm"),
            (IssueType::VisualContinuity, "visual_continuity"),
            (IssueType::DialogueStiffness, "dialogue_stiffness"),
            (IssueType::AiArtifact, "ai_artifact"),
        ];
        for (variant, expected) in all {
            assert_eq!(variant.as_str(), expected);
        }
    }

    // NextAction as_str round-trips
    #[test]
    fn next_action_as_str_covers_all_variants() {
        let all = [
            (NextAction::PatchStoryboardItems, "patch_storyboard_items"),
            (
                NextAction::RollbackToDirectorPlanning,
                "rollback_to_director_planning",
            ),
            (NextAction::UpdateCharacterAnchor, "update_character_anchor"),
            (NextAction::Observe, "observe"),
        ];
        for (variant, expected) in all {
            assert_eq!(variant.as_str(), expected);
        }
    }

    // merge_issue_diagnostics preserves existing diagnostics fields
    #[test]
    fn merge_issue_diagnostics_preserves_existing_fields() {
        use super::super::handlers::create::tests::call_merge_issue_diagnostics;
        let merged = call_merge_issue_diagnostics(
            Some(json!({"diagnostics": {"promptChars": 512}})),
            &[IssueType::DialogueStiffness],
            &NextAction::PatchStoryboardItems,
        );
        assert_eq!(merged["diagnostics"]["promptChars"], 512);
        assert_eq!(
            merged["diagnostics"]["nextAction"],
            "patch_storyboard_items"
        );
        let issue_types = merged["diagnostics"]["issueTypes"].as_array().unwrap();
        assert_eq!(issue_types[0], "dialogue_stiffness");
    }
}
