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

    fn storyboard_seed_rows(
        rows: &[(i32, Option<&str>, Option<&str>, Option<&str>)],
    ) -> HashMap<i32, StoryboardPromptSeedRow> {
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
    fn filter_selected_rows_for_subject_skips_other_subject_exact_memory() {
        let filtered = filter_selected_rows_for_subject(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景，情绪冷峻压迫".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制".into(),
                },
                AgentMemoryRow {
                    name: "script_video_style_memory".into(),
                    content: "style=镜头稳定跟拍，情绪冷峻压迫".into(),
                },
            ],
            &["林晚".to_string(), "晚晚".to_string()],
        );

        assert_eq!(filtered.len(), 2);
        assert!(filtered.iter().any(|row| {
            row.name == "selected_video_memory" && row.content.contains("subject=林晚")
        }));
        assert!(filtered
            .iter()
            .any(|row| row.name == "script_video_style_memory"));
        assert!(!filtered.iter().any(|row| {
            row.name == "selected_video_memory" && row.content.contains("subject=顾承泽")
        }));
    }

    #[test]
    fn script_video_style_summary_can_suppress_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn script_video_style_summary_with_ascii_delimiters_can_suppress_conflicting_review_fragments()
    {
        let storyboard_rows = storyboard_seed_rows(&[(
            12,
            Some("门厅对峙"),
            Some("（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"),
            Some("5s"),
        )]);
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光 | note=镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光"
                        .into(),
            }],
            &storyboard_rows,
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn script_video_style_summary_can_suppress_conflicting_rejected_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                        .into(),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn rejected_fragments_keep_non_conflicting_constraints_under_style_memory() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid face drift or costume inconsistency"
                        .into(),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref())
            .expect("storyboard 12 prompt");
        assert_eq!(prompt, "avoid face drift or costume inconsistency");
    }

    #[test]
    fn selected_video_style_does_not_suppress_non_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定".into()),
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
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref())
            .expect("storyboard 12 prompt");
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
    }

    #[test]
    fn script_style_summary_does_not_suppress_conflicting_rejected_fragments_when_storyboard_context_mismatches(
    ) {
        let storyboard_rows = storyboard_seed_rows(&[(
            12,
            Some("女主在雨夜街口停下"),
            Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、静止镜头、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）"),
            Some("5s"),
        )]);
        let prompt_seed = storyboard_rows
            .get(&12)
            .and_then(storyboard_prompt_seed)
            .expect("storyboard prompt seed");
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={prompt_seed} | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                ),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=4 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_rows,
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref())
            .expect("storyboard 12 prompt");
        assert!(prompt.contains("avoid oppressive or frantic mood"));
    }

    #[test]
    fn project_style_summary_still_suppresses_conflicting_review_when_context_matches() {
        let storyboard_rows = storyboard_seed_rows(&[(
            12,
            Some("门厅对峙"),
            Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）"),
            Some("5s"),
        )]);
        let prompt_seed = storyboard_rows
            .get(&12)
            .and_then(storyboard_prompt_seed)
            .expect("storyboard prompt seed");
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={prompt_seed} | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                ),
            }],
            &[AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &storyboard_rows,
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value: &AutoNegativePromptSelection| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn review_fragment_conflict_filter_is_limited_to_exact_selected_style_signals() {
        assert!(review_fragment_conflicts_with_selected_style(
            "avoid overly tight close-up framing",
            Some("镜头近景，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
        assert!(!review_fragment_conflicts_with_selected_style(
            "avoid wrong setting details",
            Some("镜头近景，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
    }

    #[test]
    fn resolve_storyboard_prompt_prefers_storyboard_override() {
        let item = NormalizedGenerateVideoUploadItem {
            storyboard_id: 12,
            source_url: "https://example.com/frame.png".into(),
            prompt: Some("storyboard prompt".into()),
            negative_prompt: None,
        };

        let prompt = resolve_storyboard_prompt(&item, "global prompt").expect("prompt");

        assert_eq!(prompt, "storyboard prompt");
    }

    #[test]
    fn resolve_storyboard_prompt_requires_storyboard_or_global_prompt() {
        let item = NormalizedGenerateVideoUploadItem {
            storyboard_id: 12,
            source_url: "https://example.com/frame.png".into(),
            prompt: None,
            negative_prompt: None,
        };

        let err = resolve_storyboard_prompt(&item, "").expect_err("missing prompt should fail");

        match err {
            ApiError::BadRequest(message) => {
                assert_eq!(message, "prompt must not be empty for storyboard 12");
            }
            other => panic!("unexpected error: {other:?}"),
        }
    }

    #[test]
    fn infer_video_provider_defaults_to_runway() {
        assert_eq!(infer_video_provider("gen-2"), "runway");
        assert_eq!(infer_video_provider("kling-v1"), "kling");
        assert_eq!(infer_video_provider("pika-1.5"), "pika");
    }

    #[test]
    fn compact_video_ratio_recognizes_common_formats() {
        assert_eq!(compact_video_ratio("vertical 9:16"), Some("9:16".into()));
        assert_eq!(compact_video_ratio("horizontal"), Some("16:9".into()));
        assert_eq!(compact_video_ratio("square 1:1"), Some("1:1".into()));
        assert_eq!(compact_video_ratio(""), None);
    }

    #[test]
    fn compact_project_mode_recognizes_supported_modes() {
        assert_eq!(
            compact_project_mode("live_action.short_drama"),
            Some("live_action.short_drama".into())
        );
        assert_eq!(
            compact_project_mode("animated.short_drama"),
            Some("animated.short_drama".into())
        );
        assert_eq!(compact_project_mode(""), None);
    }

    #[test]
    fn apply_project_mode_prompt_preset_adds_live_action_direction() {
        let prompt = apply_project_mode_prompt_preset(
            "夜晚巷口对峙，角色压低声音说话",
            Some("live_action.short_drama"),
        );
        assert!(prompt.contains("真人短剧写实"));
        assert!(prompt.contains("演员微表情和情绪递进"));
        assert!(prompt.contains("口型同步"));
        assert!(prompt.contains("身份一致"));
        assert!(prompt.contains("避免AI感卡通感"));
        assert!(prompt.chars().count() < 64, "{prompt}");
    }

    #[test]
    fn apply_project_mode_prompt_preset_adds_animated_direction() {
        let prompt = apply_project_mode_prompt_preset(
            "夜晚巷口对峙，角色压低声音说话",
            Some("animated.short_drama"),
        );
        assert!(prompt.contains("动漫短剧风格"));
        assert!(prompt.contains("角色表演有情绪层次"));
        assert!(prompt.contains("动作镜头利落清晰"));
        assert!(prompt.contains("避免过强真人纪实感"));
        assert!(prompt.chars().count() < 58, "{prompt}");
    }

    #[test]
    fn apply_project_mode_prompt_preset_avoids_duplicate_live_action_hint() {
        let prompt = apply_project_mode_prompt_preset(
            "真人短剧风格，夜晚巷口对峙",
            Some("live_action.short_drama"),
        );
        assert_eq!(prompt, "真人短剧风格，夜晚巷口对峙");
    }

    #[test]
    fn rejected_negative_memory_fetch_limit_scales_up_to_keep_window() {
        assert_eq!(rejected_negative_memory_fetch_limit(0), 8);
        assert_eq!(rejected_negative_memory_fetch_limit(1), 8);
        assert_eq!(rejected_negative_memory_fetch_limit(5), 10);
        assert_eq!(rejected_negative_memory_fetch_limit(9), 12);
    }

    #[test]
    fn selected_memory_fetch_limit_reserves_room_for_summary_rows() {
        assert_eq!(selected_memory_fetch_limit(0), 8);
        assert_eq!(selected_memory_fetch_limit(1), 8);
        assert_eq!(selected_memory_fetch_limit(4), 10);
        assert_eq!(selected_memory_fetch_limit(8), 14);
    }
}
