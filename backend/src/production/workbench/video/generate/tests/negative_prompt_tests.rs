use super::super::fragment_operations::{
    clip_negative_prompt, merge_negative_prompts,
    prune_negative_prompt_fragments_for_recent_quality,
};
use super::super::memory_integration::{
    compact_video_ratio, filter_selected_rows_for_subject, load_auto_negative_prompts,
    negative_review_fetch_limit, normalize_upload_sources, rejected_negative_memory_fetch_limit,
    resolve_storyboard_prompt, selected_memory_fetch_limit,
};
use super::super::negative_prompt_analysis::{
    compact_negative_constraint_against_storyboard_style,
    compact_review_fragments_against_rejected_memory, resolve_negative_filter_style_note,
    review_fragment_conflicts_with_selected_style, review_fragment_is_irrelevant_to_storyboard,
    storyboard_dialogue_is_empty,
};
use super::super::negative_prompt_builder::{
    build_storyboard_negative_prompts_test as build_storyboard_negative_prompts,
    build_storyboard_negative_prompts_with_recent_quality,
    compact_negative_fragment_against_storyboard_risk, negative_fragment_matches_storyboard_risk,
    prune_storyboard_negative_fragments,
};
use super::super::quality_control::{
    collect_negative_review_fragments, compact_negative_review_constraints,
    infer_negative_fragments_from_comments, map_bad_case_category_with_comments,
    pacing_issue_category_is_redundant, quality_review_row_matches_storyboard,
    storyboard_mismatch_category_is_redundant, visual_error_category_is_redundant,
};
use super::super::utils::infer_video_provider;
use super::super::{
    AutoNegativePromptSelection, NormalizedGenerateVideoUploadItem, QualityReviewSeedRow,
    RecentQualitySignalSeedRow, VideoNegativePromptBudgetTier, VIDEO_NEGATIVE_PROMPT_MAX_CHARS,
};
use crate::error::ApiError;
use crate::production::types::GenerateVideoUploadItem;
use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
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
fn normalize_upload_sources_rejects_duplicate_storyboards() {
    let err = normalize_upload_sources(&[
        GenerateVideoUploadItem {
            id: 3,
            sources: "https://example.com/a.png".into(),
            prompt: None,
            negative_prompt: None,
        },
        GenerateVideoUploadItem {
            id: 3,
            sources: "https://example.com/b.png".into(),
            prompt: None,
            negative_prompt: None,
        },
    ])
    .unwrap_err();
    assert!(matches!(
        err,
        crate::error::ApiError::BadRequest(message)
            if message == "uploadData must not contain duplicate storyboard ids"
    ));
}

#[test]
fn compact_negative_review_constraints_prefers_short_visual_failures() {
    let prompt = compact_negative_review_constraints(&[
        QualityReviewSeedRow {
            target_type: None,
            target_id: None,
            bad_case_category: Some("visual_error".into()),
            comments: Some("手指变形且有闪烁".into()),
        },
        QualityReviewSeedRow {
            target_type: None,
            target_id: None,
            bad_case_category: Some("character_break".into()),
            comments: Some("角色脸不稳定，服装漂移".into()),
        },
    ])
    .expect("negative prompt");

    assert!(
        prompt.contains("avoid warped hands or limbs")
            || prompt.contains("avoid warped anatomy, blur, flicker")
    );
    assert!(
        prompt.contains("avoid flicker or motion jitter")
            || prompt.contains("avoid warped anatomy, blur, flicker")
    );
    assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
    assert!(!prompt.contains("avoid costume or character drift"));
}

#[test]
fn infer_negative_fragments_from_comments_matches_cn_and_en_keywords() {
    let fragments =
        infer_negative_fragments_from_comments("面部崩坏并且 flicker，镜头切换也多而且画面发糊");
    assert!(fragments.contains(&"avoid face distortion or identity drift"));
    assert!(fragments.contains(&"avoid flicker or motion jitter"));
    assert!(fragments.contains(&"avoid blur"));
    assert!(fragments.contains(&"avoid unnecessary shot changes"));
}

#[test]
fn visual_error_category_is_redundant_when_comments_already_cover_multiple_visual_axes() {
    assert!(visual_error_category_is_redundant(
        &infer_negative_fragments_from_comments("手指变形、画面模糊还有闪烁")
    ));
    assert!(!visual_error_category_is_redundant(
        &infer_negative_fragments_from_comments("手指变形还有闪烁")
    ));
}

#[test]
fn storyboard_mismatch_category_is_redundant_when_comments_cover_shot_change_and_framing() {
    assert!(storyboard_mismatch_category_is_redundant(
        &infer_negative_fragments_from_comments("切镜太多而且近景裁切太紧")
    ));
    assert!(!storyboard_mismatch_category_is_redundant(
        &infer_negative_fragments_from_comments("切镜太多")
    ));
}

#[test]
fn prune_storyboard_negative_fragments_drops_unmatched_risk_for_grounded_silent_shot() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（男主坐在木桌前、室内书房、男主、4秒、中景、静止、低头翻开信纸、平静、室内暖光、无台词、纸张摩擦声、A03）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        prune_storyboard_negative_fragments(
            vec![
                "avoid lip-sync mismatch".into(),
                "avoid harsh backlight silhouette".into(),
                "avoid face distortion or identity drift".into(),
            ],
            Some(&storyboard_row),
        ),
        vec!["avoid face distortion or identity drift".to_string()]
    );
}

#[test]
fn negative_fragment_matches_storyboard_risk_keeps_dialogue_and_lighting_for_risky_shot() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（女主逼近门厅、旧宅门厅、女主、5秒、近景、推进、停步回头、克制、冷调逆光、你别再骗我、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert!(negative_fragment_matches_storyboard_risk(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
    assert!(negative_fragment_matches_storyboard_risk(
        "avoid harsh backlight silhouette",
        Some(&storyboard_row),
    ));
    assert!(negative_fragment_matches_storyboard_risk(
        "avoid extreme camera angle or overly tight close-up framing",
        Some(&storyboard_row),
    ));
}

#[test]
fn compact_negative_fragment_against_storyboard_risk_keeps_shot_change_only_for_grounded_shot() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_negative_fragment_against_storyboard_risk(
            "avoid extra shot changes or wrong framing",
            Some(&storyboard_row),
        )
        .as_deref(),
        Some("avoid unnecessary shot changes")
    );
}

#[test]
fn compact_negative_fragment_against_storyboard_risk_drops_motion_half_for_static_visual_error() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_negative_fragment_against_storyboard_risk(
            "avoid warped anatomy, blur, flicker",
            Some(&storyboard_row),
        )
        .as_deref(),
        Some("avoid warped anatomy or blur")
    );
}

#[test]
fn compact_negative_fragment_against_storyboard_risk_keeps_only_matching_lighting_half() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚停在门厅、旧宅门厅、林晚、5秒、中景、静止、停步抬头、克制、阴天冷光、无台词、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert_eq!(
        compact_negative_fragment_against_storyboard_risk(
            "avoid flat cold lighting or harsh backlight silhouette",
            Some(&storyboard_row),
        )
        .as_deref(),
        Some("avoid flat cold lighting")
    );
}

#[test]
fn compact_negative_fragment_against_storyboard_risk_swaps_generic_lighting_bundle_for_reflection_axis(
) {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（主角穿过雨巷、霓虹雨巷、主角、5秒、中景、稳定跟拍、踩水快步穿行、克制、霓虹反光、无台词、雨声脚步声、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert_eq!(
        compact_negative_fragment_against_storyboard_risk(
            "avoid flat cold lighting or harsh backlight silhouette",
            Some(&storyboard_row),
        )
        .as_deref(),
        Some("avoid distracting neon reflections")
    );
}

#[test]
fn pacing_issue_category_is_redundant_when_comments_cover_rushed_and_jerky_motion() {
    assert!(pacing_issue_category_is_redundant(
        &infer_negative_fragments_from_comments("动作太赶，还有明显抖动")
    ));
    assert!(!pacing_issue_category_is_redundant(
        &infer_negative_fragments_from_comments("动作太赶")
    ));
}

#[test]
fn map_bad_case_category_with_comments_skips_visual_error_when_comments_are_specific_enough() {
    assert_eq!(
        map_bad_case_category_with_comments("visual_error", Some("手指变形、画面模糊还有闪烁")),
        None
    );
    assert_eq!(
        map_bad_case_category_with_comments("visual_error", Some("手指变形还有闪烁")),
        Some("avoid warped anatomy, blur, flicker")
    );
    assert_eq!(
        map_bad_case_category_with_comments(
            "storyboard_mismatch",
            Some("切镜太多而且近景裁切太紧")
        ),
        None
    );
    assert_eq!(
        map_bad_case_category_with_comments("pacing_issue", Some("动作太赶，还有明显抖动")),
        None
    );
    assert_eq!(
        map_bad_case_category_with_comments("pacing_issue", Some("动作太赶")),
        Some("avoid rushed or jerky motion")
    );
}

#[test]
fn collect_negative_review_fragments_prioritizes_storyboard_specific_high_value_constraints() {
    let fragments = collect_negative_review_fragments(
        &[
            QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            },
            QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("visual_error".into()),
                comments: Some("背景不对而且镜头切换太多".into()),
            },
            QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定，服装漂移".into()),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        fragments.first().map(String::as_str),
        Some("avoid costume or character drift")
    );
    assert!(fragments.contains(&"avoid warped anatomy, blur, flicker".to_string()));
    assert!(fragments.contains(&"avoid extra shot changes or wrong framing".to_string()));
}

#[test]
fn collect_negative_review_fragments_skips_generic_visual_error_when_comments_are_specific() {
    let fragments = collect_negative_review_fragments(
        &[QualityReviewSeedRow {
            target_type: Some("storyboard".into()),
            target_id: Some("12".into()),
            bad_case_category: Some("visual_error".into()),
            comments: Some("手指变形、画面模糊还有闪烁".into()),
        }],
        12,
        None,
    );

    assert!(fragments.contains(&"avoid warped hands or limbs".to_string()));
    assert!(fragments.contains(&"avoid blur".to_string()));
    assert!(fragments.contains(&"avoid flicker or motion jitter".to_string()));
    assert!(!fragments.contains(&"avoid warped anatomy, blur, flicker".to_string()));
}

#[test]
fn collect_negative_review_fragments_pulls_reflection_guard_from_comments() {
    let fragments = collect_negative_review_fragments(
        &[QualityReviewSeedRow {
            target_type: Some("storyboard".into()),
            target_id: Some("12".into()),
            bad_case_category: None,
            comments: Some("霓虹反光太脏，玻璃反射抢戏".into()),
        }],
        12,
        None,
    );

    assert!(fragments.contains(&"avoid distracting neon reflections".to_string()));
}

#[test]
fn collect_negative_review_fragments_skips_generic_storyboard_and_pacing_tags_when_comments_are_specific(
) {
    let fragments = collect_negative_review_fragments(
        &[
            QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: Some("切镜太多而且近景裁切太紧".into()),
            },
            QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("pacing_issue".into()),
                comments: Some("动作太赶，还有明显抖动".into()),
            },
        ],
        12,
        None,
    );

    assert!(fragments.contains(&"avoid unnecessary shot changes".to_string()));
    assert!(fragments
        .contains(&"avoid extreme camera angle or overly tight close-up framing".to_string()));
    assert!(fragments.contains(&"avoid rushed motion".to_string()));
    assert!(fragments.contains(&"avoid flicker or motion jitter".to_string()));
    assert!(!fragments.contains(&"avoid extra shot changes or wrong framing".to_string()));
    assert!(!fragments.contains(&"avoid rushed or jerky motion".to_string()));
}

#[test]
fn collect_negative_review_fragments_prefers_delivery_axis_when_recent_quality_bias_requests_it() {
    let fragments = collect_negative_review_fragments(
        &[
            QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("visual_error".into()),
                comments: Some("手指有点变形".into()),
            },
            QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            },
        ],
        12,
        Some(VideoPromptConstraintPressure {
            prefer_delivery_memory_recall: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(
        fragments.first().map(String::as_str),
        Some("avoid blank expression or monotone delivery")
    );
}

#[test]
fn build_storyboard_negative_prompts_with_recent_quality_bias_prefers_delivery_rejected_memory() {
    let prompts = build_storyboard_negative_prompts_with_recent_quality(
            &[12],
            &[],
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=3 | avoid=avoid flat cold lighting"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=3 | avoid=avoid blank expression or monotone delivery"
                            .into(),
                },
            ],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声开口"),
                Some("（晚晚低声开口、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
            &[RecentQualitySignalSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                passed: Some(false),
                overall_score: Some(5),
                dialogue_naturalness: Some(5),
                character_consistency: Some(8),
                visual_quality: Some(7),
                memory_delivery_priority_applied: Some(false),
                is_bad_case: true,
                bad_case_category: Some("dialogue".into()),
                comments: Some("台词像读文章，没情绪".into()),
                feedback_memory_focus_tags: None,
            }],
        );

    assert_eq!(
        prompts.get(&12).and_then(|value| value.as_deref()),
        Some("avoid blank expression or monotone delivery")
    );
}

#[test]
fn build_storyboard_negative_prompts_with_recent_quality_bias_drops_generic_mood_tail_when_delivery_guard_exists(
) {
    let prompts = build_storyboard_negative_prompts_with_recent_quality(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("像读稿，情绪平".into()),
            }],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid blank expression or monotone delivery, avoid oppressive or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声开口"),
                Some("（晚晚低声开口、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
            &[RecentQualitySignalSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                passed: Some(false),
                overall_score: Some(5),
                dialogue_naturalness: Some(5),
                character_consistency: Some(8),
                visual_quality: Some(7),
                memory_delivery_priority_applied: Some(false),
                is_bad_case: true,
                bad_case_category: Some("dialogue".into()),
                comments: Some("台词像读文章，没情绪".into()),
                feedback_memory_focus_tags: None,
            }],
        );

    assert_eq!(
        prompts.get(&12).and_then(|value| value.as_deref()),
        Some("avoid blank expression or monotone delivery")
    );
}

#[test]
fn compact_negative_constraint_against_storyboard_style_keeps_non_conflicting_half() {
    let close_up_storyboard = StoryboardPromptSeedRow {
        prompt: Some("门口逼视".into()),
        video_desc: Some(
            "（主角逼视来人、旧宅门口、主角、5秒、近景、静止、逼近对手、克制、侧逆光、、、A15）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid extreme camera angle or overly tight close-up framing",
            None,
            Some(&close_up_storyboard),
        ),
        Some("avoid extreme camera angle".to_string())
    );

    let cold_light_storyboard = StoryboardPromptSeedRow {
        prompt: Some("冷光对峙".into()),
        video_desc: Some(
            "（主角对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、、、A16）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid flat cold lighting or harsh backlight silhouette",
            None,
            Some(&cold_light_storyboard),
        ),
        Some("avoid harsh backlight silhouette".to_string())
    );
}

#[test]
fn compact_negative_constraint_against_storyboard_style_keeps_frantic_guard_for_cold_scene() {
    let cold_oppressive_storyboard = StoryboardPromptSeedRow {
        prompt: Some("冷光对峙".into()),
        video_desc: Some(
            "（主角对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、、、A16）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid overly cold, oppressive, or frantic mood",
            None,
            Some(&cold_oppressive_storyboard),
        ),
        Some("avoid frantic mood".to_string())
    );
}

#[test]
fn merge_negative_prompts_deduplicates_and_clips() {
    let merged = merge_negative_prompts(
        Some("avoid blur, avoid flicker"),
        Some("avoid flicker, avoid wrong setting details"),
    )
    .expect("merged prompt");
    assert_eq!(
        merged,
        "avoid blur, avoid flicker, avoid wrong setting details"
    );
    assert!(
        clip_negative_prompt(&"a".repeat(160), VideoNegativePromptBudgetTier::Expanded)
            .ends_with("...")
    );
}

#[test]
fn merge_negative_prompts_keeps_more_informative_fragment() {
    let merged = merge_negative_prompts(
        Some("avoid flicker"),
        Some("avoid flicker or motion jitter, avoid blur"),
    )
    .expect("merged prompt");

    assert_eq!(merged, "avoid blur, avoid flicker or motion jitter");
}

#[test]
fn merge_negative_prompts_prefers_more_informative_shot_change_fragment() {
    let merged = merge_negative_prompts(
        Some("avoid unnecessary shot changes"),
        Some("avoid extra shot changes or wrong framing, avoid blur"),
    )
    .expect("merged prompt");

    assert_eq!(
        merged,
        "avoid extra shot changes or wrong framing, avoid blur"
    );
}

#[test]
fn merge_negative_prompts_compacts_character_consistency_family() {
    let merged = merge_negative_prompts(
        Some("avoid face drift or costume inconsistency"),
        Some("avoid face distortion or identity drift, avoid costume or character drift"),
    )
    .expect("merged prompt");

    assert_eq!(
        merged,
        "avoid face distortion, identity drift, costume drift"
    );
}

#[test]
fn merge_negative_prompts_compacts_character_consistency_singletons() {
    let merged = merge_negative_prompts(
        Some("avoid identity drift"),
        Some("avoid face distortion, avoid costume drift"),
    )
    .expect("merged prompt");

    assert_eq!(
        merged,
        "avoid face distortion, identity drift, costume drift"
    );
}

#[test]
fn merge_negative_prompts_compacts_performance_delivery_singletons() {
    let merged = merge_negative_prompts(
        Some("avoid blank expression"),
        Some("avoid monotone delivery"),
    )
    .expect("merged prompt");

    assert_eq!(merged, "avoid blank expression or monotone delivery");
}

#[test]
fn merge_negative_prompts_compacts_visual_style_families() {
    let merged = merge_negative_prompts(
            Some(
                "avoid extreme camera angle, avoid oppressive or frantic mood, avoid flat cold lighting",
            ),
            Some(
                "avoid overly tight close-up framing, avoid overly cold emotional tone, avoid harsh backlight silhouette",
            ),
        )
        .expect("merged prompt");

    assert_eq!(
            merged,
            "avoid extreme camera angle or overly tight close-up framing, avoid flat cold lighting or harsh backlight silhouette"
        );
}
