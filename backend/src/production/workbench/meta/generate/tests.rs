//! Unit tests for workbench meta prompt generation.

use super::{
    art_style_director_profile, build_auto_quality_review_model_params,
    build_pending_video_observation_note_from_runtime, build_video_prompt,
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
    resolve_video_prompt_duration, score_compacted_style_note_against_constraint_pressure,
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
    VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS, VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT,
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

#[test]
fn build_video_prompt_compacts_structured_storyboard_description() {
    let prompt = build_video_prompt(
            Some("（主角独立城楼远眺苍茫大地、城楼、主角/城楼、4s、全景、缓慢推进、负手而立衣袂翻飞、坚定压抑、黄昏冷调侧逆光、无台词、风声衣袂声、A001/A003）"),
            Some("https://example.com/frame.png"),
            None,
        );

    assert!(prompt.contains("Single cinematic shot."));
    assert!(prompt.contains("Subject: 主角独立城楼远眺苍茫大地."));
    assert!(prompt.contains("Camera: 全景, 缓慢推进."));
    assert!(prompt.contains("Use the supplied frame as the visual reference."));
    assert!(!prompt.contains("A001/A003"));
}

#[test]
fn parse_structured_storyboard_description_extracts_duration() {
    let fields = parse_structured_storyboard_description(
            "（雨夜街角对峙、旧街、主角/反派、6秒、中景、手持跟拍、彼此逼近、紧张、霓虹潮湿反光、你终于来了、雨声脚步声、A1/A2）",
        )
        .expect("structured description");

    assert_eq!(fields.duration_seconds, Some(6));
    assert_eq!(fields.setting, "旧街");
    assert_eq!(fields.dialogue, "你终于来了");
}

#[test]
fn resolve_video_prompt_duration_prefers_hint_then_description_then_default() {
    assert_eq!(
        resolve_video_prompt_duration(
            Some(8),
            Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
            None,
        ),
        8
    );
    assert_eq!(
        resolve_video_prompt_duration(
            None,
            Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
            None,
        ),
        4
    );
    assert_eq!(
        resolve_video_prompt_duration(None, Some("普通描述"), None),
        5
    );
}

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
fn build_video_prompt_keeps_only_non_duplicate_continuity_fragments() {
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
            continuity_notes: vec!["主角冲出旧宅，镜头中景稳定跟拍，情绪急迫，保持上一镜头压迫感".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Continuity notes: 保持上一镜头压迫感."));
    assert!(!prompt.contains("镜头中景稳定跟拍，情绪急迫"));
}

#[test]
fn build_video_prompt_drops_low_value_lighting_continuity_for_grounded_indoor_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（男主坐在木桌前、室内书房、男主、4秒、中景、静止、低头翻开信纸、克制、室内暖光、无台词、纸张摩擦声、A03）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头暖光层次".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Continuity notes:"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_lighting_continuity_for_reflective_night_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（女主站在落地窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃、隐忍、冷蓝窗光与路灯反射、无台词、雨声、A18）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头冷蓝反光层次".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 保持上一镜头冷蓝反光层次."),
        "{prompt}"
    );
}

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
fn build_video_prompt_skips_mood_and_lighting_when_style_anchor_already_covers_them() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑."), "{prompt}");
    assert!(prompt.contains("Mood: 冷峻压迫."), "{prompt}");
    assert!(prompt.contains("Lighting: 冷调逆光."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_mood_and_lighting_when_style_anchor_is_generic() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片悬疑."));
    assert!(!prompt.contains("镜头衔接统一."));
    assert!(prompt.contains("Mood: 冷峻压迫."));
    assert!(prompt.contains("Lighting: 冷调逆光."));
}

#[test]
fn build_video_prompt_skips_continuity_fragments_covered_after_prefix_trim() {
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
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光".into()],
            continuity_notes: vec!["保持上一镜头冷峻压迫，保留上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 情绪冷峻压迫，光影冷调逆光."));
    assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续."));
    assert!(!prompt.contains("Continuity notes: 保持上一镜头冷峻压迫"));
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
fn build_video_prompt_trims_redundant_camera_half_but_keeps_extra_style_hint() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、稳定跟拍、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍压迫感，光影冷调逆光颗粒".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 镜头压迫感，光影颗粒."),
        "{prompt}"
    );
    assert_eq!(prompt.matches("稳定跟拍").count(), 1, "{prompt}");
    assert!(!prompt.contains("光影冷调逆光颗粒"), "{prompt}");
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
fn compact_camera_clause_drops_axes_already_covered_by_style_anchor() {
    let camera = compact_camera_clause(
        "低机位近景",
        "稳定跟拍",
        &["镜头低机位近景稳定跟拍电影感".to_string()],
    );

    assert_eq!(camera, None);
}

#[test]
fn compact_camera_clause_keeps_only_uncovered_axis() {
    let camera = compact_camera_clause("中景", "稳定跟拍", &["镜头稳定跟拍压迫感".to_string()]);

    assert_eq!(camera.as_deref(), Some("中景"));
}

#[test]
fn build_video_prompt_deduplicates_semantic_style_fragments_across_sources() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感，情绪冷峻压迫".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert_eq!(prompt.matches("低机位压迫感").count(), 1, "{prompt}");
    assert!(!prompt.contains("镜头低机位压迫感"), "{prompt}");
    assert!(prompt.contains("Mood: 冷峻压迫."), "{prompt}");
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
fn build_video_prompt_skips_explicit_mood_and_lighting_when_style_anchor_already_covers_them() {
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
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 冷峻压迫风格, 冷调逆光质感."),
        "{prompt}"
    );
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
fn resolve_video_prompt_duration_falls_back_to_storyboard_context() {
    let context = VideoPromptContext {
        storyboard_prompt: None,
        storyboard_video_desc: None,
        storyboard_duration: Some("7 秒".into()),
        storyboard_prompt_seed: None,
        project_art_style: None,
        project_director_manual: None,
        script_role_anchors: Vec::new(),
        script_scene_anchors: Vec::new(),
        script_tool_anchors: Vec::new(),
        memory_style_notes: Vec::new(),
        continuity_notes: Vec::new(),
    };
    assert_eq!(resolve_video_prompt_duration(None, None, Some(&context)), 7);
}

#[test]
fn build_video_prompt_adds_compact_project_visual_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一，光影偏冷".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感, 光影偏冷."),
        "{prompt}"
    );
    assert!(!prompt.contains("Format:"));
    assert!(!prompt.contains("镜头衔接统一"));
}

#[test]
fn build_video_prompt_trims_project_director_style_half_already_covered_by_storyboard() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("光影冷调逆光颗粒，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 光影颗粒."),
        "{prompt}"
    );
    assert!(!prompt.contains("光影冷调逆光颗粒"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_project_art_style_fragments_already_covered_elsewhere() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片颗粒，冷调逆光，冷峻压迫".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片颗粒."), "{prompt}");
    assert!(!prompt.contains("冷调逆光;"));
    assert!(!prompt.contains("冷峻压迫;"));
}

#[test]
fn build_video_prompt_drops_generic_director_visual_placeholders() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头语言统一，风格统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 质感克制粗粝."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头语言统一"), "{prompt}");
    assert!(!prompt.contains("风格统一"), "{prompt}");
    assert!(
        prompt.contains("Natural motion, stable continuity, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_keeps_concrete_director_fragment_while_dropping_generic_visual_placeholder() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头语言统一，保持低机位压迫感，光影一致".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头语言统一"), "{prompt}");
    assert!(!prompt.contains("光影一致"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_director_manual_fragments_already_covered_by_storyboard() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头稳定跟拍，情绪急迫，光影阴天冷光，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑."));
    assert!(!prompt.contains("镜头稳定跟拍"));
    assert!(!prompt.contains("情绪急迫"));
    assert!(!prompt.contains("光影阴天冷光"));
}

#[test]
fn build_video_prompt_prioritizes_high_value_director_manual_fragments() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("场景旧宅走廊，保持低机位压迫感，镜头衔接统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感, 质感克制粗粝."));
    assert!(!prompt.contains("场景旧宅走廊"));
    assert!(!prompt.contains("镜头衔接统一"));
}

#[test]
fn build_video_prompt_adds_matching_script_role_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "主角: 黑色风衣，短发，克制冷峻".into(),
                "路人: 灰色外套".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."),);
    assert!(!prompt.contains("路人:灰色外套"));
    assert!(!prompt.contains("Subject: 主角."));
}

#[test]
fn build_video_prompt_keeps_only_strongest_matching_role_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角扶住同伴冲出旧宅、旧宅走廊、主角/同伴、5秒、中景、稳定跟拍、扶住同伴冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "同伴: 灰色毛衣，神情惊惶".into(),
                "主角: 黑色风衣，短发，克制冷峻".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(!prompt.contains("同伴:灰色毛衣，神情惊惶"));
}

#[test]
fn build_video_prompt_skips_generic_role_anchor_without_describe() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 视觉设定延续".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Character anchor:"), "{prompt}");
}

#[test]
fn build_video_prompt_adds_matching_scene_and_tool_anchors() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "街角: 雨夜霓虹".into(),
            ],
            script_tool_anchors: vec![
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
                "雨伞: 黑伞".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
    assert!(!prompt.contains("街角:雨夜霓虹"));
    assert!(!prompt.contains("雨伞:黑伞"));
    assert!(!prompt.contains("Setting: 旧宅走廊."));
}

#[test]
fn build_video_prompt_skips_generic_scene_and_tool_anchor_without_describe() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 场景设定延续".into()],
            script_tool_anchors: vec!["青铜匕首: 道具设定延续".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Scene anchor:"), "{prompt}");
    assert!(!prompt.contains("Prop anchor:"), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_subject_and_action_leading_role_name_when_anchored() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅走廊、旧宅走廊、主角、5秒、中景、稳定跟拍、主角快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(prompt.contains("Subject: 冲出旧宅走廊."));
    assert!(prompt.contains("Action: 快步推门冲出."));
    assert!(!prompt.contains("Action: 主角快步推门冲出."));
}

#[test]
fn build_video_prompt_trims_subject_action_overlap_when_subject_identity_remains() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Subject: 主角."), "{prompt}");
    assert!(
        prompt.contains("Action: 快步推门冲出旧宅后回望."),
        "{prompt}"
    );
    assert!(!prompt.contains("Subject: 主角冲出旧宅."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_subject_after_overlap_trim_when_role_anchor_already_covers_identity() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(!prompt.contains("Subject:"), "{prompt}");
    assert!(
        prompt.contains("Action: 快步推门冲出旧宅后回望."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_role_anchor_fragment_that_mostly_repeats_prompt_mood() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:短发."), "{prompt}");
    assert!(
        !prompt.contains("Character anchor: 主角:黑色风衣"),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Character anchor: 主角:短发，克制冷峻"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_role_anchor_fragment_that_repeats_prompt_lighting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，阴天冷光侧边高光".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Character anchor: 主角:侧边高光."),
        "{prompt}"
    );
    assert!(!prompt.contains("Character anchor: 主角:黑色风衣，阴天冷光侧边高光."));
    assert_eq!(prompt.matches("阴天冷光").count(), 1, "{prompt}");
    assert_eq!(prompt.matches("黑色风衣").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_trims_role_anchor_fragment_that_repeats_prompt_subject() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣主角，短发碎发".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Character anchor: 主角:短发碎发."),
        "{prompt}"
    );
    assert!(!prompt.contains("Character anchor: 主角:黑色风衣主角，短发碎发."));
    assert_eq!(prompt.matches("黑色风衣主角").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_uses_subject_refs_to_keep_two_role_anchors_for_multi_character_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（两人巷口对峙、雨夜巷口、主角/反派、5秒、中景、稳定跟拍、互相逼近、紧张压迫、冷调逆光、无台词、雨声脚步声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "主角: 黑色风衣，短发，左脸旧疤".into(),
                "反派: 湿发，深灰长外套，压低肩线".into(),
                "路人: 模糊背影".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains(
            "Character anchor: 主角:黑色风衣，短发，左脸旧疤; 反派:湿发，深灰长外套，压低肩线."
        ),
        "{prompt}"
    );
    assert!(!prompt.contains("路人:模糊背影"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_scene_anchor_when_it_only_repeats_existing_setting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、潮湿斑驳的旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Scene anchor:"), "{prompt}");
    assert!(!prompt.contains("Setting: 潮湿斑驳的旧宅走廊."), "{prompt}");
}

#[test]
fn build_video_prompt_trims_scene_anchor_fragment_that_repeats_prompt_lighting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，阴天冷光积水反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，积水反光."),
        "{prompt}"
    );
    assert!(!prompt.contains("旧宅走廊:潮湿斑驳，阴天冷光积水反光."));
    assert_eq!(prompt.matches("阴天冷光").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_trims_scene_anchor_fragment_that_repeats_prompt_setting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 旧宅走廊尽头积水反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:尽头积水反光."),
        "{prompt}"
    );
    assert!(!prompt.contains("Scene anchor: 旧宅走廊:旧宅走廊尽头积水反光."));
    assert_eq!(prompt.matches("旧宅走廊").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_compacts_tool_prefix_action_when_anchor_already_covers_prop() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首快步穿行、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首快步穿行并回头确认、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
    assert!(prompt.contains("Action: 快步穿行并回头确认."));
    assert!(!prompt.contains("Action: 握紧青铜匕首快步穿行并回头确认."));
}

#[test]
fn build_video_prompt_keeps_tool_prefix_action_when_no_followup_motion_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Action: 握紧青铜匕首."));
}

#[test]
fn build_video_prompt_keeps_two_tool_anchors_for_multi_prop_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊握紧青铜匕首撬开门锁、旧宅走廊、主角/青铜匕首/门锁、5秒、中景、稳定跟拍、握紧匕首撬开门锁后回头确认、急迫、阴天冷光、无台词、金属摩擦声脚步声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec![
                "门锁: 生锈锁芯，金属划痕".into(),
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
                "雨伞: 黑伞".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Prop anchor: 门锁:生锈锁芯，金属划痕; 青铜匕首:刀身旧磨损，寒光克制."),
        "{prompt}"
    );
    assert!(!prompt.contains("雨伞:黑伞"), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_setting_prefix_already_covered_by_scene_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、缓慢停步抬头观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(prompt.contains("Setting: 尽头的门厅."));
    assert!(!prompt.contains("Setting: 旧宅走廊尽头的门厅."));
}

#[test]
fn build_video_prompt_trims_subject_lead_in_from_setting_when_subject_already_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足、主角身后的门厅、主角、5秒、中景、稳定跟拍、抬眼观察、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Setting: 门厅."), "{prompt}");
    assert!(!prompt.contains("Setting: 主角身后的门厅."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_subject_when_compaction_makes_it_duplicate_action() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角快步推门冲出、旧宅走廊、主角、5秒、中景、稳定跟拍、主角快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Subject:"));
    assert!(prompt.contains("Action: 快步推门冲出."));
}

#[test]
fn build_video_prompt_trims_dialogue_payload_from_action_when_motion_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头并低声说你终于来了、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 驻足回头."), "{prompt}");
    assert!(
        !prompt.contains("Action: 驻足回头并低声说你终于来了."),
        "{prompt}"
    );
    assert!(prompt.contains("Dialogue: 你终于来了."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_action_when_only_dialogue_delivery_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、低声说你终于来了、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 低声说你终于来了."), "{prompt}");
    assert!(prompt.contains("Dialogue: 你终于来了."), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_leading_bridge_before_scene_prefix() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Setting: 门厅."), "{prompt}");
    assert!(prompt.contains("Action: 停步回头."), "{prompt}");
    assert!(!prompt.contains("Setting: 尽头的门厅."), "{prompt}");
    assert!(!prompt.contains("Action: 尽头停步回头."), "{prompt}");
    assert!(!prompt.contains("Setting: 在旧宅走廊尽头的门厅."));
    assert!(!prompt.contains("Action: 在旧宅走廊尽头停步回头."));
}

#[test]
fn build_video_prompt_keeps_strongest_scene_anchor_but_two_directly_referenced_tool_anchors() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊握紧青铜匕首回头、旧宅走廊/门厅、主角/青铜匕首/门锁、5秒、中景、稳定跟拍、握紧匕首回头、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "门厅: 破损玻璃，潮湿回声".into(),
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
            ],
            script_tool_anchors: vec![
                "门锁: 生锈锁芯".into(),
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(
        prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制; 门锁:生锈锁芯.")
            || prompt.contains("Prop anchor: 门锁:生锈锁芯; 青铜匕首:刀身旧磨损，寒光克制."),
        "{prompt}"
    );
    assert!(!prompt.contains("门厅:破损玻璃，潮湿回声"));
}

#[test]
fn compact_script_asset_anchor_skips_empty_describe_instead_of_emitting_generic_placeholder() {
    assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
        asset_type: "role".into(),
        name: Some("主角".into()),
        describe: None,
    })
    .is_none());
    assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
        asset_type: "scene".into(),
        name: Some("旧宅走廊".into()),
        describe: Some("   ".into()),
    })
    .is_none());
    assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
        asset_type: "tool".into(),
        name: Some("青铜匕首".into()),
        describe: None,
    })
    .is_none());
}

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
fn build_video_prompt_keeps_two_scene_anchors_for_transition_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
                "医院门厅: 冷白瓷砖，回声明亮".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊; 旧宅门厅:破损玻璃，潮湿回声.")
            || prompt.contains(
                "Scene anchor: 旧宅门厅:破损玻璃，潮湿回声; 旧宅走廊:潮湿斑驳，冷色长廊."
            ),
        "{prompt}"
    );
    assert!(!prompt.contains("医院门厅:冷白瓷砖，回声明亮"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_two_scene_anchors_for_structured_multi_setting_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅门厅/走廊尽头、主角、5秒、中景、稳定跟拍、停步回头确认身后动静、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
                "医院门厅: 冷白瓷砖，回声明亮".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊; 旧宅门厅:破损玻璃，潮湿回声.")
            || prompt.contains(
                "Scene anchor: 旧宅门厅:破损玻璃，潮湿回声; 旧宅走廊:潮湿斑驳，冷色长廊."
            ),
        "{prompt}"
    );
    assert!(!prompt.contains("医院门厅:冷白瓷砖，回声明亮"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_single_scene_anchor_for_regular_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(!prompt.contains("旧宅门厅:破损玻璃，潮湿回声"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_continuity_fragments_already_covered_by_anchors() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "黑色风衣，冷色长廊，刀身旧磨损，保持低机位压迫感，保留上一镜头走位连续"
                    .into(),
            ],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
    assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
    assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(!prompt.contains("Continuity notes: 黑色风衣"));
    assert!(!prompt.contains("Continuity notes: 冷色长廊"));
    assert!(!prompt.contains("Continuity notes: 刀身旧磨损"));
    assert!(!prompt.contains("Continuity notes: 保持低机位压迫感"));
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_single_strongest_continuity_note() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "黑色风衣，冷色长廊，刀身旧磨损，保持低机位压迫感".into(),
                "保留上一镜头走位连续，人物站位不要跳轴".into(),
            ],
        };

    let prompt = build_video_prompt(None, None, Some(&context));
    let continuity_clause = prompt
        .split("Continuity notes: ")
        .nth(1)
        .and_then(|value| value.split('.').next())
        .unwrap_or("");

    assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续，站位不要跳轴."));
    assert_eq!(prompt.matches("Continuity notes:").count(), 1);
    assert!(!continuity_clause.contains("保持低机位压迫感"));
    assert!(prompt.contains("Natural motion, no extra shot changes."));
}

#[test]
fn build_video_prompt_prefers_axis_guidance_over_generic_continuity_under_single_note_budget() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保留上一镜头走位连续".into(), "人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 站位不要跳轴."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Natural motion, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_leading_asset_coverage_from_fused_continuity_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["黑色风衣主角保留上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 黑色风衣主角"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_trims_storyboard_subject_and_action_from_continuity_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角快步推门冲出保留上一镜头走位连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 保留上一镜头走位连续."),
        "{prompt}"
    );
    assert!(!prompt.contains("主角快步推门冲出"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_continuity_style_note_when_style_anchor_already_covers_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头低机位压迫感，人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
        "{prompt}"
    );
    assert!(
        prompt.contains("Continuity notes: 站位不要跳轴."),
        "{prompt}"
    );
    assert!(
        !prompt.contains("Continuity notes: 保持上一镜头低机位压迫感"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_drops_continuity_half_already_split_between_storyboard_and_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["光影冷调逆光颗粒".into()],
            continuity_notes: vec!["保持上一镜头冷调逆光颗粒".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片冷调悬疑; 光影颗粒."),
        "{prompt}"
    );
    assert!(!prompt.contains("Continuity notes:"), "{prompt}");
    assert_eq!(prompt.matches("颗粒").count(), 1, "{prompt}");
}

#[test]
fn build_video_prompt_shortens_quality_tail_when_camera_already_implies_stability() {
    let prompt = build_video_prompt(
            Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）"),
            None,
            Some(&VideoPromptContext {
                storyboard_prompt: None,
                storyboard_video_desc: None,
                storyboard_duration: None,
                storyboard_prompt_seed: None,
                project_art_style: None,
                project_director_manual: None,
                script_role_anchors: Vec::new(),
                script_scene_anchors: Vec::new(),
                script_tool_anchors: Vec::new(),
                memory_style_notes: Vec::new(),
                continuity_notes: Vec::new(),
            }),
        );

    assert!(prompt.contains("Natural motion, no extra shot changes."));
    assert!(!prompt.contains("Natural motion, stable continuity, no extra shot changes."));
}

#[test]
fn build_video_prompt_keeps_full_quality_tail_without_continuity_signal() {
    let prompt = build_video_prompt(
        Some("主角在空旷仓库内缓慢抬头，周围静止无风。"),
        None,
        Some(&VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: None,
            storyboard_duration: None,
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        }),
    );

    assert!(prompt.contains("Natural motion, stable continuity, no extra shot changes."));
}

#[test]
fn build_video_prompt_uses_compact_template_for_grounded_low_risk_shot() {
    let prompt = build_video_prompt(
            Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、暖光、无台词、轻微环境声、A12）"),
            None,
            Some(&VideoPromptContext {
                storyboard_prompt: None,
                storyboard_video_desc: None,
                storyboard_duration: None,
                storyboard_prompt_seed: None,
                project_art_style: None,
                project_director_manual: None,
                script_role_anchors: Vec::new(),
                script_scene_anchors: Vec::new(),
                script_tool_anchors: Vec::new(),
                memory_style_notes: Vec::new(),
                continuity_notes: Vec::new(),
            }),
        );

    assert!(prompt.contains("Single shot."), "{prompt}");
    assert!(!prompt.contains("Single cinematic shot."), "{prompt}");
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_full_template_for_high_risk_emotional_shot() {
    let prompt = build_video_prompt(
            Some("（林晚冲出旧宅、旧宅走廊、林晚、5秒、中景、稳定跟拍、快步推门冲出、哽咽压抑、逆光雨夜、别回头、脚步声门响、A12）"),
            None,
            Some(&VideoPromptContext {
                storyboard_prompt: None,
                storyboard_video_desc: None,
                storyboard_duration: None,
                storyboard_prompt_seed: None,
                project_art_style: None,
                project_director_manual: None,
                script_role_anchors: Vec::new(),
                script_scene_anchors: Vec::new(),
                script_tool_anchors: Vec::new(),
                memory_style_notes: Vec::new(),
                continuity_notes: Vec::new(),
            }),
        );

    assert!(prompt.contains("Single cinematic shot."), "{prompt}");
    assert!(
        prompt.contains("Natural motion, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_keeps_full_quality_tail_when_generic_director_continuity_is_trimmed() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 胶片悬疑."), "{prompt}");
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
    assert!(
        prompt.contains("Natural motion, stable continuity, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_shortens_quality_tail_when_director_continuity_survives_style_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持稳定跟拍，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 稳定跟拍, 质感克制粗粝."),
        "{prompt}"
    );
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
    assert!(!prompt.contains("stable continuity"), "{prompt}");
}

#[test]
fn build_video_prompt_pressure_prefers_axis_continuity_for_identity_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停顿后看向顾承泽、雨夜走廊、林晚/顾承泽、5秒、近景、静止、林晚抬眼停顿后低声开口、压抑、冷调逆光、你终于来了、雨声压过呼吸声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "保持上一镜头冷调逆光层次连续".into(),
                "保持上一镜头视线方向一致，人物站位不要跳轴".into(),
            ],
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        has_dialogue_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    });

    let result = build_video_prompt_with_constraint_pressure(None, None, Some(&context), pressure);

    assert!(
        result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(result.prompt.contains("视线方向一致"), "{}", result.prompt);
    assert!(result.prompt.contains("站位不要跳轴"), "{}", result.prompt);
    assert!(
        !result.prompt.contains("冷调逆光层次连续"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("No extra shot changes."),
        "{}",
        result.prompt
    );
    assert!(
        !result
            .prompt
            .contains("Natural motion, no extra shot changes."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_pressure_prefers_lighting_continuity_for_reflection_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在落地窗边、雨夜落地窗边、林晚、5秒、中近景、缓推、停步望向玻璃反光、克制、冷调逆光与霓虹反光、无台词、雨声与车流闷响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "保持上一镜头动作节奏自然".into(),
                "保持上一镜头玻璃反光不过曝".into(),
            ],
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_lighting_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    });

    let result = build_video_prompt_with_constraint_pressure(None, None, Some(&context), pressure);

    assert!(
        result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("玻璃反光不过曝"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("动作节奏自然"), "{}", result.prompt);
    assert!(
        result.prompt.contains("No extra shot changes."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_trims_generic_continuity_clause_inside_fused_director_style_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持稳定跟拍且镜头衔接统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 稳定跟拍, 质感克制粗粝."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_generic_continuity_clause_inside_fused_director_lighting_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("光影偏冷并保持镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 胶片悬疑; 光影偏冷."),
        "{prompt}"
    );
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
    assert!(
        prompt.contains("Natural motion, stable continuity, no extra shot changes."),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_drops_generic_continuity_note_when_tail_already_covers_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头衔接统一".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("Continuity notes:"));
    assert!(prompt.contains("Natural motion, stable continuity, no extra shot changes."));
}

#[test]
fn build_video_prompt_keeps_specific_continuity_guidance_while_dropping_generic_fragment() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头衔接统一，人物站位不要跳轴".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Continuity notes: 站位不要跳轴."));
    assert!(!prompt.contains("Continuity notes: 保持上一镜头衔接统一"));
    assert!(prompt.contains("Natural motion, no extra shot changes."));
}

#[test]
fn build_video_prompt_shortens_specific_continuity_wording_without_dropping_guidance() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角对视后停步、旧宅门厅、主角、5秒、中景、静止、停步抬眼、克制紧张、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["人物视线方向一致，镜头方向连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 视线方向一致."),
        "{prompt}"
    );
    assert!(!prompt.contains("人物视线方向一致"), "{prompt}");
    assert!(!prompt.contains("镜头方向连续"), "{prompt}");
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
fn build_video_prompt_trims_sound_fragments_already_covered_by_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角贴墙疾行、旧宅走廊、主角、5秒、中景、稳定跟拍、屏息快步贴墙前进、紧张、阴天冷光、别回头、低声说别回头，脚步声逼近、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 别回头."));
    assert!(prompt.contains("Sound: 脚步声逼近."));
    assert!(!prompt.contains("Sound: 低声说别回头"));
}

#[test]
fn build_video_prompt_compacts_dialogue_wrapper_prefixes() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(!prompt.contains("Dialogue: 轻声说：你终于来了."));
}

#[test]
fn build_video_prompt_drops_non_semantic_vocalization_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角踉跄扶墙、废弃走廊、主角、5秒、中景、手持跟拍、踉跄扶墙前行、紧张压迫、冷调逆光、急促喘息、脚步声拖行、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Dialogue:"), "{prompt}");
    assert!(prompt.contains("Sound: 脚步声拖行."), "{prompt}");
}

#[test]
fn build_video_prompt_trims_sound_against_compacted_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、轻声说：你终于来了、轻声说你终于来了，风声回响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(prompt.contains("Sound: 风声回响."));
    assert!(!prompt.contains("Sound: 轻声说你终于来了"));
}

#[test]
fn build_video_prompt_keeps_semantic_short_dialogue() {
    let prompt = build_video_prompt(
            Some("（主角猛然回头、旧宅门厅、主角、5秒、中景、推进、猛然回头后抬手示警、紧张、冷调逆光、别出声、风声压过呼吸声、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 别出声."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_brief_dialogue_for_wide_moving_low_visibility_scene() {
    let prompt = build_video_prompt(
            Some("（林晚奔向街口、雨夜街头、林晚、5秒、远景、手持跟拍、穿过雨幕奔跑并喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Dialogue:"), "{prompt}");
    assert!(prompt.contains("Action: 穿过雨幕奔跑"), "{prompt}");
    assert!(prompt.contains("Sound: 脚步声和雨声混在一起."), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_speech_only_action_when_low_visibility_dialogue_is_dropped() {
    let prompt = build_video_prompt(
            Some("（林晚冲向街口、雨夜街头、林晚、5秒、远景、手持跟拍、喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Dialogue:"), "{prompt}");
    assert!(prompt.contains("Action: 急喊示意."), "{prompt}");
    assert!(!prompt.contains("Action: 喊别回头."), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_fragile_dialogue_even_when_speech_visibility_is_limited() {
    let prompt = build_video_prompt(
            Some("（林晚背对镜头停在走廊尽头、医院走廊、林晚、5秒、远景、拉远、背对镜头停步后失声说我真的撑不住了、崩溃压抑、冷白顶光、我真的撑不住了、空调低鸣、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 我真的撑不住了."), "{prompt}");
}

#[test]
fn build_video_prompt_drops_sound_clause_when_only_dialogue_wrapper_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、你终于来了、轻声说你终于来了、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(!prompt.contains("Sound:"));
}

#[test]
fn build_video_prompt_compacts_sound_wrapper_prefixes() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、无台词、伴随风声回响，传来木门吱呀声、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Sound: 风声回响，木门吱呀声."), "{prompt}");
    assert!(!prompt.contains("Sound: 伴随风声回响"));
    assert!(!prompt.contains("传来木门吱呀声"));
}

#[test]
fn build_video_prompt_drops_sound_wrapper_when_only_dialogue_payload_remains() {
    let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、你终于来了、耳边传来轻声说你终于来了，空气里只剩无音效、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Dialogue: 你终于来了."));
    assert!(!prompt.contains("Sound:"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_low_signal_ambient_sound_clause() {
    let prompt = build_video_prompt(
            Some("（主角缓步推门、旧宅门厅、主角、5秒、中景、慢推、缓步推门进入、压抑、冷调逆光、无台词、背景音乐渐起，四周一片死寂、A12）"),
            None,
            None,
        );

    assert!(!prompt.contains("Sound:"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_generic_footstep_sound_when_action_already_covers_it() {
    let prompt = build_video_prompt(
            Some("（黑衣人、走廊尽头、黑衣人、5秒、中景、慢推、脚步逼近门口、紧张、冷光、、脚步声逼近、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 脚步逼近门口."), "{prompt}");
    assert!(!prompt.contains("Sound:"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_detailed_door_sound_even_when_action_mentions_door() {
    let prompt = build_video_prompt(
            Some("（林夏、旧宅门厅、林夏、5秒、中景、推进、推门闯入、压迫、冷调逆光、无台词、门轴吱呀作响、A12）"),
            None,
            None,
        );

    assert!(prompt.contains("Action: 推门闯入."), "{prompt}");
    assert!(prompt.contains("Sound: 门轴吱呀作响."), "{prompt}");
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
fn compact_guardrail_sensitive_style_note_prefers_micro_performance_over_generic_emotion_carryover()
{
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚抬眼后低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中近景、缓推、抬眼后喉结轻滚再低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A22）".into()),
            duration: Some("4s".into()),
        };

    let note = compact_guardrail_sensitive_style_note(
        "情绪压抑克制，表演抬眼停顿，语气压低气息尾音发颤",
        &storyboard_row,
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    )
    .expect("guardrail-compacted note");
    assert!(note.contains("表演"), "{note}");
    assert!(!note.contains("情绪压抑"), "{note}");
}

#[test]
fn compact_guardrail_sensitive_style_note_prefers_lighting_over_decorative_environment() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制、暖金逆光、无台词、静场留白、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_guardrail_sensitive_style_note(
            "光影暖金逆光层次，环境镜面微雾",
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_identity_guardrail: true,
                has_lighting_guardrail: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        Some("光影层次".to_string())
    );
}

#[test]
fn pressure_style_note_selection_prefers_micro_performance_for_dialogue_guardrail() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚停顿后低声开口".into()),
            video_desc: Some("（林晚停顿后低声开口、办公室窗边、林晚、4秒、中景、静止、停顿后低声说你先出去、克制、夜间暖光、你先出去、空调低鸣、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_pressure_prioritized_style_note_candidate(
            &["光影暖金逆光层次".into()],
            &["表演喉结滚动，语气压低气息尾音发颤".into()],
            &[],
            &[],
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_dialogue_guardrail: true,
                has_emotion_guardrail: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        Some("表演喉结滚动，语气压低气息尾音发颤".to_string())
    );
}

#[test]
fn pressure_style_note_selection_keeps_lighting_when_only_lighting_guardrail_is_active() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在镜前".into()),
            video_desc: Some("（林晚站在镜前、化妆镜前、林晚、4秒、中景、静止、看向镜中倒影、平静、暖金逆光、无台词、静场留白、A13）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_pressure_prioritized_style_note_candidate(
            &["光影暖金逆光层次".into()],
            &["表演眼神放松".into()],
            &[],
            &[],
            &storyboard_row,
            Some(VideoPromptConstraintPressure {
                has_lighting_guardrail: true,
                forces_compact_memory: true,
                ..VideoPromptConstraintPressure::default()
            }),
        ),
        Some("光影层次".to_string())
    );
}

#[test]
fn compacted_style_pressure_score_rewards_micro_performance_under_identity_guardrail() {
    let fields = parse_structured_storyboard_description(
            "（林晚停顿后低声开口、办公室窗边、林晚、4秒、中景、静止、停顿后低声说你先出去、克制、夜间暖光、你先出去、空调低鸣、A12）",
        )
        .expect("structured storyboard");
    let pressure = VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        has_dialogue_guardrail: true,
        has_emotion_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    };

    assert!(
        score_compacted_style_note_against_constraint_pressure(
            "表演喉结滚动，语气压低气息尾音发颤",
            &fields,
            pressure,
        ) > score_compacted_style_note_against_constraint_pressure(
            "光影暖金逆光层次",
            &fields,
            pressure,
        )
    );
}

#[test]
fn compacted_style_pressure_score_rewards_visual_continuity_when_visual_bias_is_active() {
    let fields = parse_structured_storyboard_description(
            "（林晚站在雨夜窗边、办公室窗边、林晚、4秒、中景、静止、看向窗外夜色、克制、冷蓝反光、无台词、雨声、A18）",
        )
        .expect("structured storyboard");
    let pressure = VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        has_lighting_guardrail: true,
        forces_compact_memory: true,
        prefer_visual_continuity_memory_recall: true,
        ..VideoPromptConstraintPressure::default()
    };

    assert!(
        score_compacted_style_note_against_constraint_pressure(
            "光影冷蓝反光层次，镜头中景稳定",
            &fields,
            pressure,
        ) > score_compacted_style_note_against_constraint_pressure(
            "表演喉结滚动，语气压低气息尾音发颤",
            &fields,
            pressure,
        )
    );
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
fn build_pending_video_observation_note_from_runtime_reuses_loaded_rows() {
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
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 12,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec!["avoid identity drift".into()],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | avoid=avoid identity drift".into(),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: "subject=晚晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制".into(),
                },
            ],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    assert_eq!(
        build_pending_video_observation_note_from_runtime(&runtime),
        Some("待观察失败倾向：avoid identity drift".to_string())
    );
}

#[test]
fn build_pending_video_observation_note_from_runtime_uses_cached_candidates() {
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
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 12,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec!["avoid identity drift".into()],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=晚晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | style=表演抬眼停顿，语气轻声克制".into(),
            }],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    assert_eq!(
        build_pending_video_observation_note_from_runtime(&runtime),
        Some("待观察失败倾向：avoid identity drift".to_string())
    );
}

#[test]
fn build_pending_video_observation_note_from_runtime_can_use_role_observation_summary_rows() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("晚晚回头低声开口".into()),
            video_desc: Some(
                "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let runtime = StoryboardNegativePromptRuntime {
            storyboard_id: 15,
            selection: AutoNegativePromptSelection {
                prompt: None,
                fragment_count: 0,
                budget_tier: "lean",
                review_fragment_count: 0,
                rejected_memory_fragment_count: 0,
                used_pending_observation_fallback: false,
            },
            pending_observation_candidates: vec![
                "avoid face distortion or identity drift".into(),
                "avoid blank expression or monotone delivery".into(),
            ],
            rejected_rows: Vec::new(),
            selected_rows: Vec::new(),
            prompt_support_rows: vec![AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            }],
            storyboard_row: Some(storyboard_row),
            current_prompt_seed: None,
            subject_candidates,
        };

    assert_eq!(
        build_pending_video_observation_note_from_runtime(&runtime),
        Some("待观察失败倾向：avoid blank expression or monotone delivery".to_string())
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
fn contextual_observation_style_summary_drops_voice_tail_that_only_repeats_mood() {
    let rows = vec![
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content:
                "sampleCount=4 | style=表演喉结滚动，语气低声克制 | note=表演喉结滚动，语气低声克制"
                    .into(),
        },
        AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content:
                "sampleCount=6 | style=光影冷蓝窗光，环境雨丝玻璃 | note=光影冷蓝窗光，环境雨丝玻璃"
                    .into(),
        },
    ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边终于开口".into()),
            video_desc: Some("（林晚站在窗边终于开口、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A26）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        select_contextual_observation_summary_style_note(&rows, Some(&storyboard_row), &[], None,),
        Some("表演喉结滚动".to_string())
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

#[test]
fn prioritized_video_prompt_memory_prefers_script_summary_over_neighbor_local_framing_when_context_is_missing(
) {
    let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=6 | style=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊 | note=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊".into(),
            },
        ];

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, None),
        Some("情绪冷色压迫感，光影冷调逆光".to_string())
    );
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
fn exact_style_notes_do_not_yield_when_exact_note_has_non_template_signal() {
    assert!(!exact_style_notes_should_yield_to_role_memory(
        &["情绪冷色压迫感，动作自然".to_string()],
        &["表演喉结滚动，语气轻声克制".to_string()]
    ));
}

#[test]
fn prioritized_video_prompt_memory_keeps_neighbor_local_framing_when_no_summary_exists() {
    let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=镜头稳定近景，情绪冷色压迫感".into(),
        }];

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, None),
        Some("情绪冷色压迫感".to_string())
    );
}

#[test]
fn prioritized_video_prompt_memory_prefers_shorter_summary_when_context_signal_is_equal() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷色压迫感，光影冷调逆光 | note=镜头稳定跟拍，情绪冷色压迫感，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=情绪冷色压迫感，光影冷调逆光 | note=情绪冷色压迫感，光影冷调逆光".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里停步回头".into()),
            video_desc: Some("（主角停步回头、旧宅走廊、主角、5秒、中景、静止、停步回头、冷色压迫感、冷调逆光、无台词、风声回响、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
        Some("情绪冷色压迫感，光影冷调逆光".to_string())
    );
}

#[test]
fn resolve_observation_filter_style_note_skips_summary_that_only_repeats_storyboard_fields() {
    let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

    assert!(resolve_observation_filter_style_note(
        &rows,
        12,
        None,
        Some(&storyboard_row),
        &[],
        None,
    )
    .is_none());
}

#[test]
fn generate_video_prompt_response_serializes_observation_note() {
    let value = serde_json::to_value(GenerateVideoPromptResponse {
        prompt: "Single cinematic shot.".into(),
        negative_prompt: None,
        observation_note: Some("待观察失败倾向：avoid shaky handheld motion".into()),
        diagnostics: GenerateVideoPromptDiagnostics {
            prompt_chars: 22,
            negative_prompt_chars: 0,
            negative_constraint_count: 0,
            negative_budget_tier: "lean".into(),
            auto_negative_source: Some("pending_observation_note".into()),
            auto_negative_review_fragment_count: 0,
            auto_negative_memory_fragment_count: 0,
            observation_note_chars: 40,
            role_anchor_count: 1,
            scene_anchor_count: 1,
            tool_anchor_count: 0,
            style_anchor_count: 1,
            memory_style_anchor_count: 0,
            memory_delivery_anchor_count: 0,
            memory_delivery_priority_applied: false,
            recent_quality_memory_biases: vec!["delivery".into(), "visual_continuity".into()],
            memory_top_candidate_score: 11,
            memory_selected_primary_bucket: Some("表演".into()),
            memory_low_value_candidate_skipped: false,
            memory_style_chars: 0,
            memory_visual_chars: 0,
            memory_delivery_chars: 0,
            memory_hit_buckets: vec!["表演".into(), "语气".into()],
            memory_suppressed_buckets: vec!["动作".into()],
            memory_hit_bucket_counts: [("表演".into(), 2usize), ("语气".into(), 1usize)]
                .into_iter()
                .collect(),
            memory_suppressed_bucket_counts: [("动作".into(), 3usize)].into_iter().collect(),
            memory_optimization_applied: true,
            memory_optimization_removed_rows: 2,
            memory_optimization_removed_chars: 88,
            memory_optimization_removed_visual_rows: 1,
            memory_optimization_removed_duplicate_rows: 1,
            director_manual_yielded_to_memory: false,
            director_manual_yielded_chars: 0,
            director_performance_trimmed_chars: 0,
            director_anchor_saved_chars: 0,
            continuity_note_count: 0,
            continuity_note_chars: 0,
            uses_reference_frame: false,
            memory_budget_tier: "lean".into(),
        },
        model: "runway-gen-2".into(),
        duration: 5,
    })
    .expect("serialize response");

    assert_eq!(
        value
            .get("observationNote")
            .and_then(serde_json::Value::as_str),
        Some("待观察失败倾向：avoid shaky handheld motion")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("recentQualityMemoryBiases"))
            .and_then(serde_json::Value::as_array)
            .map(|items| items.len()),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryHitBuckets"))
            .and_then(serde_json::Value::as_array)
            .map(|items| items.len()),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memorySuppressedBuckets"))
            .and_then(serde_json::Value::as_array)
            .map(|items| items.len()),
        Some(1)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryHitBucketCounts"))
            .and_then(|item| item.get("表演"))
            .and_then(serde_json::Value::as_u64),
        Some(2)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memorySuppressedBucketCounts"))
            .and_then(|item| item.get("动作"))
            .and_then(serde_json::Value::as_u64),
        Some(3)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryTopCandidateScore"))
            .and_then(serde_json::Value::as_i64),
        Some(11)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memorySelectedPrimaryBucket"))
            .and_then(serde_json::Value::as_str),
        Some("表演")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryLowValueCandidateSkipped"))
            .and_then(serde_json::Value::as_bool),
        Some(false)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("promptChars"))
            .and_then(serde_json::Value::as_u64),
        Some(22)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("negativeConstraintCount"))
            .and_then(serde_json::Value::as_u64),
        Some(0)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("negativeBudgetTier"))
            .and_then(serde_json::Value::as_str),
        Some("lean")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("autoNegativeSource"))
            .and_then(serde_json::Value::as_str),
        Some("pending_observation_note")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryBudgetTier"))
            .and_then(serde_json::Value::as_str),
        Some("lean")
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryDeliveryAnchorCount"))
            .and_then(serde_json::Value::as_u64),
        Some(0)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryDeliveryPriorityApplied"))
            .and_then(serde_json::Value::as_bool),
        Some(false)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryOptimizationApplied"))
            .and_then(serde_json::Value::as_bool),
        Some(true)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("memoryOptimizationRemovedChars"))
            .and_then(serde_json::Value::as_u64),
        Some(88)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("directorManualYieldedToMemory"))
            .and_then(serde_json::Value::as_bool),
        Some(false)
    );
    assert_eq!(
        value
            .get("diagnostics")
            .and_then(|item| item.get("directorAnchorSavedChars"))
            .and_then(serde_json::Value::as_u64),
        Some(0)
    );
}

#[test]
fn build_auto_quality_review_model_params_includes_memory_diagnostics() {
    let diagnostics = GenerateVideoPromptDiagnostics {
        prompt_chars: 120,
        negative_prompt_chars: 24,
        negative_constraint_count: 1,
        negative_budget_tier: "lean".into(),
        auto_negative_source: Some("rejected_memory".into()),
        auto_negative_review_fragment_count: 1,
        auto_negative_memory_fragment_count: 1,
        observation_note_chars: 18,
        role_anchor_count: 1,
        scene_anchor_count: 1,
        tool_anchor_count: 0,
        style_anchor_count: 2,
        memory_style_anchor_count: 1,
        memory_delivery_anchor_count: 1,
        memory_delivery_priority_applied: true,
        recent_quality_memory_biases: vec!["delivery".into()],
        memory_top_candidate_score: 17,
        memory_selected_primary_bucket: Some("表演".into()),
        memory_low_value_candidate_skipped: true,
        memory_style_chars: 22,
        memory_visual_chars: 0,
        memory_delivery_chars: 22,
        memory_hit_buckets: vec!["表演".into()],
        memory_suppressed_buckets: vec!["环境".into()],
        memory_hit_bucket_counts: [("表演".into(), 1usize)].into_iter().collect(),
        memory_suppressed_bucket_counts: [("环境".into(), 1usize)].into_iter().collect(),
        memory_optimization_applied: false,
        memory_optimization_removed_rows: 0,
        memory_optimization_removed_chars: 0,
        memory_optimization_removed_visual_rows: 0,
        memory_optimization_removed_duplicate_rows: 0,
        director_manual_yielded_to_memory: false,
        director_manual_yielded_chars: 0,
        director_performance_trimmed_chars: 0,
        director_anchor_saved_chars: 0,
        continuity_note_count: 0,
        continuity_note_chars: 0,
        uses_reference_frame: true,
        memory_budget_tier: "lean".into(),
    };

    let value = build_auto_quality_review_model_params(&diagnostics);

    assert_eq!(
        value
            .pointer("/diagnostics/memoryTopCandidateScore")
            .and_then(serde_json::Value::as_i64),
        Some(17)
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memorySelectedPrimaryBucket")
            .and_then(serde_json::Value::as_str),
        Some("表演")
    );
    assert_eq!(
        value
            .pointer("/diagnostics/memoryLowValueCandidateSkipped")
            .and_then(serde_json::Value::as_bool),
        Some(true)
    );
}

#[test]
fn generate_video_prompt_body_accepts_auto_quality_review_flag() {
    let body: GenerateVideoPromptBody = serde_json::from_str(
        r#"{"projectId":1,"scriptId":2,"storyboardId":3,"autoQualityReview":true}"#,
    )
    .unwrap();
    assert_eq!(body.project_id, 1);
    assert_eq!(body.script_id, 2);
    assert_eq!(body.storyboard_id, Some(3));
    assert!(body.auto_quality_review);
}

#[test]
fn build_video_prompt_with_diagnostics_reports_anchor_and_memory_counts() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、停步回头确认身后动静、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损".into()],
            memory_style_notes: vec!["镜头低机位压迫感".into()],
            continuity_notes: vec!["保留上一镜头走位连续".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result
        .prompt
        .contains("Use the supplied frame as reference."));
    assert_eq!(result.diagnostics.role_anchor_count, 1);
    assert_eq!(result.diagnostics.scene_anchor_count, 1);
    assert_eq!(result.diagnostics.tool_anchor_count, 1);
    assert_eq!(result.diagnostics.style_anchor_count, 2);
    assert_eq!(result.diagnostics.memory_style_anchor_count, 1);
    assert_eq!(result.diagnostics.memory_delivery_anchor_count, 0);
    assert!(result.diagnostics.memory_style_chars > 0);
    assert!(result.diagnostics.memory_visual_chars > 0);
    assert_eq!(result.diagnostics.memory_delivery_chars, 0);
    assert!(!result.diagnostics.director_manual_yielded_to_memory);
    assert_eq!(result.diagnostics.director_manual_yielded_chars, 0);
    assert_eq!(result.diagnostics.director_performance_trimmed_chars, 0);
    assert_eq!(result.diagnostics.director_anchor_saved_chars, 0);
    assert_eq!(result.diagnostics.continuity_note_count, 1);
    assert!(result.diagnostics.continuity_note_chars > 0);
    assert!(result.diagnostics.uses_reference_frame);
    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
    assert!(result.diagnostics.prompt_chars > 0);
}

#[test]
fn build_video_prompt_with_diagnostics_reports_memory_yield_and_delivery_anchor_usage() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: Some("情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_style_anchor_count, 1);
    assert_eq!(result.diagnostics.memory_delivery_anchor_count, 1);
    assert_eq!(result.diagnostics.memory_visual_chars, 0);
    assert!(result.diagnostics.memory_delivery_chars > 0);
    assert!(result.diagnostics.director_manual_yielded_to_memory);
    assert!(result.diagnostics.director_manual_yielded_chars > 0);
    assert_eq!(
        result.diagnostics.director_anchor_saved_chars,
        result.diagnostics.director_manual_yielded_chars
            + result.diagnostics.director_performance_trimmed_chars
    );
}

#[test]
fn build_video_prompt_with_diagnostics_adds_complementary_memory_anchor_in_expanded_tier() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚缓慢开口、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头微动后低声说你终于来了、隐忍压抑、冷蓝窗光、你终于来了、雨声回响、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec![
                "光影冷蓝窗光，环境雨丝玻璃".into(),
                "表演喉结滚动，语气压低尾音发颤".into(),
            ],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
    assert_eq!(result.diagnostics.memory_style_anchor_count, 2);
    assert_eq!(result.diagnostics.memory_delivery_anchor_count, 1);
    assert!(result.diagnostics.memory_delivery_priority_applied);
    assert!(result.diagnostics.memory_visual_chars > 0);
    assert!(result.diagnostics.memory_delivery_chars > 0);
    assert!(
        result.diagnostics.memory_style_chars <= 56,
        "{}",
        result.prompt
    );
    assert!(
        result
            .prompt
            .contains("Style anchor: 表演喉结滚动，语气压低尾音发颤; 光影冷蓝窗光，环境雨丝玻璃."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_reports_trimmed_director_performance_chars() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚低声开口、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后压住气息低声说你终于来了、隐忍压抑、冷蓝窗光、你终于来了、雨声、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演神情低落，眼神黯淡，眉心轻蹙，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(result.diagnostics.director_performance_trimmed_chars > 0);
    assert_eq!(result.diagnostics.director_manual_yielded_chars, 0);
    assert_eq!(
        result.diagnostics.director_anchor_saved_chars,
        result.diagnostics.director_performance_trimmed_chars
    );
}

#[test]
fn build_video_prompt_with_diagnostics_uses_lean_memory_tier_for_grounded_low_risk_shot() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS);
    assert!(
        !result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Character: 林晚:黑色针织外套."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Scene: 咖啡厅窗边:木桌与雨痕玻璃."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Prop: 咖啡杯:陶瓷白杯."),
        "{}",
        result.prompt
    );
    assert!(
        result
            .prompt
            .contains("Style: 真人都市写实; 咖啡热气; 动作自然; 表演眼神放松."),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("Character anchor:"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("Scene anchor:"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("Prop anchor:"), "{}", result.prompt);
    assert!(
        !result.prompt.contains("Style anchor:"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_can_pull_emotional_scene_back_to_lean_when_base_anchors_are_present(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停步回头、旧宅走廊、林晚、4秒、中景、缓推、回头后强忍情绪低声开口、压抑哽咽、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["旧宅走廊: 冷蓝反光墙面".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪压抑克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        None,
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_emotion_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪压抑克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_reference_frame_yields_decorative_style_anchors_for_fragile_dialogue_turn(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边低声开口、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、抿唇停顿后低声说你终于来了、隐忍 / 克制、夜间冷蓝窗光、你终于来了、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤，环境咖啡热气".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result
        .prompt
        .contains("Use the supplied frame as reference."));
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(
        result.prompt.contains("语气压低气息尾音发颤"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("咖啡热气"), "{}", result.prompt);
    assert!(!result.prompt.contains("动作自然"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_reference_frame_keeps_visual_style_anchor_when_lighting_guardrail_is_active(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚在镜前低声开口、化妆镜前、林晚、4秒、近景、静止、抿唇停顿后低声说我没事、克制隐忍、暖金逆光、我没事、静场留白、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["化妆镜前: 镜面暖光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演眼神迟疑，光影暖金逆光层次".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        result.prompt.contains("光影暖金逆光层次"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_grounded_low_risk_shot_in_lean_tier_when_continuity_note_is_only_generic_tail(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: vec!["保持上一镜头衔接统一".into()],
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(result.prompt.contains("Single shot."), "{}", result.prompt);
    assert!(
        !result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_drops_specific_continuity_note_without_scene_risk() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(!result.prompt.contains("Continuity:"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_single_specific_continuity_note_when_axis_risk_exists()
{
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚对视后停步、咖啡厅门口、林晚、4秒、中景、缓推、对视后停步回头、克制紧张、夜间暖光、你怎么来了、杯碟轻响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅门口: 木门与暖色玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
    assert_eq!(result.diagnostics.continuity_note_count, 1);
    assert!(
        result
            .prompt
            .contains("Continuity notes: 保留上一镜头走位连续，站位不要跳轴."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_drops_axis_continuity_for_single_subject_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边低声说话、咖啡厅窗边、林晚、4秒、中景、缓推、看向门口后低声说你终于来了、隐忍、夜间暖光、你终于来了、轻微杯碟声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与暖色玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演呼吸压住情绪，眼神迟疑".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(!result.prompt.contains("Continuity:"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_drops_axis_continuity_for_multi_subject_filler_utterance_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚和顾承泽对视、咖啡厅门口、林晚/顾承泽、4秒、中景、缓推、对视后微微点头、克制紧张、夜间暖光、嗯、轻微杯碟声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into(), "顾承泽: 深灰大衣".into()],
            script_scene_anchors: vec!["咖啡厅门口: 木门与暖色玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神迟疑，动作轻缓克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续，人物站位不要跳轴".into()],
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(!result.prompt.contains("Continuity:"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_grounded_anchor_complete_shot_in_lean_tier_without_reference_frame(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.continuity_note_count, 0);
    assert!(result.prompt.contains("Single shot."), "{}", result.prompt);
    assert!(
        result.prompt.contains("Character: 林晚:黑色针织外套."),
        "{}",
        result.prompt
    );
    assert!(
        !result
            .prompt
            .contains("Use the supplied frame as reference."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_drops_subject_and_setting_when_anchor_keys_match() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: vec!["咖啡杯: 陶瓷白杯".into()],
            memory_style_notes: vec!["表演眼神放松，动作轻缓克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(!result.prompt.contains("Subject:"), "{}", result.prompt);
    assert!(!result.prompt.contains("Setting:"), "{}", result.prompt);
    assert!(
        result.prompt.contains("Character: 林晚:黑色针织外套."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Scene: 咖啡厅窗边:木桌与雨痕玻璃."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Action: 看向窗外."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_subject_when_anchor_key_only_partially_matches() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚看向门外、雨夜门厅、林晚、4秒、中景、稳定跟拍、停步回头、克制、冷调逆光、无台词、雨声回响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚礼服版: 黑色丝绒长裙".into()],
            script_scene_anchors: vec!["旧宅门厅: 雨水反光石阶".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(
        result.prompt.contains("Subject: 林晚."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Setting: 雨夜门厅."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_performance_fragment_in_lean_memory_tier() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、看向窗外、平静、夜间暖光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，环境咖啡热气，表演眼神放松".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演眼神放松"), "{}", result.prompt);
    assert!(!result.prompt.contains("镜头稳定跟拍"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_micro_expression_fragment_in_lean_memory_tier() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、欲言又止后停顿片刻、隐忍克制、夜间冷蓝窗光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演自然克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("表演自然克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_skips_voice_fragment_for_truly_silent_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚/咖啡杯、4秒、中景、缓推、看向窗外、隐忍克制、夜间冷蓝窗光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演抬眼停顿"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气轻声"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_with_diagnostics_drops_mood_only_voice_tail_for_emotional_lean_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、欲言又止后低声开口、隐忍哽咽、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气低声克制，环境咖啡热气".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声克制"), "{}", result.prompt);
    assert!(!result.prompt.contains("环境咖啡热气"), "{}", result.prompt);
    assert!(
        result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
        "{:?}",
        result.diagnostics
    );
}

#[test]
fn compact_contextual_video_style_note_drops_voice_fragment_when_trim_only_leaves_mood_tail() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边终于开口".into()),
            video_desc: Some("（林晚站在窗边终于开口、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A26）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演喉结滚动，语气低声克制", Some(&storyboard_row),),
        Some("表演喉结滚动".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_generic_emotion_and_motion_carryover_for_dialogue_scene(
) {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边低声开口".into()),
            video_desc: Some("（林晚站在窗边低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、隐忍 / 克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note(
            "情绪压抑克制，动作自然，表演喉结滚动",
            Some(&storyboard_row),
        ),
        Some("表演喉结滚动".to_string())
    );
}

#[test]
fn build_video_prompt_drops_voice_fragment_when_action_and_mood_already_cover_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、低声开口后停顿、克制、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_drops_stale_soft_voice_fragment_for_fragile_turning_point() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、呼吸发颤后哽咽开口、哽咽压抑、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气轻声"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_constraint_pressure_keeps_micro_performance_but_drops_generic_voice_and_mood_memory(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、低声说你别看我后喉结发紧、压抑哽咽、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪压抑克制，语气低声克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_emotion_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪压抑"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_identity_guardrail_drops_generic_environment_and_motion_memory() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚在窗边停住、咖啡厅窗边、林晚、4秒、中景、缓推、停住后看向门外、克制、夜间暖光、无台词、轻微杯碟声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与暖色玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["动作克制自然，环境雨丝玻璃，表演眼神迟疑".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演眼神迟疑"), "{}", result.prompt);
    assert!(!result.prompt.contains("动作克制自然"), "{}", result.prompt);
    assert!(!result.prompt.contains("环境雨丝玻璃"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_identity_guardrail_drops_generic_voice_memory_without_micro_detail() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、低声说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["语气低声克制，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_identity_dialogue_scene_keeps_micro_performance_and_high_signal_voice_pair() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后压低气息说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(
        result.prompt.contains("语气压低气息尾音发颤"),
        "{}",
        result.prompt
    );
    assert!(
        result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
        "{:?}",
        result.diagnostics
    );
}

#[test]
fn build_video_prompt_identity_dialogue_scene_still_skips_generic_voice_pair() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后低声说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_dialogue_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气低声"), "{}", result.prompt);
    assert!(!result.prompt.contains("语气克制"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_constraint_pressure_adds_guardrail_performance_anchor_for_flat_dialogue_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边开口、咖啡厅窗边、林晚、4秒、中景、缓推、看向门外说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_emotion_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        result.prompt.contains("气息带情绪起伏"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_adds_proactive_performance_anchor_for_fragile_dialogue_scene_without_pressure(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚强忍泪意低声说我没事、病房门口、林晚、4秒、近景、缓推、抽气后低声说我没事、压抑、冷白侧光、我没事、空调低鸣、A18）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["病房门口: 冷白墙面与玻璃门".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, Some("https://example.com/frame.png"), Some(&context));

    assert!(prompt.contains("开口前先压住气息"), "{prompt}");
    assert!(prompt.contains("尾音带轻颤"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_proactive_performance_anchor_when_storyboard_already_has_micro_performance(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后压低气息说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, Some("https://example.com/frame.png"), Some(&context));

    assert!(!prompt.contains("眼神先动再开口"), "{prompt}");
    assert!(!prompt.contains("开口前先压住气息"), "{prompt}");
    assert!(!prompt.contains("尾音带轻颤"), "{prompt}");
}

#[test]
fn build_video_prompt_constraint_pressure_skips_guardrail_performance_anchor_when_micro_performance_already_present(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚近景低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、抬眼后压低气息说你先走、克制、夜间冷蓝窗光、你先走、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        !result.prompt.contains("眼神先动再开口"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("气息带情绪起伏"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_drops_decorative_environment_texture_for_dialogue_guardrail_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微站在落地窗旁开口、城市夜景落地窗边、沈知微、4秒、中景、缓推、抬眼后压低气息说你终于来了、隐忍 / 克制、冷蓝窗光与路灯反射、你终于来了、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: vec!["城市夜景落地窗边: 雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_dialogue_guardrail: true,
            has_identity_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(result.prompt.contains("表演抬眼停顿"), "{}", result.prompt);
    assert!(
        result.prompt.contains("语气压低气息尾音发颤"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("赛璐璐动态质感"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_constraint_pressure_still_keeps_environment_anchor_for_non_dialogue_lighting_guardrail(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在车窗边停住、雨夜街边车窗、林晚、4秒、中景、静止、抬眼看向倒影、克制隐忍、霓虹反光逆光、无台词、车流闷响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["雨夜街边车窗: 玻璃水痕".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["光影霓虹反光层次".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert!(
        result.prompt.contains("霓虹") || result.prompt.contains("反光"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_drops_generic_emotion_and_motion_carryover_for_dialogue_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、隐忍克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["咖啡厅窗边: 木桌与雨痕玻璃".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪压抑克制，动作自然，表演喉结滚动".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert!(result.prompt.contains("表演喉结滚动"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪压抑"), "{}", result.prompt);
    assert!(!result.prompt.contains("情绪克制"), "{}", result.prompt);
    assert!(!result.prompt.contains("动作自然"), "{}", result.prompt);
}

#[test]
fn compact_contextual_video_style_note_drops_stale_role_voice_when_scene_turns_fragile() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚终于失声开口".into()),
            video_desc: Some("（林晚终于失声开口、咖啡厅窗边、林晚、4秒、中景、缓推、呼吸发颤后哽咽开口、哽咽压抑、夜间冷蓝窗光、你别看我、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演呼吸发颤，语气轻声克制", Some(&storyboard_row),),
        Some("表演呼吸发颤".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_keeps_high_signal_performance_detail_for_dialogue_scene() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边低声开口".into()),
            video_desc: Some("（林晚站在窗边低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、停顿后低声说你终于来了、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演喉结滚动，语气轻声克制", Some(&storyboard_row),),
        Some("语气轻声，表演喉结滚动".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_keeps_identity_micro_performance_for_silent_close_up() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制、暖金逆光、无台词、静场留白、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演眼神迟疑，语气轻声克制", Some(&storyboard_row),),
        Some("表演眼神迟疑".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_keeps_action_matched_performance_for_silent_identity_scene()
{
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼停顿后看向镜中倒影、克制、暖金逆光、无台词、静场留白、A12）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("光影暖金逆光，表演抬眼停顿", Some(&storyboard_row),),
        Some("表演抬眼停顿".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_voice_fragment_for_low_visibility_hidden_speech() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚穿过雨幕回头".into()),
            video_desc: Some("（林晚穿过雨幕回头、雨夜街头、林晚、5秒、远景、手持跟拍、穿过雨幕奔跑并喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("语气轻声克制，声场雨声回响", Some(&storyboard_row),),
        Some("声场雨声回响".to_string())
    );
}

#[test]
fn compact_contextual_video_style_note_drops_soft_voice_for_broken_breath_turn() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚失声后勉强开口".into()),
            video_desc: Some("（林晚失声后勉强开口、咖啡厅窗边、林晚、4秒、中景、缓推、抽气后失声开口、压抑、夜间冷蓝窗光、我没事、轻微环境声、A13）".into()),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_contextual_video_style_note("表演喉结滚动，语气轻声克制", Some(&storyboard_row),),
        None
    );
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_lighting_fragment_in_lean_memory_tier_for_reflective_scene(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚立在车窗边、雨夜街边车窗、林晚、4秒、中景、静止、抬眼看向倒影、克制隐忍、霓虹反光逆光、无台词、车流闷响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["雨夜街边车窗: 玻璃水痕".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演眼神放松，光影霓虹反光层次，环境车窗水痕".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(
        result.prompt.contains("光影霓虹反光层次"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("表演眼神放松"), "{}", result.prompt);
}

#[test]
fn build_video_prompt_constraint_pressure_keeps_micro_performance_and_lighting_pair_for_identity_close_up(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影、克制隐忍、暖金逆光、无台词、静场留白、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: vec!["化妆镜前: 镜面暖光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演眼神迟疑，光影暖金逆光层次，环境镜面微雾".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_constraint_pressure(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
        Some(VideoPromptConstraintPressure {
            has_identity_guardrail: true,
            has_lighting_guardrail: true,
            forces_compact_memory: true,
            ..VideoPromptConstraintPressure::default()
        }),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(result.prompt.contains("表演眼神迟疑"), "{}", result.prompt);
    assert!(
        result.prompt.contains("光影暖金逆光层次"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("环境镜面微雾"), "{}", result.prompt);
    assert!(
        result.diagnostics.memory_style_chars <= VIDEO_PROMPT_LEAN_MEMORY_NOTE_MAX_CHARS,
        "{:?}",
        result.diagnostics
    );
}

#[test]
fn build_video_prompt_with_diagnostics_prefers_motion_fragment_in_lean_memory_tier_for_follow_shot()
{
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚穿过旧楼梯口、旧楼梯口、林晚、4秒、中景、稳定跟拍、快步下楼回头、紧张克制、冷色走廊灯、无台词、脚步空响、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色风衣".into()],
            script_scene_anchors: vec!["旧楼梯口: 冷色墙面".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演呼吸发颤，镜头稳定跟拍压迫，动作快步回头停顿".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert!(
        result.prompt.contains("动作快步回头停顿") || result.prompt.contains("镜头稳定跟拍压迫"),
        "{}",
        result.prompt
    );
    assert!(!result.prompt.contains("表演呼吸发颤"), "{}", result.prompt);
    assert!(
        !result.prompt.contains("Natural motion"),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("No extra shot changes."),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_with_diagnostics_skips_low_value_memory_anchor_in_low_risk_lean_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚坐在客厅沙发、客厅沙发、林晚、4秒、中景、静止、安静看向桌面、平静、室内自然光、无台词、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 米色针织衫".into()],
            script_scene_anchors: vec!["客厅沙发: 木桌与浅灰布艺".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["环境客厅空气安静".into()],
            continuity_notes: Vec::new(),
        };

    let result = build_video_prompt_with_diagnostics(
        None,
        Some("https://example.com/frame.png"),
        Some(&context),
    );

    assert_eq!(result.diagnostics.memory_budget_tier, "lean");
    assert_eq!(result.diagnostics.memory_top_candidate_score, 3);
    assert_eq!(result.diagnostics.memory_selected_primary_bucket, None);
    assert!(result.diagnostics.memory_low_value_candidate_skipped);
    assert_eq!(result.diagnostics.memory_style_anchor_count, 0);
    assert_eq!(result.diagnostics.memory_style_chars, 0);
    assert!(
        !result.prompt.contains("环境客厅空气安静"),
        "{}",
        result.prompt
    );
}

#[test]
fn build_video_prompt_drops_motion_tail_when_continuity_note_already_carries_motion_guidance() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头动作节奏连续".into()],
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Continuity notes: 动作节奏连续."),
        "{prompt}"
    );
    assert!(prompt.contains("No extra shot changes."), "{prompt}");
    assert!(!prompt.contains("Natural motion"), "{prompt}");
    assert!(!prompt.contains("stable continuity"), "{prompt}");
}

#[test]
fn build_video_prompt_with_diagnostics_keeps_full_labels_for_high_risk_scene() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚冲出旧宅、旧宅走廊、林晚/青铜匕首、5秒、中景、稳定跟拍、快步推门冲出、哽咽压抑、逆光雨夜、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色风衣，短发".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损".into()],
            memory_style_notes: vec!["表演呼吸发颤，语气哽咽克制".into()],
            continuity_notes: vec!["保留上一镜头走位连续".into()],
        };

    let result = build_video_prompt_with_diagnostics(None, None, Some(&context));

    assert!(
        result
            .prompt
            .contains("Character anchor: 林晚:黑色风衣，短发."),
        "{}",
        result.prompt
    );
    assert!(
        result
            .prompt
            .contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."),
        "{}",
        result.prompt
    );
    assert!(
        result.prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损."),
        "{}",
        result.prompt
    );
    assert!(result.prompt.contains("Style anchor:"), "{}", result.prompt);
    assert!(
        result.prompt.contains("Continuity notes:"),
        "{}",
        result.prompt
    );
    assert!(
        !result.prompt.contains("Character: 林晚"),
        "{}",
        result.prompt
    );
    assert_eq!(result.diagnostics.memory_budget_tier, "expanded");
}

#[test]
fn build_video_prompt_adds_art_style_performance_anchor_for_matching_mood() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情内敛, 眼神深沉, 唇线收紧"),
        "{prompt}"
    );
    assert!(prompt.contains("动作自然"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_generic_director_mood_when_art_style_performance_anchor_exists() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("情绪隐忍克制，镜头衔接统一".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情内敛, 眼神深沉, 唇线收紧"),
        "{prompt}"
    );
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
    assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_unique_director_camera_fragment_after_dropping_generic_mood() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("低机位压迫感，情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("低机位压迫感"), "{prompt}");
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
    assert!(prompt.contains("神情内敛, 眼神深沉, 唇线收紧"), "{prompt}");
}

#[test]
fn build_video_prompt_prefers_fragile_director_anchor_for_broken_voice_turn() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、咖啡厅窗边、林晚、4秒、中景、缓推、抽气后失声开口、隐忍哽咽、夜间冷蓝窗光、我没事、轻微环境声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情低落, 眼神黯淡, 眉心轻蹙"),
        "{prompt}"
    );
    assert!(!prompt.contains("动作自然"), "{prompt}");
    assert!(!prompt.contains("神情内敛"), "{prompt}");
    assert!(!prompt.contains("眼神深沉"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}

#[test]
fn build_video_prompt_prefers_fragile_director_anchor_for_sad_anime_turn() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微停在雨夜落地窗旁、城市夜景落地窗边、沈知微、4秒、中景、缓推、哽咽后强忍泪意看向窗外、隐忍哽咽、冷蓝窗光与路灯反射、无台词、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 成熟都市言情二次元动画; 神情哀戚, 眼神低垂, 眉头轻锁"),
        "{prompt}"
    );
    assert!(!prompt.contains("动作缓慢"), "{prompt}");
    assert!(!prompt.contains("神情内敛"), "{prompt}");
    assert!(!prompt.contains("眼神深沉"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}

#[test]
fn compact_director_emotion_fragment_group_prefers_high_signal_cue() {
    assert_eq!(
        compact_director_emotion_fragment_group(
            "神情内敛，面容沉静",
            DirectorEmotionFragmentGroup::Face,
        )
        .as_deref(),
        Some("神情内敛")
    );
    assert_eq!(
        compact_director_emotion_fragment_group(
            "眼神深沉，眼底有情绪压抑",
            DirectorEmotionFragmentGroup::Eyes,
        )
        .as_deref(),
        Some("眼神深沉")
    );
    assert_eq!(
        compact_director_emotion_fragment_group(
            "眉心轻蹙，表情内敛",
            DirectorEmotionFragmentGroup::MicroExpression,
        )
        .as_deref(),
        Some("眉心轻蹙")
    );
}

#[test]
fn build_video_prompt_keeps_unique_micro_expression_when_memory_overlaps_director_anchor() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演神情内敛眼神深沉喉结滚动，语气轻声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 真人都市写实; 神情内敛, 眼神深沉, 唇线收紧;"),
        "{prompt}"
    );
    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演神情内敛眼神深沉喉结滚动"), "{prompt}");
}

#[test]
fn build_video_prompt_drops_director_performance_anchor_when_delivery_memory_already_covers_fragile_turn(
) {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抽气后失声开口、隐忍哽咽、冷蓝窗光、我没事、雨声、A14）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演神情低落，眼神黯淡，眉心轻蹙，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 真人都市写实;"), "{prompt}");
    assert!(prompt.contains("表演神情低落"), "{prompt}");
    assert!(prompt.contains("语气压低气息尾音发颤"), "{prompt}");
    assert!(
        !prompt.contains("神情低落, 眼神黯淡, 眉心轻蹙;"),
        "{prompt}"
    );
}

#[test]
fn build_video_prompt_lets_high_value_memory_replace_generic_director_mood_on_fragile_turn() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A14）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(prompt.contains("语气压低气息尾音发颤"), "{prompt}");
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
}

#[test]
fn build_video_prompt_keeps_visual_director_note_even_when_memory_handles_delivery() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A14）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: Some("低机位压迫感，情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动，语气压低气息尾音发颤".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("低机位压迫感"), "{prompt}");
    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(prompt.contains("语气压低气息尾音发颤"), "{prompt}");
    assert!(!prompt.contains("情绪隐忍克制"), "{prompt}");
}

#[test]
fn build_video_prompt_compacts_director_performance_anchor_to_high_signal_cues() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微站在落地窗旁、城市夜景落地窗边、沈知微、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(
        prompt.contains("Style anchor: 成熟都市言情动画风格; 神情内敛, 眼神深沉, 唇线收紧;"),
        "{prompt}"
    );
    assert!(!prompt.contains("面容沉静"), "{prompt}");
    assert!(!prompt.contains("眼底有情绪压抑"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_director_micro_expression_when_storyboard_already_states_it() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A14）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("Style anchor: 真人都市写实;"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_performance_anchor_without_matching_art_style_profile() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在门口停下、门口、主角、4秒、中景、静止、停步回望、紧张、阴天冷光、无台词、风声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("眼神深沉"));
    assert!(!prompt.contains("表情略带茫然"));
}

#[test]
fn parse_director_emotion_cues_reads_bundled_emotion_table() {
    let profile = art_style_director_profile("成熟都市言情二次元动画").expect("matched art style");
    let cues = parse_director_emotion_cues(profile.director_storyboard);

    assert!(cues.iter().any(|cue| {
        cue.emotion_terms.iter().any(|term| term == "隐忍")
            && cue.face == "神情内敛，面容沉静"
            && cue.eyes == "眼神深沉，眼底有情绪压抑"
    }));
}

#[test]
fn parse_director_motion_cue_reads_bundled_motion_style_section() {
    let profile = art_style_director_profile("国风二次元").expect("matched art style");
    let cue = parse_director_motion_cue(profile.director_storyboard_table_style);

    assert_eq!(cue.as_deref(), Some("动作缓慢优雅"));
}

#[test]
fn parse_director_environment_cues_reads_bundled_environment_section() {
    let profile = art_style_director_profile("真人都市写实").expect("matched art style");
    let cues = parse_director_environment_cues(profile.director_storyboard_table_style);

    assert!(cues.iter().any(|cue| cue == "咖啡热气"));
    assert!(cues.iter().any(|cue| cue == "手机屏幕亮灭"));
}

#[test]
fn parse_director_environment_texture_cues_reads_bundled_texture_section() {
    let profile = art_style_director_profile("成熟都市言情二次元动画").expect("matched art style");
    let cues = parse_director_environment_texture_cues(profile.director_storyboard_table_style);

    assert!(cues.iter().any(|cue| cue.cue == "手绘光影斑驳"));
    assert!(cues.iter().any(|cue| cue.cue == "细腻线条动态"));
    assert!(cues.iter().any(|cue| cue.cue == "赛璐璐动态质感"));
}

#[test]
fn build_video_prompt_adds_environment_style_anchor_for_matching_setting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在咖啡厅窗边、咖啡厅窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、夜间冷蓝窗光、无台词、雨声、A12）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("真人都市写实".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("咖啡热气"), "{prompt}");
    assert!(prompt.contains("动作自然"), "{prompt}");
}

#[test]
fn build_video_prompt_adds_environment_texture_style_anchor_for_matching_setting() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微站在落地窗旁、城市夜景落地窗边、沈知微、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert_eq!(prompt.matches("雨丝划过玻璃").count(), 1, "{prompt}");
    assert!(prompt.contains("赛璐璐动态质感"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_environment_style_anchor_for_dense_environment_storyboard() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（沈知微站在落地窗旁、城市夜景落地窗边、沈知微、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A13）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["沈知微: 米色风衣".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("窗帘轻摆"), "{prompt}");
    assert!(!prompt.contains("车流光影"), "{prompt}");
    assert!(!prompt.contains("路灯光晕闪烁"), "{prompt}");
    assert!(prompt.contains("赛璐璐动态质感"), "{prompt}");
}

#[test]
fn build_video_prompt_skips_weak_environment_texture_fallback_without_direct_match() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚停在公司走廊尽头、公司走廊尽头、林晚、4秒、中景、缓推、拽了拽袖口后停住、隐忍 / 克制、灰冷顶色、无台词、空调低鸣、A41）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("成熟都市言情二次元动画".into()),
            project_director_manual: None,
            script_role_anchors: vec!["林晚: 黑色西装外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(!prompt.contains("细腻线条动态"), "{prompt}");
    assert!(!prompt.contains("手绘光影斑驳"), "{prompt}");
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
fn build_video_prompt_keeps_compacted_delivery_memory_anchor_high_value() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A31）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: Some("情绪隐忍克制".into()),
            script_role_anchors: vec!["林晚: 黑色针织外套".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演喉结滚动低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动低声"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_shared_performance_keywords_but_keeps_micro_expression_detail() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A24）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演抬眼停顿喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演抬眼停顿喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演抬眼"), "{prompt}");
}

#[test]
fn build_video_prompt_trims_synonymous_performance_micro_expression_but_keeps_unique_detail() {
    let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抿唇后停顿片刻才低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A25）".into()),
            storyboard_duration: Some("4s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["表演唇线收紧喉结滚动，语气低声克制".into()],
            continuity_notes: Vec::new(),
        };

    let prompt = build_video_prompt(None, None, Some(&context));

    assert!(prompt.contains("表演喉结滚动"), "{prompt}");
    assert!(!prompt.contains("表演唇线收紧喉结滚动"), "{prompt}");
    assert!(!prompt.contains("唇线收紧"), "{prompt}");
}

#[test]
fn observation_note_conflict_filter_skips_style_conflicts() {
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid flat cold lighting",
        Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
        None,
    ));
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid oppressive or frantic mood",
        Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
        None,
    ));
}

#[test]
fn observation_note_conflict_filter_keeps_non_conflicting_warnings() {
    assert!(!video_prompt_observation_conflicts_with_style(
        "avoid face drift or costume inconsistency",
        Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
        None,
    ));
    assert!(!video_prompt_observation_conflicts_with_style(
        "avoid flat cold lighting",
        None,
        None,
    ));
}

#[test]
fn observation_note_conflict_filter_can_fall_back_to_next_candidate() {
    let note = [
        "avoid flat cold lighting".to_string(),
        "avoid shaky handheld motion".to_string(),
    ]
    .into_iter()
    .find(|note| {
        !video_prompt_observation_conflicts_with_style(
            note,
            Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
            None,
        )
    });

    assert_eq!(note, Some("avoid shaky handheld motion".to_string()));
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

#[test]
fn prune_low_signal_observation_candidates_drops_single_generic_mood_note() {
    assert!(prune_low_signal_observation_candidates(vec![
        "avoid overly cold emotional tone".to_string()
    ])
    .is_empty());
}

#[test]
fn prune_low_signal_observation_candidates_keeps_specific_note_while_dropping_generic_retry() {
    assert_eq!(
        prune_low_signal_observation_candidates(vec![
            "avoid repeating stable follow camera".to_string(),
            "avoid extreme camera angle".to_string(),
        ]),
        vec!["avoid extreme camera angle".to_string()]
    );
}

#[test]
fn prune_storyboard_observation_candidates_drops_mood_only_note_for_low_risk_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（男主坐在木桌前、室内书房、男主、4秒、中景、静止、低头翻开信纸、平静、室内暖光、无台词、纸张摩擦声、A03）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid overly cold emotional tone".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_keeps_lighting_note_for_reflective_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（女主站在落地窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃、隐忍、冷蓝窗光与路灯反射、无台词、雨声、A18）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        prune_storyboard_observation_candidates(
            vec!["avoid harsh backlight silhouette".into()],
            Some(&storyboard_row)
        ),
        vec!["avoid harsh backlight silhouette".to_string()]
    );
}

#[test]
fn prune_storyboard_observation_candidates_keeps_lip_sync_note_for_dialogue_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（女主逼近门厅、旧宅门厅、女主、5秒、近景、推进、停步回头、克制、冷调逆光、你别再骗我、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert_eq!(
        prune_storyboard_observation_candidates(
            vec!["avoid lip-sync mismatch".into()],
            Some(&storyboard_row)
        ),
        vec!["avoid lip-sync mismatch".to_string()]
    );
}

#[test]
fn prune_storyboard_observation_candidates_drops_lip_sync_note_for_brief_filler_utterance() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在门口低低应了一声".into()),
            video_desc: Some(
                "（主角停在门口、旧宅门口、主角、4秒、近景、静止、抿唇后轻轻应了一声、克制、冷调逆光、嗯、风声回响、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid lip-sync mismatch".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_drops_lip_sync_note_for_wide_moving_dialogue_storyboard()
{
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在街口边跑边喊别管我".into()),
            video_desc: Some(
                "（主角穿过雨夜街口、雨夜街口、主角、5秒、全景、手持跟拍、奔跑间回头喊出别管我、紧张、霓虹反光、别管我、雨声车流声、A14）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid lip-sync mismatch".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_drops_blocking_note_for_grounded_low_risk_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚坐在窗边、雨夜书房、林晚、4秒、中景、静止、低头捏紧信纸、克制、室内暖光、你终于来了、雨声压过呼吸声、A21）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(prune_storyboard_observation_candidates(
        vec!["avoid extra shot changes or wrong framing".into()],
        Some(&storyboard_row)
    )
    .is_empty());
}

#[test]
fn prune_storyboard_observation_candidates_keeps_blocking_note_for_multi_subject_blocking_storyboard(
) {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: None,
            video_desc: Some(
                "（林晚与顾承泽对峙、旧宅门厅、林晚/顾承泽、5秒、中景、稳定跟拍、林晚侧身让开后顾承泽逼近一步、压迫、冷调逆光、别过来、风声回响、A22）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert_eq!(
        prune_storyboard_observation_candidates(
            vec!["avoid extra shot changes or wrong framing".into()],
            Some(&storyboard_row)
        ),
        vec!["avoid extra shot changes or wrong framing".to_string()]
    );
}

#[test]
fn score_video_prompt_observation_specificity_penalizes_repeat_style_retry() {
    assert!(
        score_video_prompt_observation_specificity("avoid extreme camera angle")
            > score_video_prompt_observation_specificity("avoid repeating stable follow camera")
    );
}

#[test]
fn observation_note_conflict_filter_uses_storyboard_context_without_style_memory() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("门厅对峙".into()),
        video_desc: Some(
            "（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"
                .into(),
        ),
        duration: Some("5s".into()),
    };

    assert!(video_prompt_observation_conflicts_with_style(
        "avoid overly tight close-up framing",
        None,
        Some(&storyboard_row),
    ));
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid flat cold lighting",
        None,
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_conflict_filter_keeps_non_conflicting_half_of_combined_warning() {
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
fn observation_note_conflict_filter_understands_handheld_follow_and_neon_context() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角穿过霓虹雨巷".into()),
            video_desc: Some(
                "（主角穿过霓虹雨巷、雨夜巷口、主角、5秒、中景、手持跟拍、踩水快步穿行、悲怆、霓虹反光、无台词、雨声脚步声、A14）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

    assert!(video_prompt_observation_conflicts_with_style(
        "avoid shaky handheld motion",
        None,
        Some(&storyboard_row),
    ));
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid distracting neon reflections",
        None,
        Some(&storyboard_row),
    ));
    assert!(video_prompt_observation_conflicts_with_style(
        "avoid heavy tragic mood",
        None,
        Some(&storyboard_row),
    ));
    assert!(!video_prompt_observation_conflicts_with_style(
        "avoid lip-sync mismatch",
        None,
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_conflict_filter_drops_blank_expression_when_style_note_already_carries_specific_performance_direction(
) {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚抽气后哽咽开口".into()),
            video_desc: Some(
                "（林晚抽气后哽咽开口、病房门口、林晚、4秒、中景、缓推、抽气后哽咽开口、压抑、冷白侧光、我没事、空调低鸣、A18）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid blank expression or monotone delivery",
            Some("表演喉结滚动，语气哽咽克制"),
            Some(&storyboard_row),
        ),
        None
    );
}

#[test]
fn observation_note_conflict_filter_keeps_blank_expression_when_style_note_is_only_generic_mood() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚低声开口".into()),
            video_desc: Some(
                "（林晚低声开口、病房门口、林晚、4秒、中景、缓推、停顿后低声开口、压抑、冷白侧光、我没事、空调低鸣、A19）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert_eq!(
        compact_negative_constraint_against_storyboard_style(
            "avoid blank expression or monotone delivery",
            Some("情绪压抑克制"),
            Some(&storyboard_row),
        ),
        Some("avoid blank expression or monotone delivery".to_string())
    );
}

#[test]
fn observation_note_irrelevant_filter_skips_lip_sync_for_silent_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角贴墙前行".into()),
            video_desc: Some(
                "（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

    assert!(video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
    assert!(!video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid shaky handheld motion",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_keeps_lip_sync_for_dialogue_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角低声说你终于来了".into()),
            video_desc: Some(
                "（主角低声说你终于来了、旧宅门口、主角、5秒、近景、稳定跟拍、停步低声说出、压迫、冷调逆光、你终于来了、风声压过呼吸声、A13）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

    assert!(!video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_skips_lip_sync_for_brief_filler_utterance() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在门口低低应了一声".into()),
            video_desc: Some(
                "（主角停在门口、旧宅门口、主角、4秒、近景、静止、抿唇后轻轻应了一声、克制、冷调逆光、嗯、风声回响、A12）"
                    .into(),
            ),
            duration: Some("4s".into()),
        };

    assert!(video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_note_irrelevant_filter_skips_lip_sync_for_wide_moving_dialogue_storyboard() {
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在街口边跑边喊别管我".into()),
            video_desc: Some(
                "（主角穿过雨夜街口、雨夜街口、主角、5秒、全景、手持跟拍、奔跑间回头喊出别管我、紧张、霓虹反光、别管我、雨声车流声、A14）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

    assert!(video_prompt_observation_is_irrelevant_to_storyboard(
        "avoid lip-sync mismatch",
        Some(&storyboard_row),
    ));
}

#[test]
fn observation_filter_style_note_can_fall_back_to_contextual_summary() {
    let rows = vec![AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        resolve_observation_filter_style_note(&rows, 12, None, Some(&storyboard_row), &[], None,),
        Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string())
    );
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
fn observation_filter_style_note_skips_contextual_summary_when_storyboard_mismatches() {
    let rows = vec![AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("暖光会面".into()),
        video_desc: Some(
            "（主角寒暄、茶馆包间、主角、5秒、中景、轻推、坐下寒暄、温和克制、室内暖光、、、A12）"
                .into(),
        ),
        duration: Some("5s".into()),
    };

    assert!(resolve_observation_filter_style_note(
        &rows,
        12,
        None,
        Some(&storyboard_row),
        &[],
        None,
    )
    .is_none());
}

#[test]
fn observation_filter_style_note_prefers_shorter_contextual_summary_when_signal_is_equal() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍推进，情绪冷峻压迫克制，光影冷调逆光颗粒 | note=镜头稳定跟拍推进，情绪冷峻压迫克制，光影冷调逆光颗粒".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍推进，情绪冷峻压迫，光影冷调逆光颗粒 | note=镜头稳定跟拍推进，情绪冷峻压迫，光影冷调逆光颗粒".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        resolve_observation_filter_style_note(&rows, 12, None, Some(&storyboard_row), &[], None,),
        Some("镜头推进".to_string())
    );
}

#[test]
fn observation_style_note_context_evidence_counts_action_voice_and_sound_families() {
    let context = StructuredStoryboardDescription {
        subject: "林晚".into(),
        setting: "雨夜窗边".into(),
        subject_refs: "林晚".into(),
        duration_seconds: Some(5),
        shot: "近景".into(),
        camera_move: "静止".into(),
        action: "抿唇停顿后低声开口".into(),
        mood: "克制".into(),
        lighting: "室内暗光".into(),
        dialogue: "你终于来了".into(),
        sound: "雨声压过呼吸声".into(),
    };

    assert_eq!(
        observation_style_note_context_evidence(
            "表演抿唇喉结滚动，语气低声克制，声场雨声回响",
            &context,
        ),
        4
    );
}

#[test]
fn observation_filter_style_note_contextual_summary_keeps_matching_sound_family_note() {
    let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=表演抿唇喉结滚动，语气低声克制，声场雨声回响 | note=表演抿唇喉结滚动，语气低声克制，声场雨声回响".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚贴窗低声开口".into()),
            video_desc: Some("（林晚贴窗低声开口、雨夜窗边、林晚、5秒、近景、静止、抿唇停顿后低声开口、克制、室内暗光、你终于来了、雨声压过呼吸声、A12）".into()),
            duration: Some("5s".into()),
        };

    assert_eq!(
        select_contextual_observation_summary_style_note(&rows, Some(&storyboard_row), &[], None,),
        Some("声场雨声回响".to_string())
    );
}

#[test]
fn observation_filter_style_note_contextual_summary_prefers_primary_subject_role_summary_when_multiple_roles_exist(
) {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪压抑，光影冷调逆光 | note=镜头稳定跟拍，情绪压抑，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=5 | style=表演冷眼逼视，语气低声压迫 | note=表演冷眼逼视，语气低声压迫".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
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
        select_contextual_observation_summary_style_note(
            &rows,
            Some(&storyboard_row),
            &subject_candidates,
            None,
        ),
        Some("表演抬眼停顿".to_string())
    );
}

#[test]
fn observation_filter_style_note_contextual_summary_keeps_primary_role_high_signal_voice_note_even_when_global_summary_has_more_context_hits(
) {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪压抑，光影冷调逆光 | note=镜头稳定跟拍，情绪压抑，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=2 | style=语气低声尾音发颤 | note=语气低声尾音发颤".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚抿唇后低声说我没事".into()),
            video_desc: Some("（林晚抿唇后低声说我没事、雨夜门厅、林晚、5秒、近景、稳定跟拍、抿唇后低声说我没事、压抑、冷调逆光、我没事、雨声回响、A12）".into()),
            duration: Some("5s".into()),
        };
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();

    assert_eq!(
        select_contextual_observation_summary_style_note(
            &rows,
            Some(&storyboard_row),
            &subject_candidates,
            None,
        ),
        Some("语气低声尾音发颤".to_string())
    );
}

#[test]
fn observation_filter_style_note_contextual_summary_reorders_fragments_for_dialogue_risk() {
    let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=表演喉结滚动，语气轻声克制，光影冷调逆光 | note=表演喉结滚动，语气轻声克制，光影冷调逆光".into(),
        }];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚停顿后低声说你终于来了".into()),
            video_desc: Some("（林晚停顿后低声说你终于来了、雨夜窗边、林晚、5秒、近景、静止、抿唇停顿后低声开口、压抑、冷调逆光、你终于来了、雨声压过呼吸声、A12）".into()),
            duration: Some("5s".into()),
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        has_dialogue_guardrail: true,
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
        Some("表演喉结滚动，语气轻声".to_string())
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

#[test]
fn observation_filter_style_note_pressure_prefers_micro_performance_over_global_lighting_summary() {
    let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪压抑，光影冷调逆光 | note=镜头稳定跟拍，情绪压抑，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=表演喉结滚动，语气轻声克制，声场雨声回响 | note=表演喉结滚动，语气轻声克制，声场雨声回响".into(),
            },
        ];
    let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("林晚停顿后低声说你终于来了".into()),
            video_desc: Some("（林晚停顿后低声说你终于来了、雨夜窗边、林晚、5秒、近景、静止、抿唇停顿后低声开口、压抑、冷调逆光、你终于来了、雨声压过呼吸声、A12）".into()),
            duration: Some("5s".into()),
        };
    let pressure = Some(VideoPromptConstraintPressure {
        has_identity_guardrail: true,
        has_dialogue_guardrail: true,
        forces_compact_memory: true,
        ..VideoPromptConstraintPressure::default()
    });

    assert_eq!(
        resolve_observation_filter_style_note(
            &rows,
            12,
            None,
            Some(&storyboard_row),
            &[],
            pressure,
        ),
        Some("表演喉结滚动，语气轻声".to_string())
    );
}
