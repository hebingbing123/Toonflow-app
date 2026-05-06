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
fn build_video_prompt_uses_storyboard_context_and_memory_notes() {
    let context = VideoPromptContext {
            storyboard_prompt: Some("主角转身冲向门外".into()),
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头已确认的冷调压迫感".into()],
        };
    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Subject: 主角冲出旧宅."));
    assert!(prompt.contains("Dialogue: 别回头."));
    assert!(prompt.contains("Continuity notes: 保持上一镜头已确认的冷调压迫感."));
}

#[test]
fn build_video_prompt_deduplicates_structured_memory_fragments() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角冲出旧宅，镜头中景稳定跟拍，情绪急迫，光影阴天冷光，场景旧宅走廊".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Continuity notes:"));
    assert_eq!(prompt.matches("Subject: 主角冲出旧宅.").count(), 1);
}

#[test]
fn build_video_prompt_drops_generic_motion_memory_when_base_motion_anchor_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（女主站在窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A18）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["动作从容克制，环境雨丝玻璃".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 真人都市写实;"), "{prompt}");
    assert!(prompt.contains("环境雨丝玻璃"), "{prompt}");
    assert!(prompt.contains("动作自然"), "{prompt}");
    assert!(!prompt.contains("动作从容克制"), "{prompt}");
}

#[test]
fn prefer_role_memory_only_for_silent_identity_scene_uses_micro_performance_note() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制、暖金逆光、无台词、静场留白、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        prefer_role_memory_only_for_silent_identity_scene(
            &["光影暖金逆光".to_string()],
            &["表演眼神迟疑".to_string()],
            &storyboard_row,
        ),
        Some("表演眼神迟疑".to_string())
    );
}

#[test]
fn prefer_role_memory_only_for_silent_identity_scene_skips_emotional_dialogue_turn() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边迟疑开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中近景、缓推、抬眼后迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        prefer_role_memory_only_for_silent_identity_scene(
            &["光影冷蓝窗光".to_string()],
            &["表演抬眼停顿，语气轻声".to_string()],
            &storyboard_row,
        ),
        None
    );
}

#[test]
fn trim_video_prompt_memory_rows_keeps_summary_memories_when_selected_rows_are_dense() {
    let mut rows = Vec::new();
    for id in (1..=8).rev() {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: format!("storyboardIds={id} | style=镜头中景稳定跟拍{id}"),
        });
    }
    rows.push(AgentMemoryRow {
        name: "script_video_style_memory".into(),
        content: "sampleCount=4 | style=情绪冷峻压迫，光影冷调逆光".into(),
    });
    rows.push(AgentMemoryRow {
        name: "project_video_style_memory".into(),
        content: "sampleCount=7 | style=镜头中景稳定跟拍，情绪冷峻压迫".into(),
    });
    rows.push(AgentMemoryRow {
        name: "auto_scope_memory".into(),
        content:
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持走位连续"
                .into(),
    });

    let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"), &[]);

    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "selected_video_memory")
            .count(),
        6
    );
    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "script_video_style_memory")
            .count(),
        1
    );
    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "project_video_style_memory")
            .count(),
        1
    );
    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "auto_scope_memory")
            .count(),
        1
    );
    assert!(trimmed.iter().any(|row| {
        row.name == "script_video_style_memory"
            && row.content.contains("情绪冷峻压迫，光影冷调逆光")
    }));
    assert!(trimmed.iter().any(|row| {
        row.name == "project_video_style_memory"
            && row.content.contains("镜头中景稳定跟拍，情绪冷峻压迫")
    }));
}

#[test]
fn trim_video_prompt_memory_rows_prioritizes_matching_storyboard_memories_over_newer_noise() {
    let mut rows = Vec::new();
    for id in (20..=26).rev() {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: format!(
                "storyboardIds={id} | promptSeed=seed-{id} | style=镜头中景稳定跟拍{id}"
            ),
        });
    }
    rows.push(AgentMemoryRow {
        name: "selected_video_memory".into(),
        content:
            "storyboardIds=12 | promptSeed=seed-12-current | style=镜头中景稳定跟拍，情绪冷峻压迫"
                .into(),
    });
    for id in (30..=36).rev() {
        rows.push(AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: format!(
                    "tool=run_sub_agent_storyboard_panel | scope=storyboardIds={id} | summary=别的镜头{id}"
                ),
            });
    }
    rows.push(AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物站位不要跳轴"
                    .into(),
        });

    let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"), &[]);

    assert!(trimmed.iter().any(|row| {
        row.name == "selected_video_memory"
            && row.content.contains("storyboardIds=12")
            && row.content.contains("promptSeed=seed-12-current")
    }));
    assert!(trimmed.iter().any(|row| {
        row.name == "auto_scope_memory" && row.content.contains("storyboardIds=12")
    }));
}

#[test]
fn trim_video_prompt_memory_rows_keeps_current_prompt_seed_over_newer_stale_same_storyboard_rows() {
    let mut rows = Vec::new();
    for stale_seed in [
        "seed-12-stale-6",
        "seed-12-stale-5",
        "seed-12-stale-4",
        "seed-12-stale-3",
        "seed-12-stale-2",
        "seed-12-stale-1",
    ] {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: format!(
                "storyboardIds=12 | promptSeed={stale_seed} | style=镜头中景稳定跟拍，情绪冷峻压迫"
            ),
        });
    }
    rows.push(AgentMemoryRow {
        name: "selected_video_memory".into(),
        content:
            "storyboardIds=12 | promptSeed=seed-12-current | style=镜头近景稳定跟拍，情绪紧张压迫"
                .into(),
    });

    let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"), &[]);

    assert!(trimmed.iter().any(|row| {
        row.name == "selected_video_memory" && row.content.contains("promptSeed=seed-12-current")
    }));
    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "selected_video_memory")
            .count(),
        6
    );
}

#[test]
fn trim_video_prompt_memory_rows_prefers_matching_auto_scope_prompt_seed_map_over_newer_stale_row()
{
    let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12,14 | storyboardPromptSeeds=12:seed-12-current,14:seed-14-current | summary=保持当前镜头角色站位".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-stale | summary=旧版镜头走位".into(),
            },
        ];

    let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"), &[]);

    assert!(trimmed.iter().any(|row| {
        row.name == "auto_scope_memory"
            && row
                .content
                .contains("storyboardPromptSeeds=12:seed-12-current,14:seed-14-current")
    }));
}

#[test]
fn trim_video_prompt_memory_rows_prefers_matching_role_style_rows_for_current_subject() {
    let rows = vec![
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=顾承泽 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制".into(),
        },
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | sampleCount=3 | style=表演欲言又止，语气低声克制".into(),
        },
        AgentMemoryRow {
            name: "project_role_video_style_memory".into(),
            content: "subject=沈知遥 | sampleCount=5 | style=动作从容克制，光影冷蓝窗光".into(),
        },
        AgentMemoryRow {
            name: "project_role_video_style_memory".into(),
            content: "subject=晚晚 | sampleCount=5 | style=动作克制自然，光影暖金逆光".into(),
        },
    ];

    let trimmed = trim_video_prompt_memory_rows(
        rows,
        12,
        Some("seed-12-current"),
        &["林晚".to_string(), "晚晚".to_string()],
    );

    assert_eq!(
        trimmed
            .iter()
            .filter(|row| {
                row.name == "script_role_video_style_memory"
                    || row.name == "project_role_video_style_memory"
            })
            .count(),
        2
    );
    assert!(trimmed.iter().any(|row| {
        row.name == "script_role_video_style_memory" && row.content.contains("subject=林晚")
    }));
    assert!(trimmed.iter().any(|row| {
        row.name == "project_role_video_style_memory" && row.content.contains("subject=晚晚")
    }));
    assert!(!trimmed
        .iter()
        .any(|row| row.content.contains("subject=顾承泽")));
    assert!(!trimmed
        .iter()
        .any(|row| row.content.contains("subject=沈知遥")));
}

#[test]
fn trim_video_prompt_memory_rows_with_context_prefers_delivery_rich_selected_rows_on_fragile_turn()
{
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: None,
        video_desc: Some(
            "（林晚停顿后看向顾承泽、雨夜走廊、林晚/顾承泽、5秒、近景、静止、林晚抬眼停顿后低声开口、压抑、冷调逆光、你终于来了、雨声压过呼吸声、A12）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let mut rows = vec![AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=12 | promptSeed=seed-12-current | style=表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光 | delivery=表演喉结滚动低声尾音发颤".into(),
    }];
    for id in (13..=18).rev() {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: format!(
                "storyboardIds={id} | promptSeed=seed-{id} | style=镜头中景稳定跟拍，光影冷蓝窗光"
            ),
        });
    }

    let trimmed = trim_video_prompt_memory_rows_with_context(
        rows,
        12,
        Some("seed-12-current"),
        &["林晚".to_string(), "顾承泽".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    let selected = trimmed
        .iter()
        .filter(|row| row.name == "selected_video_memory")
        .map(|row| row.content.as_str())
        .collect::<Vec<_>>();
    assert_eq!(selected.len(), 6);
    assert!(selected.iter().any(|row| {
        row.contains("storyboardIds=12") && row.contains("delivery=表演喉结滚动低声尾音发颤")
    }));
}

#[test]
fn trim_video_prompt_memory_rows_with_context_keeps_note_and_focus_driven_delivery_row_on_fragile_turn(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚强忍情绪后开口".into()),
        video_desc: Some(
            "（林晚强忍情绪后开口、雨夜走廊、林晚、5秒、近景、静止、抬眼停顿后低声开口、压抑、冷蓝窗光、别再说了、雨声压过呼吸声、A19）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let mut rows = vec![AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=19 | promptSeed=seed-19-current | style=镜头近景，光影冷蓝窗光 | note=表演抬眼停顿后再低声开口，强忍泪意 | focusTags=delivery_realism/emotion_arc".into(),
    }];
    for id in (20..=25).rev() {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: format!(
                "storyboardIds={id} | promptSeed=seed-{id} | style=镜头近景稳定跟拍，构图压迫"
            ),
        });
    }

    let trimmed = trim_video_prompt_memory_rows_with_context(
        rows,
        19,
        Some("seed-19-current"),
        &["林晚".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            prefer_delivery_memory_recall: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    let selected = trimmed
        .iter()
        .filter(|row| row.name == "selected_video_memory")
        .map(|row| row.content.as_str())
        .collect::<Vec<_>>();
    assert!(selected.iter().any(|row| {
        row.contains("storyboardIds=19")
            && row.contains("note=表演抬眼停顿后再低声开口，强忍泪意")
            && row.contains("focusTags=delivery_realism/emotion_arc")
    }));
}

#[test]
fn trim_video_prompt_memory_rows_with_context_keeps_visual_selected_rows_when_scene_is_not_fragile()
{
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: None,
        video_desc: Some(
            "（主角走过空旷厂房、旧厂房、主角、5秒、远景、缓推、继续前行、冷峻、冷调逆光、无台词、风声回响、A12）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let rows = vec![
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | promptSeed=seed-12-current | style=镜头中景稳定跟拍，光影冷蓝窗光".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | promptSeed=seed-11 | style=镜头远景稳定跟拍，光影冷调逆光".into(),
        },
    ];

    let trimmed = trim_video_prompt_memory_rows_with_context(
        rows,
        12,
        Some("seed-12-current"),
        &["主角".to_string()],
        Some(&storyboard_row),
        None,
    );

    assert_eq!(
        trimmed
            .iter()
            .filter(|row| row.name == "selected_video_memory")
            .count(),
        2
    );
}

#[test]
fn trim_video_prompt_memory_rows_with_context_prioritizes_identity_and_lighting_selected_rows_when_visual_pressure_is_hot(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚在雨夜窗边慢慢回头".into()),
        video_desc: Some(
            "（林晚在雨夜窗边慢慢回头、雨夜窗边、林晚、5秒、近景、缓推、停步后回头看向窗外、隐忍、冷蓝窗光与玻璃反射、无台词、雨声、A31）"
                .into(),
        ),
        duration: Some("5s".into()),
    };
    let mut rows = vec![AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=31 | promptSeed=seed-31-current | subject=林晚 | style=表演回头前眼神停顿，光影冷蓝窗光映脸，环境玻璃反射 | note=保持林晚脸部窗光和回头停顿一致".into(),
    }];
    for id in 32..=37 {
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: format!(
                "storyboardIds={id} | promptSeed=seed-{id} | style=镜头近景稳定跟拍，构图压迫"
            ),
        });
    }
    rows.push(AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=38 | promptSeed=seed-38 | style=镜头中景稳定跟拍，光影冷调反光"
            .into(),
    });

    let trimmed = trim_video_prompt_memory_rows_with_context(
        rows,
        31,
        Some("seed-31-current"),
        &["林晚".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptConstraintPressure {
            prefer_visual_continuity_memory_recall: true,
            has_identity_guardrail: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    let selected = trimmed
        .iter()
        .filter(|row| row.name == "selected_video_memory")
        .map(|row| row.content.as_str())
        .collect::<Vec<_>>();
    assert_eq!(selected.len(), 6);
    assert!(selected
        .iter()
        .any(|row| { row.contains("storyboardIds=31") && row.contains("subject=林晚") }));
    assert!(!selected
        .iter()
        .any(|row| row.contains("storyboardIds=38") && row.contains("镜头中景稳定跟拍")));
}

#[test]
fn trim_video_prompt_memory_rows_with_context_drops_project_style_fill_when_script_memory_is_precise(
) {
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

    let trimmed = trim_video_prompt_memory_rows_with_context(
        rows,
        18,
        Some("seed-18-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            prefer_delivery_memory_recall: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(trimmed.iter().any(|row| {
        row.name == "script_role_video_style_memory" && row.content.contains("subject=林晚")
    }));
    assert!(!trimmed
        .iter()
        .any(|row| row.name == "project_video_style_memory"));
}

#[test]
fn trim_video_prompt_memory_rows_with_context_keeps_project_style_when_visual_continuity_is_prioritized(
) {
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

    let trimmed = trim_video_prompt_memory_rows_with_context(
        rows,
        22,
        Some("seed-22-current"),
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptConstraintPressure {
            prefer_visual_continuity_memory_recall: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(trimmed
        .iter()
        .any(|row| row.name == "project_video_style_memory"));
}

#[test]
fn observation_note_conflict_filter_prefers_matching_role_rejection_memory_alias() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚强忍泪意看向门外".into()),
            video_desc: Some("（晚晚强忍泪意看向门外、雨夜门厅、晚晚/林晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();

    let note = select_best_video_prompt_observation_note(
            prune_low_signal_observation_candidates(
                select_pending_rejected_video_observation_candidates_for_subject(
                    &[
                        AgentMemoryRow {
                            name: "rejected_video_negative_memory".into(),
                            content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | avoid=avoid identity drift".into(),
                        },
                        AgentMemoryRow {
                            name: "rejected_video_negative_memory".into(),
                            content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | avoid=avoid lip-sync mismatch".into(),
                        },
                    ],
                    12,
                    None,
                    &subject_candidates,
                    Some(&storyboard_row),
                )
                .into_iter()
                .filter(|candidate| {
                    !video_prompt_observation_is_irrelevant_to_storyboard(
                        candidate,
                        Some(&storyboard_row),
                    )
                })
                .collect(),
            ),
        );

    assert_eq!(note, Some("avoid identity drift".to_string()));
}

#[test]
fn prioritized_video_prompt_memory_allows_script_summary_when_multiple_fields_match() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=8 | style=镜头环绕，情绪热烈，光影暖金逆光 | note=镜头环绕，情绪热烈，光影暖金逆光".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
        Some("镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".to_string())
    );
}

#[test]
fn prioritized_video_prompt_memory_skips_exact_storyboard_selection_when_it_only_repeats_current_prompt(
) {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头低机位压迫感，情绪克制 | note=镜头低机位压迫感，情绪克制".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=光影冷调逆光，场景旧宅走廊 | note=光影冷调逆光，场景旧宅走廊".into(),
            },
        ];

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, None),
        Some("光影冷调逆光".to_string())
    );
}

#[test]
fn prioritized_video_prompt_memory_returns_empty_when_only_exact_storyboard_selection_exists() {
    let rows = vec![AgentMemoryRow {
        name: "selected_video_memory".into(),
        content:
            "storyboardIds=12 | style=镜头低机位压迫感，情绪克制 | note=镜头低机位压迫感，情绪克制"
                .into(),
    }];

    assert!(select_prioritized_video_style_note(&rows, 12, None, None).is_none());
}
