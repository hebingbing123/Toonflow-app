use super::super::fragment_operations::{
    clip_negative_prompt, merge_negative_prompts,
    prune_negative_prompt_fragments_for_recent_quality,
};
use super::super::memory_integration::{
    filter_selected_rows_for_subject, load_auto_negative_prompts, negative_review_fetch_limit,
    rejected_negative_memory_fetch_limit, selected_memory_fetch_limit,
};
use super::super::negative_prompt_analysis::resolve_negative_filter_style_note;
use super::super::negative_prompt_builder::{
    build_storyboard_negative_prompts_test as build_storyboard_negative_prompts,
    build_storyboard_negative_prompts_with_recent_quality,
};
use super::super::quality_control::quality_review_row_matches_storyboard;
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
fn prune_negative_prompt_fragments_for_recent_quality_prefers_specific_delivery_guard() {
    let fragments = prune_negative_prompt_fragments_for_recent_quality(
        vec![
            "avoid oppressive or frantic mood".to_string(),
            "avoid blank expression or monotone delivery".to_string(),
        ],
        Some(VideoPromptConstraintPressure {
            prefer_delivery_memory_recall: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(
        fragments,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn prune_negative_prompt_fragments_for_recent_quality_prefers_specific_visual_continuity_guard() {
    let fragments = prune_negative_prompt_fragments_for_recent_quality(
        vec![
            "avoid unnecessary shot changes".to_string(),
            "avoid extreme camera angle or overly tight close-up framing".to_string(),
            "avoid oppressive or frantic mood".to_string(),
        ],
        Some(VideoPromptConstraintPressure {
            prefer_visual_continuity_memory_recall: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(
        fragments,
        vec!["avoid extreme camera angle or overly tight close-up framing".to_string()]
    );
}

#[test]
fn merge_negative_prompts_compacts_shot_change_and_framing_into_single_fragment() {
    let merged = merge_negative_prompts(
        Some("avoid unnecessary shot changes"),
        Some("avoid extreme camera angle or overly tight close-up framing"),
    )
    .expect("merged prompt");

    assert_eq!(merged, "avoid extra shot changes or wrong framing");
}

#[test]
fn merge_negative_prompts_compacts_rushed_and_jerky_motion_into_single_fragment() {
    let merged = merge_negative_prompts(
        Some("avoid rushed motion"),
        Some("avoid flicker or motion jitter"),
    )
    .expect("merged prompt");

    assert_eq!(merged, "avoid rushed or jerky motion");
}

#[test]
fn merge_negative_prompts_compacts_visual_error_family_before_budgeting() {
    let merged = merge_negative_prompts(
        Some("avoid blur, avoid flicker"),
        Some("avoid warped hands or limbs"),
    )
    .expect("merged prompt");

    assert_eq!(merged, "avoid warped anatomy, blur, flicker");
}

#[test]
fn merge_negative_prompts_visual_error_bundle_covers_individual_fragments() {
    let merged = merge_negative_prompts(
        Some("avoid warped anatomy, blur, flicker"),
        Some("avoid blur, avoid flicker or motion jitter"),
    )
    .expect("merged prompt");

    assert_eq!(merged, "avoid warped anatomy, blur, flicker");
}

#[tokio::test]
async fn load_auto_negative_prompts_returns_empty_without_storyboards() {
    let pool =
        PgPool::connect_lazy("postgres://postgres:postgres@localhost/postgres").expect("lazy pool");
    let prompts = load_auto_negative_prompts(&pool, Uuid::nil(), 1, 2, &[])
        .await
        .expect("prompts");
    assert!(prompts.is_empty());
}

#[test]
fn negative_review_fetch_limit_scales_with_storyboard_batch_size() {
    assert_eq!(negative_review_fetch_limit(0), 8);
    assert_eq!(negative_review_fetch_limit(1), 12);
    assert_eq!(negative_review_fetch_limit(3), 20);
    assert_eq!(negative_review_fetch_limit(8), 24);
}

#[test]
fn rejected_video_negative_memory_can_merge_with_review_constraints() {
    let rows = vec![
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | rejectionCount=2 | avoid=avoid shaky handheld motion".into(),
            },
        ];
    let merged = merge_negative_prompts(
        Some("avoid flicker"),
        select_rejected_video_negative_memory_notes(&rows, 12, None)
            .first()
            .map(String::as_str),
    )
    .expect("merged");

    assert_eq!(
        merged,
        "avoid flicker, avoid oppressive or frantic mood, avoid flat cold lighting"
    );
}

#[test]
fn negative_filter_style_note_skips_contextual_summary_when_it_only_repeats_storyboard_axes() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光，人物持续逼近 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光，人物持续逼近".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）".into()),
            duration: Some("5".into()),
        };

    assert_eq!(
        resolve_negative_filter_style_note(&rows, 12, None, Some(&storyboard_row), None, &[], None,),
        None
    );
}

#[test]
fn negative_filter_style_note_skips_summary_that_only_repeats_storyboard_fields() {
    let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

    assert_eq!(
        resolve_negative_filter_style_note(&rows, 12, None, Some(&storyboard_row), None, &[], None,),
        None
    );
}

#[test]
fn negative_filter_style_note_prefers_matching_role_memory_before_generic_summary() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=女主 | subjectAliases=女主/苏晚 | sampleCount=3 | style=表演欲言又止，语气轻声克制".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

    assert_eq!(
        resolve_negative_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            None,
            &["女主".into(), "苏晚".into()],
            None,
        ),
        Some("表演欲言又止，语气轻声克制".to_string())
    );
}

#[test]
fn negative_filter_style_note_lets_role_memory_override_low_signal_exact_camera_note() {
    let rows = vec![AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=女主 | subjectAliases=女主/苏晚 | sampleCount=3 | style=表演欲言又止，语气轻声克制".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

    assert_eq!(
        resolve_negative_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            Some("镜头稳定跟拍".to_string()),
            &["女主".into(), "苏晚".into()],
            None,
        ),
        Some("表演欲言又止，语气轻声克制".to_string())
    );
}

#[test]
fn negative_filter_style_note_keeps_exact_note_when_camera_fragment_carries_emotion_signal() {
    let rows = vec![AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=女主 | subjectAliases=女主/苏晚 | sampleCount=3 | style=表演欲言又止，语气轻声克制".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5".into()),
        };

    assert_eq!(
        resolve_negative_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            Some("镜头稳定跟拍，情绪克制停顿".to_string()),
            &["女主".into(), "苏晚".into()],
            None,
        ),
        Some("镜头稳定跟拍，情绪克制停顿".to_string())
    );
}

#[test]
fn negative_filter_style_note_prefers_visual_summary_when_recent_quality_needs_continuity() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_generation_brief_memory".into(),
                content: "style=表演抬眼停顿后再低声开口，语气克制 | avoid=避免口型僵硬 | riskTags=dialogue/performance | focusTags=delivery_realism".into(),
            },
            AgentMemoryRow {
                name: "project_video_generation_brief_memory".into(),
                content: "style=镜头稳定跟拍，光影潮湿路灯反光里保持脸侧轮廓，环境玻璃水痕保持连贯 | avoid=避免冷光铺平 | riskTags=identity/lighting | focusTags=identity_continuity/lighting_realism".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边看向门外".into()),
            video_desc: Some("（林晚站在窗边看向门外、雨夜门厅、林晚、5秒、近景、稳定跟拍、停步抬眼看向门外、克制、潮湿路灯反光、无台词、雨声回响、A12）".into()),
            duration: Some("5".into()),
        };

    assert_eq!(
        resolve_negative_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            None,
            &["林晚".into()],
            Some(VideoPromptConstraintPressure {
                prefer_visual_continuity_memory_recall: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        Some("光影里保持脸侧轮廓".to_string())
    );
}

#[test]
fn merge_negative_prompts_compacts_lighting_family_before_budgeting() {
    let merged = merge_negative_prompts(
        Some("avoid flicker"),
        Some("avoid flat cold lighting, avoid harsh backlight silhouette"),
    )
    .expect("merged");

    assert_eq!(
        merged,
        "avoid flicker, avoid flat cold lighting or harsh backlight silhouette"
    );
}

#[test]
fn merge_negative_prompts_prioritizes_higher_value_automatic_constraints_when_over_budget() {
    let merged = merge_negative_prompts(
            Some(
                "avoid extra shot changes or wrong framing, avoid overly cold, oppressive, or frantic mood, avoid flat cold lighting or harsh backlight silhouette, avoid wrong setting details",
            ),
            Some(
                "avoid face distortion or identity drift, avoid costume or character drift, avoid warped hands or limbs, avoid blur, avoid flicker",
            ),
        )
        .expect("merged");

    assert!(merged.contains("avoid face distortion, identity drift, costume drift"));
    assert!(merged.contains("avoid warped anatomy, blur, flicker"));
    assert!(!merged.contains("avoid overly cold, oppressive, or frantic mood"));
    assert!(merged.chars().count() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS);
}

#[test]
fn quality_review_row_matches_storyboard_keeps_storyboard_scope_isolated() {
    let storyboard_row = QualityReviewSeedRow {
        target_type: Some("storyboard".into()),
        target_id: Some("12".into()),
        bad_case_category: Some("storyboard_mismatch".into()),
        comments: None,
    };
    let global_row = QualityReviewSeedRow {
        target_type: Some("video".into()),
        target_id: None,
        bad_case_category: Some("visual_error".into()),
        comments: None,
    };

    assert!(quality_review_row_matches_storyboard(&storyboard_row, 12));
    assert!(!quality_review_row_matches_storyboard(&storyboard_row, 9));
    assert!(quality_review_row_matches_storyboard(&global_row, 9));
}

#[test]
fn build_storyboard_negative_prompts_keeps_each_storyboard_prompt_independent() {
    let prompts = build_storyboard_negative_prompts(
        &[12, 13],
        &[
            QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            },
            QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("visual_error".into()),
                comments: Some("有明显闪烁".into()),
            },
        ],
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=13 | rejectionCount=2 | avoid=avoid flat cold lighting"
                    .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood"
                        .into(),
            },
        ],
        &[],
        &HashMap::new(),
    );

    let prompt_12 = prompts
        .get(&12)
        .and_then(|value| value.as_deref())
        .expect("storyboard 12 prompt");
    let prompt_13 = prompts
        .get(&13)
        .and_then(|value| value.as_deref())
        .expect("storyboard 13 prompt");

    assert!(prompt_12.contains("avoid extra shot changes or wrong framing"));
    assert!(prompt_12.contains("avoid warped anatomy, blur, flicker"));
    assert!(prompt_12.contains("avoid op"));
    assert!(!prompt_12.contains("avoid flat cold lighting"));

    assert!(prompt_13.contains("avoid warped anatomy, blur, flicker"));
    assert!(prompt_13.contains("avoid flat cold lighting"));
    assert!(!prompt_13.contains("avoid extra shot changes or wrong framing"));
}

#[test]
fn build_storyboard_negative_prompts_prefers_matching_role_rejected_memory_alias() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | avoid=avoid identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=3 | avoid=avoid lip-sync mismatch".into(),
                },
            ],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚强忍泪意看向门外"),
                Some("（晚晚强忍泪意看向门外、雨夜门厅、晚晚/林晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、克制、冷调逆光、无台词、雨声回响、A12）"),
                Some("5s"),
            )]),
        );

    assert_eq!(
        prompts.get(&12).and_then(|value| value.as_deref()),
        Some("avoid identity drift")
    );
    assert_eq!(
        prompts.get(&12).map(|value| value.budget_tier),
        Some("expanded")
    );
}

#[test]
fn build_storyboard_negative_prompts_uses_lean_budget_for_low_risk_single_axis_warning() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("pacing_issue".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("林晚站在窗边"),
                Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(selection.as_deref(), Some("avoid rushed or jerky motion"));
    assert_eq!(selection.fragment_count, 1);
    assert_eq!(selection.budget_tier, "lean");
}

#[test]
fn build_storyboard_negative_prompts_keeps_lean_budget_for_single_subject_low_risk_warning() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("pacing_issue".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚站在窗边"),
                Some("（晚晚站在窗边、咖啡厅窗边、晚晚/林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(selection.as_deref(), Some("avoid rushed or jerky motion"));
    assert_eq!(selection.fragment_count, 1);
    assert_eq!(selection.budget_tier, "lean");
}

#[test]
fn build_storyboard_negative_prompts_keeps_shot_change_guard_for_grounded_storyboard_mismatch() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("林晚站在窗边"),
                Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(selection.as_deref(), Some("avoid unnecessary shot changes"));
    assert_eq!(selection.fragment_count, 1);
}

#[test]
fn build_storyboard_negative_prompts_trims_storyboard_mismatch_to_framing_only_axis() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角抬头看向楼梯上方"),
                Some("（主角抬头看向楼梯上方、旧宅楼梯口、主角、4秒、仰拍中景、静止、抬头盯住楼上、压抑、室内暖光、无台词、木地板回响、A12）"),
                Some("4s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(selection.as_deref(), Some("avoid extreme camera angle"));
    assert_eq!(selection.fragment_count, 1);
    assert_eq!(selection.budget_tier, "lean");
}

#[test]
fn build_storyboard_negative_prompts_trims_storyboard_mismatch_to_tight_close_up_only_axis() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("storyboard_mismatch".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角压低声音盯住来人"),
                Some("（主角压低声音盯住来人、旧宅门厅、主角、4秒、特写、静止、盯住来人、克制、室内暖光、你终于来了、空调低鸣、A12）"),
                Some("4s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(
        selection.as_deref(),
        Some("avoid overly tight close-up framing")
    );
    assert_eq!(selection.fragment_count, 1);
    assert_eq!(selection.budget_tier, "lean");
}

#[test]
fn build_storyboard_negative_prompts_keeps_expanded_budget_for_single_subject_identity_warning() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("output".into()),
                target_id: None,
                bad_case_category: Some("character_break".into()),
                comments: None,
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚站在窗边"),
                Some("（晚晚站在窗边、咖啡厅窗边、晚晚/林晚、4秒、中景、静止、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）"),
                Some("4s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(
        selection.as_deref(),
        Some("avoid face drift or costume inconsistency")
    );
    assert_eq!(selection.fragment_count, 1);
    assert_eq!(selection.budget_tier, "expanded");
}

#[test]
fn build_storyboard_negative_prompts_compacts_broad_mood_guard_for_restrained_scene() {
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
                Some("晚晚低声忍住眼泪"),
                Some("（晚晚低声忍住眼泪、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(selection.as_deref(), Some("avoid frantic mood"));
    assert_eq!(selection.budget_tier, "lean");
}

#[test]
fn build_storyboard_negative_prompts_keeps_performance_guard_for_restrained_dialogue_scene() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声开口"),
                Some("（晚晚低声开口、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(
        selection.as_deref(),
        Some("avoid blank expression or monotone delivery")
    );
    assert_eq!(selection.fragment_count, 1);
}

#[test]
fn build_storyboard_negative_prompts_drops_redundant_frantic_guard_when_review_flags_monotone_restrained_scene(
) {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            }],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid overly cold, oppressive, or frantic mood"
                        .into(),
            }],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("晚晚低声开口"),
                Some("（晚晚低声开口、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"),
                Some("5s"),
            )]),
        );

    let selection = prompts.get(&12).expect("storyboard 12 prompt");
    assert_eq!(
        selection.as_deref(),
        Some("avoid blank expression or monotone delivery")
    );
    assert_eq!(selection.fragment_count, 1);
    assert_eq!(selection.budget_tier, "lean");
}

#[test]
fn build_storyboard_negative_prompts_drops_performance_guard_for_non_emotional_silent_scene() {
    let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("台词像读文章，表情发木没情绪".into()),
            }],
            &[],
            &[],
            &storyboard_seed_rows(&[(
                12,
                Some("主角站在门口"),
                Some("（主角站在门口、旧宅门厅、主角、4秒、中景、静止、站在门口、平静、室内暖光、无台词、风声、A12）"),
                Some("4s"),
            )]),
        );

    assert_eq!(prompts.get(&12).and_then(|value| value.as_deref()), None);
}
