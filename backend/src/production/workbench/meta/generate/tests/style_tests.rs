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
fn exact_style_notes_do_not_yield_when_exact_note_has_non_template_signal() {
    assert!(!exact_style_notes_should_yield_to_role_memory(
        &["情绪冷色压迫感，动作自然".to_string()],
        &["表演喉结滚动，语气轻声克制".to_string()]
    ));
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
fn parse_director_motion_cue_reads_bundled_motion_style_section() {
    let profile = art_style_director_profile("国风二次元").expect("matched art style");
    let cue = parse_director_motion_cue(profile.director_storyboard_table_style);

    assert_eq!(cue.as_deref(), Some("动作缓慢优雅"));
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
