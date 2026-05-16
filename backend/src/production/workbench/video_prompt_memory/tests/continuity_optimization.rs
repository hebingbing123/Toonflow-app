use super::*;

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
