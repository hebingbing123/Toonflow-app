//! Prompt builder and diagnostics logic.

use super::super::*;
use super::*;

pub fn style_fragment_is_low_gain_hidden_speech_voice(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    prompt: &str,
) -> bool {
    fragment.starts_with("语气")
        && dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
            &fields.dialogue,
            fields,
            prompt,
        )
}

pub fn style_fragment_lags_current_emotional_turn(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    if !fragment.starts_with("语气") {
        return false;
    }

    let Some(fragment_voice_family) = style_voice_family_for_generate(fragment) else {
        return false;
    };
    let Some(context_voice_family) = current_storyboard_voice_family(fields) else {
        return false;
    };
    if fragment_voice_family == context_voice_family {
        return false;
    }

    current_storyboard_is_fragile_emotional_turn(fields)
        || matches!(context_voice_family, "fragile" | "clipped")
}

pub fn current_storyboard_voice_family(
    fields: &StructuredStoryboardDescription,
) -> Option<&'static str> {
    [
        fields.dialogue.as_str(),
        fields.action.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .find_map(style_voice_family_for_generate)
}

pub fn current_storyboard_is_fragile_emotional_turn(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.action.as_str(),
        fields.dialogue.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .any(|field| {
        [
            "哽咽", "发哽", "含泪", "泪", "哭", "发颤", "颤声", "鼻音", "抽气", "强忍",
        ]
        .iter()
        .any(|keyword| field.contains(keyword))
    })
}

pub fn style_voice_family_for_generate(text: &str) -> Option<&'static str> {
    [
        ("哽咽", "fragile"),
        ("发哽", "fragile"),
        ("失声", "fragile"),
        ("哑声", "fragile"),
        ("哭腔", "fragile"),
        ("颤声", "fragile"),
        ("鼻音", "fragile"),
        ("抽气", "fragile"),
        ("发颤", "fragile"),
        ("低声", "low"),
        ("压低", "low"),
        ("轻声", "light"),
        ("轻轻", "light"),
        ("呢喃", "murmur"),
        ("喃喃", "murmur"),
        ("耳语", "murmur"),
        ("短促", "clipped"),
        ("急促", "clipped"),
    ]
    .into_iter()
    .find_map(|(keyword, family)| text.contains(keyword).then_some(family))
}

pub fn memory_style_bucket(fragment: &str) -> Option<&'static str> {
    [
        ("表演", "表演"),
        ("语气", "语气"),
        ("情绪", "情绪"),
        ("动作", "动作"),
        ("镜头", "镜头"),
        ("光影", "光影"),
        ("环境", "环境"),
        ("声场", "声场"),
    ]
    .into_iter()
    .find_map(|(prefix, bucket)| fragment.starts_with(prefix).then_some(bucket))
}

pub fn style_fragment_is_low_gain_mood_carryover(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    if fragment.starts_with("语气") {
        if !storyboard_supports_voice_style(fields) {
            return false;
        }

        let body = normalize_prompt_text(fragment.trim_start_matches("语气"));
        return !body.is_empty()
            && body
                .split(['，', ',', '；', ';', '、', '/', ' '])
                .map(normalize_prompt_text)
                .filter(|part| !part.is_empty())
                .all(|part| voice_fragment_token_is_generic_mood_carryover(part.as_str()));
    }

    if fragment.starts_with("情绪") {
        let body = normalize_prompt_text(fragment.trim_start_matches("情绪"));
        return mood_fragment_is_generic_carryover(body.as_str());
    }

    fragment.starts_with("动作")
        && !video_prompt_scene_has_motion_risk(fields)
        && generic_motion_style_fragment(fragment)
}

pub fn style_note_contains_family(note: &str, family: &str) -> bool {
    split_prompt_note_fragments(note)
        .any(|fragment| style_note_fragment_family(&fragment) == Some(family))
}

pub fn style_fragment_matches_prompt_style_field(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    (!fields.mood.is_empty() && style_fragment_semantically_covers_field(fragment, &fields.mood))
        || (!fields.lighting.is_empty()
            && style_fragment_semantically_covers_field(fragment, &fields.lighting))
        || (fragment.starts_with("表演")
            && ((!fields.action.is_empty()
                && style_fragment_semantically_covers_field(fragment, &fields.action))
                || (!fields.dialogue.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.dialogue))
                || (!fields.mood.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.mood))))
        || (fragment.starts_with("语气")
            && ((!fields.action.is_empty()
                && style_fragment_semantically_covers_field(fragment, &fields.action))
                || (!fields.dialogue.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.dialogue))
                || (!fields.mood.is_empty()
                    && style_fragment_semantically_covers_field(fragment, &fields.mood))))
}

pub fn style_fragment_prefix(fragment: &str) -> bool {
    [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ]
    .iter()
    .any(|prefix| fragment.starts_with(prefix))
}

pub fn style_fragment_prefix_and_body(fragment: &str) -> Option<(&'static str, String)> {
    [
        "镜头", "情绪", "光影", "动作", "表演", "环境", "语气", "声场",
    ]
    .iter()
    .find_map(|prefix| {
        fragment
            .strip_prefix(prefix)
            .map(normalize_prompt_text)
            .filter(|body| !body.is_empty())
            .map(|body| (*prefix, body))
    })
}

pub fn style_fragment_body(fragment: &str) -> Option<String> {
    style_fragment_prefix_and_body(fragment).map(|(_, body)| body)
}

pub fn style_fragment_or_body_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    style_fragment_is_semantically_covered(fragment, coverage)
        || style_fragment_body(fragment)
            .as_deref()
            .is_some_and(|body| prompt_fragment_is_covered(body, coverage))
}

pub fn style_fragment_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    continuity_fragment_is_semantically_covered(fragment, coverage)
}

pub fn project_director_reserved_anchor_already_carries_performance(anchor: &str) -> bool {
    anchor.starts_with("表演")
        || [
            "神情", "眼神", "目光", "眼底", "眼尾", "眼眶", "唇线", "嘴角", "喉结", "眉心",
        ]
        .iter()
        .any(|keyword| anchor.contains(keyword))
}
