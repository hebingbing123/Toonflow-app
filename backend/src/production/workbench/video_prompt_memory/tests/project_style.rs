use super::*;

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
