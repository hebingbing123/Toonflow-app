use super::*;

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
