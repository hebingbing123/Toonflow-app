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

#[test]
fn select_video_prompt_style_notes_falls_back_to_matching_neighbor_style_fragments() {
    let rows = vec![AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=11 | note=女主贴墙前行，镜头稳定近景，情绪冷色压迫感".into(),
    }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、紧张、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 12, None, &storyboard_row, None),
        vec!["镜头稳定".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_prefers_script_summary_over_neighbor_local_framing() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪克制 | note=镜头稳定近景，情绪克制".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=6 | style=情绪克制，光影潮湿路灯暖光，场景雨夜街口 | note=情绪克制，光影潮湿路灯暖光，场景雨夜街口".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、近景、稳定跟拍、停步抬头看向路灯、克制、暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 12, None, &storyboard_row, None),
        vec!["光影潮湿路灯".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_skips_neighbor_memory_from_other_subject() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=21 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=表演低头停顿，语气低声克制".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=19 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边迟疑开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 22, None, &storyboard_row, None),
        vec!["表演抬眼停顿，语气轻声".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_trims_exact_storyboard_style_memory_to_residual_hint() {
    let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | style=镜头近景稳定跟拍，情绪紧张压迫，光影冷调逆光 | note=当前镜头已确认".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、紧张、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 12, None, &storyboard_row, None),
        vec!["情绪压迫".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_prefers_role_memory_over_low_signal_exact_camera_note() {
    let rows = vec![
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=22 | style=镜头中景稳定跟拍 | note=镜头中景稳定跟拍".into(),
        },
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边迟疑开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 22, None, &storyboard_row, None),
        vec!["表演抬眼停顿，语气轻声".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_skips_exact_selected_memory_from_other_subject() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=22 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头低机位压迫感，表演冷眼逼视，语气低声压迫".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=22 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演喉结滚动，语气轻声克制".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边迟疑开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 22, None, &storyboard_row, None),
        Vec::<String>::new()
    );
}

#[test]
fn select_video_prompt_style_notes_keeps_exact_memory_when_it_carries_strong_style_signal() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=22 | style=镜头低机位压迫感，情绪冷峻压迫 | note=镜头低机位压迫感，情绪冷峻压迫".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚贴墙压低声音".into()),
            video_desc: Some("（林晚贴墙站定、昏暗走廊墙边、林晚、4秒、中景、缓推、压低声音试探开口、紧张 / 克制、冷调逆光、你听见了吗、衣料摩擦声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 22, None, &storyboard_row, None),
        vec!["镜头低机位压迫感，情绪压迫，语气轻声".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_merges_exact_and_role_memory_for_emotional_scene() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=22 | style=镜头低机位压迫感，情绪冷峻压迫 | note=镜头低机位压迫感，情绪冷峻压迫".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边迟疑开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 22, None, &storyboard_row, None),
        vec!["镜头低机位压迫感，情绪压迫，表演抬眼停顿，语气轻声".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_uses_pressure_to_yield_exact_camera_template_to_summary() {
    let rows = vec![
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | style=镜头中景稳定跟拍 | note=镜头中景稳定跟拍".into(),
        },
        AgentMemoryRow {
            name: "project_video_generation_brief_memory".into(),
            content: "sampleCount=5 | style=光影冷蓝反光层次，环境雨丝玻璃".into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚站在窗边看着雨丝划过玻璃".into()),
        video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、静止、看着雨丝划过玻璃后迟疑抬眼、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A18）".into()),
        duration: Some("4s".into()),
    };

    assert_eq!(
        select_video_prompt_style_notes(
            &rows,
            18,
            None,
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_identity_guardrail: true,
                has_lighting_guardrail: true,
                prefer_visual_continuity_memory_recall: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        vec!["光影冷蓝反光层次".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_prefers_script_generation_brief_for_fragile_dialogue_turn() {
    let rows = vec![
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=6 | style=镜头稳定跟拍，光影冷蓝窗光，环境雨丝回响".into(),
        },
        AgentMemoryRow {
            name: "script_video_generation_brief_memory".into(),
            content: "sampleCount=4 | style=表演呼吸发颤后停顿，语气压低哽咽尾音 | riskTags=dialogue/performance | focusTags=delivery_realism/emotion_arc".into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚含泪低声说别走".into()),
        video_desc: Some("（林晚含泪低声说别走、雨夜窗边、林晚、5秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光、别走、雨声压住呼吸、A18）".into()),
        duration: Some("5s".into()),
    };

    assert_eq!(
        select_video_prompt_style_notes(
            &rows,
            18,
            None,
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_dialogue_guardrail: true,
                has_emotion_guardrail: true,
                prefer_delivery_memory_recall: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        vec!["表演呼吸发颤后停顿，语气压低哽咽尾音".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_prefers_project_generation_brief_for_visual_continuity() {
    let rows = vec![
        AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=8 | style=镜头稳定跟拍，情绪克制，光影冷蓝反光，环境玻璃雨痕".into(),
        },
        AgentMemoryRow {
            name: "project_video_generation_brief_memory".into(),
            content: "sampleCount=5 | style=光影冷蓝反光里保住脸侧轮廓，环境玻璃雨痕连续 | riskTags=identity/lighting | focusTags=identity_continuity/lighting_realism".into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚站在窗边看向门外".into()),
        video_desc: Some("（林晚站在窗边看向门外、雨夜门厅、林晚、5秒、近景、稳定跟拍、停步抬眼看向门外、克制、潮湿路灯反光、无台词、雨声回响、A12）".into()),
        duration: Some("5秒".into()),
    };

    assert_eq!(
        select_video_prompt_style_notes(
            &rows,
            12,
            None,
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_identity_guardrail: true,
                has_lighting_guardrail: true,
                prefer_visual_continuity_memory_recall: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        vec!["光影里保住脸侧轮廓，环境玻璃雨痕连续".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_prefers_shorter_style_summary_when_brief_is_redundant() {
    let rows = vec![
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=6 | style=表演呼吸发颤后停顿，语气压低哽咽尾音".into(),
        },
        AgentMemoryRow {
            name: "script_video_generation_brief_memory".into(),
            content: "sampleCount=4 | style=表演呼吸发颤后停顿，语气压低哽咽尾音，情绪压抑克制 | riskTags=dialogue/performance | focusTags=delivery_realism/emotion_arc".into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚含泪低声说别走".into()),
        video_desc: Some("（林晚含泪低声说别走、雨夜窗边、林晚、5秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光、别走、雨声压住呼吸、A18）".into()),
        duration: Some("5s".into()),
    };

    assert_eq!(
        select_video_prompt_style_notes(
            &rows,
            18,
            None,
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_dialogue_guardrail: true,
                has_emotion_guardrail: true,
                prefer_delivery_memory_recall: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        vec!["表演呼吸发颤后停顿，语气压低哽咽尾音".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_prefers_subject_role_memory_before_generic_summary() {
    let rows = vec![
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=6 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        },
        AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边迟疑开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 22, None, &storyboard_row, None),
        vec!["表演抬眼停顿，语气轻声".to_string()]
    );
}

#[test]
fn select_video_prompt_style_notes_skip_script_summary_that_only_repeats_storyboard_fields() {
    let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

    assert!(select_video_prompt_style_notes(&rows, 12, None, &storyboard_row, None).is_empty());
}

#[test]
fn select_video_prompt_style_notes_prefers_role_memory_over_exact_template_motion_note() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，动作自然"
                        .into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content:
                    "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演喉结滚动，语气轻声克制 | note=表演喉结滚动，语气轻声克制"
                        .into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边低声开口".into()),
            video_desc: Some("（林晚站在窗边低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_video_prompt_style_notes(&rows, 12, None, &storyboard_row, None),
        vec!["语气轻声，表演喉结滚动".to_string()]
    );
}

#[test]
fn select_best_video_prompt_observation_note_prefers_specific_constraint_over_generic_retry() {
    let note = select_best_video_prompt_observation_note(vec![
        "avoid repeating stable follow camera".to_string(),
        "avoid extreme camera angle".to_string(),
    ]);

    assert_eq!(note, Some("avoid extreme camera angle".to_string()));
}

#[test]
fn select_best_video_prompt_observation_note_prefers_shorter_when_scores_tie() {
    let note = select_best_video_prompt_observation_note(vec![
        "avoid harsh backlight silhouette please".to_string(),
        "avoid harsh backlight silhouette".to_string(),
    ]);

    assert_eq!(note, Some("avoid harsh backlight silhouette".to_string()));
}
