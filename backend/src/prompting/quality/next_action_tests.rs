//! Tests for NextAction enum and inference logic (需求 I.4)

use super::issue_type::IssueType;
use super::next_action::{
    infer_next_action, infer_suggested_action_from_bad_case_category, NextAction,
};
use super::types::QualityReview;
use uuid::Uuid;

fn make_review(
    overall_score: Option<i16>,
    passed: Option<bool>,
    is_bad_case: bool,
    grade: Option<&str>,
) -> QualityReview {
    QualityReview {
        id: Uuid::new_v4(),
        created_at: chrono::Utc::now(),
        updated_at: chrono::Utc::now(),
        user_id: Uuid::new_v4(),
        project_id: Some(1),
        script_id: Some(1),
        job_id: None,
        target_type: "storyboard".to_string(),
        target_id: Some("1".to_string()),
        source: "auto".to_string(),
        plot_coherence: None,
        character_consistency: None,
        dialogue_naturalness: None,
        pacing: None,
        faithfulness: None,
        visual_quality: None,
        overall_score,
        passed,
        comments: None,
        skill_version: None,
        model_name: None,
        model_params: None,
        memory_delivery_priority_applied: None,
        reviewer_id: None,
        is_bad_case,
        bad_case_category: None,
        stage: Some("storyboard_panel".to_string()),
        grade: grade.map(String::from),
        skill_file_path: None,
        skill_version_hash: None,
        next_action: None,
        suggested_action: None,
    }
}

#[test]
fn test_next_action_as_str() {
    assert_eq!(
        NextAction::PatchStoryboardItems.as_str(),
        "patch_storyboard_items"
    );
    assert_eq!(
        NextAction::RollbackToDirectorPlanning.as_str(),
        "rollback_to_director_planning"
    );
    assert_eq!(
        NextAction::UpdateCharacterAnchor.as_str(),
        "update_character_anchor"
    );
    assert_eq!(NextAction::Observe.as_str(), "observe");
    assert_eq!(
        NextAction::RegenerateStoryboard.as_str(),
        "regenerate_storyboard"
    );
    assert_eq!(
        NextAction::AdjustVideoPrompt.as_str(),
        "adjust_video_prompt"
    );
    assert_eq!(
        NextAction::RetryVideoGeneration.as_str(),
        "retry_video_generation"
    );
    assert_eq!(NextAction::ManualReview.as_str(), "manual_review");
}

#[test]
fn test_next_action_from_str() {
    use std::str::FromStr;

    assert_eq!(
        NextAction::from_str("patch_storyboard_items"),
        Ok(NextAction::PatchStoryboardItems)
    );
    assert_eq!(
        NextAction::from_str("rollback_to_director_planning"),
        Ok(NextAction::RollbackToDirectorPlanning)
    );
    assert_eq!(
        NextAction::from_str("update_character_anchor"),
        Ok(NextAction::UpdateCharacterAnchor)
    );
    assert_eq!(NextAction::from_str("observe"), Ok(NextAction::Observe));
    assert_eq!(
        NextAction::from_str("regenerate_storyboard"),
        Ok(NextAction::RegenerateStoryboard)
    );
    assert_eq!(
        NextAction::from_str("adjust_video_prompt"),
        Ok(NextAction::AdjustVideoPrompt)
    );
    assert_eq!(
        NextAction::from_str("retry_video_generation"),
        Ok(NextAction::RetryVideoGeneration)
    );
    assert_eq!(
        NextAction::from_str("manual_review"),
        Ok(NextAction::ManualReview)
    );
    assert!(NextAction::from_str("invalid_action").is_err());
}

#[test]
fn test_infer_next_action_grade_d_triggers_rollback() {
    let review = make_review(Some(5), Some(false), false, Some("D"));
    let action = infer_next_action(&review, &[]);
    assert_eq!(action, NextAction::RollbackToDirectorPlanning);
}

#[test]
fn test_infer_next_action_severe_score_triggers_rollback() {
    let review = make_review(Some(3), Some(false), false, Some("C"));
    let action = infer_next_action(&review, &[]);
    assert_eq!(action, NextAction::RollbackToDirectorPlanning);
}

#[test]
fn test_infer_next_action_character_consistency_triggers_update_anchor() {
    let review = make_review(Some(6), Some(true), false, Some("B"));
    let action = infer_next_action(&review, &[IssueType::CharacterConsistency]);
    assert_eq!(action, NextAction::UpdateCharacterAnchor);
}

#[test]
fn test_infer_next_action_bad_case_triggers_patch() {
    let review = make_review(Some(7), Some(true), true, Some("B"));
    let action = infer_next_action(&review, &[]);
    assert_eq!(action, NextAction::PatchStoryboardItems);
}

#[test]
fn test_infer_next_action_low_score_triggers_patch() {
    let review = make_review(Some(5), Some(false), false, Some("C"));
    let action = infer_next_action(&review, &[]);
    assert_eq!(action, NextAction::PatchStoryboardItems);
}

#[test]
fn test_infer_next_action_failed_triggers_patch() {
    let review = make_review(Some(7), Some(false), false, Some("B"));
    let action = infer_next_action(&review, &[]);
    assert_eq!(action, NextAction::PatchStoryboardItems);
}

#[test]
fn test_infer_next_action_good_review_triggers_observe() {
    let review = make_review(Some(8), Some(true), false, Some("A"));
    let action = infer_next_action(&review, &[]);
    assert_eq!(action, NextAction::Observe);
}

#[test]
fn test_next_action_serialization() {
    let action = NextAction::RegenerateStoryboard;
    let json = serde_json::to_string(&action).unwrap();
    assert_eq!(json, "\"regenerate_storyboard\"");
}

#[test]
fn test_next_action_deserialization() {
    let json = "\"adjust_video_prompt\"";
    let action: NextAction = serde_json::from_str(json).unwrap();
    assert_eq!(action, NextAction::AdjustVideoPrompt);
}

#[test]
fn test_suggested_action_mapping_from_bad_case_category() {
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("plot_hole")),
        Some("rollback_to_director_planning")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("character_break")),
        Some("update_character_anchor")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("storyboard_mismatch")),
        Some("patch_storyboard_items")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("dialogue_issue")),
        Some("adjust_video_prompt")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("visual_error")),
        Some("retry_video_generation")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("pacing_issue")),
        Some("regenerate_storyboard")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("other")),
        Some("manual_review")
    );
    assert_eq!(
        infer_suggested_action_from_bad_case_category(Some("unknown")),
        None
    );
    assert_eq!(infer_suggested_action_from_bad_case_category(None), None);
}
