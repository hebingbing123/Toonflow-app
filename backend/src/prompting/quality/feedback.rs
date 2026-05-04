//! Quality review to agent memory feedback loop (barrel).
//!
//! Severe storyboard/output review failures are converted into the existing
//! `rejected_video_negative_memory` chain so the next generation can directly
//! reuse them without extra LLM calls. Non-video targets still fall back to a
//! compact generic summary memory.
#![allow(dead_code)]

pub use super::feedback_generic::QualityFeedbackMemoryOutcome;
pub use super::feedback_memory::maybe_write_quality_feedback_to_memory;

#[cfg(test)]
mod tests {
    use super::super::feedback_generic::{
        build_generic_quality_feedback_content, compact_quality_review_negative_fragments,
        infer_quality_feedback_focus_tags,
    };
    use super::super::feedback_memory::QUALITY_FEEDBACK_MEMORY_NAME;
    use super::super::feedback_video::{
        build_quality_review_rejected_video_memory, prepare_selected_video_memory_for_promotion,
        should_promote_quality_review_selected_video_memory,
    };
    use crate::prompting::quality::types::QualityReview;
    use serde_json::json;
    use uuid::Uuid;

    fn sample_review() -> QualityReview {
        QualityReview {
            id: Uuid::nil(),
            created_at: chrono::Utc::now(),
            updated_at: chrono::Utc::now(),
            user_id: Uuid::nil(),
            project_id: Some(1),
            script_id: Some(2),
            job_id: None,
            target_type: "storyboard".into(),
            target_id: Some("12".into()),
            source: "manual".into(),
            plot_coherence: None,
            character_consistency: Some(5),
            dialogue_naturalness: Some(4),
            pacing: None,
            faithfulness: None,
            visual_quality: Some(4),
            overall_score: Some(4),
            passed: Some(false),
            comments: Some("表情太平像读稿，嘴型也有点对不上，逆光太硬".into()),
            skill_version: None,
            model_name: Some("demo-model".into()),
            model_params: Some(json!({})),
            memory_delivery_priority_applied: Some(true),
            reviewer_id: None,
            is_bad_case: true,
            bad_case_category: Some("dialogue_issue".into()),
            stage: Some("storyboard_table".into()),
            grade: Some("D".into()),
            skill_file_path: None,
            skill_version_hash: None,
        }
    }

    #[test]
    fn severe_storyboard_review_builds_rejected_video_memory() {
        let content = build_quality_review_rejected_video_memory(&sample_review())
            .expect("rejected video memory");
        assert!(content.contains("storyboardIds=12"), "{content}");
        assert!(content.contains("rejectionCount=2"), "{content}");
        assert!(content.contains("riskTags=dialogue"), "{content}");
        assert!(
            content.contains("avoid=avoid lip-sync mismatch"),
            "{content}"
        );
        assert!(
            content.contains("avoid blank expression or monotone delivery"),
            "{content}"
        );
    }

    #[test]
    fn non_severe_review_stays_as_observation_strength_memory() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(5);
        review.comments = Some("情绪太平，像读稿".into());
        let content =
            build_quality_review_rejected_video_memory(&review).expect("rejected video memory");
        assert!(content.contains("rejectionCount=1"), "{content}");
        assert!(
            content.contains("avoid blank expression or monotone delivery"),
            "{content}"
        );
    }

    #[test]
    fn asset_review_does_not_pretend_to_be_storyboard_scoped_video_memory() {
        let mut review = sample_review();
        review.target_type = "asset".into();
        review.target_id = Some("12".into());
        assert!(build_quality_review_rejected_video_memory(&review).is_none());
        assert!(!should_promote_quality_review_selected_video_memory(&review));
    }

    #[test]
    fn generic_feedback_content_truncates_long_comments() {
        let mut review = sample_review();
        review.target_type = "script".into();
        review.target_id = Some("script-9".into());
        review.comments = Some("a".repeat(240));
        let content = build_generic_quality_feedback_content(&review);
        assert!(content.contains("target=script-9"), "{content}");
        assert!(content.contains("low_scores=["), "{content}");
        assert!(content.contains("notes="), "{content}");
        assert!(!content.contains("model=demo-model"), "{content}");
    }

    #[test]
    fn generic_feedback_content_keeps_only_two_lowest_scores() {
        let mut review = sample_review();
        review.plot_coherence = Some(3);
        review.pacing = Some(2);
        review.faithfulness = Some(5);
        let content = build_generic_quality_feedback_content(&review);
        assert!(
            content.contains("low_scores=[pacing:2, plot_coherence:3]"),
            "{content}"
        );
        assert!(!content.contains("faithfulness:5"), "{content}");
    }

    #[test]
    fn generic_feedback_summary_memory_stays_named_for_scope_replacement() {
        assert_eq!(QUALITY_FEEDBACK_MEMORY_NAME, "quality_feedback_memory");
    }

    #[test]
    fn successful_storyboard_review_qualifies_for_selected_video_memory_promotion() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(9);
        review.comments = Some("人物状态自然，情绪和镜头都稳定".into());
        assert!(should_promote_quality_review_selected_video_memory(&review));
    }

    #[test]
    fn failed_or_low_score_storyboard_review_does_not_promote_selected_video_memory() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(7);
        assert!(!should_promote_quality_review_selected_video_memory(
            &review
        ));
        review.overall_score = Some(9);
        review.passed = Some(false);
        assert!(!should_promote_quality_review_selected_video_memory(
            &review
        ));
    }

    #[test]
    fn negative_feedback_focus_tags_capture_delivery_identity_and_lighting() {
        let tags = infer_quality_feedback_focus_tags(&sample_review(), false);
        assert_eq!(
            tags,
            vec![
                "delivery_realism".to_string(),
                "identity_continuity".to_string(),
                "lighting_realism".to_string()
            ]
        );
    }

    #[test]
    fn positive_feedback_focus_tags_capture_emotion_and_identity() {
        let mut review = sample_review();
        review.is_bad_case = false;
        review.passed = Some(true);
        review.overall_score = Some(9);
        review.dialogue_naturalness = Some(9);
        review.character_consistency = Some(9);
        review.visual_quality = Some(8);
        review.comments = Some("情绪递进自然，角色一致，光影真实自然".into());
        let tags = infer_quality_feedback_focus_tags(&review, true);
        assert_eq!(
            tags,
            vec![
                "delivery_realism".to_string(),
                "emotion_arc".to_string(),
                "identity_continuity".to_string(),
                "lighting_realism".to_string(),
            ]
        );
    }

    #[test]
    fn selected_memory_promotion_compacts_generic_delivery_fillers_when_focus_is_hot() {
        let prepared = prepare_selected_video_memory_for_promotion(
            "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声克制，情绪克制，动作从容克制，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=强忍泪意",
            &["delivery_realism".into(), "emotion_arc".into()],
        )
        .expect("prepared memory");
        assert!(
            prepared.contains("style=表演喉结滚动，光影冷蓝窗光"),
            "{prepared}"
        );
        assert!(!prepared.contains("语气低声克制"), "{prepared}");
        assert!(!prepared.contains("情绪克制"), "{prepared}");
        assert!(!prepared.contains("动作从容克制"), "{prepared}");
    }

    #[test]
    fn selected_memory_promotion_skips_low_signal_selected_memory() {
        let prepared = prepare_selected_video_memory_for_promotion(
            "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制 | note=保持克制",
            &["delivery_realism".into(), "emotion_arc".into()],
        );
        assert!(prepared.is_none());
    }

    #[test]
    fn rejected_memory_compaction_prefers_focus_aligned_fragments() {
        let compacted = compact_quality_review_negative_fragments(
            vec![
                "avoid face distortion or identity drift".into(),
                "avoid harsh backlight silhouette".into(),
                "avoid lip-sync mismatch".into(),
            ],
            &["identity_continuity".into(), "lighting_realism".into()],
        );
        assert_eq!(
            compacted,
            vec![
                "avoid face distortion or identity drift".to_string(),
                "avoid harsh backlight silhouette".to_string()
            ]
        );
    }

    #[test]
    fn severe_storyboard_review_uses_focus_tags_to_drop_lower_priority_negative_fragment() {
        let mut review = sample_review();
        review.comments = Some("串脸明显，逆光太硬，嘴型偶尔没对上".into());
        review.bad_case_category = Some("identity_issue".into());
        let content = build_quality_review_rejected_video_memory(&review)
            .expect("focused rejected video memory");
        assert!(
            content.contains(
                "avoid=avoid face distortion or identity drift, avoid harsh backlight silhouette"
            ),
            "{content}"
        );
        assert!(!content.contains("avoid lip-sync mismatch"), "{content}");
    }
}
