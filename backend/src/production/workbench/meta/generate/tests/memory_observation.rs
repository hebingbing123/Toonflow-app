//! Tests for video prompt generation.

use crate::production::workbench::meta::generate::{
    art_style_director_profile, build_auto_quality_review_model_params,
    build_pending_video_observation_note_from_runtime,
    build_pending_video_observation_selection_from_runtime, build_video_prompt,
    build_video_prompt_memory_notes, build_video_prompt_with_constraint_pressure,
    build_video_prompt_with_diagnostics, compact_camera_clause,
    compact_contextual_video_style_note, compact_director_emotion_fragment_group,
    compact_guardrail_sensitive_style_note, compact_negative_constraint_against_storyboard_style,
    compact_script_asset_anchor, exact_style_notes_should_yield_to_role_memory,
    observation_style_note_context_evidence, parse_director_emotion_cues,
    parse_director_environment_cues, parse_director_environment_texture_cues,
    parse_director_motion_cue, parse_structured_storyboard_description,
    prefer_role_memory_only_for_silent_identity_scene, prune_low_signal_observation_candidates,
    prune_storyboard_observation_candidates, resolve_observation_filter_style_note,
    resolve_video_prompt_duration, resolve_video_prompt_memory_budget_tier,
    score_compacted_style_note_against_constraint_pressure,
    score_video_prompt_observation_specificity, select_best_video_prompt_observation_note,
    select_contextual_observation_summary_style_note,
    select_pressure_prioritized_style_note_candidate, select_script_asset_anchors,
    select_video_prompt_asset_seed_rows, select_video_prompt_memory_notes,
    select_video_prompt_style_notes, trim_video_prompt_memory_rows,
    trim_video_prompt_memory_rows_with_context, trim_video_prompt_observation_rows,
    video_prompt_observation_conflicts_with_style,
    video_prompt_observation_is_irrelevant_to_storyboard, DirectorEmotionFragmentGroup,
    GenerateVideoPromptBody, GenerateVideoPromptDiagnostics, GenerateVideoPromptResponse,
    ScriptRolePromptSeedRow, VideoPromptConstraintPressure, VideoPromptContext,
    VideoPromptMemoryBudgetTier, VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
    VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT,
};
use crate::production::workbench::video::generate::{
    AutoNegativePromptSelection, StoryboardNegativePromptRuntime,
};
use crate::production::workbench::video_prompt_memory::{
    select_neighbor_selected_video_memory_notes,
    select_pending_rejected_video_observation_candidates_for_subject,
    select_prioritized_video_style_note, select_project_video_style_memory_notes,
    select_script_video_style_memory_notes, selected_memory_subject_aliases, AgentMemoryRow,
    StoryboardPromptSeedRow, StructuredStoryboardDescription,
};
use proptest::prelude::*;

use super::test_helpers::{
    elevated_risk_fields, grounded_low_risk_fields, sample_generate_video_prompt_diagnostics,
};

#[test]
fn trim_video_prompt_observation_rows_keeps_matching_rejection_row_over_newer_style_noise() {
    let mut rows = Vec::new();
    for _ in 0..12 {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=88 | promptSeed=noise-seed | style=别的镜头风格".into(),
        });
    }
    rows.push(AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | promptSeed=seed-12-current | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
        });

    let trimmed = trim_video_prompt_observation_rows(rows, 12, Some("seed-12-current"), &[], None);

    assert!(trimmed.iter().any(|row| {
        row.name == "rejected_video_negative_memory"
            && row.content.contains("storyboardIds=12")
            && row.content.contains("promptSeed=seed-12-current")
    }));
}

#[test]
fn trim_video_prompt_observation_rows_prefers_current_prompt_seed_over_newer_stale_rejection_rows()
{
    let mut rows = Vec::new();
    for stale_seed in [
        "seed-12-stale-8",
        "seed-12-stale-7",
        "seed-12-stale-6",
        "seed-12-stale-5",
        "seed-12-stale-4",
        "seed-12-stale-3",
        "seed-12-stale-2",
        "seed-12-stale-1",
    ] {
        rows.push(AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={stale_seed} | rejectionCount=1 | avoid=avoid flat cold lighting"
                ),
            });
    }
    rows.push(AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | promptSeed=seed-12-current | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
        });

    let trimmed = trim_video_prompt_observation_rows(rows, 12, Some("seed-12-current"), &[], None);

    assert!(trimmed.iter().any(|row| {
        row.name == "rejected_video_negative_memory"
            && row.content.contains("promptSeed=seed-12-current")
    }));
    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "rejected_video_negative_memory")
            .count(),
        8
    );
}

#[test]
fn trim_video_prompt_observation_rows_prefers_matching_role_memory_over_newer_other_roles() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=4 | style=表演冷眼逼视，语气低声压迫".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=晚晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=沈知遥 | sampleCount=5 | style=动作克制停顿，语气淡声".into(),
            },
        ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        12,
        Some("seed-12-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        None,
    );

    assert!(trimmed.iter().any(|row| {
        row.name == "script_role_video_style_memory" && row.content.contains("subject=晚晚")
    }));
    assert!(!trimmed.iter().any(|row| {
        row.name == "script_role_video_style_memory" && row.content.contains("subject=顾承泽")
    }));
    assert!(!trimmed.iter().any(|row| {
        row.name == "project_role_video_style_memory" && row.content.contains("subject=沈知遥")
    }));
}

#[test]
fn trim_video_prompt_observation_rows_drops_project_style_fill_when_script_memory_is_precise() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚含泪低声说别走".into()),
        video_desc: Some(
            "（林晚含泪低声说别走、雨夜窗边、林晚、5秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光、别走、雨声压住呼吸、A18）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let rows = vec![
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制 | note=表演呼吸发颤，语气哽咽克制".into(),
        },
        AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=6 | style=镜头稳定跟拍，情绪压抑，光影冷蓝窗光 | note=镜头稳定跟拍，情绪压抑，光影冷蓝窗光".into(),
        },
    ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        18,
        Some("seed-18-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert!(trimmed.iter().any(|row| {
        row.name == "script_role_video_style_memory" && row.content.contains("subject=林晚")
    }));
    assert!(!trimmed
        .iter()
        .any(|row| row.name == "project_video_style_memory"));
}

#[test]
fn trim_video_prompt_observation_rows_keeps_project_style_when_visual_continuity_is_prioritized() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚沿着雨夜走廊回头".into()),
        video_desc: Some(
            "（林晚沿着雨夜走廊回头、雨夜走廊、林晚、5秒、中景、稳定跟拍、停步回头、压抑、霓虹反光、无台词、雨声车流回响、A22）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let rows = vec![
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
        },
        AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=6 | style=镜头稳定跟拍，光影霓虹反光，环境潮湿地面反射 | note=镜头稳定跟拍，光影霓虹反光，环境潮湿地面反射".into(),
        },
    ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        22,
        Some("seed-22-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert!(trimmed
        .iter()
        .any(|row| row.name == "project_video_style_memory"));
}

#[test]
fn trim_video_prompt_observation_rows_skips_exact_selected_memory_from_other_subject() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=表演冷眼逼视，语气低声压迫".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制".into(),
            },
        ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        12,
        Some("seed-12-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        None,
    );

    assert!(trimmed.iter().any(|row| {
        row.name == "selected_video_memory" && row.content.contains("subject=林晚")
    }));
    assert!(!trimmed.iter().any(|row| {
        row.name == "selected_video_memory" && row.content.contains("subject=顾承泽")
    }));
}

#[test]
fn trim_video_prompt_observation_rows_keeps_matching_role_observation_summary() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头低声开口".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
    let rows = vec![
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=4 | riskTags=motion/framing | avoid=avoid shaky handheld motion".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            },
        ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        15,
        Some("seed-15-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert!(trimmed.iter().any(|row| {
        row.name == "script_role_video_observation_memory" && row.content.contains("subject=林晚")
    }));
    assert!(!trimmed.iter().any(|row| {
        row.name == "script_role_video_observation_memory" && row.content.contains("subject=顾承泽")
    }));
}

#[test]
fn trim_video_prompt_observation_rows_prefers_primary_subject_role_summary_under_limit() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚低声开口顾承泽沉默看着她".into()),
            video_desc: Some(
                "（晚晚低声开口、雨夜办公室、林晚/晚晚/顾承泽、5秒、近景、慢推、回头低声开口喉结滚动顾承泽站在身后沉默注视、压抑、霓虹反光、你别逼我、雨声回响、A16）"
                    .into(),
            ),
            duration: Some("5".into()),
        };
    let rows = vec![
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=9 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_observation_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=8 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | riskTags=identity/dialogue/lighting | avoid=avoid blank expression or monotone delivery".into(),
            },
        ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        16,
        Some("seed-16-current"),
        &[
            "林晚".to_string(),
            "晚晚".to_string(),
            "顾承泽".to_string(),
            "顾总".to_string(),
        ],
        Some(&storyboard_row),
    );

    let kept_role_rows = trimmed
        .iter()
        .filter(|row| row.name.ends_with("role_video_observation_memory"))
        .map(|row| row.content.as_str())
        .collect::<Vec<_>>();
    assert_eq!(kept_role_rows.len(), 2, "{kept_role_rows:?}");
    assert!(kept_role_rows
        .iter()
        .any(|content| content.contains("subject=林晚")));
    assert_eq!(
        kept_role_rows
            .iter()
            .filter(|content| content.contains("subject=顾承泽"))
            .count(),
        1
    );
}

#[test]
fn trim_video_prompt_observation_rows_drops_project_style_fill_when_role_memory_is_precise() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚含泪低声说别走".into()),
        video_desc: Some(
            "（林晚含泪低声说别走、雨夜窗边、林晚、5秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光、别走、雨声压住呼吸、A18）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let rows = vec![
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制 | note=表演呼吸发颤，语气哽咽克制".into(),
        },
        AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=6 | style=镜头稳定跟拍，情绪压抑，光影冷蓝窗光 | note=镜头稳定跟拍，情绪压抑，光影冷蓝窗光".into(),
        },
    ];

    let trimmed = trim_video_prompt_observation_rows(
        rows,
        18,
        Some("seed-18-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert!(trimmed.iter().any(|row| {
        row.name == "script_role_video_style_memory" && row.content.contains("subject=林晚")
    }));
    assert!(!trimmed
        .iter()
        .any(|row| row.name == "project_video_style_memory"));
}
