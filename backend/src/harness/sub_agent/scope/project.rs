//! Project scope construction and matching logic.

use serde_json::{json, Value};

use super::{
    parse_asset_type_list, parse_focus_section_list, parse_positive_id_list,
    parse_relative_script_offset, parse_storyboard_prompt_seed_scope, ScopeSignature,
    AUTO_MEMORY_FALLBACK_LIMIT, AUTO_MEMORY_REWORK_LIMIT, AUTO_MEMORY_SUMMARY_LIMIT,
};

fn parse_scope_list(segment: Option<&str>) -> Vec<i64> {
    let mut values = segment
        .unwrap_or_default()
        .split(',')
        .filter_map(|value| value.trim().parse::<i64>().ok())
        .filter(|value| *value > 0)
        .collect::<Vec<_>>();
    values.sort_unstable();
    values.dedup();
    values
}

fn parse_scope_enum_list<T: Ord>(
    segment: Option<&str>,
    normalize: impl Fn(&str) -> Option<T>,
) -> Vec<T> {
    let mut values = segment
        .unwrap_or_default()
        .split(',')
        .filter_map(|value| normalize(value.trim()))
        .collect::<Vec<_>>();
    values.sort_unstable();
    values.dedup();
    values
}

pub(in crate::harness::sub_agent) fn parse_scope_signature(content: &str) -> ScopeSignature {
    let mut signature = ScopeSignature::default();
    for segment in content.split(" | ") {
        if let Some(scope_segment) = segment.strip_prefix("scope=") {
            for entry in scope_segment.split("; ") {
                let Some((key, value)) = entry.split_once('=') else {
                    continue;
                };
                match key {
                    "storyboardIds" => signature.storyboard_ids = parse_scope_list(Some(value)),
                    "assetIds" => signature.asset_ids = parse_scope_list(Some(value)),
                    "assetTypes" => {
                        signature.asset_types = parse_scope_enum_list(Some(value), |raw| match raw
                            .to_ascii_lowercase()
                            .as_str()
                        {
                            "role" => Some("role"),
                            "scene" => Some("scene"),
                            "tool" => Some("tool"),
                            _ => None,
                        })
                    }
                    "focusSections" => {
                        signature.focus_sections =
                            parse_scope_enum_list(Some(value), |raw| match raw {
                                "storySkeleton" => Some("storySkeleton"),
                                "adaptationStrategy" => Some("adaptationStrategy"),
                                "script" => Some("script"),
                                _ => None,
                            })
                    }
                    "novelIds" => signature.novel_ids = parse_scope_list(Some(value)),
                    "relativeScriptOffset" => {
                        signature.relative_script_offset =
                            value.parse::<i64>().ok().filter(|v| *v != 0)
                    }
                    _ => {}
                }
            }
            continue;
        }
        if let Some(prompt_seed_segment) = segment.strip_prefix("promptSeed=") {
            let prompt_seed = prompt_seed_segment.trim();
            if let Some(storyboard_id) = signature.storyboard_ids.first().copied() {
                if !prompt_seed.is_empty() {
                    signature
                        .storyboard_prompt_seeds
                        .push((storyboard_id, prompt_seed.to_string()));
                }
            }
            continue;
        }
        if segment.starts_with("storyboardPromptSeeds=") {
            signature.storyboard_prompt_seeds = parse_storyboard_prompt_seed_scope(Some(segment));
        }
    }
    signature
}

pub(in crate::harness::sub_agent) fn has_scope(signature: &ScopeSignature) -> bool {
    !signature.storyboard_ids.is_empty()
        || !signature.storyboard_prompt_seeds.is_empty()
        || !signature.asset_ids.is_empty()
        || !signature.asset_types.is_empty()
        || !signature.focus_sections.is_empty()
        || !signature.novel_ids.is_empty()
        || signature.relative_script_offset.is_some()
}

fn overlap_count<T: Eq>(current: &[T], candidate: &[T]) -> usize {
    current
        .iter()
        .filter(|value| candidate.iter().any(|other| other == *value))
        .count()
}

fn prompt_seed_overlap_score(current: &ScopeSignature, candidate: &ScopeSignature) -> usize {
    current
        .storyboard_prompt_seeds
        .iter()
        .filter(|(storyboard_id, prompt_seed)| {
            candidate.storyboard_prompt_seeds.iter().any(
                |(candidate_storyboard_id, candidate_prompt_seed)| {
                    candidate_storyboard_id == storyboard_id && candidate_prompt_seed == prompt_seed
                },
            )
        })
        .count()
}

pub(in crate::harness::sub_agent) fn scope_has_matching_storyboard_prompt_seed(
    scope: &ScopeSignature,
    storyboard_id: i64,
    prompt_seed: &str,
) -> bool {
    scope
        .storyboard_prompt_seeds
        .iter()
        .any(|(candidate_storyboard_id, candidate_prompt_seed)| {
            *candidate_storyboard_id == storyboard_id && candidate_prompt_seed == prompt_seed
        })
}

pub(in crate::harness::sub_agent) fn scope_has_conflicting_storyboard_prompt_seed(
    current: &ScopeSignature,
    candidate: &ScopeSignature,
) -> bool {
    candidate
        .storyboard_prompt_seeds
        .iter()
        .any(|(storyboard_id, candidate_prompt_seed)| {
            current.storyboard_prompt_seeds.iter().any(
                |(current_storyboard_id, current_prompt_seed)| {
                    current_storyboard_id == storyboard_id
                        && current_prompt_seed != candidate_prompt_seed
                },
            )
        })
}

pub(in crate::harness::sub_agent) fn scope_overlap_score(
    current: &ScopeSignature,
    candidate: &ScopeSignature,
) -> usize {
    let mut score = 0;
    score += prompt_seed_overlap_score(current, candidate) * 16;
    score += overlap_count(&current.storyboard_ids, &candidate.storyboard_ids) * 8;
    score += overlap_count(&current.asset_ids, &candidate.asset_ids) * 5;
    score += overlap_count(&current.asset_types, &candidate.asset_types) * 3;
    score += overlap_count(&current.focus_sections, &candidate.focus_sections) * 3;
    score += overlap_count(&current.novel_ids, &candidate.novel_ids) * 2;
    if current.relative_script_offset.is_some()
        && current.relative_script_offset == candidate.relative_script_offset
    {
        score += 1;
    }
    score
}

pub(in crate::harness::sub_agent) fn has_rework_reason(arguments: &Value) -> bool {
    arguments
        .get("reworkReason")
        .or_else(|| arguments.get("reason"))
        .and_then(Value::as_str)
        .map(str::trim)
        .is_some_and(|value| !value.is_empty())
}

pub(in crate::harness::sub_agent) fn select_auto_memory_entries(
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
    rows: Vec<String>,
) -> Vec<String> {
    if rows.is_empty() {
        return rows;
    }
    let current_scope = super::scope_signature_from_args(arguments, prompt_seed_scope);
    let rework_mode = has_rework_reason(arguments);
    if !has_scope(&current_scope) {
        return rows
            .into_iter()
            .take(if rework_mode {
                AUTO_MEMORY_REWORK_LIMIT.min(AUTO_MEMORY_FALLBACK_LIMIT.max(1))
            } else {
                AUTO_MEMORY_FALLBACK_LIMIT
            })
            .collect();
    }
    let mut scored = rows
        .into_iter()
        .enumerate()
        .map(|(index, row)| {
            let candidate_scope = parse_scope_signature(&row);
            (
                scope_overlap_score(&current_scope, &candidate_scope),
                index,
                candidate_scope,
                row,
            )
        })
        .collect::<Vec<_>>();
    let matched_count = scored.iter().filter(|(score, _, _, _)| *score > 0).count();
    if matched_count == 0 {
        return scored
            .into_iter()
            .map(|(_, _, _, row)| row)
            .take(if rework_mode {
                AUTO_MEMORY_REWORK_LIMIT.min(AUTO_MEMORY_FALLBACK_LIMIT.max(1))
            } else {
                AUTO_MEMORY_FALLBACK_LIMIT
            })
            .collect();
    }
    let has_matching_prompt_seed_storyboards = current_scope
        .storyboard_prompt_seeds
        .iter()
        .filter(|(storyboard_id, prompt_seed)| {
            scored.iter().any(|(_, _, candidate_scope, _)| {
                scope_has_matching_storyboard_prompt_seed(
                    candidate_scope,
                    *storyboard_id,
                    prompt_seed,
                )
            })
        })
        .map(|(storyboard_id, _)| *storyboard_id)
        .collect::<Vec<_>>();
    scored.sort_by(|l, r| r.0.cmp(&l.0).then(l.1.cmp(&r.1)));
    scored
        .into_iter()
        .filter(|(score, _, candidate_scope, _)| {
            if *score == 0 {
                return false;
            }
            if has_matching_prompt_seed_storyboards.is_empty() {
                return true;
            }
            if !scope_has_conflicting_storyboard_prompt_seed(&current_scope, candidate_scope) {
                return true;
            }
            !candidate_scope
                .storyboard_prompt_seeds
                .iter()
                .any(|(storyboard_id, _)| {
                    has_matching_prompt_seed_storyboards.contains(storyboard_id)
                })
        })
        .take(if rework_mode {
            AUTO_MEMORY_REWORK_LIMIT
        } else {
            AUTO_MEMORY_SUMMARY_LIMIT as usize
        })
        .map(|(_, _, _, row)| row)
        .collect()
}

pub(in crate::harness::sub_agent) fn dedupe_auto_memory_entries(
    entries: Vec<String>,
) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    let mut deduped = Vec::with_capacity(entries.len());
    for entry in entries {
        let normalized = entry.trim();
        if normalized.is_empty() || !seen.insert(normalized.to_string()) {
            continue;
        }
        deduped.push(normalized.to_string());
    }
    deduped
}

pub(in crate::harness::sub_agent) fn scope_summary(arguments: &Value) -> Option<String> {
    let mut parts = Vec::new();
    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    if !storyboard_ids.is_empty() {
        parts.push(format!(
            "storyboardIds={}",
            storyboard_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    let asset_ids = parse_positive_id_list(arguments, "assetIds");
    if !asset_ids.is_empty() {
        parts.push(format!(
            "assetIds={}",
            asset_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    let asset_types = parse_asset_type_list(arguments, "assetTypes");
    if !asset_types.is_empty() {
        parts.push(format!("assetTypes={}", asset_types.join(",")));
    }
    let focus_sections = parse_focus_section_list(arguments, "focusSections");
    if !focus_sections.is_empty() {
        parts.push(format!("focusSections={}", focus_sections.join(",")));
    }
    let novel_ids = parse_positive_id_list(arguments, "novelIds");
    if !novel_ids.is_empty() {
        parts.push(format!(
            "novelIds={}",
            novel_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if let Some(offset) = parse_relative_script_offset(arguments, "relativeScriptOffset") {
        parts.push(format!("relativeScriptOffset={offset}"));
    }
    if parts.is_empty() {
        None
    } else {
        Some(parts.join("; "))
    }
}

pub(in crate::harness::sub_agent) fn scope_signature_json(
    episode_id: Option<i32>,
    signature: &ScopeSignature,
) -> Option<Value> {
    let mut map = serde_json::Map::new();
    if let Some(episode_id) = episode_id.filter(|value| *value > 0) {
        map.insert("episodeId".to_string(), json!(episode_id));
    }
    if !signature.storyboard_ids.is_empty() {
        map.insert("storyboardIds".to_string(), json!(signature.storyboard_ids));
    }
    if !signature.asset_ids.is_empty() {
        map.insert("assetIds".to_string(), json!(signature.asset_ids));
    }
    if !signature.asset_types.is_empty() {
        map.insert("assetTypes".to_string(), json!(signature.asset_types));
    }
    if !signature.focus_sections.is_empty() {
        map.insert("focusSections".to_string(), json!(signature.focus_sections));
    }
    if !signature.novel_ids.is_empty() {
        map.insert("novelIds".to_string(), json!(signature.novel_ids));
    }
    if let Some(offset) = signature.relative_script_offset {
        map.insert("relativeScriptOffset".to_string(), json!(offset));
    }
    (!map.is_empty()).then_some(Value::Object(map))
}
