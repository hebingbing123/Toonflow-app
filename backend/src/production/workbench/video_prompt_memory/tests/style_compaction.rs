use super::*;

#[test]
fn selected_memory_subject_identity_prefers_subject_refs_name() {
    assert_eq!(
        selected_memory_subject_identity("女主站在窗边", "林晚/咖啡杯"),
        Some("林晚".to_string())
    );
}

#[test]
fn selected_memory_subject_aliases_trim_descriptive_subject_and_drop_prop_refs() {
    assert_eq!(
        selected_memory_subject_aliases("林晚站在窗边", "林晚站在窗边/晚晚/咖啡杯"),
        vec!["林晚".to_string(), "晚晚".to_string()]
    );
}

#[test]
fn selected_memory_subject_aliases_trim_dialogue_or_action_tails() {
    assert_eq!(
        selected_memory_subject_aliases("晚晚低声开口", "林晚轻声说道/晚晚低声开口"),
        vec!["林晚".to_string(), "晚晚".to_string()]
    );
}

#[test]
fn selected_memory_subject_aliases_keep_generic_role_when_followed_by_action() {
    assert_eq!(
        selected_memory_subject_aliases("主角推门回望", "主角推门回望/门厅"),
        vec!["主角".to_string()]
    );
}

#[test]
fn compact_video_style_prompt_note_trims_keyword_covered_mood_and_lighting_suffix_noise() {
    let note =
        compact_video_style_prompt_note("情绪紧张压迫感，光影冷调逆光颗粒").expect("style note");

    assert_eq!(note, "情绪紧张压迫，光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_keeps_partial_lighting_context_when_keyword_coverage_is_weak() {
    let note = compact_video_style_prompt_note("情绪克制，光影潮湿路灯暖光").expect("style note");

    assert_eq!(note, "情绪克制，光影潮湿路灯暖光");
}

#[test]
fn compact_video_style_prompt_note_drops_generic_cold_mood_when_lighting_already_covers_it() {
    let note = compact_video_style_prompt_note("情绪冷调，光影冷调逆光").expect("style note");

    assert_eq!(note, "光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_keeps_distinct_mood_when_lighting_is_cold() {
    let note = compact_video_style_prompt_note("情绪冷峻压迫，光影冷调逆光").expect("style note");

    assert_eq!(note, "情绪冷峻压迫，光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_supports_ascii_delimiters() {
    let note = compact_video_style_prompt_note("镜头稳定跟拍, 情绪冷峻压迫; 光影冷调逆光")
        .expect("style note");

    assert_eq!(note, "镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光");
}

#[test]
fn compact_video_style_prompt_note_drops_generic_cold_mood_when_cold_lighting_is_more_specific() {
    let note = compact_video_style_prompt_note("情绪冷调，光影阴天冷光").expect("style note");

    assert_eq!(note, "光影阴天冷光");
}

#[test]
fn select_script_video_style_memory_notes_reads_summary_note() {
    let notes = select_script_video_style_memory_notes(&[
        AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
        },
        AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | note=别的内容".into(),
        },
    ]);

    assert_eq!(
        notes,
        vec!["镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
    );
}

#[test]
fn select_script_video_style_memory_notes_for_storyboard_prefers_delivery_profile_for_dialogue_scene(
) {
    let storyboard_row = StoryboardPromptSeedRow {
        prompt: Some("林晚喉头发紧后低声开口".into()),
        video_desc: Some("（林晚喉头发紧后低声开口、咖啡厅窗边、林晚、4秒、中景、缓推、喉结滚动后低声开口、克制、夜间冷蓝窗光、你终于来了、轻微环境声、A12）".into()),
        duration: Some("4s".into()),
    };
    let notes = select_script_video_style_memory_notes_for_storyboard(
        &[AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content:
                "sampleCount=3 | style=镜头稳定跟拍，光影冷蓝窗光 | delivery=表演喉结滚动低声克制"
                    .into(),
        }],
        Some(&storyboard_row),
    );

    assert_eq!(notes, vec!["表演喉结滚动低声克制".to_string()]);
}
