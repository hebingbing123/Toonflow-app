//! Tests for video prompt generation - Part 1: Asset and Memory Selection.

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
fn select_video_prompt_asset_seed_rows_keeps_per_type_budget_instead_of_global_recent_rows() {
    let rows = (0..8)
        .map(|idx| ScriptRolePromptSeedRow {
            asset_type: "role".into(),
            name: Some(format!("角色{idx}")),
            describe: Some("黑色风衣".into()),
        })
        .chain((0..3).map(|idx| ScriptRolePromptSeedRow {
            asset_type: "scene".into(),
            name: Some(format!("场景{idx}")),
            describe: Some("潮湿长廊".into()),
        }))
        .chain((0..3).map(|idx| ScriptRolePromptSeedRow {
            asset_type: "tool".into(),
            name: Some(format!("道具{idx}")),
            describe: Some("旧磨损".into()),
        }))
        .collect::<Vec<_>>();

    let selected = select_video_prompt_asset_seed_rows(rows);
    let role_count = selected
        .iter()
        .filter(|row| row.asset_type == "role")
        .count();
    let scene_count = selected
        .iter()
        .filter(|row| row.asset_type == "scene")
        .count();
    let tool_count = selected
        .iter()
        .filter(|row| row.asset_type == "tool")
        .count();

    assert_eq!(role_count, VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT);
    assert_eq!(scene_count, 3);
    assert_eq!(tool_count, 3);
}

#[test]
fn select_video_prompt_asset_seed_rows_skips_unknown_asset_types() {
    let selected = select_video_prompt_asset_seed_rows(vec![
        ScriptRolePromptSeedRow {
            asset_type: "role".into(),
            name: Some("主角".into()),
            describe: Some("黑色风衣".into()),
        },
        ScriptRolePromptSeedRow {
            asset_type: "vehicle".into(),
            name: Some("摩托".into()),
            describe: Some("破旧".into()),
        },
    ]);

    assert_eq!(selected.len(), 1);
    assert_eq!(selected[0].asset_type, "role");
}

#[test]
fn select_video_prompt_asset_seed_rows_dedupes_same_asset_identity_before_budgeting() {
    let selected = select_video_prompt_asset_seed_rows(vec![
        ScriptRolePromptSeedRow {
            asset_type: "role".into(),
            name: Some("林晚".into()),
            describe: Some("黑色针织外套".into()),
        },
        ScriptRolePromptSeedRow {
            asset_type: "role".into(),
            name: Some("林晚".into()),
            describe: Some("深灰针织外套".into()),
        },
        ScriptRolePromptSeedRow {
            asset_type: "scene".into(),
            name: Some("咖啡厅窗边".into()),
            describe: Some("木桌与雨痕玻璃".into()),
        },
    ]);

    assert_eq!(selected.len(), 2);
    assert_eq!(selected[0].name.as_deref(), Some("林晚"));
    assert_eq!(selected[1].name.as_deref(), Some("咖啡厅窗边"));
}

#[test]
fn select_script_asset_anchors_keeps_multiple_ranked_results_when_requested() {
    let selected = select_script_asset_anchors(
        vec![
            (120, 0, "主角:黑色风衣".into()),
            (110, 1, "反派:深灰长外套".into()),
            (90, 2, "路人:模糊背影".into()),
        ],
        2,
    );

    assert_eq!(
        selected,
        vec!["主角:黑色风衣".to_string(), "反派:深灰长外套".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_keeps_only_matching_storyboard_entries() {
    let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=女主转身回望，保持女主冷色调近景".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=补图时主角冲向巷口，保持镜头方向连续".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=7 | review=target=storyboardTable; summary=别的镜头".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_derive_assets | scope=storyboardIds=12 | result=无关素材".to_string(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、紧张、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["方向连续".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_trim_storyboard_subject_and_action_from_auto_scope_note() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=主角快步推门冲出保留上一镜头走位连续".to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["保留上一镜头走位连续".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_prefers_specific_axis_guidance_over_generic_continuity() {
    let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=保留上一镜头走位连续".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物站位不要跳轴".to_string(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_drops_generic_auto_scope_summary_without_continuity_guidance() {
    let rows = vec![AgentMemoryRow {
        name: "auto_scope_memory".into(),
        content:
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=当前镜头已确认"
                .to_string(),
    }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert!(select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty());
}

#[test]
fn select_video_prompt_memory_notes_strips_current_shot_scaffolding_from_auto_scope_summary() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持当前镜头角色站位不要跳轴".to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_shortens_redundant_subject_fillers_in_auto_scope_summary() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物视线方向一致，镜头方向连续".to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["视线方向一致".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_drops_axis_guidance_for_grounded_single_subject_scene() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物视线方向一致，人物站位不要跳轴"
                    .to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边看向窗外".into()),
            video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert!(select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty());
}

#[test]
fn select_video_prompt_memory_notes_drops_axis_guidance_for_single_subject_dialogue_scene() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物视线方向一致，人物站位不要跳轴"
                    .to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边低声说你终于来了".into()),
            video_desc: Some("（林晚站在窗边低声说话、咖啡厅窗边、林晚、4秒、中景、缓推、看向门口后低声说你终于来了、隐忍、夜间暖光、你终于来了、轻微杯碟声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert!(select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty());
}

#[test]
fn select_video_prompt_memory_notes_drops_axis_guidance_for_multi_subject_filler_utterance_scene() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物视线方向一致，人物站位不要跳轴"
                    .to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚和顾承泽对视后轻轻嗯了一声".into()),
            video_desc: Some("（林晚和顾承泽对视、咖啡厅门口、林晚/顾承泽、4秒、中景、缓推、对视后微微点头、克制紧张、夜间暖光、嗯、轻微杯碟声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert!(select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty());
}

#[test]
fn select_video_prompt_memory_notes_drops_generic_continuity_half_inside_same_summary() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持当前镜头衔接统一，人物站位不要跳轴".to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_drops_weaker_positioning_fragment_when_jump_axis_exists() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持当前镜头角色站位连续，人物站位不要跳轴".to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_supports_ascii_delimited_auto_scope_summary() {
    let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=后续反派从暗处逼近, 保持当前镜头角色站位不要跳轴; 镜头中景稳定跟拍".to_string(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_drops_auto_scope_summary_after_scaffolding_becomes_empty() {
    let rows = vec![AgentMemoryRow {
        name: "auto_scope_memory".into(),
        content:
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=当前分镜已确认"
                .to_string(),
    }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert!(select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty());
}

#[test]
fn select_video_prompt_memory_notes_skips_stale_auto_scope_prompt_seed_when_current_seed_exists() {
    let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | storyboardPromptSeeds=12:seed-new | summary=人物站位不要跳轴".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | storyboardPromptSeeds=12:seed-old | result=保留上一镜头走位连续".to_string(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, Some("seed-new"), Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}

#[test]
fn select_video_prompt_memory_notes_skips_unseeded_auto_scope_fallback_when_current_seed_exists() {
    let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | storyboardPromptSeeds=12:seed-new | summary=人物站位不要跳轴".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=保留上一镜头走位连续".to_string(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_memory_notes(&rows, 12, Some("seed-new"), Some(&storyboard_row)),
        vec!["站位不要跳轴".to_string()]
    );
}
