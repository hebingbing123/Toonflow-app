use super::*;

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
