use super::*;

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
