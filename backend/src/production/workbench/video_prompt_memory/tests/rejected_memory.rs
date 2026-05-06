use super::*;

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
        "storyboardIds=12 | rejectionCount=1 | riskTags=lighting/dialogue/performance | focusTags=delivery_realism/emotion_arc | badCaseCategory=dialogue_issue | reviewSummary=台词像读文章 | avoid=avoid flat cold lighting, avoid blank expression or monotone delivery, avoid lip-sync mismatch",
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
    assert!(
        prepared.contains("badCaseCategory=dialogue_issue"),
        "{prepared}"
    );
    assert!(prepared.contains("reviewSummary=台词像读文章"), "{prepared}");
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
