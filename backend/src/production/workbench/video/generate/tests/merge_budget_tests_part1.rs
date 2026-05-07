#![allow(unused_imports)]

#[cfg(test)]
mod tests {
    use crate::error::ApiError;
    use crate::production::types::GenerateVideoUploadItem;
    use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
    use crate::production::workbench::video::generate::fragment_operations::merge_negative_prompts;
    use crate::production::workbench::video::generate::memory_integration::{
        apply_project_mode_prompt_preset, compact_project_mode, compact_video_ratio,
        filter_selected_rows_for_subject, normalize_upload_sources,
        rejected_negative_memory_fetch_limit, resolve_storyboard_prompt,
        selected_memory_fetch_limit,
    };
    use crate::production::workbench::video::generate::negative_prompt_analysis::{
        compact_review_fragments_against_rejected_memory,
        review_fragment_conflicts_with_selected_style, review_fragment_is_irrelevant_to_storyboard,
        storyboard_dialogue_is_empty,
    };
    use crate::production::workbench::video::generate::negative_prompt_builder::build_storyboard_negative_prompts_test as build_storyboard_negative_prompts;
    use crate::production::workbench::video::generate::negative_prompt_core::build_storyboard_observation_negative_fragments;
    use crate::production::workbench::video::generate::utils::infer_video_provider;
    use crate::production::workbench::video::generate::{
        AutoNegativePromptSelection, NormalizedGenerateVideoUploadItem, QualityReviewSeedRow,
        RecentQualitySignalSeedRow, VideoNegativePromptBudgetTier, VIDEO_NEGATIVE_PROMPT_MAX_CHARS,
    };
    use crate::production::workbench::video_prompt_memory::{
        select_rejected_video_negative_memory_notes, storyboard_prompt_seed, AgentMemoryRow,
        StoryboardPromptSeedRow,
    };
    use sqlx::PgPool;
    use std::collections::HashMap;
    use uuid::Uuid;

    type SeedFixtureRow<'a> = (i32, Option<&'a str>, Option<&'a str>, Option<&'a str>);

    fn storyboard_seed_rows(rows: &[SeedFixtureRow<'_>]) -> HashMap<i32, StoryboardPromptSeedRow> {
        rows.iter()
            .map(|(storyboard_id, prompt, video_desc, duration)| {
                (
                    *storyboard_id,
                    StoryboardPromptSeedRow {
                        prompt: prompt.map(str::to_string),
                        video_desc: video_desc.map(str::to_string),
                        duration: duration.map(str::to_string),
                    },
                )
            })
            .collect()
    }

    #[test]
    fn build_storyboard_negative_prompts_falls_back_to_pending_observation_when_no_promoted_negative_exists(
    ) {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角冲下楼梯"),
                Some("（主角冲下楼梯、旧宅楼梯、主角、5秒、近景、稳定跟拍、冲下楼梯、紧张、室内冷光、快走、急促脚步声、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid flicker or motion jitter"));
        assert_eq!(selection.fragment_count, 1);
        assert_eq!(selection.budget_tier, "lean");
        assert_eq!(selection.review_fragment_count, 0);
        assert_eq!(selection.rejected_memory_fragment_count, 1);
        assert!(selection.used_pending_observation_fallback);
        assert_eq!(
            selection.source_label(),
            Some("pending_rejected_observation")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_narrows_frantic_guard_for_intended_panic_scene() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角惊慌冲出门厅"),
                Some("（主角惊慌冲出门厅、旧宅门厅、主角、5秒、近景、手持跟拍、狂奔冲出门厅、惊慌失控、车灯逆光、快跑啊、呼吸急促混着脚步声、A12）"),
                Some("5s"),
            )]),
        );

        assert_eq!(
            prompts
                .get(&12)
                .and_then(|value: &AutoNegativePromptSelection| value.as_deref()),
            Some("avoid oppressive mood")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_frantic_guard_for_cold_oppressive_mood() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角站在门厅冷静对峙"),
                Some("（主角站在门厅冷静对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、你终于来了、风声回响、A12）"),
                Some("5s"),
            )]),
        );

        let selection = prompts.get(&12).expect("storyboard 12 prompt");
        assert_eq!(selection.as_deref(), Some("avoid frantic mood"));
        assert_eq!(selection.budget_tier, "lean");
    }

    #[test]
    fn review_fragment_is_irrelevant_to_dialogue_free_storyboard() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角贴墙前行".into()),
            video_desc: Some("（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）".into()),
            duration: Some("5".into()),
        };

        assert!(review_fragment_is_irrelevant_to_storyboard(
            "avoid lip-sync mismatch",
            Some(&storyboard_row),
        ));
        assert!(!review_fragment_is_irrelevant_to_storyboard(
            "avoid flicker or motion jitter",
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn storyboard_dialogue_is_empty_recognizes_silent_markers() {
        assert!(storyboard_dialogue_is_empty("无台词"));
        assert!(storyboard_dialogue_is_empty("No dialogue"));
        assert!(storyboard_dialogue_is_empty("silent"));
        assert!(!storyboard_dialogue_is_empty("你终于来了"));
    }

    #[test]
    fn build_storyboard_negative_prompts_drops_lip_sync_for_silent_storyboard_only() {
        let prompts = build_storyboard_negative_prompts(
            &[12, 13],
            &[QualityReviewSeedRow {
                target_type: Some("video".into()),
                target_id: None,
                bad_case_category: Some("dialogue_issue".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[
                (
                    12,
                    Some("主角贴墙前行"),
                    Some("（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）"),
                    Some("5"),
                ),
                (
                    13,
                    Some("主角低声说你终于来了"),
                    Some("（主角低声说你终于来了、旧宅门口、主角、5秒、近景、稳定跟拍、停步低声说出、压迫、冷调逆光、你终于来了、风声压过呼吸声、A13）"),
                    Some("5"),
                ),
            ]),
        );

        assert_eq!(
            prompts
                .get(&12)
                .and_then(|value: &AutoNegativePromptSelection| value.as_deref()),
            None
        );
        assert_eq!(
            prompts
                .get(&13)
                .and_then(|value: &AutoNegativePromptSelection| value.as_deref()),
            Some("avoid lip-sync mismatch")
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_storyboard_memory_axis_when_global_review_is_higher_value(
    ) {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("明显闪烁，手部也会变形".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("character_break".into()),
                    comments: Some("角色服装和脸都会漂移".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref())
            .expect("storyboard 12 prompt");

        assert!(prompt.contains("avoid flat cold lighting"));
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
        assert!(prompt.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt.len() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS);
    }

    #[test]
    fn build_storyboard_negative_prompts_prioritizes_higher_value_constraints_under_budget() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("明显闪烁，手部也会变形".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("character_break".into()),
                    comments: Some("角色服装和脸都会漂移".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref())
            .expect("storyboard 12 prompt");

        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
        assert!(prompt.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt.contains("avoid flat cold lighting"));
        assert!(!prompt.contains("avoid oppressive or frantic mood"));
        assert!(prompt.len() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS);
    }

    #[test]
    fn compact_review_fragments_against_rejected_memory_drops_covered_global_tail_only() {
        let review_fragments = vec![
            "avoid flicker".to_string(),
            "avoid harsh backlight silhouette".to_string(),
            "avoid face drift or costume inconsistency".to_string(),
        ];
        let rejected_fragments = vec![
            "avoid flicker or motion jitter".to_string(),
            "avoid flat cold lighting".to_string(),
        ];

        assert_eq!(
            compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments),
            vec![
                "avoid harsh backlight silhouette".to_string(),
                "avoid face drift or costume inconsistency".to_string()
            ]
        );
    }

    #[test]
    fn compact_review_fragments_against_rejected_memory_trims_storyboard_mismatch_bundle_to_new_axis(
    ) {
        let review_fragments = vec!["avoid extra shot changes or wrong framing".to_string()];
        let rejected_fragments =
            vec!["avoid extreme camera angle or overly tight close-up framing".to_string()];

        assert_eq!(
            compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments),
            vec!["avoid unnecessary shot changes".to_string()]
        );
    }

    #[test]
    fn compact_review_fragments_against_rejected_memory_trims_pacing_bundle_to_new_axis() {
        let review_fragments = vec!["avoid rushed or jerky motion".to_string()];
        let rejected_fragments = vec!["avoid flicker or motion jitter".to_string()];

        assert_eq!(
            compact_review_fragments_against_rejected_memory(review_fragments, &rejected_fragments),
            vec!["avoid rushed motion".to_string()]
        );
    }

    #[test]
    fn build_storyboard_observation_negative_fragments_drops_covered_weaker_fallback_fragment() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚含泪低声说别走".into()),
            video_desc: Some("（林晚含泪低声说别走、雨夜窗边、林晚、5秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光、别走、雨声压住呼吸、A18）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            build_storyboard_observation_negative_fragments(
                vec![
                    "avoid blank expression or monotone delivery".to_string(),
                    "avoid monotone delivery".to_string(),
                    "avoid lip-sync mismatch".to_string(),
                ],
                None,
                Some(&storyboard_row),
            ),
            vec![
                "avoid blank expression or monotone delivery".to_string(),
                "avoid lip-sync mismatch".to_string(),
            ]
        );
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_global_tail_only_when_it_adds_new_axis() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: None,
                    comments: Some("闪烁明显".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: None,
                    comments: Some("逆光太重".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker or motion jitter, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        assert_eq!(
            prompts.get(&12).and_then(|value: &AutoNegativePromptSelection| value.as_deref()),
            Some("avoid flicker or motion jitter, avoid flat cold lighting or harsh backlight silhouette")
        );
    }

    #[test]
    fn selected_video_style_can_suppress_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("近景太近，情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=seed000000001 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=镜头近景，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_seed_rows(&[(
                12,
                Some("门厅对峙"),
                Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
                Some("5s"),
            )]),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn storyboard_context_can_suppress_conflicting_review_fragments_without_style_memory() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("近景太近，情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("门厅对峙"),
                Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
                Some("5s"),
            )]),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref());
        assert_eq!(prompt, None);
    }
}
