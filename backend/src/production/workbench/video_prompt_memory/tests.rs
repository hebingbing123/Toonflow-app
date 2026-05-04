use super::{
    build_project_role_video_style_memories, build_project_video_style_memory,
    build_project_video_style_memory_with_bias, build_rejected_video_negative_memory,
    build_script_role_video_style_memories, build_script_video_style_memory,
    build_script_video_style_memory_with_bias, build_selected_video_memory,
    clear_rejected_video_negative_memory, clear_selected_video_memory,
    compact_rejected_negative_avoid, compact_selected_memory_action,
    compact_selected_memory_setting, compact_selected_memory_subject,
    compact_selected_video_memory_for_focus, compact_video_continuity_note,
    compact_video_style_prompt_note, merge_rejected_negative_avoid_with_bias,
    merge_rejected_video_negative_memory, merge_selected_memory_subject_action,
    parse_structured_storyboard_description, plan_selected_video_memory_optimization,
    prepare_rejected_video_negative_memory_for_storage, prepare_selected_video_memory_for_storage,
    rejected_video_negative_rejection_count, select_neighbor_selected_video_memory_notes,
    select_pending_rejected_video_observation_candidates,
    select_pending_rejected_video_observation_candidates_for_subject,
    select_pending_rejected_video_observation_candidates_for_subject_with_bias,
    select_pending_rejected_video_observation_note, select_prioritized_video_style_note,
    select_project_video_style_memory_notes,
    select_project_video_style_memory_notes_for_storyboard,
    select_rejected_video_memory_notes_and_observation_candidates_for_subject,
    select_rejected_video_negative_memory_notes,
    select_rejected_video_negative_memory_notes_for_subject,
    select_script_video_style_memory_notes, select_script_video_style_memory_notes_for_storyboard,
    select_selected_video_memory_notes, select_selected_video_memory_notes_for_storyboard,
    select_subject_role_video_style_memory_notes,
    select_subject_role_video_style_memory_notes_for_storyboard, selected_memory_subject_aliases,
    selected_memory_subject_identity, selected_video_memory_is_low_signal,
    selected_video_memory_quality_score, selected_video_memory_scope,
    selected_video_memory_update_would_reduce_quality_with_bias, storyboard_prompt_seed,
    AgentMemoryRow, ScopedAgentMemoryRow, SelectedVideoMemoryOptimizationBias,
    SelectedVideoMemoryOptimizationCandidate, SelectedVideoMemoryScope, StoryboardPromptSeedRow,
    VideoPromptMemorySelectionBias,
};
use proptest::prelude::*;
use sqlx::PgPool;
use uuid::Uuid;

#[test]
fn parse_structured_storyboard_description_extracts_fields() {
    let fields = parse_structured_storyboard_description(
        "（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）",
    )
    .expect("fields");

    assert_eq!(fields.setting, "旧宅走廊");
    assert_eq!(fields.duration_seconds, Some(5));
    assert_eq!(fields.dialogue, "别回头");
    assert_eq!(fields.sound, "脚步声门响");
}

#[test]
fn build_selected_video_memory_prefers_compact_structured_note() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里冲出门外".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("storyboardIds=12"));
    assert!(content.contains("promptSeed="));
    assert!(content.contains("style=镜头稳定跟拍，情绪急迫，光影阴天冷光"));
    assert!(content.contains("note=主角推门冲出旧宅"));
    assert!(!content.contains("快步推门冲出"));
    assert!(!content.contains("note=主角冲出旧宅，推门冲出"));
    assert!(!content.contains("note=主角冲出旧宅，镜头中景稳定跟拍"));
    assert!(!content.contains("note=主角冲出旧宅，快步推门冲出，情绪急迫"));
    assert!(!content.contains("场景旧宅走廊"));
    assert!(!content.contains("duration="));
}

#[test]
fn build_selected_video_memory_drops_duplicate_subject_and_scene_fragments() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角在旧宅走廊尽头停步回头".into()),
            video_desc: Some("（主角在旧宅走廊尽头停步回头、旧宅走廊尽头、主角、5秒、中景、稳定跟拍、主角在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("停步回头"), "{content}");
    assert!(!content.contains("note=主角"), "{content}");
    assert!(!content.contains("note=主角在旧宅走廊尽头停步回头，镜头中景稳定跟拍"));
    assert!(!content.contains("note=主角在旧宅走廊尽头停步回头"));
    assert!(!content.contains("场景旧宅走廊尽头"));
    assert!(content.contains("情绪压抑"));
}

#[test]
fn build_selected_video_memory_trims_subject_and_pace_prefix_from_action_when_mood_exists() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("女主冲出旧宅".into()),
            video_desc: Some("（女主冲出旧宅、旧宅门厅、女主、5秒、中景、稳定跟拍、女主快步推门冲出、急迫、阴天冷光、无台词、门响脚步声、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("note=女主推门冲出旧宅"));
    assert!(!content.contains("女主快步推门冲出"), "{content}");
    assert!(
        !content.contains("note=女主冲出旧宅，快步推门冲出"),
        "{content}"
    );
}

#[test]
fn build_selected_video_memory_trims_subject_action_overlap_when_identity_remains() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅门厅、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、门响脚步声、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("note=主角，推门后回望"), "{content}");
    assert!(
        !content.contains("note=主角冲出旧宅，快步推门冲出旧宅后回望"),
        "{content}"
    );
}

#[test]
fn build_selected_video_memory_trims_object_prefix_from_action_when_subject_lists_prop() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角握紧匕首穿过走廊".into()),
            video_desc: Some("（主角穿过走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首转身格挡、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("note=主角穿过走廊"), "{content}");
    assert!(content.contains("转身格挡"), "{content}");
    assert!(!content.contains("握紧青铜匕首转身格挡"), "{content}");
}

#[test]
fn build_selected_video_memory_trims_subject_lead_in_from_setting_when_scene_suffix_remains() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角驻足".into()),
            video_desc: Some("（主角驻足、主角身后的门厅、主角、5秒、中景、稳定跟拍、抬眼观察、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(!content.contains("场景主角身后的门厅"), "{content}");
}

#[test]
fn build_selected_video_memory_trims_setting_lead_in_repeated_by_action_context() {
    let content = build_selected_video_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角在旧宅走廊尽头回头".into()),
            video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("停步回头"), "{content}");
    assert!(!content.contains("场景在旧宅走廊尽头的门厅"), "{content}");
    assert!(!content.contains("在旧宅走廊尽头停步回头"), "{content}");
}

#[test]
fn build_selected_video_memory_prefers_environment_fragment_over_raw_scene_suffix() {
    let content = build_selected_video_memory(
        18,
        &StoryboardPromptSeedRow {
            prompt: Some("女主站在窗边看着雨幕".into()),
            video_desc: Some("（女主站在窗边、城市夜景落地窗边、女主、4秒、中景、缓推、看着雨丝划过玻璃并轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A18）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("环境雨丝玻璃"), "{content}");
    assert!(!content.contains("场景城市夜景落地窗边"), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_motion_style_fragment() {
    let content = build_selected_video_memory(
        21,
        &StoryboardPromptSeedRow {
            prompt: Some("女主站在窗边压住情绪".into()),
            video_desc: Some("（女主站在窗边、城市夜景落地窗边、女主、4秒、中景、缓推、缓缓抬眼轻扶窗帘、隐忍 / 克制、冷蓝窗光与路灯反射、无台词、雨声、A21）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("style=动作从容克制"), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_voice_and_sound_style_fragments() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚看着窗外低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("语气低声克制"), "{content}");
    assert!(content.contains("声场雨声回响"), "{content}");
    assert!(!content.contains("迟迟没有开口"), "{content}");
    assert!(!content.contains("低声开口"), "{content}");
}

#[test]
fn build_selected_video_memory_persists_delivery_separately_when_visual_style_remains() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚看着窗外低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉结滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(
        content.contains("style=表演喉结滚动，语气低声克制，光影冷蓝窗光，声场雨声回响"),
        "{content}"
    );
    assert!(
        content.contains("delivery=表演喉结滚动低声克制"),
        "{content}"
    );
}

#[test]
fn build_selected_video_memory_compacts_visible_speech_delivery_into_single_fragment() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚喉头滚动后低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演喉结滚动低声克制"), "{content}");
    assert!(content.contains("声场雨声回响"), "{content}");
    assert!(!content.contains("语气低声克制"), "{content}");
    assert!(!content.contains("note="), "{content}");
}

#[test]
fn build_selected_video_memory_keeps_high_signal_tail_tremble_delivery() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚抿唇后压低气息开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后压低气息说你终于来了尾音发颤、隐忍 / 克制、冷蓝窗光、你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(
        content.contains("表演喉结滚动压低气息尾音发颤"),
        "{content}"
    );
    assert!(!content.contains("语气低声克制"), "{content}");
    assert!(!content.contains("语气低声尾音发颤"), "{content}");
}

#[test]
fn build_selected_video_memory_drops_low_gain_voice_mood_and_motion_when_performance_exists() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚抬眼后低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、缓缓抬眼后停顿片刻、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(
        content.contains("style=表演抬眼停顿，光影冷蓝窗光，声场雨声回响"),
        "{content}"
    );
    assert!(!content.contains("动作从容克制"), "{content}");
    assert!(!content.contains("情绪克制"), "{content}");
    assert!(!content.contains("语气低声克制"), "{content}");
}

#[test]
fn build_selected_video_memory_identity_silent_scene_prefers_micro_performance_only() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前停住".into()),
            video_desc: Some("（林晚在镜前停住、化妆镜前、林晚、4秒、近景、静止、抬眼看向镜中倒影后停顿、克制、暖金逆光、无台词、静场留白、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("style=表演抬眼停顿"), "{content}");
    assert!(!content.contains("镜头近景"), "{content}");
    assert!(!content.contains("光影暖金逆光"), "{content}");
    assert!(!content.contains("声场静场留白"), "{content}");
}

#[test]
fn build_selected_video_memory_identity_scene_keeps_visual_carryover_when_no_micro_performance_exists(
) {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚在镜前沉默".into()),
            video_desc: Some("（林晚在镜前沉默、化妆镜前、林晚、4秒、近景、静止、静静看向镜中倒影、克制、暖金逆光、无台词、静场留白、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("光影暖金逆光"), "{content}");
    assert!(content.contains("声场静场留白"), "{content}");
    assert!(
        content.contains("focusTags=identity_continuity/lighting_realism"),
        "{content}"
    );
    assert!(!content.contains("style=表演"), "{content}");
}

#[test]
fn build_selected_video_memory_persists_focus_tags_for_delivery_identity_and_lighting() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚抬眼后低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、缓缓抬眼后停顿片刻、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(
        content.contains(
            "focusTags=delivery_realism/emotion_arc/identity_continuity/lighting_realism"
        ),
        "{content}"
    );
}

#[test]
fn compact_selected_video_memory_for_focus_drops_generic_delivery_fillers() {
    let content = compact_selected_video_memory_for_focus(
        "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声克制，情绪克制，动作从容克制，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=强忍泪意",
        &["delivery_realism".into(), "emotion_arc".into()],
    );

    assert!(
        content.contains("style=表演喉结滚动，光影冷蓝窗光"),
        "{content}"
    );
    assert!(!content.contains("语气低声克制"), "{content}");
    assert!(!content.contains("情绪克制"), "{content}");
    assert!(!content.contains("动作从容克制"), "{content}");
}

#[test]
fn compact_selected_video_memory_for_focus_drops_local_framing_when_lighting_is_priority() {
    let content = compact_selected_video_memory_for_focus(
        "storyboardIds=12 | subject=林晚 | style=镜头近景，光影暖金逆光，声场静场留白 | note=保持角色光线一致",
        &["lighting_realism".into(), "identity_continuity".into()],
    );

    assert!(
        content.contains("style=光影暖金逆光，声场静场留白"),
        "{content}"
    );
    assert!(!content.contains("镜头近景"), "{content}");
}

#[test]
fn prepare_selected_video_memory_for_storage_rebuilds_focus_tags_after_compaction() {
    let content = prepare_selected_video_memory_for_storage(
        "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声克制，情绪克制，动作从容克制，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=强忍泪意",
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: true,
        }),
    )
    .expect("content");

    assert!(
        content.contains(
            "focusTags=delivery_realism/emotion_arc/identity_continuity/lighting_realism"
        ),
        "{content}"
    );
    assert!(!content.contains("语气低声克制"), "{content}");
    assert!(!content.contains("动作从容克制"), "{content}");
}

#[test]
fn selected_video_memory_is_low_signal_flags_generic_restrained_style() {
    assert!(selected_video_memory_is_low_signal(
        "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制 | note=保持克制"
    ));
    assert!(!selected_video_memory_is_low_signal(
        "storyboardIds=12 | style=表演喉结滚动，光影冷蓝窗光 | note=强忍泪意"
    ));
}

#[test]
fn prepare_selected_video_memory_for_storage_compacts_focus_fillers_before_persisting() {
    let prepared = prepare_selected_video_memory_for_storage(
        "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声克制，情绪克制，动作从容克制，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=强忍泪意",
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: false,
        }),
    )
    .expect("prepared");

    assert!(
        prepared.contains("style=表演喉结滚动，光影冷蓝窗光"),
        "{prepared}"
    );
    assert!(!prepared.contains("语气低声克制"), "{prepared}");
    assert!(!prepared.contains("情绪克制"), "{prepared}");
    assert!(!prepared.contains("动作从容克制"), "{prepared}");
}

#[test]
fn prepare_selected_video_memory_for_storage_drops_low_signal_after_focus_compaction() {
    let prepared = prepare_selected_video_memory_for_storage(
        "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制 | note=保持克制",
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: false,
        }),
    );

    assert!(prepared.is_none());
}

#[test]
fn build_selected_video_memory_skips_voice_memory_for_wide_moving_low_visibility_dialogue() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚穿过雨幕边跑边喊".into()),
            video_desc: Some("（林晚穿过雨幕、雨夜街头、林晚、4秒、远景、手持跟拍、穿过雨幕奔跑并喊别回头、紧张、霓虹反光、别回头、脚步声和雨声混在一起、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(!content.contains("语气"), "{content}");
    assert!(!content.contains("表演"), "{content}");
    assert!(content.contains("镜头远景手持跟拍"), "{content}");
}

#[test]
fn build_selected_video_memory_persists_subject_identity_for_role_memory() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚看着窗外低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("subject=林晚"), "{content}");
}

#[test]
fn build_selected_video_memory_persists_subject_aliases_for_role_memory() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("晚晚看着窗外低声开口".into()),
            video_desc: Some("（晚晚站在窗边、城市夜景落地窗边、林晚/晚晚、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("subjectAliases="), "{content}");
    assert!(content.contains("subject=林晚"), "{content}");
    assert!(content.contains("subjectAliases=晚晚"), "{content}");
    assert!(!content.contains("subjectAliases=林晚/"), "{content}");
}

#[test]
fn build_selected_video_memory_drops_descriptive_or_prop_subject_alias_noise() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边轻声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚站在窗边/晚晚/咖啡杯、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("subject=林晚"), "{content}");
    assert!(content.contains("subjectAliases=晚晚"), "{content}");
    assert!(!content.contains("林晚站在窗边"), "{content}");
    assert!(!content.contains("咖啡杯"), "{content}");
}

#[test]
fn build_selected_video_memory_drops_dialogue_shaped_subject_alias_noise() {
    let content = build_selected_video_memory(
        22,
        &StoryboardPromptSeedRow {
            prompt: Some("晚晚低声开口".into()),
            video_desc: Some("（晚晚低声开口、城市夜景落地窗边、林晚轻声说道/晚晚低声开口、4秒、中景、缓推、捧着咖啡迟迟没有开口、隐忍 / 克制、冷蓝窗光、低声说：你终于来了、雨声在玻璃边回响、A22）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("subject=林晚"), "{content}");
    assert!(content.contains("subjectAliases=晚晚"), "{content}");
    assert!(!content.contains("林晚轻声说道"), "{content}");
    assert!(!content.contains("晚晚低声开口"), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_performance_style_fragment() {
    let content = build_selected_video_memory(
        23,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚抬眼却没说出口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、抬眼后停顿片刻迟迟没有开口、隐忍 / 克制、冷蓝窗光、无台词、雨声、A23）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演抬眼停顿"), "{content}");
    assert!(!content.contains("抬眼后停顿片刻"), "{content}");
    assert!(!content.contains("note="), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_throat_motion_performance_fragment() {
    let content = build_selected_video_memory(
        23,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚喉头滚动后低声开口".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、喉头滚动后低声开口、隐忍 / 克制、冷蓝窗光、你终于来了、雨声、A23）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演喉结滚动"), "{content}");
    assert!(!content.contains("喉头滚动后低声开口"), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_stiff_smile_performance_fragment() {
    let content = build_selected_video_memory(
        23,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚嘴角僵住仍强撑微笑".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、嘴角僵住仍强撑微笑、压抑、冷蓝窗光、无台词、雨声、A23）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演嘴角发僵"), "{content}");
    assert!(!content.contains("嘴角僵住仍强撑微笑"), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_finger_tremble_performance_fragment() {
    let content = build_selected_video_memory(
        23,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚手指轻颤着攥紧衣角".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、手指轻颤着攥紧衣角、隐忍、冷蓝窗光、无台词、雨声、A23）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演指尖发颤"), "{content}");
    assert!(!content.contains("手指轻颤着攥紧衣角"), "{content}");
}

#[test]
fn build_selected_video_memory_extracts_tight_jaw_performance_fragment() {
    let content = build_selected_video_memory(
        23,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚下颌绷紧后才慢慢转身".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、下颌绷紧后才慢慢转身、压抑、冷蓝窗光、无台词、雨声、A23）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演下颌绷紧"), "{content}");
    assert!(!content.contains("下颌绷紧后才慢慢转身"), "{content}");
}

#[test]
fn build_selected_video_memory_keeps_action_note_not_covered_by_style() {
    let content = build_selected_video_memory(
        27,
        &StoryboardPromptSeedRow {
            prompt: Some("主角推门后回望".into()),
            video_desc: Some("（主角推门后回望、旧宅门厅、主角、4秒、中景、稳定跟拍、抬眼停顿后推门回望、克制、冷蓝窗光、无台词、雨声、A27）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("表演抬眼停顿"), "{content}");
    assert!(content.contains("note=主角，推门回望"), "{content}");
}

#[test]
fn build_selected_video_memory_drops_local_framing_when_other_style_signal_exists() {
    let content = build_selected_video_memory(
        24,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边压住情绪".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、近景、无、抬眼后停顿片刻、克制、冷蓝窗光、无台词、雨声回响、A24）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(
        content.contains("style=动作从容克制，表演抬眼停顿，光影冷蓝窗光，声场雨声回响"),
        "{content}"
    );
    assert!(!content.contains("镜头近景"), "{content}");
    assert!(!content.contains("情绪克制"), "{content}");
}

#[test]
fn build_selected_video_memory_keeps_generic_restrained_mood_without_character_signal() {
    let content = build_selected_video_memory(
        25,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边看着雨幕".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、近景、无、站定看向窗外、克制、无、无台词、无音效、A25）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("情绪克制"), "{content}");
    assert!(!content.contains("光影无"), "{content}");
}

#[test]
fn build_selected_video_memory_drops_subject_only_note_when_identity_is_stored() {
    let content = build_selected_video_memory(
        26,
        &StoryboardPromptSeedRow {
            prompt: Some("林晚站在窗边".into()),
            video_desc: Some("（林晚站在窗边、城市夜景落地窗边、林晚、4秒、中景、缓推、无、克制、冷蓝窗光、无台词、雨声、A26）".into()),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("subject=林晚"), "{content}");
    assert!(
        content.contains("style=情绪克制，光影冷蓝窗光"),
        "{content}"
    );
    assert!(!content.contains("note="), "{content}");
}

#[test]
fn compact_selected_memory_action_keeps_pace_prefix_when_mood_is_missing() {
    let action = compact_selected_memory_action(
        "女主缓步后退躲避",
        Some("女主后退躲避"),
        Some("女主后退躲避"),
        Some("女主"),
        None,
        "",
    )
    .expect("action");

    assert_eq!(action, "缓步后退躲避");
}

#[test]
fn compact_selected_memory_action_strips_setting_prefix_when_followup_motion_remains() {
    let action = compact_selected_memory_action(
        "在旧宅走廊尽头停步回头",
        Some("主角在旧宅走廊尽头回头"),
        Some("主角在旧宅走廊尽头回头"),
        Some("主角"),
        Some("在旧宅走廊尽头的门厅"),
        "压抑",
    )
    .expect("action");

    assert_eq!(action, "停步回头");
}

#[test]
fn compact_selected_memory_action_strips_subject_motion_overlap_before_followup_suffix() {
    let action = compact_selected_memory_action(
        "快步推门冲出旧宅后回望",
        Some("主角"),
        Some("主角冲出旧宅"),
        Some("主角"),
        None,
        "急迫",
    )
    .expect("action");

    assert_eq!(action, "推门后回望");
}

#[test]
fn merge_selected_memory_subject_action_merges_shared_motion_tail() {
    let merged = merge_selected_memory_subject_action(Some("主角冲出旧宅"), Some("推门冲出"))
        .expect("merged");

    assert_eq!(merged, "主角推门冲出旧宅");
}

#[test]
fn compact_selected_memory_subject_trims_shared_action_overlap() {
    let subject =
        compact_selected_memory_subject("主角冲出旧宅", "快步推门冲出旧宅后回望").expect("subject");

    assert_eq!(subject, "主角");
}

#[test]
fn merge_selected_memory_subject_action_skips_locative_subjects() {
    assert_eq!(
        merge_selected_memory_subject_action(Some("主角在旧宅走廊尽头回头"), Some("停步回头"),),
        None
    );
}

#[test]
fn compact_selected_memory_setting_strips_prop_or_subject_lead_in() {
    let setting =
        compact_selected_memory_setting("青铜匕首旁的供桌边", None, Some("主角/青铜匕首"), None)
            .expect("setting");

    assert_eq!(setting, "供桌边");
}

#[test]
fn compact_selected_memory_setting_strips_locative_lead_in_when_subject_or_action_covers_it() {
    let setting = compact_selected_memory_setting(
        "在旧宅走廊尽头的门厅",
        Some("主角在旧宅走廊尽头回头"),
        Some("主角"),
        Some("在旧宅走廊尽头停步回头"),
    )
    .expect("setting");

    assert_eq!(setting, "门厅");
}

#[test]
fn build_rejected_video_negative_memory_extracts_short_retry_constraints() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里冲出门外".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("storyboardIds=12"));
    assert!(content.contains("promptSeed="));
    assert!(content.contains("subject=主角"));
    assert!(content.contains("rejectionCount=1"));
    assert!(content.contains("avoid repeating stable follow camera"));
    assert!(content.contains("avoid flat cold lighting"));
    assert!(!content.contains("avoid oppressive or frantic mood"));
}

#[test]
fn build_rejected_video_negative_memory_compacts_same_family_fragments() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("门厅低机位逼视".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、近景、低机位逼近、盯住来人、克制、暖光、、、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("avoid=avoid extreme camera angle or overly tight close-up framing"));
    assert!(
        !content.contains("avoid=avoid overly tight close-up framing, avoid extreme camera angle")
    );
}

#[test]
fn build_rejected_video_negative_memory_prefers_handheld_warning_for_handheld_follow_camera() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("雨巷追随".into()),
            video_desc: Some("（主角穿过雨巷、霓虹雨巷、主角、5秒、中景、手持跟拍、踩水快步穿行、克制、霓虹反光、无台词、雨声脚步声、A12）".into()),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("avoid shaky handheld motion"));
    assert!(!content.contains("avoid repeating stable follow camera"));
}

#[test]
fn build_rejected_video_negative_memory_skips_low_signal_mood_only_memory() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角停在门口".into()),
            video_desc: Some(
                "（主角停在门口、旧宅门厅、主角、5秒、中景、固定、停步凝视、压迫、暖光、无台词、风声、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        },
    );

    assert!(content.is_none());
}

#[test]
fn build_rejected_video_negative_memory_skips_repeat_follow_camera_only_memory() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角穿过走廊".into()),
            video_desc: Some(
                "（主角穿过走廊、旧宅走廊、主角、5秒、中景、稳定跟拍、穿过走廊、平静、暖光、无台词、脚步声、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        },
    );

    assert!(content.is_none());
}

#[test]
fn build_rejected_video_negative_memory_drops_cold_mood_when_cold_lighting_already_exists() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角停在楼梯口".into()),
            video_desc: Some(
                "（主角停在楼梯口、旧宅楼梯、主角、5秒、中景、固定、停步回望、冷调、阴天冷光、无台词、风声、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("avoid=avoid flat cold lighting"));
    assert!(!content.contains("avoid overly cold emotional tone"));
}

#[test]
fn build_rejected_video_negative_memory_adds_performance_guard_for_restrained_dialogue_scene() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("晚晚欲言又止".into()),
            video_desc: Some(
                "（晚晚欲言又止、医院走廊、晚晚/林晚、5秒、中景、静止、停顿后低声开口、克制、夜间中性光、别再问了、空调低鸣、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(content.contains("avoid blank expression or monotone delivery"));
}

#[test]
fn build_rejected_video_negative_memory_adds_performance_guard_for_high_signal_silent_scene() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("她强忍泪意转身".into()),
            video_desc: Some(
                "（她强忍泪意转身、病房门口、她、4秒、中景、静止、喉结滚动后慢慢转身、隐忍、冷白侧光、无台词、空调低鸣、A12）"
                    .into(),
            ),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("avoid blank expression or monotone delivery"));
}

#[test]
fn build_rejected_video_negative_memory_skips_performance_guard_for_low_signal_silent_scene() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("主角站在门口".into()),
            video_desc: Some(
                "（主角站在门口、旧宅门厅、主角、4秒、中景、静止、站在门口、平静、室内暖光、无台词、风声、A12）"
                    .into(),
            ),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(!content.contains("avoid blank expression or monotone delivery"));
}

#[test]
fn build_rejected_video_negative_memory_persists_compact_risk_tags() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("晚晚抬眼后低声开口".into()),
            video_desc: Some(
                "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        },
    )
    .expect("content");

    assert!(
        content.contains("riskTags=lighting/emotion/performance/dialogue"),
        "{content}"
    );
}

#[test]
fn build_rejected_video_negative_memory_persists_identity_risk_tag_for_face_visible_shot() {
    let content = build_rejected_video_negative_memory(
        12,
        &StoryboardPromptSeedRow {
            prompt: Some("晚晚回头看向镜头".into()),
            video_desc: Some(
                "（晚晚回头看向镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                    .into(),
            ),
            duration: Some("4".into()),
        },
    )
    .expect("content");

    assert!(content.contains("riskTags=identity"), "{content}");
}

#[test]
fn prepare_rejected_video_negative_memory_for_storage_prefers_delivery_guards_when_bias_is_hot() {
    let prepared = prepare_rejected_video_negative_memory_for_storage(
        "storyboardIds=12 | rejectionCount=1 | riskTags=lighting/dialogue/performance | avoid=avoid flat cold lighting, avoid blank expression or monotone delivery, avoid lip-sync mismatch",
        Some(VideoPromptMemorySelectionBias {
            prefer_delivery: true,
            prefer_visual_continuity: false,
        }),
    )
    .expect("prepared");

    assert!(
        prepared
            .contains("avoid=avoid blank expression or monotone delivery, avoid lip-sync mismatch")
            || prepared.contains(
                "avoid=avoid lip-sync mismatch, avoid blank expression or monotone delivery"
            ),
        "{prepared}"
    );
    assert!(!prepared.contains("avoid flat cold lighting"), "{prepared}");
    assert!(
        prepared.contains("riskTags=dialogue/emotion/performance"),
        "{prepared}"
    );
    assert!(
        prepared.contains("focusTags=delivery_realism"),
        "{prepared}"
    );
}

#[test]
fn merge_rejected_negative_avoid_with_bias_prefers_visual_guards_when_visual_bias_is_hot() {
    let merged = merge_rejected_negative_avoid_with_bias(
        Some("avoid blank expression or monotone delivery, avoid flat cold lighting"),
        Some("avoid extreme camera angle"),
        Some(VideoPromptMemorySelectionBias {
            prefer_delivery: false,
            prefer_visual_continuity: true,
        }),
    );

    assert!(
        merged == "avoid extreme camera angle, avoid flat cold lighting"
            || merged == "avoid flat cold lighting, avoid extreme camera angle",
        "{merged}"
    );
    assert!(!merged.contains("avoid blank expression or monotone delivery"));
}

#[test]
fn select_selected_video_memory_notes_keeps_latest_matching_storyboard() {
    let notes = select_selected_video_memory_notes(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | note=别的镜头".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进"
                        .into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "storyboardIds=12 | note=不应读取".into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(notes, vec!["情绪压迫".to_string()]);
}

#[test]
fn select_selected_video_memory_notes_prefers_older_style_over_newer_confirmation_note() {
    let notes = select_selected_video_memory_notes(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | note=当前镜头已确认".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进"
                        .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(notes, vec!["情绪压迫".to_string()]);
}

#[test]
fn select_selected_video_memory_notes_prefers_richer_older_style_over_newer_single_axis_note() {
    let notes = select_selected_video_memory_notes(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪压迫 | note=当前镜头情绪压迫".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | style=情绪压迫，光影冷调逆光 | note=保持情绪压迫和冷调逆光"
                        .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(notes, vec!["情绪压迫，光影冷调逆光".to_string()]);
}

#[test]
fn select_selected_video_memory_notes_skips_confirmation_note_without_style() {
    let notes = select_selected_video_memory_notes(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | note=当前镜头已确认".into(),
        }],
        12,
        None,
    );

    assert!(notes.is_empty());
}

#[test]
fn selected_video_memory_update_would_reduce_quality_when_incoming_drops_style_signal() {
    assert!(selected_video_memory_update_would_reduce_quality_with_bias(
        "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=主角贴墙前行",
        "storyboardIds=12 | promptSeed=seed-12 | note=当前镜头已确认",
        None,
    ));
}

#[test]
fn selected_video_memory_update_would_reduce_quality_when_incoming_keeps_style_but_loses_useful_note(
) {
    assert!(selected_video_memory_update_would_reduce_quality_with_bias(
        "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=主角贴墙前行",
        "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=当前镜头已确认",
        None,
    ));
}

#[test]
fn selected_video_memory_quality_score_prefers_incoming_when_it_adds_style_signal() {
    assert!(
        selected_video_memory_quality_score(
            "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=主角贴墙前行"
        ) > selected_video_memory_quality_score(
            "storyboardIds=12 | promptSeed=seed-12 | note=主角贴墙前行"
        )
    );
    assert!(!selected_video_memory_update_would_reduce_quality_with_bias(
        "storyboardIds=12 | promptSeed=seed-12 | note=主角贴墙前行",
        "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫 | note=主角贴墙前行",
        None,
    ));
}

#[test]
fn selected_video_memory_quality_score_penalizes_low_gain_style_redundancy_when_performance_exists()
{
    assert!(
        selected_video_memory_quality_score(
            "storyboardIds=12 | promptSeed=seed-12 | style=动作从容克制，表演抬眼停顿，语气低声克制，情绪克制，光影冷蓝窗光，声场雨声回响"
        ) < selected_video_memory_quality_score(
            "storyboardIds=12 | promptSeed=seed-12 | style=表演抬眼停顿，光影冷蓝窗光，声场雨声回响"
        )
    );
    assert!(!selected_video_memory_update_would_reduce_quality_with_bias(
        "storyboardIds=12 | promptSeed=seed-12 | style=动作从容克制，表演抬眼停顿，语气低声克制，情绪克制，光影冷蓝窗光，声场雨声回响",
        "storyboardIds=12 | promptSeed=seed-12 | style=表演抬眼停顿，光影冷蓝窗光，声场雨声回响",
        None,
    ));
}

#[test]
fn selected_video_memory_quality_score_prefers_delivery_rich_style_over_visual_only_style() {
    let visual_only =
        "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光";
    let delivery_rich =
        "storyboardIds=12 | promptSeed=seed-12 | style=表演喉结滚动，语气低声尾音发颤，情绪强忍泪意";

    assert!(
        selected_video_memory_quality_score(delivery_rich)
            > selected_video_memory_quality_score(visual_only)
    );
    assert!(
        !selected_video_memory_update_would_reduce_quality_with_bias(
            visual_only,
            delivery_rich,
            None,
        )
    );
}

#[test]
fn selected_video_memory_update_with_bias_prefers_focus_aligned_delivery_anchor() {
    let visual_only = "storyboardIds=12 | promptSeed=seed-12 | style=镜头稳定跟拍，光影冷调逆光";
    let delivery_rich = "storyboardIds=12 | promptSeed=seed-12 | style=表演喉结滚动，语气低声尾音发颤，情绪强忍泪意";
    let bias = Some(SelectedVideoMemoryOptimizationBias {
        prefer_delivery: true,
        prefer_emotion: true,
        prefer_identity: false,
        prefer_lighting: false,
    });

    assert!(selected_video_memory_update_would_reduce_quality_with_bias(
        delivery_rich,
        visual_only,
        bias,
    ));
    assert!(
        !selected_video_memory_update_would_reduce_quality_with_bias(
            visual_only,
            delivery_rich,
            bias,
        )
    );
}

#[test]
fn selected_video_memory_scope_uses_storyboard_and_prompt_seed() {
    let scope = selected_video_memory_scope(
        "storyboardIds=12 | promptSeed=seed-12-current | style=镜头近景稳定跟拍，情绪压迫",
    )
    .expect("scope");

    assert_eq!(
        scope,
        SelectedVideoMemoryScope {
            storyboard_ids: "12".to_string(),
            prompt_seed: Some("seed-12-current".to_string()),
        }
    );
}

#[test]
fn selected_video_memory_scope_distinguishes_prompt_seed_variants() {
    let current =
        selected_video_memory_scope("storyboardIds=12 | promptSeed=seed-current | note=主角回头")
            .expect("current scope");
    let stale =
        selected_video_memory_scope("storyboardIds=12 | promptSeed=seed-stale | note=主角回头")
            .expect("stale scope");
    let unseeded =
        selected_video_memory_scope("storyboardIds=12 | note=主角回头").expect("unseeded");

    assert_ne!(current, stale);
    assert_ne!(current, unseeded);
    assert_ne!(stale, unseeded);
}

#[test]
fn select_neighbor_selected_video_memory_notes_prefers_nearest_storyboards() {
    let notes = select_neighbor_selected_video_memory_notes(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=5 | style=镜头中景慢推，情绪压迫，光影暖金逆光 | note=主角推门而入，镜头中景慢推，情绪压迫，光影暖金逆光".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=16 | style=镜头中景稳定跟拍，情绪冷峻，光影冷色夜景 | note=反派逼近，镜头中景稳定跟拍，情绪冷峻，光影冷色夜景".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头近景稳定跟拍，情绪压迫 | note=女主贴墙前行，镜头近景稳定跟拍，情绪压迫".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | note=当前镜头已确认".into(),
            },
        ],
        12,
        2,
    );

    assert_eq!(
        notes,
        vec![
            "镜头近景稳定跟拍，情绪压迫".to_string(),
            "镜头中景稳定跟拍，情绪冷峻，光影冷色夜景".to_string()
        ]
    );
}

#[test]
fn select_prioritized_video_style_note_keeps_neighbor_selected_style_when_current_seed_differs() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("女主转身回望".into()),
        video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、压迫、冷调逆光、无台词、脚步回响、A12）".into()),
        duration: Some("5s".into()),
    };
    let note = select_prioritized_video_style_note(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪压迫 | note=女主贴墙前行，镜头近景稳定跟拍，情绪压迫".into(),
        }],
        12,
        Some("current-seed-9999"),
        Some(&storyboard_row),
    );

    assert_eq!(note, Some("镜头稳定跟拍，情绪压迫".to_string()));
}

#[test]
fn select_prioritized_video_style_note_prefers_role_summary_when_neighbor_style_is_only_adjacent_carryover(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("女主含泪开口".into()),
        video_desc: Some("（女主含泪开口、旧宅走廊、女主、5秒、近景、稳定跟拍、呼吸发颤后哽咽开口、克制 / 哽咽、冷调逆光、你别走、雨声回响、A12）".into()),
        duration: Some("5s".into()),
    };
    let note = select_prioritized_video_style_note(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪克制，语气轻声克制 | note=女主贴墙前行，镜头近景稳定跟拍，情绪克制，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=女主 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制 | note=表演呼吸发颤，语气哽咽克制".into(),
            },
        ],
        12,
        Some("current-seed-9999"),
        Some(&storyboard_row),
    );

    assert_eq!(note, Some("表演呼吸发颤，语气哽咽克制".to_string()));
}

#[test]
fn select_prioritized_video_style_note_prefers_role_delivery_profile_for_dialogue_scene() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("女主低声开口".into()),
        video_desc: Some("（女主低声开口、旧宅走廊、女主、5秒、近景、稳定跟拍、喉结滚动后低声说你先走、克制、冷调逆光、你先走、雨声回响、A12）".into()),
        duration: Some("5s".into()),
    };
    let note = select_prioritized_video_style_note(
        &[AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=女主 | sampleCount=4 | style=表演喉结滚动，语气低声尾音发颤，声场雨声回响 | delivery=表演喉结滚动低声尾音发颤".into(),
        }],
        12,
        Some("current-seed-9999"),
        Some(&storyboard_row),
    );

    assert_eq!(note, Some("表演喉结滚动低声尾音发颤".to_string()));
}

#[test]
fn select_prioritized_video_style_note_prefers_neighbor_selected_delivery_for_dialogue_scene() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("女主低声开口".into()),
        video_desc: Some("（女主低声开口、旧宅走廊、女主、5秒、近景、稳定跟拍、喉结滚动后低声说你先走、克制、冷调逆光、你先走、雨声回响、A12）".into()),
        duration: Some("5s".into()),
    };
    let note = select_prioritized_video_style_note(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | promptSeed=neighbor-seed-0001 | style=表演喉结滚动，语气低声尾音发颤，光影冷调逆光 | delivery=表演喉结滚动低声尾音发颤 | note=...".into(),
        }],
        12,
        Some("current-seed-9999"),
        Some(&storyboard_row),
    );

    assert_eq!(note, Some("表演喉结滚动低声尾音发颤".to_string()));
}

#[test]
fn select_prioritized_video_style_note_prefers_fragile_role_summary_for_broken_breath_turn() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("女主抽气后失声开口".into()),
        video_desc: Some("（女主抽气后失声开口、旧宅走廊、女主、5秒、近景、稳定跟拍、抽气后失声开口、压抑、冷调逆光、我没事、雨声回响、A13）".into()),
        duration: Some("5s".into()),
    };
    let note = select_prioritized_video_style_note(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪克制，语气轻声克制 | note=女主贴墙前行，镜头近景稳定跟拍，情绪克制，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=女主 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制 | note=表演呼吸发颤，语气哽咽克制".into(),
            },
        ],
        13,
        Some("current-seed-0002"),
        Some(&storyboard_row),
    );

    assert_eq!(note, Some("表演呼吸发颤，语气哽咽克制".to_string()));
}

#[test]
fn select_prioritized_video_style_note_prefers_primary_subject_role_summary_when_multiple_roles_match(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚与顾承泽擦肩后强忍泪意".into()),
        video_desc: Some("（林晚与顾承泽擦肩后强忍泪意、雨夜门厅、林晚/顾承泽、5秒、近景、稳定跟拍、林晚抬眼停顿后侧身让开、克制、冷调逆光、无台词、雨声回响、A14）".into()),
        duration: Some("5s".into()),
    };
    let note = select_prioritized_video_style_note(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=13 | promptSeed=neighbor-seed-0001 | style=镜头近景稳定跟拍，情绪克制，光影冷调逆光 | note=顾承泽逼近后停步，镜头近景稳定跟拍，情绪克制，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制 | note=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=6 | style=表演冷眼逼视，语气低声压迫 | note=表演冷眼逼视，语气低声压迫".into(),
            },
        ],
        14,
        Some("current-seed-0003"),
        Some(&storyboard_row),
    );

    assert_eq!(note, Some("表演抬眼停顿，语气轻声克制".to_string()));
}

#[test]
fn select_rejected_video_negative_memory_notes_keeps_matching_storyboard_only() {
    let notes = select_rejected_video_negative_memory_notes(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=9 | rejectionCount=3 | avoid=avoid shaky handheld motion"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid flat cold lighting, avoid oppressive or frantic mood"]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_skips_single_rejection_noise() {
    let notes = select_rejected_video_negative_memory_notes(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                .into(),
        }],
        12,
        None,
    );

    assert!(notes.is_empty());
}

#[test]
fn select_rejected_video_negative_memory_notes_keeps_two_strongest_fragments() {
    let notes = select_rejected_video_negative_memory_notes(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting, avoid shaky handheld motion".into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_combines_multiple_rows_without_extra_budget() {
    let notes = select_rejected_video_negative_memory_notes(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                    .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=4 | avoid=avoid shaky handheld motion"
                    .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood"
                        .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_for_subject_prefers_matching_role() {
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | avoid=avoid identity drift".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | rejectionCount=3 | avoid=avoid lip-sync mismatch".into(),
            },
        ],
        12,
        None,
        &["晚晚".to_string()],
        None,
    );

    assert_eq!(notes, vec!["avoid identity drift".to_string()]);
}

#[test]
fn select_rejected_video_negative_memory_notes_for_subject_prefers_primary_subject_when_multiple_roles_match(
) {
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
        ],
        12,
        None,
        &[
            "林晚".to_string(),
            "晚晚".to_string(),
            "顾承泽".to_string(),
            "顾总".to_string(),
        ],
        None,
    );

    assert!(notes.iter().any(|note| note.contains("blank expression")));
    assert_eq!(
        notes
            .iter()
            .filter(|note| {
                note.contains("lip-sync mismatch")
                    || note.contains("face distortion or identity drift")
            })
            .count(),
        0
    );
}

#[test]
fn select_rejected_video_memory_notes_and_observation_candidates_for_subject_splits_confidence_paths(
) {
    let selection =
        select_rejected_video_memory_notes_and_observation_candidates_for_subject(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
                },
            ],
            12,
            None,
            &[
                "林晚".to_string(),
                "晚晚".to_string(),
                "顾承泽".to_string(),
                "顾总".to_string(),
            ],
            None,
        );

    assert_eq!(
        selection.negative_notes,
        vec!["avoid face distortion or identity drift".to_string()]
    );
    assert_eq!(
        selection.observation_notes,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_for_subject_can_fallback_to_same_role_matching_risk()
{
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚抬眼后低声开口".into()),
        video_desc: Some(
            "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=motion/framing | avoid=avoid shaky handheld motion".into(),
            },
        ],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_for_subject_keeps_risk_fallback_when_exact_row_is_only_pending(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚抬眼后低声开口".into()),
        video_desc: Some(
            "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
        ],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_for_subject_prioritizes_matching_fragment_for_scene_risk(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头盯住来人".into()),
        video_desc: Some(
            "（晚晚回头盯住来人、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=15 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/lighting | avoid=avoid flat cold lighting, avoid face distortion or identity drift".into(),
        }],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid face distortion or identity drift, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_for_subject_can_fallback_to_same_role_identity_risk()
{
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头看向镜头".into()),
        video_desc: Some(
            "（晚晚回头看向镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/lighting | avoid=avoid face distortion or identity drift".into(),
        }],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid face distortion or identity drift".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_deduplicates_weaker_family_across_rows() {
    let notes = select_rejected_video_negative_memory_notes(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flicker".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker or motion jitter"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                    .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid flicker or motion jitter, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_drops_repeat_follow_when_handheld_warning_exists() {
    let notes = select_rejected_video_negative_memory_notes(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid repeating stable follow camera"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=3 | avoid=avoid shaky handheld motion"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                    .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_drops_generic_style_fillers_for_high_signal_visual_guard(
) {
    let notes = select_rejected_video_negative_memory_notes(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid face distortion, identity drift, costume drift, avoid extreme camera angle, avoid flat cold lighting".into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid face distortion, identity drift, costume drift".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_parses_ascii_and_cjk_delimiters() {
    let notes = select_rejected_video_negative_memory_notes(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker；avoid flat cold lighting, avoid harsh backlight silhouette".into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid flicker or motion jitter, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_pending_rejected_video_observation_note_reads_single_rejection_noise() {
    let note = select_pending_rejected_video_observation_note(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion, avoid flat cold lighting".into(),
        }],
        12,
        None,
    );

    assert_eq!(note, Some("avoid shaky handheld motion".into()));
}

#[test]
fn select_pending_rejected_video_observation_note_skips_promoted_noise() {
    let note = select_pending_rejected_video_observation_note(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid shaky handheld motion"
                .into(),
        }],
        12,
        None,
    );

    assert_eq!(note, None);
}

#[test]
fn select_pending_rejected_video_observation_candidates_for_subject_prefers_matching_role() {
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | avoid=avoid identity drift".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | rejectionCount=1 | avoid=avoid lip-sync mismatch".into(),
            },
        ],
        12,
        None,
        &["晚晚".to_string()],
        None,
    );

    assert_eq!(notes, vec!["avoid identity drift".to_string()]);
}

#[test]
fn select_pending_rejected_video_observation_candidates_prefers_primary_subject_when_multiple_roles_match(
) {
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=identity/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
        ],
        12,
        None,
        &[
            "林晚".to_string(),
            "晚晚".to_string(),
            "顾承泽".to_string(),
            "顾总".to_string(),
        ],
        None,
    );

    assert_eq!(
        notes.first().map(String::as_str),
        Some("avoid blank expression or monotone delivery")
    );
    assert_eq!(
        notes
            .iter()
            .filter(|note| {
                note.contains("lip-sync mismatch")
                    || note.contains("face distortion or identity drift")
            })
            .count(),
        0
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_can_fallback_to_same_role_matching_risk() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚抬眼后低声开口".into()),
        video_desc: Some(
            "（晚晚看向门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=motion/framing | avoid=avoid shaky handheld motion".into(),
            },
        ],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_prioritizes_matching_fragment_for_scene_risk(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚压住情绪低声开口".into()),
        video_desc: Some(
            "（晚晚盯着门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid flat cold lighting, avoid blank expression or monotone delivery".into(),
        }],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec![
            "avoid blank expression or monotone delivery".to_string(),
            "avoid flat cold lighting".to_string()
        ]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_bias_prefers_delivery_fragments() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头低声开口".into()),
        video_desc: Some(
            "（晚晚站在门厅、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、回头停顿后低声开口、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject_with_bias(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid flat cold lighting, avoid blank expression or monotone delivery".into(),
        }],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptMemorySelectionBias {
            prefer_delivery: true,
            prefer_visual_continuity: false,
        }),
    );

    assert_eq!(
        notes.first().map(String::as_str),
        Some("avoid blank expression or monotone delivery")
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_bias_prefers_visual_continuity_fragments() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头低声开口".into()),
        video_desc: Some(
            "（晚晚站在门厅、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、回头停顿后低声开口、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject_with_bias(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/performance/dialogue | avoid=avoid flat cold lighting, avoid blank expression or monotone delivery".into(),
        }],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
        Some(VideoPromptMemorySelectionBias {
            prefer_delivery: false,
            prefer_visual_continuity: true,
        }),
    );

    assert_eq!(
        notes.first().map(String::as_str),
        Some("avoid flat cold lighting")
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_can_fallback_to_same_role_identity_risk() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头看向镜头".into()),
        video_desc: Some(
            "（晚晚回头看向镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=8 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=identity/lighting | avoid=avoid face distortion or identity drift".into(),
        }],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid face distortion or identity drift".to_string()]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_summary_prefers_performance_guard_over_higher_sample_lighting(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚压住情绪低声开口".into()),
        video_desc: Some(
            "（晚晚盯着门外、雨夜门厅、林晚/晚晚、5秒、近景、稳定跟拍、抬眼停顿后低声吸气、隐忍 / 克制、冷调逆光、你别走、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[
            AgentMemoryRow {
                name: "script_video_observation_memory".into(),
                content: "sampleCount=9 | riskTags=lighting | avoid=avoid flat cold lighting"
                    .into(),
            },
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=2 | riskTags=performance/dialogue | avoid=avoid blank expression or monotone delivery".into(),
            },
        ],
        12,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_summary_prefers_role_summary_over_project_generic_fill(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头低声开口".into()),
        video_desc: Some(
            "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[
            AgentMemoryRow {
                name: "project_video_observation_memory".into(),
                content: "sampleCount=8 | riskTags=identity/lighting | avoid=avoid flat cold lighting, avoid face distortion or identity drift".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=3 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery".into(),
            },
        ],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec![
            "avoid blank expression or monotone delivery".to_string(),
            "avoid face distortion or identity drift".to_string()
        ]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_summary_prefers_primary_subject_role_summary_when_multiple_roles_match(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头低声开口".into()),
        video_desc: Some(
            "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_pending_rejected_video_observation_candidates_for_subject(
        &[
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=6 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch, avoid face distortion or identity drift".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | riskTags=identity/dialogue/performance | avoid=avoid blank expression or monotone delivery".into(),
            },
        ],
        15,
        None,
        &[
            "林晚".to_string(),
            "晚晚".to_string(),
            "顾承泽".to_string(),
            "顾总".to_string(),
        ],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes.first().map(String::as_str),
        Some(
            "avoid blank expression or monotone delivery, avoid face distortion or identity drift"
        )
    );
    assert_eq!(notes.get(1).map(String::as_str), None);
}

#[test]
fn merge_rejected_video_negative_memory_accumulates_rejection_count_and_deduplicates() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=motion/lighting | avoid=avoid shaky handheld motion, avoid flat cold lighting",
        "storyboardIds=12 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/emotion | avoid=avoid flat cold lighting, avoid oppressive or frantic mood",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("storyboardIds=12"));
    assert!(merged.contains("subject=晚晚"));
    assert!(merged.contains("subjectAliases=林晚"));
    assert!(merged.contains("riskTags=emotion/lighting/motion"));
    assert!(merged.contains("focusTags=delivery_realism/identity_continuity/lighting_realism"));
    assert!(merged.contains("avoid=avoid shaky handheld motion, avoid flat cold lighting"));
    assert!(!merged.contains("avoid oppressive or frantic mood"));
}

#[test]
fn select_rejected_video_negative_memory_notes_prefers_focus_tag_aligned_row_when_bias_is_hot() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚忍着眼泪低声开口".into()),
        video_desc: Some(
            "（林晚忍着眼泪低声开口、雨夜走廊、林晚/晚晚、5秒、近景、静止、抬眼停顿后低声开口、隐忍、冷蓝窗光、你先别说、雨声回响、A12）"
                .into(),
        ),
        duration: Some("5".into()),
    };
    let rows = vec![
        AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue/performance | focusTags=identity_continuity | avoid=avoid face distortion or identity drift".into(),
        },
        AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=7 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue/performance | focusTags=delivery_realism | avoid=avoid blank expression or monotone delivery".into(),
        },
    ];

    let notes =
        crate::production::workbench::video_prompt_memory::select_rejected_video_negative_memory_notes_for_subject_with_bias(
        &rows,
        12,
        None,
        &["林晚".into(), "晚晚".into()],
        Some(&storyboard_row),
        Some(VideoPromptMemorySelectionBias {
            prefer_delivery: true,
            prefer_visual_continuity: false,
        }),
    );

    assert_eq!(
        notes,
        vec!["avoid blank expression or monotone delivery".to_string()]
    );
}

#[test]
fn merge_rejected_video_negative_memory_resets_when_prompt_seed_changes() {
    let incoming =
        "storyboardIds=12 | promptSeed=newseed000002 | rejectionCount=1 | avoid=avoid flat cold lighting";
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=3 | avoid=avoid shaky handheld motion, avoid oppressive or frantic mood",
        incoming,
    );

    assert_eq!(merged, incoming);
    assert_eq!(rejected_video_negative_rejection_count(&merged), 1);
    assert!(merged.contains("promptSeed=newseed000002"));
    assert!(!merged.contains("avoid shaky handheld motion"));
}

#[test]
fn storyboard_prompt_seed_changes_with_storyboard_version() {
    let first = storyboard_prompt_seed(&StoryboardPromptSeedRow {
        prompt: Some("主角在走廊里冲出门外".into()),
        video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
        duration: Some("5".into()),
    })
    .expect("first seed");
    let second = storyboard_prompt_seed(&StoryboardPromptSeedRow {
        prompt: Some("主角在楼梯口停步回望".into()),
        video_desc: Some("（主角停在楼梯口、旧宅楼梯、主角、5秒、近景、缓慢推进、停步回望、压迫、冷调逆光、无台词、风声、A12）".into()),
        duration: Some("5".into()),
    })
    .expect("second seed");

    assert_ne!(first, second);
}

#[test]
fn select_selected_video_memory_notes_skips_stale_prompt_seed() {
    let notes = select_selected_video_memory_notes(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | promptSeed=oldseed000001 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进".into(),
        }],
        12,
        Some("newseed000002"),
    );

    assert!(notes.is_empty());
}

#[test]
fn select_selected_video_memory_notes_falls_back_to_unseeded_when_current_seed_has_no_match() {
    let notes = select_selected_video_memory_notes(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | promptSeed=oldseed000001 | style=镜头冷调近景，情绪压迫"
                        .into(),
            },
        ],
        12,
        Some("newseed000002"),
    );

    assert_eq!(
        notes,
        vec!["镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
    );
}

#[test]
fn select_pending_rejected_video_observation_note_skips_stale_prompt_seed() {
    let note = select_pending_rejected_video_observation_note(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
        }],
        12,
        Some("newseed000002"),
    );

    assert_eq!(note, None);
}

#[test]
fn select_pending_rejected_video_observation_note_falls_back_to_unseeded_when_current_seed_has_no_match(
) {
    let note = select_pending_rejected_video_observation_note(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=1 | avoid=avoid flat cold lighting"
                    .into(),
            },
        ],
        12,
        Some("newseed000002"),
    );

    assert_eq!(note, Some("avoid flicker or motion jitter".into()));
}

#[test]
fn select_rejected_video_negative_memory_notes_falls_back_to_unseeded_when_current_seed_has_no_match(
) {
    let notes = select_rejected_video_negative_memory_notes(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flicker or motion jitter"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=2 | avoid=avoid flat cold lighting"
                    .into(),
            },
        ],
        12,
        Some("newseed000002"),
    );

    assert_eq!(notes, vec!["avoid flicker or motion jitter".to_string()]);
}

#[test]
fn select_pending_rejected_video_observation_note_prefers_stronger_camera_warning() {
    let note = select_pending_rejected_video_observation_note(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                    .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                    .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(note, Some("avoid shaky handheld motion".into()));
}

#[test]
fn select_pending_rejected_video_observation_note_skips_single_low_signal_mood_retry() {
    let note = select_pending_rejected_video_observation_note(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid overly cold emotional tone"
                .into(),
        }],
        12,
        None,
    );

    assert_eq!(note, None);
}

#[test]
fn select_pending_rejected_video_observation_candidates_orders_by_strength() {
    let notes = select_pending_rejected_video_observation_candidates(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                    .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                    .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                    .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec![
            "avoid shaky handheld motion".to_string(),
            "avoid flat cold lighting".to_string(),
        ]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_keeps_secondary_fragment_from_same_row() {
    let notes = select_pending_rejected_video_observation_candidates(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content:
                "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting, avoid shaky handheld motion"
                    .into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec![
            "avoid shaky handheld motion".to_string(),
            "avoid flat cold lighting".to_string(),
        ]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_deduplicates_weaker_family_member() {
    let notes = select_pending_rejected_video_observation_candidates(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                    .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec![
            "avoid flat cold lighting".to_string(),
            "avoid flicker or motion jitter".to_string(),
        ]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_drops_repeat_follow_when_handheld_warning_exists(
) {
    let notes = select_pending_rejected_video_observation_candidates(
        &[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid repeating stable follow camera"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                        .into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                    .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec![
            "avoid shaky handheld motion".to_string(),
            "avoid flat cold lighting".to_string(),
        ]
    );
}

#[test]
fn compact_rejected_negative_avoid_preserves_original_order_for_same_priority() {
    let compacted = compact_rejected_negative_avoid(
        "avoid flat cold lighting, avoid harsh backlight silhouette, avoid oppressive or frantic mood",
    );

    assert_eq!(
        compacted,
        "avoid flat cold lighting or harsh backlight silhouette, avoid oppressive or frantic mood"
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_compacts_visual_style_family() {
    let notes = select_pending_rejected_video_observation_candidates(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content:
                "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting, avoid harsh backlight silhouette"
                    .into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid flat cold lighting or harsh backlight silhouette".to_string(),]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_compacts_visual_error_family() {
    let notes = select_pending_rejected_video_observation_candidates(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content:
                "storyboardIds=12 | rejectionCount=1 | avoid=avoid warped anatomy, avoid blur, avoid flicker"
                    .into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["avoid warped anatomy, blur, flicker".to_string(),]
    );
}

#[test]
fn select_pending_rejected_video_observation_candidates_parse_mixed_delimiters() {
    let notes = select_pending_rejected_video_observation_candidates(
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting；avoid harsh backlight silhouette, avoid shaky handheld motion".into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec![
            "avoid shaky handheld motion".to_string(),
            "avoid flat cold lighting or harsh backlight silhouette".to_string(),
        ]
    );
}

#[test]
fn merge_rejected_video_negative_memory_compacts_family_fragments() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid harsh backlight silhouette",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid=avoid flat cold lighting or harsh backlight silhouette"));
}

#[test]
fn merge_rejected_video_negative_memory_compacts_visual_error_family_fragments() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid warped anatomy, avoid blur",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid=avoid warped anatomy, blur, flicker"));
}

#[test]
fn merge_rejected_video_negative_memory_keeps_only_top_storage_fragments() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid shaky handheld motion, avoid flat cold lighting",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid oppressive or frantic mood",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid=avoid shaky handheld motion, avoid flat cold lighting"));
    assert!(!merged.contains("avoid oppressive or frantic mood"));
}

#[test]
fn merge_rejected_video_negative_memory_prioritizes_character_consistency_over_mood() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid face distortion or identity drift, avoid flat cold lighting",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid oppressive or frantic mood",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid face distortion or identity drift"));
    assert!(!merged.contains("avoid flat cold lighting"));
    assert!(!merged.contains("avoid oppressive or frantic mood"));
}

#[test]
fn merge_rejected_video_negative_memory_drops_generic_style_budget_fillers_when_high_signal_visual_guard_exists(
) {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid face distortion, identity drift, costume drift, avoid extreme camera angle",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid face distortion, identity drift, costume drift"));
    assert!(!merged.contains("avoid extreme camera angle"));
    assert!(!merged.contains("avoid flat cold lighting"));
}

#[test]
fn merge_rejected_video_negative_memory_keeps_performance_guard_when_high_signal_visual_guard_exists(
) {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid face distortion, identity drift, costume drift",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid blank expression or monotone delivery, avoid flat cold lighting",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid face distortion, identity drift, costume drift"));
    assert!(merged.contains("avoid blank expression or monotone delivery"));
    assert!(!merged.contains("avoid flat cold lighting"));
}

#[test]
fn merge_rejected_video_negative_memory_prefers_performance_guard_over_generic_mood_tone() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid blank expression or monotone delivery",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid oppressive or frantic mood",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid blank expression or monotone delivery"));
    assert!(!merged.contains("avoid oppressive or frantic mood"));
}

#[test]
fn merge_rejected_video_negative_memory_parses_ascii_and_cjk_delimiters() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting；avoid harsh backlight silhouette",
        "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("avoid flicker or motion jitter"));
    assert!(merged.contains("avoid flat cold lighting or harsh backlight silhouette"));
}

#[test]
fn select_rejected_video_negative_memory_notes_can_fallback_to_role_observation_summary() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚低声回头".into()),
        video_desc: Some(
            "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[AgentMemoryRow {
            name: "script_role_video_observation_memory".into(),
            content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=2 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
        }],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec![
            "avoid face distortion or identity drift, avoid blank expression or monotone delivery"
                .to_string()
        ]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_role_observation_summary_prioritizes_dialogue_guard_fragment_for_dialogue_scene(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头低声开口".into()),
        video_desc: Some(
            "（晚晚站在落地窗边、雨夜办公室、林晚/晚晚、4秒、近景、慢推、回头低声开口喉结滚动、压抑、霓虹反光、你别看我、雨声回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[AgentMemoryRow {
            name: "script_role_video_observation_memory".into(),
            content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid face distortion or identity drift, avoid flat cold lighting, avoid blank expression or monotone delivery".into(),
        }],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec![
            "avoid blank expression or monotone delivery, avoid face distortion or identity drift"
                .to_string()
        ]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_role_observation_summary_prioritizes_identity_guard_fragment_for_identity_scene(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚回头盯住镜头".into()),
        video_desc: Some(
            "（晚晚回头盯住镜头、旧宅走廊、林晚/晚晚、4秒、近景、慢推、回头抬眼停顿、压抑、冷调逆光、无台词、脚步回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[AgentMemoryRow {
            name: "script_role_video_observation_memory".into(),
            content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=5 | riskTags=identity/dialogue/lighting | avoid=avoid blank expression or monotone delivery, avoid face distortion or identity drift, avoid flat cold lighting".into(),
        }],
        15,
        None,
        &["晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec!["avoid face distortion or identity drift, avoid flat cold lighting".to_string()]
    );
}

#[test]
fn select_rejected_video_negative_memory_notes_role_observation_summary_prefers_primary_subject_when_multiple_roles_match(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("晚晚停住呼吸看向顾承泽".into()),
        video_desc: Some(
            "（晚晚停在落地窗边、雨夜办公室、林晚/晚晚/顾承泽、4秒、近景、慢推、抬眼停顿后低声开口、压抑、霓虹反光、你别看我、雨声回响、A15）"
                .into(),
        ),
        duration: Some("4".into()),
    };
    let notes = select_rejected_video_negative_memory_notes_for_subject(
        &[
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾承泽/顾总 | sampleCount=6 | riskTags=identity/dialogue | avoid=avoid lip-sync mismatch, avoid face distortion or identity drift".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_observation_memory".into(),
                content: "subject=林晚 | subjectAliases=林晚/晚晚 | sampleCount=4 | riskTags=identity/dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid face distortion or identity drift".into(),
            },
        ],
        15,
        None,
        &[
            "林晚".to_string(),
            "晚晚".to_string(),
            "顾承泽".to_string(),
            "顾总".to_string(),
        ],
        Some(&storyboard_row),
    );

    assert_eq!(
        notes,
        vec![
            "avoid blank expression or monotone delivery, avoid face distortion or identity drift"
                .to_string()
        ]
    );
}

#[test]
fn build_script_video_style_memory_extracts_recurring_style_fragments() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅楼梯 | note=女主贴墙前行，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅楼梯".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | style=镜头近景手持跟拍，情绪紧张压迫，光影冷调逆光，场景旧宅走廊 | note=反派逼近，镜头近景手持跟拍，情绪紧张压迫，光影冷调逆光，场景旧宅走廊".into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=3"));
    assert!(summary.contains("镜头稳定跟拍"));
    assert!(!summary.contains("中景"));
    assert!(summary.contains("情绪冷峻压迫"));
    assert!(summary.contains("光影冷调逆光"));
    assert!(!summary.contains("场景旧宅走廊"));
    assert!(!summary.contains("女主"));
}

#[test]
fn build_script_video_style_memory_drops_fragments_that_recent_rejections_keep_hitting() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=表演抬眼停顿，语气低声克制，情绪克制，光影冷蓝窗光，环境雨丝玻璃 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=表演抬眼停顿，语气低声克制，情绪克制，光影冷蓝窗光，环境雨丝玻璃 | note=...".into(),
            },
        ],
        &[AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=9 | rejectionCount=2 | avoid=avoid blank expression or monotone delivery, avoid flat cold lighting".into(),
        }],
    )
    .expect("summary");

    assert!(summary.contains("环境雨丝玻璃"), "{summary}");
    assert!(summary.contains("delivery=表演抬眼停顿"), "{summary}");
    assert!(!summary.contains("语气低声克制"), "{summary}");
    assert!(!summary.contains("情绪克制"), "{summary}");
    assert!(!summary.contains("光影冷蓝窗光"), "{summary}");
}

#[test]
fn build_script_video_style_memory_extracts_recurring_style_fragments_from_ascii_delimiters() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头中景稳定跟拍, 情绪冷峻压迫; 光影冷调逆光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | style=镜头近景稳定跟拍, 情绪冷峻压迫; 光影冷调逆光 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=2"));
    assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"));
}

#[test]
fn build_script_video_style_memory_keeps_recurring_environment_fragment() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，情绪克制，环境雨丝玻璃 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=10 | style=镜头近景稳定跟拍，情绪克制，环境雨丝玻璃 | note=..."
                        .into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("环境雨丝玻璃"), "{summary}");
}

#[test]
fn build_script_video_style_memory_keeps_recurring_motion_fragment() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，动作从容克制，情绪克制 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=10 | style=镜头近景稳定跟拍，动作从容克制，情绪隐忍 | note=..."
                        .into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("动作从容克制"), "{summary}");
}

#[test]
fn build_script_video_style_memory_keeps_recurring_voice_and_sound_fragments() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头稳定跟拍，语气轻声克制，声场雨声回响 | note=..."
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | style=镜头近景稳定跟拍，语气轻声克制，声场雨声回响 | note=..."
                .into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("语气轻声克制"), "{summary}");
    assert!(summary.contains("声场雨声回响"), "{summary}");
}

#[test]
fn build_script_video_style_memory_keeps_recurring_performance_fragment() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头稳定跟拍，表演抬眼停顿，情绪克制 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=10 | style=镜头近景稳定跟拍，表演抬眼停顿，情绪隐忍 | note=..."
                        .into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("表演抬眼停顿"), "{summary}");
}

#[test]
fn build_script_video_style_memory_drops_low_gain_voice_mood_and_motion_when_performance_exists() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头稳定跟拍，表演呼吸发颤，语气轻声克制，情绪克制，动作从容克制，声场静场留白 | note=..."
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | style=镜头近景稳定跟拍，表演呼吸发颤，语气轻声克制，情绪隐忍，动作从容克制，声场静场留白 | note=..."
                .into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("表演呼吸发颤"), "{summary}");
    assert!(summary.contains("声场静场留白"), "{summary}");
    assert!(!summary.contains("语气轻声克制"), "{summary}");
    assert!(!summary.contains("情绪克制"), "{summary}");
    assert!(!summary.contains("情绪隐忍"), "{summary}");
    assert!(!summary.contains("动作从容克制"), "{summary}");
}

#[test]
fn build_script_video_style_memory_drops_ambient_sound_when_visual_and_performance_fragments_exist()
{
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头稳定跟拍，表演喉结滚动，光影冷蓝窗光，环境雨丝玻璃，声场雨声回响 | note=..."
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | style=镜头近景稳定跟拍，表演喉结滚动，光影冷蓝窗光，环境雨丝玻璃，声场雨声回响 | note=..."
                .into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("表演喉结滚动"), "{summary}");
    assert!(summary.contains("光影冷蓝窗光"), "{summary}");
    assert!(summary.contains("环境雨丝玻璃"), "{summary}");
    assert!(!summary.contains("声场雨声回响"), "{summary}");
}

#[test]
fn build_script_video_style_memory_drops_character_signature_fragments_when_subjects_mix() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，光影冷调逆光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景稳定跟拍，表演抬眼停顿，语气轻声克制，光影冷调逆光 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("镜头稳定跟拍"), "{summary}");
    assert!(summary.contains("光影冷调逆光"), "{summary}");
    assert!(!summary.contains("表演抬眼停顿"), "{summary}");
    assert!(!summary.contains("语气轻声克制"), "{summary}");
}

#[test]
fn build_script_role_video_style_memories_groups_persona_by_subject() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制"
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=晚晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气低声克制"
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=24 | subject=顾承泽 | style=动作从容克制".into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | subjectAliases=晚晚 | style=表演抬眼停顿".to_string()]
    );
}

#[test]
fn build_project_role_video_style_memories_keep_subjects_isolated_across_scripts() {
    let summaries = build_project_role_video_style_memories(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气轻声克制"
                .into(),
            episodes_id: Some(7),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=晚晚 | subjectAliases=林晚/晚晚 | style=表演抬眼停顿，语气低声克制"
                .into(),
            episodes_id: Some(8),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=21 | subject=顾承泽 | style=动作从容克制".into(),
            episodes_id: Some(8),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | subjectAliases=晚晚 | style=表演抬眼停顿".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_prefers_most_supported_voice_variant() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=表演抬眼停顿，语气轻声克制".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=表演抬眼停顿，语气低声克制".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=24 | subject=林晚 | style=表演抬眼停顿，语气低声克制".into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=3 | style=表演抬眼停顿".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_keep_fragile_voice_when_it_carries_emotional_turn() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=表演呼吸发颤，语气哽咽克制".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=表演呼吸发颤，语气哽咽克制".into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | style=表演呼吸发颤，语气哽咽克制 | delivery=表演呼吸发颤哽咽克制".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_keep_high_signal_tail_tremble_voice_variant() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声尾音发颤"
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=表演抿唇停顿，语气低声尾音发颤"
                .into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | style=语气低声尾音发颤".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_drop_camera_shell_when_character_signal_exists() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=镜头稳定跟拍，表演抬眼停顿，情绪克制"
                .into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content:
                "storyboardIds=18 | subject=林晚 | style=镜头近景稳定跟拍，表演抬眼停顿，情绪隐忍"
                    .into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | style=表演抬眼停顿".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_skip_camera_only_role_memory() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=镜头稳定跟拍".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=镜头近景稳定跟拍".into(),
        },
    ]);

    assert!(summaries.is_empty(), "{summaries:?}");
}

#[test]
fn build_script_role_video_style_memories_skip_scene_shell_without_character_signal() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=光影冷调逆光，声场雨声回响".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=光影冷调逆光，环境雨丝玻璃".into(),
        },
    ]);

    assert!(summaries.is_empty(), "{summaries:?}");
}

#[test]
fn build_script_role_video_style_memories_drop_generic_restrained_mood_when_performance_exists() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=表演抬眼停顿，情绪克制".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=表演抬眼停顿，情绪隐忍".into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | style=表演抬眼停顿".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_keep_distinct_intense_mood_when_performance_exists() {
    let summaries = build_script_role_video_style_memories(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | style=表演抬眼停顿，情绪冷峻压迫".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=18 | subject=林晚 | style=表演抬眼停顿，情绪冷峻压迫".into(),
        },
    ]);

    assert_eq!(
        summaries,
        vec!["subject=林晚 | sampleCount=2 | style=情绪冷峻压迫，表演抬眼停顿".to_string()]
    );
}

#[test]
fn build_script_role_video_style_memories_seed_single_high_signal_sample() {
    let summaries = build_script_role_video_style_memories(&[AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头近景稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光".into(),
    }]);

    assert_eq!(
        summaries,
        vec![
            "subject=林晚 | sampleCount=1 | subjectAliases=晚晚 | style=表演喉结滚动低声尾音发颤"
                .to_string()
        ]
    );
}

#[test]
fn build_script_role_video_style_memories_skip_single_generic_soft_sample() {
    let summaries = build_script_role_video_style_memories(&[AgentMemoryRow {
        name: "selected_video_memory".into(),
        content: "storyboardIds=12 | subject=林晚 | style=动作从容克制，语气轻声克制".into(),
    }]);

    assert!(summaries.is_empty(), "{summaries:?}");
}

#[test]
fn select_subject_role_video_style_memory_notes_matches_subject_aliases() {
    let notes = select_subject_role_video_style_memory_notes(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制"
                    .into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=顾承泽 | sampleCount=3 | style=动作从容克制，语气低声克制"
                    .into(),
            },
        ],
        &["晚晚".to_string()],
    );

    assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_prefers_script_scope_over_project_scope() {
    let notes = select_subject_role_video_style_memory_notes(
        &[
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=5 | style=动作从容克制，语气低声克制".into(),
            },
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
            },
        ],
        &["林晚".to_string()],
    );

    assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_merges_project_fill_only_when_axis_is_missing() {
    let notes = select_subject_role_video_style_memory_notes(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content:
                    "subject=林晚 | sampleCount=5 | style=动作从容克制，语气低声克制，光影冷蓝窗光"
                        .into(),
            },
        ],
        &["林晚".to_string()],
    );

    assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_skips_low_support_generic_project_fill() {
    let notes = select_subject_role_video_style_memory_notes(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content:
                    "subject=林晚 | sampleCount=2 | style=动作从容克制，语气低声克制，光影冷蓝窗光"
                        .into(),
            },
        ],
        &["林晚".to_string()],
    );

    assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_skips_supported_generic_project_fill_when_script_scope_already_has_richer_signal(
) {
    let notes = select_subject_role_video_style_memory_notes(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=表演抬眼停顿".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=4 | style=动作从容克制，语气低声克制".into(),
            },
        ],
        &["林晚".to_string()],
    );

    assert_eq!(notes, vec!["表演抬眼停顿".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_keeps_supported_generic_project_fill_for_weak_script_signal(
) {
    let notes = select_subject_role_video_style_memory_notes(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=2 | style=语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=林晚 | sampleCount=4 | style=动作从容克制，语气低声克制".into(),
            },
        ],
        &["林晚".to_string()],
    );

    assert_eq!(notes, vec!["语气轻声克制，动作从容克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_for_storyboard_drops_mismatched_soft_voice() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚抽气后失声开口".into()),
        video_desc: Some("（林晚抽气后失声开口、雨夜门厅、林晚、5秒、近景、稳定跟拍、抽气后失声开口、压抑、冷调逆光、我没事、雨声回响、A13）".into()),
        duration: Some("5s".into()),
    };

    let notes = select_subject_role_video_style_memory_notes_for_storyboard(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演呼吸发颤，语气哽咽克制".into(),
            },
        ],
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演呼吸发颤，语气哽咽克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_for_storyboard_prefers_delivery_profile_for_visible_speech(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚低声开口".into()),
        video_desc: Some("（林晚低声开口、雨夜门厅、林晚、5秒、近景、稳定跟拍、喉结滚动后低声说我没事、压抑克制、冷调逆光、我没事、雨声回响、A13）".into()),
        duration: Some("5s".into()),
    };

    let notes = select_subject_role_video_style_memory_notes_for_storyboard(
        &[AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演喉结滚动，语气低声尾音发颤，声场雨声回响 | delivery=表演喉结滚动低声尾音发颤".into(),
        }],
        &["林晚".to_string(), "晚晚".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演喉结滚动低声尾音发颤".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_for_storyboard_keeps_no_context_behavior() {
    let notes = select_subject_role_video_style_memory_notes_for_storyboard(
        &[AgentMemoryRow {
            name: "script_role_video_style_memory".into(),
            content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=2 | style=表演抬眼停顿，语气轻声克制".into(),
        }],
        &["晚晚".to_string()],
        None,
    );

    assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
}

#[test]
fn select_subject_role_video_style_memory_notes_for_storyboard_prefers_primary_subject_when_multiple_roles_match(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚与顾承泽擦肩后强忍泪意".into()),
        video_desc: Some("（林晚与顾承泽擦肩后强忍泪意、雨夜门厅、林晚/顾承泽、5秒、近景、稳定跟拍、林晚抬眼停顿后侧身让开、克制、冷调逆光、无台词、雨声回响、A13）".into()),
        duration: Some("5s".into()),
    };

    let notes = select_subject_role_video_style_memory_notes_for_storyboard(
        &[
            AgentMemoryRow {
                name: "script_role_video_style_memory".into(),
                content: "subject=林晚 | subjectAliases=晚晚 | sampleCount=4 | style=表演抬眼停顿，语气轻声克制".into(),
            },
            AgentMemoryRow {
                name: "project_role_video_style_memory".into(),
                content: "subject=顾承泽 | subjectAliases=顾总 | sampleCount=6 | style=表演冷眼逼视，语气低声压迫".into(),
            },
        ],
        &["林晚".to_string(), "顾承泽".to_string()],
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(20))]

    // Feature: drama-platform-completion, Property 7: 角色级记忆优先级
    // 验证：需求 15.2
    #[test]
    fn prop_storyboard_role_memory_prefers_primary_subject_in_multi_role_scene(
        primary in "[A-Za-z]{2,8}",
        secondary in "[A-Za-z]{2,8}",
        primary_alias in "[A-Za-z]{2,8}",
        secondary_alias in "[A-Za-z]{2,8}",
    ) {
        prop_assume!(primary != secondary);
        prop_assume!(primary != primary_alias);
        prop_assume!(secondary != secondary_alias);
        prop_assume!(primary_alias != secondary_alias);
        prop_assume!(primary_alias != secondary);
        prop_assume!(secondary_alias != primary);

        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some(format!("{primary}与{secondary}擦肩后强忍泪意")),
            video_desc: Some(format!(
                "（{primary}与{secondary}擦肩后强忍泪意、雨夜门厅、{primary}/{secondary}、5秒、近景、稳定跟拍、{primary}抬眼停顿后侧身让开、克制、冷调逆光、无台词、雨声回响、A13）"
            )),
            duration: Some("5s".into()),
        };

        let notes = select_subject_role_video_style_memory_notes_for_storyboard(
            &[
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: format!(
                        "subject={primary} | subjectAliases={primary_alias} | sampleCount=4 | style=表演抬眼停顿，语气轻声克制"
                    ),
                },
                AgentMemoryRow {
                    name: "script_role_video_style_memory".into(),
                    content: format!(
                        "subject={secondary} | subjectAliases={secondary_alias} | sampleCount=9 | style=表演冷眼逼视，语气低声压迫"
                    ),
                },
            ],
            &[primary.clone(), secondary.clone()],
            Some(&storyboard_row),
        );

        prop_assert_eq!(notes, vec!["表演抬眼停顿，语气轻声克制".to_string()]);
    }
}

#[test]
fn selected_memory_subject_identity_prefers_subject_refs_name() {
    assert_eq!(
        selected_memory_subject_identity("女主站在窗边", "林晚/咖啡杯"),
        Some("林晚".to_string())
    );
}

#[test]
fn selected_memory_subject_aliases_trim_descriptive_subject_and_drop_prop_refs() {
    assert_eq!(
        selected_memory_subject_aliases("林晚站在窗边", "林晚站在窗边/晚晚/咖啡杯"),
        vec!["林晚".to_string(), "晚晚".to_string()]
    );
}

#[test]
fn selected_memory_subject_aliases_trim_dialogue_or_action_tails() {
    assert_eq!(
        selected_memory_subject_aliases("晚晚低声开口", "林晚轻声说道/晚晚低声开口"),
        vec!["林晚".to_string(), "晚晚".to_string()]
    );
}

#[test]
fn selected_memory_subject_aliases_keep_generic_role_when_followed_by_action() {
    assert_eq!(
        selected_memory_subject_aliases("主角推门回望", "主角推门回望/门厅"),
        vec!["主角".to_string()]
    );
}

#[test]
fn compact_video_style_prompt_note_trims_keyword_covered_mood_and_lighting_suffix_noise() {
    let note =
        compact_video_style_prompt_note("情绪紧张压迫感，光影冷调逆光颗粒").expect("style note");

    assert_eq!(note, "情绪紧张压迫，光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_keeps_partial_lighting_context_when_keyword_coverage_is_weak() {
    let note = compact_video_style_prompt_note("情绪克制，光影潮湿路灯暖光").expect("style note");

    assert_eq!(note, "情绪克制，光影潮湿路灯暖光");
}

#[test]
fn compact_video_style_prompt_note_drops_generic_cold_mood_when_lighting_already_covers_it() {
    let note = compact_video_style_prompt_note("情绪冷调，光影冷调逆光").expect("style note");

    assert_eq!(note, "光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_keeps_distinct_mood_when_lighting_is_cold() {
    let note = compact_video_style_prompt_note("情绪冷峻压迫，光影冷调逆光").expect("style note");

    assert_eq!(note, "情绪冷峻压迫，光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_supports_ascii_delimiters() {
    let note = compact_video_style_prompt_note("镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光")
        .expect("style note");

    assert_eq!(note, "镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_drops_generic_cold_mood_when_cold_lighting_is_more_specific() {
    let note = compact_video_style_prompt_note("情绪冷调，光影阴天冷光").expect("style note");

    assert_eq!(note, "光影阴天冷光");
}

#[test]
fn select_script_video_style_memory_notes_reads_summary_note() {
    let notes = select_script_video_style_memory_notes(&[
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | note=别的内容".into(),
        },
    ]);

    assert_eq!(
        notes,
        vec!["镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
    );
}

#[test]
fn select_script_video_style_memory_notes_for_storyboard_prefers_delivery_profile_for_dialogue_scene(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚喉头发紧后低声开口".into()),
        video_desc: Some("（林晚喉头发紧后低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、喉结滚动后低声开口、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
        duration: Some("4s".into()),
    };
    let notes = select_script_video_style_memory_notes_for_storyboard(
        &[AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content:
                "sampleCount=3 | style=镜头稳定跟拍，光影冷蓝窗光 | delivery=表演喉结滚动低声克制"
                    .into(),
        }],
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演喉结滚动低声克制".to_string()]);
}

#[test]
fn build_project_video_style_memory_extracts_cross_script_recurring_style() {
    let summary = build_project_video_style_memory(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            episodes_id: Some(1),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，场景废弃走廊 | note=...".into(),
            episodes_id: Some(2),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=17 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            episodes_id: Some(3),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=3"));
    assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫"));
    assert!(!summary.contains("中景"));
    assert!(!summary.contains("场景废弃走廊"));
}

#[test]
fn build_script_video_style_memory_splits_visual_style_and_delivery_for_single_subject() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光，声场雨声回响 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头中景稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光，声场雨声回响 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(
        summary.contains("style=镜头稳定跟拍，光影冷蓝窗光"),
        "{summary}"
    );
    assert!(
        summary.contains("delivery=表演喉结滚动低声尾音发颤"),
        "{summary}"
    );
    assert!(!summary.contains("style=表演"), "{summary}");
    assert!(!summary.contains("style=语气"), "{summary}");
    assert!(!summary.contains("style=声场"), "{summary}");
}

#[test]
fn build_script_video_style_memory_keeps_high_signal_delivery_across_mixed_subjects() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头中景稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(
        summary.contains("style=镜头稳定跟拍，光影冷蓝窗光"),
        "{summary}"
    );
    assert!(
        summary.contains("delivery=表演喉结滚动低声尾音发颤"),
        "{summary}"
    );
}

#[test]
fn build_project_video_style_memory_drops_character_signature_fragments_when_subjects_mix() {
    let summary = build_project_video_style_memory(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=3 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，情绪冷峻压迫 | note=...".into(),
            episodes_id: Some(1),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，情绪冷峻压迫 | note=...".into(),
            episodes_id: Some(2),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=17 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头近景稳定跟拍，表演抬眼停顿，语气轻声克制，情绪冷峻压迫 | note=...".into(),
            episodes_id: Some(3),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("镜头稳定跟拍"), "{summary}");
    assert!(summary.contains("情绪冷峻压迫"), "{summary}");
    assert!(!summary.contains("表演抬眼停顿"), "{summary}");
    assert!(!summary.contains("语气轻声克制"), "{summary}");
}

#[test]
fn build_project_video_style_memory_keeps_high_signal_delivery_across_mixed_subjects() {
    let summary = build_project_video_style_memory(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=3 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光 | note=...".into(),
            episodes_id: Some(1),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光 | note=...".into(),
            episodes_id: Some(2),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=17 | subject=苏蔓 | subjectAliases=苏蔓/阿蔓 | style=镜头近景稳定跟拍，表演喉结滚动，语气低声尾音发颤，光影冷蓝窗光 | note=...".into(),
            episodes_id: Some(3),
        },
    ], &[])
    .expect("summary");

    assert!(
        summary.contains("style=镜头稳定跟拍，光影冷蓝窗光"),
        "{summary}"
    );
    assert!(
        summary.contains("delivery=表演喉结滚动低声尾音发颤"),
        "{summary}"
    );
}

#[test]
fn build_project_video_style_memory_drops_low_gain_voice_mood_and_motion_when_performance_exists() {
    let summary = build_project_video_style_memory(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=3 | style=镜头稳定跟拍，表演呼吸发颤，语气轻声克制，情绪克制，动作自然，声场静场留白 | note=..."
                .into(),
            episodes_id: Some(1),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头近景稳定跟拍，表演呼吸发颤，语气轻声克制，情绪隐忍，动作自然，声场静场留白 | note=..."
                .into(),
            episodes_id: Some(2),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=17 | style=镜头稳定跟拍，表演呼吸发颤，语气轻声克制，情绪克制，动作自然，声场静场留白 | note=..."
                .into(),
            episodes_id: Some(3),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("表演呼吸发颤"), "{summary}");
    assert!(summary.contains("声场静场留白"), "{summary}");
    assert!(!summary.contains("语气轻声克制"), "{summary}");
    assert!(!summary.contains("情绪克制"), "{summary}");
    assert!(!summary.contains("情绪隐忍"), "{summary}");
    assert!(!summary.contains("动作自然"), "{summary}");
}

#[test]
fn build_project_video_style_memory_drops_recurring_sound_when_subjects_mix() {
    let summary = build_project_video_style_memory(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=3 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，光影冷调逆光，声场雨声回响 | note=..."
                .into(),
            episodes_id: Some(1),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景稳定跟拍，光影冷调逆光，声场雨声回响 | note=..."
                .into(),
            episodes_id: Some(2),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=17 | subject=沈砚 | subjectAliases=沈砚/阿砚 | style=镜头稳定跟拍，光影冷调逆光，声场雨声回响 | note=..."
                .into(),
            episodes_id: Some(3),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("镜头稳定跟拍"), "{summary}");
    assert!(summary.contains("光影冷调逆光"), "{summary}");
    assert!(!summary.contains("声场雨声回响"), "{summary}");
}

#[test]
fn build_project_video_style_memory_requires_majority_support_when_samples_are_dense() {
    let summary = build_project_video_style_memory(
        &[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=1 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=2 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=镜头稳定跟拍，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=4 | style=镜头稳定跟拍，情绪悲怆，光影冷调逆光 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=5 | style=镜头近景手持，情绪悲怆，光影暖光 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("sampleCount=4"), "{summary}");
    assert!(summary.contains("style=镜头稳定跟拍，光影冷调逆光"));
    assert!(!summary.contains("情绪冷峻压迫"));
}

#[test]
fn build_project_video_style_memory_prefers_latest_prompt_seed_within_each_script_storyboard() {
    let summary = build_project_video_style_memory(&[
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=newseed000002 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            episodes_id: Some(7),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=oldseed000001 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            episodes_id: Some(7),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=seed000000003 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            episodes_id: Some(8),
        },
        ScopedAgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | promptSeed=seed000000004 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            episodes_id: Some(7),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=3"));
    assert!(summary.contains("光影暖金逆光"));
    assert!(!summary.contains("光影冷调逆光"));
}

#[test]
fn build_project_video_style_memory_caps_samples_per_script_to_reduce_single_script_bias() {
    let summary = build_project_video_style_memory(
        &[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=1 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=2 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=3 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=4 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=..."
                        .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=..."
                        .into(),
                episodes_id: Some(2),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("sampleCount=4"));
    assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫"));
    assert!(!summary.contains("光影冷调逆光"));
    assert!(!summary.contains("光影暖金逆光"));
}

#[test]
fn build_project_video_style_memory_drops_generic_cold_mood_if_lighting_already_carries_it() {
    let summary = build_project_video_style_memory(
        &[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=情绪冷调，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=情绪冷调，光影冷调逆光 | note=...".into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | style=情绪冷调，光影冷调逆光 | note=...".into(),
                episodes_id: Some(3),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("sampleCount=3"));
    assert!(summary.contains("style=光影冷调逆光"));
    assert!(!summary.contains("情绪冷调"));
}

#[test]
fn build_project_video_style_memory_with_bias_prefers_identity_and_lighting_fragments() {
    let summary = build_project_video_style_memory_with_bias(
        &[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | subject=林晚 | subjectAliases=林晚/晚晚 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，情绪克制，光影暖金逆光，环境窗帘轻摆 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | subject=顾承泽 | subjectAliases=顾承泽/顾总 | style=镜头近景稳定跟拍，表演抬眼停顿，语气轻声克制，情绪隐忍，光影暖金逆光，环境窗帘轻摆 | note=...".into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | subject=苏蔓 | subjectAliases=苏蔓/阿蔓 | style=镜头稳定跟拍，表演抬眼停顿，语气轻声克制，情绪克制，光影暖金逆光，环境窗帘轻摆 | note=...".into(),
                episodes_id: Some(3),
            },
        ],
        &[],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: false,
            prefer_emotion: false,
            prefer_identity: true,
            prefer_lighting: true,
        }),
    )
    .expect("summary");

    assert!(
        summary.contains("style=镜头稳定跟拍，光影暖金逆光，环境窗帘轻摆"),
        "{summary}"
    );
    assert!(!summary.contains("表演抬眼停顿"), "{summary}");
    assert!(!summary.contains("语气轻声克制"), "{summary}");
    assert!(!summary.contains("情绪克制"), "{summary}");
    assert!(!summary.contains("情绪隐忍"), "{summary}");
}

#[test]
fn build_script_video_style_memory_drops_generic_cold_mood_if_specific_cold_lighting_already_carries_it(
) {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷调，光影阴天冷光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷调，光影阴天冷光 | note=...".into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("sampleCount=2"));
    assert!(summary.contains("style=光影阴天冷光"));
    assert!(!summary.contains("情绪冷调"));
}

#[test]
fn build_script_video_style_memory_with_bias_prefers_delivery_and_lighting_fragments() {
    let summary = build_script_video_style_memory_with_bias(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定跟拍，表演喉结滚动，语气低声克制，情绪克制，动作从容克制，光影冷蓝窗光，环境雨丝玻璃 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头近景稳定跟拍，表演喉结滚动，语气低声克制，情绪隐忍，动作从容克制，光影冷蓝窗光，环境雨丝玻璃 | note=...".into(),
            },
        ],
        &[],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: true,
        }),
    )
    .expect("summary");

    assert!(
        summary.contains("style=镜头稳定跟拍，光影冷蓝窗光，环境雨丝玻璃"),
        "{summary}"
    );
    assert!(summary.contains("delivery=表演喉结滚动"), "{summary}");
    assert!(
        !summary.contains("style=镜头稳定跟拍，表演喉结滚动"),
        "{summary}"
    );
    assert!(!summary.contains("语气低声克制"), "{summary}");
    assert!(!summary.contains("情绪克制"), "{summary}");
    assert!(!summary.contains("情绪隐忍"), "{summary}");
    assert!(!summary.contains("动作从容克制"), "{summary}");
}

#[test]
fn build_script_video_style_memory_summarizes_recurring_keywords_from_variant_notes() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | style=镜头近景稳定跟拍，情绪紧张压迫，光影冷调逆光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | style=镜头低机位稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=3"));
    assert!(summary.contains("style=镜头稳定跟拍"));
    assert!(summary.contains("情绪冷峻压迫"));
    assert!(summary.contains("光影阴天冷光"));
    assert!(!summary.contains("近景"));
    assert!(!summary.contains("低机位"));
}

#[test]
fn build_script_video_style_memory_drops_recurring_local_framing_without_stable_shot_language() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头近景，情绪冷峻压迫，光影阴天冷光 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头近景，情绪紧张压迫，光影阴天冷光 | note=..."
                    .into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("情绪冷峻压迫"));
    assert!(summary.contains("光影阴天冷光"));
    assert!(!summary.contains("镜头近景"));
}

#[test]
fn build_script_video_style_memory_deduplicates_same_storyboard_prompt_seed_samples() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=seed000000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=seed000000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=重复确认同镜头".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | promptSeed=seed000000002 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=2"));
    assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"));
    assert!(!summary.contains("中景"));
}

#[test]
fn build_script_video_style_memory_prefers_latest_prompt_seed_per_storyboard() {
    let summary = build_script_video_style_memory(&[
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=newseed000002 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=9 | promptSeed=oldseed000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=10 | promptSeed=seed000000003 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
        },
    ], &[])
    .expect("summary");

    assert!(summary.contains("sampleCount=2"));
    assert!(summary.contains("光影暖金逆光"));
    assert!(!summary.contains("光影冷调逆光"));
}

#[test]
fn build_script_video_style_memory_skips_low_support_keywords_when_note_pool_is_large() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=13 | style=情绪悲怆，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=14 | style=情绪悲怆，光影暖光 | note=...".into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("sampleCount=4"));
    assert!(summary.contains("style=光影冷调逆光"));
    assert!(!summary.contains("情绪冷峻压迫"));
    assert!(!summary.contains("情绪悲怆"));
}

#[test]
fn build_script_video_style_memory_drops_generic_cold_mood_if_lighting_already_carries_it() {
    let summary = build_script_video_style_memory(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷调，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷调，光影冷调逆光 | note=...".into(),
            },
        ],
        &[],
    )
    .expect("summary");

    assert!(summary.contains("sampleCount=2"));
    assert!(summary.contains("style=光影冷调逆光"));
    assert!(!summary.contains("情绪冷调"));
}

#[test]
fn select_project_video_style_memory_notes_reads_summary_note() {
    let notes = select_project_video_style_memory_notes(&[
        AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content:
                "sampleCount=6 | style=镜头稳定跟拍，情绪冷峻压迫 | note=镜头稳定跟拍，情绪冷峻压迫"
                    .into(),
        },
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=3 | style=镜头近景手持 | note=镜头近景手持".into(),
        },
    ]);

    assert_eq!(notes, vec!["镜头稳定跟拍，情绪冷峻压迫".to_string()]);
}

#[test]
fn select_project_video_style_memory_notes_for_storyboard_prefers_delivery_on_fragile_turn() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚终于哽咽开口".into()),
        video_desc: Some("（林晚终于哽咽开口、病房窗边、林晚、4秒、近景、缓推、呼吸发颤后哽咽开口、哽咽压抑、冷蓝窗光、我没事、静场留白、A13）".into()),
        duration: Some("4s".into()),
    };
    let notes = select_project_video_style_memory_notes_for_storyboard(
        &[AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content:
                "sampleCount=5 | style=镜头稳定跟拍，光影冷蓝窗光 | delivery=表演呼吸发颤哽咽克制"
                    .into(),
        }],
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演呼吸发颤哽咽克制".to_string()]);
}

#[test]
fn select_selected_video_memory_notes_drop_scene_fragments_from_prompt_style_memory() {
    let notes = select_selected_video_memory_notes(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊 | note=...".into(),
        }],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
    );
}

#[test]
fn select_selected_video_memory_notes_drop_local_framing_when_other_style_fragments_exist() {
    let notes = select_selected_video_memory_notes(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | style=镜头近景，情绪冷峻压迫，光影阴天冷光 | note=..."
                .into(),
        }],
        12,
        None,
    );

    assert_eq!(notes, vec!["情绪冷峻压迫，光影阴天冷光".to_string()]);
}

#[test]
fn select_selected_video_memory_notes_keep_local_framing_when_it_is_only_style_signal() {
    let notes = select_selected_video_memory_notes(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | style=镜头近景 | note=...".into(),
        }],
        12,
        None,
    );

    assert_eq!(notes, vec!["镜头近景".to_string()]);
}

#[test]
fn select_selected_video_memory_notes_prefers_delivery_rich_style_over_visual_only_style() {
    let notes = select_selected_video_memory_notes(
        &[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | style=镜头稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=..."
                        .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=12 | style=表演喉结滚动，语气低声尾音发颤，情绪强忍泪意 | note=..."
                        .into(),
            },
        ],
        12,
        None,
    );

    assert_eq!(
        notes,
        vec!["表演喉结滚动，语气低声尾音发颤，情绪强忍泪意".to_string()]
    );
}

#[test]
fn select_selected_video_memory_notes_for_storyboard_prefers_delivery_on_fragile_turn() {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚喉头发紧后低声开口".into()),
        video_desc: Some("（林晚喉头发紧后低声开口、咖啡厅窗边、林晚、4秒、近景、缓推、喉结滚动后低声开口、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A21）".into()),
        duration: Some("4".into()),
    };
    let notes = select_selected_video_memory_notes_for_storyboard(
        &[AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=21 | style=表演喉结滚动，语气低声克制，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=...".into(),
        }],
        21,
        None,
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演喉结滚动低声克制".to_string()]);
}

#[test]
fn compact_video_continuity_note_keeps_only_style_and_continuity_fragments() {
    let note = compact_video_continuity_note(
        "女主推门冲出；保持冷调压迫感；镜头中景稳定跟拍；后续反派从暗处逼近",
    )
    .expect("note");

    assert_eq!(note, "保持冷调压迫感，镜头中景稳定跟拍");
    assert!(!note.contains("反派"));
}

#[test]
fn compact_video_continuity_note_supports_ascii_delimiters_and_drops_unrelated_fragments() {
    let note = compact_video_continuity_note(
        "后续反派从暗处逼近, 保持冷调压迫感; 镜头中景稳定跟拍\n无关素材提示",
    )
    .expect("note");

    assert_eq!(note, "保持冷调压迫感，镜头中景稳定跟拍");
    assert!(!note.contains("反派"));
    assert!(!note.contains("素材"));
}

#[tokio::test]
async fn clear_selected_video_memory_ignores_invalid_storyboard_id() {
    let pool = PgPool::connect_lazy("postgresql://user:pass@localhost/db").expect("lazy pg pool");
    let result = clear_selected_video_memory(&pool, Uuid::nil(), 1, 2, 0).await;

    assert!(result.is_ok());
}

#[tokio::test]
async fn clear_rejected_video_negative_memory_ignores_invalid_storyboard_id() {
    let pool = PgPool::connect_lazy("postgresql://user:pass@localhost/db").expect("lazy pg pool");
    let result = clear_rejected_video_negative_memory(&pool, Uuid::nil(), 1, 2, 0).await;

    assert!(result.is_ok());
}

#[test]
fn plan_selected_video_memory_optimization_removes_duplicates_and_old_visual_only_rows() {
    let plan = plan_selected_video_memory_optimization(&[
        SelectedVideoMemoryOptimizationCandidate {
            id: 41,
            content:
                "storyboardIds=12 | delivery=表演喉结滚动低声克制 | style=表演喉结滚动，语气低声克制"
                    .into(),
            create_time_ms: 500,
        },
        SelectedVideoMemoryOptimizationCandidate {
            id: 42,
            content:
                "storyboardIds=12 | style=镜头近景，光影冷调逆光，机位压迫 | note=镜头近景，光影冷调逆光，机位压迫"
                    .into(),
            create_time_ms: 400,
        },
        SelectedVideoMemoryOptimizationCandidate {
            id: 43,
            content:
                "storyboardIds=18 | style=镜头稳定跟拍，光影阴天冷光，构图压迫 | note=镜头稳定跟拍，光影阴天冷光，构图压迫"
                    .into(),
            create_time_ms: 300,
        },
        SelectedVideoMemoryOptimizationCandidate {
            id: 44,
            content:
                "storyboardIds=18 | style=镜头稳定跟拍，光影阴天冷光，构图压迫 | note=镜头稳定跟拍，光影阴天冷光，构图压迫"
                    .into(),
            create_time_ms: 200,
        },
    ], None);

    assert_eq!(plan.delete_ids, vec![43, 44]);
    assert_eq!(plan.removed_visual_rows, 1);
    assert_eq!(plan.removed_duplicate_rows, 1);
    assert!(plan.removed_chars > 0);
}

#[test]
fn plan_selected_video_memory_optimization_keeps_latest_visual_when_no_delivery_exists() {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 51,
                content: "storyboardIds=12 | style=镜头近景，光影冷调逆光".into(),
                create_time_ms: 500,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 52,
                content: "storyboardIds=13 | style=镜头稳定跟拍，光影阴天冷光".into(),
                create_time_ms: 400,
            },
        ],
        None,
    );

    assert!(plan.delete_ids.is_empty());
    assert_eq!(plan.removed_visual_rows, 0);
    assert_eq!(plan.removed_duplicate_rows, 0);
}

#[test]
fn plan_selected_video_memory_optimization_drops_scope_filler_when_richer_same_storyboard_exists() {
    let plan = plan_selected_video_memory_optimization(&[
        SelectedVideoMemoryOptimizationCandidate {
            id: 61,
            content:
                "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制 | note=保持克制"
                    .into(),
            create_time_ms: 600,
        },
        SelectedVideoMemoryOptimizationCandidate {
            id: 62,
            content:
                "storyboardIds=12 | style=表演喉结滚动，语气压低气息尾音发颤，光影冷蓝窗光 | note=强忍泪意"
                    .into(),
            create_time_ms: 500,
        },
    ], None);

    assert_eq!(plan.delete_ids, vec![61]);
    assert_eq!(plan.removed_visual_rows, 0);
    assert_eq!(plan.removed_duplicate_rows, 0);
    assert!(plan.removed_chars > 0);
}

#[test]
fn plan_selected_video_memory_optimization_keeps_scope_filler_when_no_richer_same_storyboard_exists(
) {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 71,
                content:
                    "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制 | note=保持克制"
                        .into(),
                create_time_ms: 600,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 72,
                content: "storyboardIds=13 | style=镜头稳定跟拍，光影阴天冷光".into(),
                create_time_ms: 500,
            },
        ],
        None,
    );

    assert!(plan.delete_ids.is_empty());
}

#[test]
fn plan_selected_video_memory_optimization_drops_scope_filler_when_delivery_bias_makes_richer_anchor_more_valuable(
) {
    let rows = [
        SelectedVideoMemoryOptimizationCandidate {
            id: 81,
            content:
                "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制，镜头近景 | note=保持克制"
                    .into(),
            create_time_ms: 600,
        },
        SelectedVideoMemoryOptimizationCandidate {
            id: 82,
            content:
                "storyboardIds=12 | subject=林晚 | style=表演眼眶发红，光影冷蓝窗光 | note=强忍泪意"
                    .into(),
            create_time_ms: 500,
        },
    ];

    let baseline = plan_selected_video_memory_optimization(&rows, None);
    let biased = plan_selected_video_memory_optimization(
        &rows,
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: false,
        }),
    );

    assert!(baseline.delete_ids.is_empty());
    assert_eq!(biased.delete_ids, vec![81]);
}

#[test]
fn plan_selected_video_memory_optimization_drops_row_that_turns_low_signal_after_focus_compaction()
{
    let plan = plan_selected_video_memory_optimization(
        &[SelectedVideoMemoryOptimizationCandidate {
            id: 88,
            content:
                "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制，镜头近景 | note=保持克制"
                    .into(),
            create_time_ms: 600,
        }],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: false,
        }),
    );

    assert_eq!(plan.delete_ids, vec![88]);
    assert_eq!(plan.removed_duplicate_rows, 0);
    assert!(plan.removed_chars > 0);
}

#[test]
fn plan_selected_video_memory_optimization_uses_compacted_content_for_bias_aware_dedup() {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 89,
                content:
                    "storyboardIds=12 | subject=林晚 | style=表演喉结滚动，语气低声克制，情绪克制，动作从容克制，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=强忍泪意"
                        .into(),
                create_time_ms: 600,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 90,
                content:
                    "storyboardIds=18 | subject=林晚 | style=表演喉结滚动，光影冷蓝窗光 | delivery=表演喉结滚动低声克制 | note=强忍泪意"
                        .into(),
                create_time_ms: 500,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: false,
        }),
    );

    assert_eq!(plan.delete_ids, vec![90]);
    assert_eq!(plan.removed_duplicate_rows, 1);
}

#[test]
fn plan_selected_video_memory_optimization_keeps_best_lighting_row_when_visual_focus_is_hot() {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 91,
                content:
                    "storyboardIds=12 | delivery=表演喉结滚动低声克制 | style=表演喉结滚动，语气低声克制"
                        .into(),
                create_time_ms: 700,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 92,
                content: "storyboardIds=13 | style=镜头近景，构图压迫".into(),
                create_time_ms: 650,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 93,
                content:
                    "storyboardIds=14 | subject=林晚 | style=镜头近景，光影暖金逆光，构图稳定 | note=保持角色光线一致"
                        .into(),
                create_time_ms: 500,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: false,
            prefer_emotion: false,
            prefer_identity: true,
            prefer_lighting: true,
        }),
    );

    assert_eq!(plan.delete_ids, vec![92]);
}

#[test]
fn plan_selected_video_memory_optimization_drops_cross_scope_fillers_when_focus_bias_has_multiple_strong_anchors(
) {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 101,
                content:
                    "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制，镜头近景 | note=保持克制"
                        .into(),
                create_time_ms: 900,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 102,
                content:
                    "storyboardIds=13 | subject=林晚 | style=表演眼眶发红，语气压低气息尾音发颤，光影冷蓝窗光 | note=强忍泪意"
                        .into(),
                create_time_ms: 800,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 103,
                content:
                    "storyboardIds=14 | subject=顾承泽 | style=镜头稳定跟拍，光影暖金逆光，环境玻璃水痕连贯 | note=保持角色光线一致"
                        .into(),
                create_time_ms: 700,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 104,
                content:
                    "storyboardIds=15 | style=动作缓慢，语气轻声克制，情绪克制 | note=保持克制"
                        .into(),
                create_time_ms: 600,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: true,
            prefer_lighting: true,
        }),
    );

    assert_eq!(plan.delete_ids, vec![101, 104]);
}

#[test]
fn plan_selected_video_memory_optimization_keeps_cross_scope_fillers_when_focus_anchor_is_not_yet_dense(
) {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 111,
                content:
                    "storyboardIds=12 | style=动作从容克制，语气低声克制，情绪克制，镜头近景 | note=保持克制"
                        .into(),
                create_time_ms: 900,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 112,
                content:
                    "storyboardIds=13 | subject=林晚 | style=表演眼眶发红，语气压低气息尾音发颤，光影冷蓝窗光 | note=强忍泪意"
                        .into(),
                create_time_ms: 800,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: false,
            prefer_lighting: false,
        }),
    );

    assert!(plan.delete_ids.is_empty());
}

#[test]
fn plan_selected_video_memory_optimization_prefers_focus_tagged_identity_lighting_row() {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 121,
                content:
                    "storyboardIds=12 | style=镜头近景，构图压迫 | note=保持克制 | focusTags=emotion_arc"
                        .into(),
                create_time_ms: 650,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 122,
                content:
                    "storyboardIds=12 | subject=林晚 | style=光影暖金逆光，声场静场留白 | note=保持角色光线一致 | focusTags=identity_continuity/lighting_realism"
                        .into(),
                create_time_ms: 500,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: false,
            prefer_emotion: false,
            prefer_identity: true,
            prefer_lighting: true,
        }),
    );

    assert_eq!(plan.delete_ids, vec![121]);
}

#[test]
fn plan_selected_video_memory_optimization_drops_cross_scope_fillers_when_single_anchor_covers_multiple_hot_focuses(
) {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 131,
                content:
                    "storyboardIds=12 | style=动作从容克制，语气轻声克制，情绪克制，镜头近景 | note=保持克制"
                        .into(),
                create_time_ms: 900,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 132,
                content:
                    "storyboardIds=13 | subject=林晚 | style=表演眼眶发红，光影冷蓝窗光 | note=强忍泪意 | focusTags=delivery_realism/emotion_arc/identity_continuity/lighting_realism"
                        .into(),
                create_time_ms: 800,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: true,
            prefer_lighting: true,
        }),
    );

    assert_eq!(plan.delete_ids, vec![131]);
}

#[test]
fn plan_selected_video_memory_optimization_keeps_cross_scope_fillers_when_single_anchor_only_covers_one_hot_focus(
) {
    let plan = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 141,
                content:
                    "storyboardIds=12 | style=动作从容克制，语气轻声克制，情绪克制，镜头近景 | note=保持克制"
                        .into(),
                create_time_ms: 900,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 142,
                content:
                    "storyboardIds=13 | subject=林晚 | style=表演眼眶发红 | note=强忍泪意 | focusTags=delivery_realism"
                        .into(),
                create_time_ms: 800,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_identity: true,
            prefer_lighting: false,
        }),
    );

    assert!(plan.delete_ids.is_empty());
}

#[test]
fn plan_selected_video_memory_optimization_drops_same_scope_focus_redundant_row_when_stronger_anchor_exists(
) {
    let baseline = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 151,
                content:
                    "storyboardIds=12 | subject=林晚 | style=表演回头前眼神停顿，光影冷蓝窗光映脸，环境玻璃反射 | note=保持林晚脸部窗光和回头停顿一致"
                        .into(),
                create_time_ms: 900,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 152,
                content:
                    "storyboardIds=12 | style=镜头近景，光影冷蓝窗光 | note=保持冷蓝窗光"
                        .into(),
                create_time_ms: 800,
            },
        ],
        None,
    );
    let biased = plan_selected_video_memory_optimization(
        &[
            SelectedVideoMemoryOptimizationCandidate {
                id: 151,
                content:
                    "storyboardIds=12 | subject=林晚 | style=表演回头前眼神停顿，光影冷蓝窗光映脸，环境玻璃反射 | note=保持林晚脸部窗光和回头停顿一致"
                        .into(),
                create_time_ms: 900,
            },
            SelectedVideoMemoryOptimizationCandidate {
                id: 152,
                content:
                    "storyboardIds=12 | style=镜头近景，光影冷蓝窗光 | note=保持冷蓝窗光"
                        .into(),
                create_time_ms: 800,
            },
        ],
        Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: false,
            prefer_emotion: false,
            prefer_identity: true,
            prefer_lighting: true,
        }),
    );

    assert!(baseline.delete_ids.is_empty());
    assert_eq!(biased.delete_ids, vec![152]);
}
