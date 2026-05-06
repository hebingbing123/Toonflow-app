//! Scope signature: parsing, matching, scoring, and prompt-building for sub-agent memory scoping.

use serde_json::Value;

mod production;
mod project;

pub(in crate::harness::sub_agent) use production::*;
pub(in crate::harness::sub_agent) use project::*;

pub(in crate::harness::sub_agent) const AUTO_MEMORY_SUMMARY_LIMIT: i64 = 3;
pub(in crate::harness::sub_agent) const AUTO_MEMORY_FALLBACK_LIMIT: usize = 1;
pub(in crate::harness::sub_agent) const AUTO_MEMORY_REWORK_LIMIT: usize = 2;
pub(in crate::harness::sub_agent) const AUTO_MEMORY_KEEP_ROWS: i64 = 8;
pub(in crate::harness::sub_agent) const AUTO_MEMORY_MAX_CHARS: usize = 320;
pub(in crate::harness::sub_agent) const AUTO_MEMORY_FETCH_LIMIT: i64 = AUTO_MEMORY_KEEP_ROWS;
pub(in crate::harness::sub_agent) const REWORK_REASON_MAX_CHARS: usize = 120;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(in crate::harness::sub_agent) struct ScopeSignature {
    pub(in crate::harness::sub_agent) storyboard_ids: Vec<i64>,
    pub(in crate::harness::sub_agent) storyboard_prompt_seeds: Vec<(i64, String)>,
    pub(in crate::harness::sub_agent) asset_ids: Vec<i64>,
    pub(in crate::harness::sub_agent) asset_types: Vec<&'static str>,
    pub(in crate::harness::sub_agent) focus_sections: Vec<&'static str>,
    pub(in crate::harness::sub_agent) novel_ids: Vec<i64>,
    pub(in crate::harness::sub_agent) relative_script_offset: Option<i64>,
}

pub(in crate::harness::sub_agent) fn parse_positive_id_list(
    arguments: &Value,
    key: &str,
) -> Vec<i64> {
    let mut ids = arguments
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_i64)
        .filter(|id| *id > 0)
        .collect::<Vec<_>>();
    ids.sort_unstable();
    ids.dedup();
    ids
}

pub(in crate::harness::sub_agent) fn parse_asset_type_list(
    arguments: &Value,
    key: &str,
) -> Vec<&'static str> {
    let mut types = arguments
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .filter_map(|value| match value.trim().to_ascii_lowercase().as_str() {
            "role" => Some("role"),
            "scene" => Some("scene"),
            "tool" => Some("tool"),
            _ => None,
        })
        .collect::<Vec<_>>();
    types.sort_unstable();
    types.dedup();
    types
}

pub(in crate::harness::sub_agent) fn parse_focus_section_list(
    arguments: &Value,
    key: &str,
) -> Vec<&'static str> {
    let mut sections = arguments
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .filter_map(|value| match value.trim() {
            "storySkeleton" => Some("storySkeleton"),
            "adaptationStrategy" => Some("adaptationStrategy"),
            "script" => Some("script"),
            _ => None,
        })
        .collect::<Vec<_>>();
    sections.sort_unstable();
    sections.dedup();
    sections
}

pub(in crate::harness::sub_agent) fn parse_relative_script_offset(
    arguments: &Value,
    key: &str,
) -> Option<i64> {
    match arguments.get(key).and_then(Value::as_i64) {
        Some(-1) => Some(-1),
        Some(1) => Some(1),
        _ => None,
    }
}

pub(in crate::harness::sub_agent) fn parse_storyboard_prompt_seed_scope(
    scope: Option<&str>,
) -> Vec<(i64, String)> {
    let Some(scope) = scope.map(str::trim).filter(|value| !value.is_empty()) else {
        return Vec::new();
    };
    if let Some(prompt_seed) = scope.strip_prefix("promptSeed=") {
        let prompt_seed = prompt_seed.trim();
        return if !prompt_seed.is_empty() {
            vec![(0_i64, prompt_seed.to_string())]
        } else {
            Vec::new()
        };
    }
    let Some(mapped) = scope.strip_prefix("storyboardPromptSeeds=") else {
        return Vec::new();
    };
    let mut seeds = mapped
        .split(',')
        .filter_map(|entry| {
            let (storyboard_id, prompt_seed) = entry.trim().split_once(':')?;
            let storyboard_id = storyboard_id.trim().parse::<i64>().ok()?;
            let prompt_seed = prompt_seed.trim();
            (storyboard_id > 0 && !prompt_seed.is_empty())
                .then(|| (storyboard_id, prompt_seed.to_string()))
        })
        .collect::<Vec<_>>();
    seeds.sort_by(|l, r| l.0.cmp(&r.0).then(l.1.cmp(&r.1)));
    seeds.dedup();
    seeds
}

pub(in crate::harness::sub_agent) fn scope_signature_from_args(
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
) -> ScopeSignature {
    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    let mut storyboard_prompt_seeds = parse_storyboard_prompt_seed_scope(prompt_seed_scope);
    if storyboard_ids.len() == 1
        && storyboard_prompt_seeds.len() == 1
        && storyboard_prompt_seeds[0].0 == 0
    {
        storyboard_prompt_seeds[0].0 = storyboard_ids[0];
    }
    ScopeSignature {
        storyboard_ids,
        storyboard_prompt_seeds,
        asset_ids: parse_positive_id_list(arguments, "assetIds"),
        asset_types: parse_asset_type_list(arguments, "assetTypes"),
        focus_sections: parse_focus_section_list(arguments, "focusSections"),
        novel_ids: parse_positive_id_list(arguments, "novelIds"),
        relative_script_offset: parse_relative_script_offset(arguments, "relativeScriptOffset"),
    }
}

pub(in crate::harness::sub_agent) fn normalize_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(in crate::harness::sub_agent) fn truncate_chars(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }
    let truncated = text
        .chars()
        .take(max_chars.saturating_sub(1))
        .collect::<String>();
    format!("{truncated}…")
}

pub(in crate::harness::sub_agent) fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

pub(in crate::harness::sub_agent) fn script_scope_note(arguments: &Value) -> Option<String> {
    let focus_sections = parse_focus_section_list(arguments, "focusSections");
    let novel_ids = parse_positive_id_list(arguments, "novelIds");
    let relative_script_offset = parse_relative_script_offset(arguments, "relativeScriptOffset");
    if focus_sections.is_empty() && novel_ids.is_empty() && relative_script_offset.is_none() {
        return None;
    }
    let mut attrs = Vec::new();
    if !focus_sections.is_empty() {
        attrs.push(format!("focusSections=\"{}\"", focus_sections.join(",")));
    }
    if !novel_ids.is_empty() {
        attrs.push(format!(
            "novelIds=\"{}\"",
            novel_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if let Some(offset) = relative_script_offset {
        attrs.push(format!("relativeScriptOffset=\"{offset}\""));
    }
    Some(format!(
        "<scope {} />\n仅限此范围；不足再最小补读。",
        attrs.join(" ")
    ))
}
