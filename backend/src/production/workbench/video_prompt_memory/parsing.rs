//! Parsing and extraction utilities for video prompt memory.

use super::types::StructuredStoryboardDescription;

/// Normalize prompt text by collapsing whitespace
pub(crate) fn normalize_prompt_text(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Clip prompt fragment to maximum character count
pub(crate) fn clip_prompt_fragment(text: &str, max_chars: usize) -> String {
    let normalized = normalize_prompt_text(text);
    let mut chars = normalized.chars();
    let clipped = chars.by_ref().take(max_chars).collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}

/// Parse structured storyboard description from text
///
/// Expected format: (subject、setting、subject_refs、duration、shot、camera_move、action、mood、lighting、dialogue、sound)
pub(crate) fn parse_structured_storyboard_description(
    description: &str,
) -> Option<StructuredStoryboardDescription> {
    let normalized = description
        .trim()
        .trim_start_matches(['（', '('])
        .trim_end_matches(['）', ')'])
        .trim();
    if normalized.is_empty() {
        return None;
    }
    let parts = normalized
        .split('、')
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>();
    if parts.len() < 8 {
        return None;
    }
    Some(StructuredStoryboardDescription {
        subject: parts.first().cloned().unwrap_or_default(),
        setting: parts.get(1).cloned().unwrap_or_default(),
        subject_refs: parts.get(2).cloned().unwrap_or_default(),
        duration_seconds: parts.get(3).and_then(|value| parse_positive_int(value)),
        shot: parts.get(4).cloned().unwrap_or_default(),
        camera_move: parts.get(5).cloned().unwrap_or_default(),
        action: parts.get(6).cloned().unwrap_or_default(),
        mood: parts.get(7).cloned().unwrap_or_default(),
        lighting: parts.get(8).cloned().unwrap_or_default(),
        dialogue: parts.get(9).cloned().unwrap_or_default(),
        sound: parts.get(10).cloned().unwrap_or_default(),
    })
}

/// Parse positive integer from text, extracting first sequence of digits
pub(crate) fn parse_positive_int(text: &str) -> Option<i32> {
    let mut digits = String::new();
    for ch in text.chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if !digits.is_empty() {
            break;
        }
    }
    digits.parse::<i32>().ok().filter(|value| *value > 0)
}

/// Extract key-value pair from memory content string
///
/// Format: "key=value | " or "key=value; "
pub(crate) fn extract_key_value(row: &str, key: &str) -> Option<String> {
    let marker = format!("{key}=");
    let start = row.find(&marker)? + marker.len();
    let rest = &row[start..];
    let end = rest
        .find(" | ")
        .or_else(|| rest.find("; "))
        .unwrap_or(rest.len());
    let value = normalize_prompt_text(rest[..end].trim());
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

/// Extract rejected video risk tags from memory content
pub(super) fn extract_rejected_video_risk_tags(content: &str) -> Vec<String> {
    extract_key_value(content, "riskTags")
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

/// Extract storyboard IDs from memory content
pub(super) fn extract_storyboard_ids(content: &str) -> Vec<i32> {
    extract_key_value(content, "storyboardIds")
        .map(|raw| {
            raw.split([',', '，'])
                .filter_map(|part| parse_positive_int(part.trim()))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}
