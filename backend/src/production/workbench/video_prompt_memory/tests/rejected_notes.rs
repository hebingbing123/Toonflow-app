use super::*;

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
