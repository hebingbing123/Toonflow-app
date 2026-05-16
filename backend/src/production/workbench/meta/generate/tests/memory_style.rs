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
fn build_video_prompt_promotes_memory_style_notes_into_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感，情绪冷色压迫感".into()],
            continuity_notes: vec!["保持上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 镜头低机位压迫感，情绪冷色压迫感."));
    assert!(prompt.contains("Continuity notes: 保持上一镜头走位连续."));
    assert!(!prompt.contains("Continuity notes: 镜头低机位压迫感"));
}

#[test]
fn build_video_prompt_trims_memory_style_fragments_already_covered_by_prompt() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，场景旧宅走廊，情绪冷峻压迫".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感; 情绪冷峻压迫."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头稳定跟拍"));
    assert!(!prompt.contains("场景旧宅走廊"));
}

#[test]
fn build_video_prompt_trims_exact_storyboard_style_from_selected_memory_note() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头中景稳定跟拍，情绪急迫，光影阴天冷光".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑."), "{prompt}");
    assert!(!prompt.contains("镜头中景稳定跟拍"), "{prompt}");
    assert!(prompt.contains("Mood: 急迫."), "{prompt}");
    assert!(prompt.contains("Lighting: 阴天冷光."), "{prompt}");
}

#[test]
fn build_video_prompt_deduplicates_prefixed_memory_style_against_director_style_phrase() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持冷峻压迫风格，冷调逆光质感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光，镜头低机位压迫感".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 冷峻压迫风格, 冷调逆光质感; 镜头低机位压迫感."),
        "{prompt}"
    );
    assert_eq!(prompt.matches("冷峻压迫").count(), 1, "{prompt}");
    assert_eq!(prompt.matches("冷调逆光").count(), 1, "{prompt}");
    assert!(!prompt.contains("情绪冷峻压迫"), "{prompt}");
    assert!(!prompt.contains("光影冷调逆光"), "{prompt}");
    assert!(!prompt.contains("Mood: 冷峻压迫."), "{prompt}");
    assert!(!prompt.contains("Lighting: 冷调逆光."), "{prompt}");
}

#[test]
fn build_video_prompt_skips_memory_style_anchor_when_fully_covered() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持稳定跟拍，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，场景旧宅走廊".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑."));
    assert!(!prompt.contains("场景旧宅走廊"));
}

#[test]
fn build_video_prompt_supports_ascii_delimited_memory_style_and_continuity_notes() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感, 情绪冷峻压迫; 光影冷调逆光颗粒".into()],
            continuity_notes: vec!["保持上一镜头冷峻压迫, 人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 镜头低机位压迫感，光影颗粒."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Continuity notes: 站位不要跳轴."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 保持上一镜头冷峻压迫"),
        "{prompt}"
    );
}

#[test]
fn neighbor_selected_video_memory_notes_use_only_style_fragments_before_auto_scope_fallback() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | note=女主贴墙前行，镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=次级摘要".to_string(),
            },
        ];

    assert_eq!(
        select_neighbor_selected_video_memory_notes(&rows, 12, 2),
        vec!["镜头稳定近景，情绪冷色压迫感".to_string()]
    );
}

#[test]
fn script_video_style_memory_is_available_before_auto_scope_fallback() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | note=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=次级摘要".to_string(),
            },
        ];

    assert_eq!(
        select_script_video_style_memory_notes(&rows),
        vec!["镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
    );
}

#[test]
fn project_video_style_memory_is_available_before_auto_scope_fallback() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头中景稳定跟拍，情绪冷峻压迫 | note=镜头中景稳定跟拍，情绪冷峻压迫".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=次级摘要".to_string(),
            },
        ];

    assert_eq!(
        select_project_video_style_memory_notes(&rows),
        vec!["镜头中景稳定跟拍，情绪冷峻压迫".to_string()]
    );
}

#[test]
fn build_video_prompt_memory_notes_reuses_runtime_rows_for_style_and_continuity() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚盯着门外，呼吸发紧".into()),
            video_desc: Some("（林晚盯着门外、雨夜门厅、林晚/晚晚、6秒、近景、稳定跟拍、抬眼停顿后缓慢吸气、压抑、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("6s".into()),
        };

    let (style_notes, continuity_notes) = build_video_prompt_memory_notes(
            vec![
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | promptSeed=seed-12 | style=镜头近景稳定，表演抬眼停顿，语气压低后缓慢吸气".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=晚晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，喉结轻滚".into(),
                },
                AgentMemoryRow {
                    name: "auto_scope_memory".into(),
                    content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=11,12 | review=target=storyboardTable; summary=动作接上门边停住".into(),
                },
            ],
            12,
            Some("seed-12"),
            &storyboard_row,
        );

    assert_eq!(style_notes, vec!["镜头近景稳定，表演抬眼停顿".to_string()]);
    assert_eq!(continuity_notes, vec!["动作接上门边停住".to_string()]);
}

#[test]
fn prioritized_video_prompt_memory_prefers_single_best_matching_style_note() {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=女主贴墙前行，镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊 | note=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=保持角色站位".to_string(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷色压迫感、冷调逆光、别回头、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
        Some("情绪冷色压迫感，光影冷调逆光".to_string())
    );
}

#[test]
fn prioritized_video_prompt_memory_skips_script_and_project_style_when_context_mismatch_is_weak() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=8 | style=镜头环绕，情绪热烈，光影暖金逆光 | note=镜头环绕，情绪热烈，光影暖金逆光".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、静止镜头、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

    assert!(select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)).is_none());
}

#[test]
fn build_video_prompt_consumes_environment_memory_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（女主站在窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃、隐忍 / 克制、冷蓝窗光、无台词、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，环境雨丝玻璃".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("环境雨丝玻璃"), "{prompt}");
}

#[test]
fn build_video_prompt_consumes_voice_and_sound_memory_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["语气轻声克制，声场雨声回响".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("语气轻声"), "{prompt}");
    assert!(prompt.contains("声场雨声回响"), "{prompt}");
    assert!(!prompt.contains("声场回响"), "{prompt}");
}

#[test]
fn build_video_prompt_consumes_performance_memory_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后停顿片刻迟迟没有开口、隐忍 / 克制、冷蓝窗光、无台词、雨声、A23）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("语气轻声"), "{prompt}");
    assert!(!prompt.contains("表演抬眼停顿"), "{prompt}");
    assert!(!prompt.contains("语气轻声克制"), "{prompt}");
}

#[test]
fn observation_filter_style_note_prefers_matching_role_memory_over_global_summary() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=4 | style=表演冷眼逼视，语气低声压迫 | note=表演冷眼逼视，语气低声压迫".into(),
            },
        ];
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
    assert_eq!(
            crate::production::workbench::video_prompt_memory::select_subject_role_video_style_memory_notes_for_storyboard(
                &rows,
                &subject_candidates,
                Some(&storyboard_row),
            ),
            vec!["表演抬眼停顿，语气轻声克制".to_string()]
        );

    assert_eq!(
        resolve_observation_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            &subject_candidates,
            None,
        ),
        Some("语气轻声".to_string())
    );
}

#[test]
fn observation_filter_style_note_prefers_primary_subject_role_memory_when_multiple_roles_match() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=6 | style=表演冷眼逼视，语气低声压迫 | note=表演冷眼逼视，语气低声压迫".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚与顾承泽擦肩后强忍泪意".into()),
            video_desc: Some("（林晚与顾承泽擦肩后强忍泪意、雨夜门厅、林晚/顾承泽、5秒、近景、稳定跟拍、林晚抬眼停顿后侧身让开、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();

    assert_eq!(
        resolve_observation_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            &subject_candidates,
            None,
        ),
        Some("表演抬眼停顿".to_string())
    );
}

#[test]
fn observation_filter_style_note_drops_voice_memory_for_silent_non_speaking_storyboard() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边看向门外".into()),
            video_desc: Some("（林晚站在窗边看向门外、雨夜门厅、林晚、5秒、近景、稳定跟拍、停步抬眼看向门外、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();

    assert_eq!(
        resolve_observation_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            &subject_candidates,
            None,
        ),
        Some("表演抬眼停顿".to_string())
    );
}

#[test]
fn observation_filter_style_note_contextual_summary_prefers_delivery_memory_for_fragile_dialogue_turn(
) {
    let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，光影冷蓝窗光 | delivery=表演呼吸发颤哽咽克制 | note=镜头稳定跟拍，光影冷蓝窗光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚含泪低声说别走".into()),
            video_desc: Some("（林晚含泪低声说别走、雨夜窗边、林晚、5秒、近景、静止、含泪停顿后低声开口、哽咽克制、冷蓝窗光、别走、雨声压住呼吸、A18）".into()),
            duration: Some("5s".into()),
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_dialogue_guardrail: true,
        has_emotion_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    });

    assert_eq!(
        select_contextual_observation_summary_style_note(
            &rows,
            Some(&storyboard_row),
            &[],
            pressure,
        ),
        Some("表演呼吸发颤哽咽克制".to_string())
    );
}
