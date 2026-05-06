use super::*;

#[test]
fn merge_rejected_video_negative_memory_accumulates_rejection_count_and_deduplicates() {
    let merged = merge_rejected_video_negative_memory(
        "storyboardIds=12 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=motion/lighting | badCaseCategory=lighting_issue | reviewSummary=逆光太硬 | avoid=avoid shaky handheld motion, avoid flat cold lighting",
        "storyboardIds=12 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=1 | riskTags=lighting/emotion | badCaseCategory=dialogue_issue | reviewSummary=台词像读文章 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood",
    );

    assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
    assert!(merged.contains("storyboardIds=12"));
    assert!(merged.contains("subject=晚晚"));
    assert!(merged.contains("subjectAliases=林晚"));
    assert!(merged.contains("riskTags=emotion/lighting/motion"));
    assert!(merged.contains("focusTags=delivery_realism/identity_continuity/lighting_realism"));
    assert!(merged.contains("badCaseCategory=dialogue_issue"));
    assert!(merged.contains("reviewSummary=台词像读文章"));
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
