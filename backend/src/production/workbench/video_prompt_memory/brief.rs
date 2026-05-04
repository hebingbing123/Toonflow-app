use super::style_compact::{
    selected_style_fragment_is_generic_restrained_mood, selected_style_fragment_is_low_gain_motion,
    selected_style_fragment_is_low_gain_voice,
};
use super::style_rank::{is_local_framing_only_fragment, selected_video_style_value_from_content};
use super::*;

pub(super) fn build_video_generation_brief_memory(
    style_summary: Option<&str>,
    observation_summary: Option<&str>,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let style = style_summary
        .and_then(|content| build_video_generation_brief_style(content, bias))
        .or_else(|| {
            observation_summary.and_then(|content| {
                extract_key_value(content, "avoid")
                    .and_then(|value| compact_video_generation_brief_avoid(&value, bias))
            })
        })?;

    let mut parts = vec![format!("style={style}")];
    if let Some(avoid) = observation_summary
        .and_then(|content| extract_key_value(content, "avoid"))
        .and_then(|value| compact_video_generation_brief_avoid(&value, bias))
        .filter(|value| !value.is_empty())
    {
        parts.push(format!("avoid={avoid}"));
    }
    if let Some(risk_tags) = observation_summary
        .and_then(|content| extract_key_value(content, "riskTags"))
        .and_then(|value| compact_video_generation_brief_risk_tags(&value, bias))
        .filter(|value| !value.is_empty())
    {
        parts.push(format!("riskTags={risk_tags}"));
    }
    let focus_tags = selected_video_memory_focus_tags_from_bias(bias);
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    Some(parts.join(" | "))
}

fn build_video_generation_brief_style(
    style_summary: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let delivery = delivery_style_value_from_content(style_summary);
    let style = selected_video_style_value_from_content(style_summary)?;
    let mut fragments = Vec::<String>::new();

    if let Some(delivery) = delivery {
        fragments.extend(split_prompt_note_fragments(&delivery));
    }
    fragments.extend(split_prompt_note_fragments(&style));

    let bias = bias.unwrap_or_default();
    let mut ranked = fragments
        .into_iter()
        .filter(|fragment| !video_generation_brief_fragment_is_low_signal(fragment))
        .map(|fragment| {
            let axis = video_generation_brief_fragment_axis(&fragment);
            let score = video_generation_brief_fragment_score(&fragment, bias);
            (score, axis, fragment)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(b.1)).then(a.2.cmp(&b.2)));

    let mut kept = Vec::<String>::new();
    let mut seen_axes = std::collections::HashSet::<&'static str>::new();
    for (_, axis, fragment) in ranked {
        if !seen_axes.insert(axis) {
            continue;
        }
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
        if kept.len() >= 3 {
            break;
        }
    }

    compact_video_style_prompt_note(&kept.join("，"))
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !value.is_empty())
}

fn compact_video_generation_brief_avoid(
    avoid: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let bias = selected_optimization_bias_to_rejected_selection_bias(bias);
    compact_rejected_negative_memory_fragments_for_storage_with_bias(
        split_video_generation_brief_avoid_fragments(avoid),
        bias,
    )
    .into_iter()
    .next()
    .map(|fragment| clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
}

fn split_video_generation_brief_avoid_fragments(avoid: &str) -> Vec<String> {
    avoid
        .split([';', '；', ',', '，'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}

fn compact_video_generation_brief_risk_tags(
    risk_tags: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let mut tags = risk_tags
        .split(['/', ',', '，', ';', '；'])
        .map(normalize_prompt_text)
        .filter(|tag| !tag.is_empty())
        .collect::<Vec<_>>();
    if tags.is_empty() {
        return None;
    }
    let prefer_delivery = bias.is_some_and(|value| value.prefer_delivery || value.prefer_emotion);
    let prefer_visual = bias.is_some_and(|value| value.prefer_identity || value.prefer_lighting);
    tags.sort_by(|left, right| {
        video_generation_brief_risk_tag_score(right, prefer_delivery, prefer_visual)
            .cmp(&video_generation_brief_risk_tag_score(
                left,
                prefer_delivery,
                prefer_visual,
            ))
            .then(left.cmp(right))
    });
    tags.dedup();
    Some(tags.into_iter().take(2).collect::<Vec<_>>().join("/"))
}

fn video_generation_brief_risk_tag_score(
    tag: &str,
    prefer_delivery: bool,
    prefer_visual: bool,
) -> i32 {
    let mut score = 0;
    if prefer_delivery && matches!(tag, "dialogue" | "performance" | "emotion") {
        score += 8;
    }
    if prefer_visual && matches!(tag, "identity" | "lighting" | "motion" | "framing") {
        score += 8;
    }
    score
}

fn video_generation_brief_fragment_axis(fragment: &str) -> &'static str {
    if fragment.starts_with("表演") {
        return "performance";
    }
    if fragment.starts_with("语气") {
        return "voice";
    }
    if fragment.starts_with("情绪") {
        return "emotion";
    }
    if fragment.starts_with("光影") {
        return "lighting";
    }
    if fragment.starts_with("环境") {
        return "environment";
    }
    if fragment.starts_with("声场") {
        return "sound";
    }
    if fragment.starts_with("动作") {
        return "motion";
    }
    if fragment.starts_with("镜头") {
        return "camera";
    }
    "other"
}

fn video_generation_brief_fragment_score(
    fragment: &str,
    bias: SelectedVideoMemoryOptimizationBias,
) -> i32 {
    let mut score = match video_generation_brief_fragment_axis(fragment) {
        "performance" => 18,
        "voice" => 16,
        "emotion" => 14,
        "lighting" => 13,
        "environment" => 10,
        "sound" => 9,
        "motion" => 8,
        "camera" => 6,
        _ => 4,
    };
    if bias.prefer_delivery
        && matches!(
            video_generation_brief_fragment_axis(fragment),
            "performance" | "voice"
        )
    {
        score += 10;
    }
    if bias.prefer_emotion
        && matches!(
            video_generation_brief_fragment_axis(fragment),
            "performance" | "emotion" | "voice"
        )
    {
        score += 8;
    }
    if bias.prefer_lighting
        && matches!(
            video_generation_brief_fragment_axis(fragment),
            "lighting" | "environment" | "sound"
        )
    {
        score += 8;
    }
    if bias.prefer_identity
        && matches!(
            video_generation_brief_fragment_axis(fragment),
            "performance" | "motion" | "camera"
        )
    {
        score += 4;
    }
    if !is_local_framing_only_fragment(fragment) && fragment.starts_with("镜头") {
        score += 2;
    }
    score
}

fn video_generation_brief_fragment_is_low_signal(fragment: &str) -> bool {
    if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
        return selected_style_fragment_is_low_gain_voice(&voice);
    }
    if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
        return selected_style_fragment_is_generic_restrained_mood(&mood);
    }
    if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
        return selected_style_fragment_is_low_gain_motion(&action);
    }
    fragment.starts_with("镜头") && is_local_framing_only_fragment(fragment)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_video_generation_brief_memory_prefers_delivery_emotion_and_skips_low_signal() {
        let style_summary = Some(
            "style=镜头 中景正反打，表演 抬眼停顿后轻轻吸气，语气 轻声，情绪 克制，光影 冷调侧逆光",
        );
        let observation_summary =
            Some("riskTags=lighting/performance/dialogue | avoid=避免表情空白，避免口型僵硬");
        let bias = Some(SelectedVideoMemoryOptimizationBias {
            prefer_delivery: true,
            prefer_emotion: true,
            prefer_lighting: false,
            prefer_identity: false,
        });

        let brief =
            build_video_generation_brief_memory(style_summary, observation_summary, bias).unwrap();

        assert!(brief.contains("抬眼停顿后轻轻吸气"));
        assert!(brief.contains("冷调侧逆光"));
        assert!(!brief.contains("语气轻声"));
        assert!(!brief.contains("情绪克制"));
        assert!(brief.contains("riskTags="));
        assert!(brief.contains("dialogue"));
        assert!(brief.contains("performance"));
    }
}
