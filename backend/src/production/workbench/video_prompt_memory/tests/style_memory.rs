use super::*;

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
