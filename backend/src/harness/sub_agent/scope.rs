//! Scope signature: parsing, matching, scoring, and prompt-building for sub-agent memory scoping.

use serde_json::{json, Value};

pub(super) const AUTO_MEMORY_SUMMARY_LIMIT: i64 = 3;
pub(super) const AUTO_MEMORY_FALLBACK_LIMIT: usize = 1;
pub(super) const AUTO_MEMORY_REWORK_LIMIT: usize = 2;
pub(super) const AUTO_MEMORY_KEEP_ROWS: i64 = 8;
pub(super) const AUTO_MEMORY_MAX_CHARS: usize = 320;
pub(super) const AUTO_MEMORY_FETCH_LIMIT: i64 = AUTO_MEMORY_KEEP_ROWS;
pub(super) const REWORK_REASON_MAX_CHARS: usize = 120;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(super) struct ScopeSignature {
    pub(super) storyboard_ids: Vec<i64>,
    pub(super) storyboard_prompt_seeds: Vec<(i64, String)>,
    pub(super) asset_ids: Vec<i64>,
    pub(super) asset_types: Vec<&'static str>,
    pub(super) focus_sections: Vec<&'static str>,
    pub(super) novel_ids: Vec<i64>,
    pub(super) relative_script_offset: Option<i64>,
}

pub(super) fn parse_positive_id_list(arguments: &Value, key: &str) -> Vec<i64> {
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

pub(super) fn parse_asset_type_list(arguments: &Value, key: &str) -> Vec<&'static str> {
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

pub(super) fn parse_focus_section_list(arguments: &Value, key: &str) -> Vec<&'static str> {
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

pub(super) fn parse_relative_script_offset(arguments: &Value, key: &str) -> Option<i64> {
    match arguments.get(key).and_then(Value::as_i64) {
        Some(-1) => Some(-1),
        Some(1) => Some(1),
        _ => None,
    }
}

pub(super) fn parse_storyboard_prompt_seed_scope(scope: Option<&str>) -> Vec<(i64, String)> {
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

pub(super) fn scope_signature_from_args(
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

pub(super) fn parse_scope_signature(content: &str) -> ScopeSignature {
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

pub(super) fn has_scope(signature: &ScopeSignature) -> bool {
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

pub(super) fn scope_has_matching_storyboard_prompt_seed(
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

pub(super) fn scope_has_conflicting_storyboard_prompt_seed(
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

pub(super) fn scope_overlap_score(current: &ScopeSignature, candidate: &ScopeSignature) -> usize {
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

pub(super) fn has_rework_reason(arguments: &Value) -> bool {
    arguments
        .get("reason")
        .and_then(Value::as_str)
        .map(str::trim)
        .is_some_and(|value| !value.is_empty())
}

pub(super) fn select_auto_memory_entries(
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
    rows: Vec<String>,
) -> Vec<String> {
    if rows.is_empty() {
        return rows;
    }
    let current_scope = scope_signature_from_args(arguments, prompt_seed_scope);
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

pub(super) fn compact_auto_memory_entry_for_scope(
    entry: &str,
    current_scope: &ScopeSignature,
) -> String {
    if !has_scope(current_scope) {
        return entry.trim().to_string();
    }
    let candidate_scope = parse_scope_signature(entry);
    let scope_matches_exactly = candidate_scope.storyboard_ids == current_scope.storyboard_ids
        && candidate_scope.storyboard_prompt_seeds == current_scope.storyboard_prompt_seeds
        && candidate_scope.asset_ids == current_scope.asset_ids
        && candidate_scope.asset_types == current_scope.asset_types
        && candidate_scope.focus_sections == current_scope.focus_sections
        && candidate_scope.novel_ids == current_scope.novel_ids
        && candidate_scope.relative_script_offset == current_scope.relative_script_offset;
    if !scope_matches_exactly {
        return entry.trim().to_string();
    }
    let compacted = entry
        .split(" | ")
        .map(str::trim)
        .filter(|segment| {
            !segment.starts_with("scope=")
                && !segment.starts_with("promptSeed=")
                && !segment.starts_with("storyboardPromptSeeds=")
        })
        .collect::<Vec<_>>()
        .join(" | ");
    compact_exact_scope_auto_memory_entry(&compacted)
}

pub(super) fn dedupe_auto_memory_entries(entries: Vec<String>) -> Vec<String> {
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

pub(super) fn normalize_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(super) fn truncate_chars(text: &str, max_chars: usize) -> String {
    if text.chars().count() <= max_chars {
        return text.to_string();
    }
    let truncated = text
        .chars()
        .take(max_chars.saturating_sub(1))
        .collect::<String>();
    format!("{truncated}…")
}

pub(super) fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}

pub(super) fn scope_summary(arguments: &Value) -> Option<String> {
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

pub(super) fn scope_signature_json(
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

pub(super) fn script_scope_note(arguments: &Value) -> Option<String> {
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

pub(super) fn production_scope_note(arguments: &Value) -> Option<String> {
    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    let asset_ids = parse_positive_id_list(arguments, "assetIds");
    let asset_types = parse_asset_type_list(arguments, "assetTypes");
    if storyboard_ids.is_empty() && asset_ids.is_empty() && asset_types.is_empty() {
        return None;
    }
    let mut attrs = Vec::new();
    if !storyboard_ids.is_empty() {
        attrs.push(format!(
            "storyboardIds=\"{}\"",
            storyboard_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if !asset_ids.is_empty() {
        attrs.push(format!(
            "assetIds=\"{}\"",
            asset_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if !asset_types.is_empty() {
        attrs.push(format!("assetTypes=\"{}\"", asset_types.join(",")));
    }
    Some(format!(
        "<scope {} />\n仅限此范围；不足再最小补读。",
        attrs.join(" ")
    ))
}

// ── compact helpers ──────────────────────────────────────────────────────────

fn is_low_signal_auto_memory_result_fragment(fragment: &str) -> bool {
    if fragment.is_empty() {
        return true;
    }
    let normalized = fragment
        .chars()
        .filter(|ch| !ch.is_whitespace())
        .collect::<String>()
        .to_ascii_lowercase();
    matches!(
        normalized.as_str(),
        "完成"
            | "完成了"
            | "执行完成"
            | "本轮执行完成"
            | "已完成"
            | "已生成"
            | "已读取"
            | "已读取flow"
            | "已写入"
            | "已写入工作区"
            | "已同步"
            | "已更新"
            | "已检查"
            | "已核对"
            | "结果"
            | "内容"
            | "工作区"
            | "flow"
            | "分镜"
            | "分镜图"
            | "分镜表"
            | "剧本"
            | "脚本"
            | "提示词"
            | "素材"
            | "资产"
            | "导演规划"
            | "storyboard"
            | "storyboardtable"
            | "script"
            | "scriptplan"
    )
}

fn compact_auto_memory_result_clause_group(fragment: &str) -> String {
    let clauses =
        fragment
            .split(['，', ','])
            .map(|clause| {
                normalize_whitespace(clause.trim_matches(|ch: char| {
                    ch.is_whitespace() || "，,。；;：:!！?？".contains(ch)
                }))
            })
            .filter(|clause| !clause.is_empty())
            .filter(|clause| !is_low_signal_auto_memory_result_fragment(clause))
            .collect::<Vec<_>>();
    if clauses.is_empty() {
        return String::new();
    }
    clauses.join("，")
}

pub(super) fn compact_auto_memory_result_fragment(fragment: &str) -> String {
    let mut compacted = normalize_whitespace(
        fragment.trim_matches(|ch: char| ch.is_whitespace() || "，,。；;：:!！?？".contains(ch)),
    );
    if compacted.is_empty() {
        return compacted;
    }
    for prefix in [
        "本轮执行完成",
        "本轮已完成",
        "执行完成",
        "生成完成",
        "读取完成",
        "写入完成",
        "同步完成",
        "更新完成",
        "检查完成",
        "核对完成",
        "已完成",
        "已生成",
        "已读取 flow",
        "已读取 Flow",
        "已读取",
        "已写入工作区",
        "已写入",
        "已同步",
        "已更新",
        "已检查",
        "已核对",
    ] {
        if let Some(stripped) = compacted.strip_prefix(prefix) {
            compacted =
                normalize_whitespace(stripped.trim_matches(|ch: char| {
                    ch.is_whitespace() || "，,。；;：:!！?？".contains(ch)
                }));
            break;
        }
    }
    compact_auto_memory_result_clause_group(&compacted)
}

fn is_low_signal_auto_memory_summary_fragment(fragment: &str) -> bool {
    let normalized = fragment
        .chars()
        .filter(|ch| !ch.is_whitespace() && !"，,。；;：:!！?？".contains(*ch))
        .collect::<String>()
        .to_ascii_lowercase();
    if normalized.is_empty() {
        return true;
    }
    matches!(
        normalized.as_str(),
        "风格统一"
            | "镜头语言统一"
            | "镜头衔接统一"
            | "画面风格统一"
            | "视觉风格统一"
            | "光影一致"
            | "情绪一致"
            | "情绪延续"
            | "风格延续"
            | "保持一致"
            | "保持统一"
            | "视觉设定延续"
            | "场景设定延续"
            | "道具设定延续"
            | "角色设定延续"
    )
}

fn strip_auto_memory_scaffolding(fragment: &str) -> String {
    let mut compacted = normalize_whitespace(fragment.trim());
    if compacted.is_empty() {
        return compacted;
    }
    for pattern in [
        "当前镜头已确认的",
        "当前分镜已确认的",
        "本镜头已确认的",
        "该镜头已确认的",
        "当前镜头已确认",
        "当前分镜已确认",
        "本镜头已确认",
        "该镜头已确认",
        "当前镜头",
        "当前分镜",
        "本镜头",
        "该镜头",
    ] {
        compacted = compacted.replace(pattern, "");
    }
    let compacted = normalize_whitespace(compacted.trim());
    match compacted.as_str() {
        "" | "已确认" | "镜头已确认" | "分镜已确认" => String::new(),
        _ => compacted,
    }
}

pub(super) fn compact_auto_memory_summary_text(text: &str) -> Option<String> {
    let compacted = text
        .split('，')
        .map(strip_auto_memory_scaffolding)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| !is_low_signal_auto_memory_summary_fragment(fragment))
        .collect::<Vec<_>>()
        .join("，");
    let compacted = normalize_whitespace(compacted.trim());
    (!compacted.is_empty()).then_some(truncate_chars(&compacted, AUTO_MEMORY_MAX_CHARS))
}

pub(super) fn compact_auto_memory_review_text(review: &str) -> Option<String> {
    let summary = review
        .split(';')
        .map(str::trim)
        .find_map(|part| part.strip_prefix("summary="))
        .and_then(compact_auto_memory_summary_text);
    if summary.is_some() {
        return summary;
    }
    let target = review
        .split(';')
        .map(str::trim)
        .find_map(|part| part.strip_prefix("target="))
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let next = review
        .split(';')
        .map(str::trim)
        .find_map(|part| part.strip_prefix("next="))
        .map(str::trim)
        .filter(|value| !value.is_empty());
    match (target, next) {
        (Some(target), Some(next)) => Some(format!("{target} {next}")),
        (Some(target), None) => Some(target.to_string()),
        (None, Some(next)) => Some(next.to_string()),
        (None, None) => None,
    }
}

pub(super) fn compact_auto_memory_tool_alias(tool_name: &str) -> &str {
    match tool_name {
        "run_sub_agent_storyboard_panel" => "panel",
        "run_sub_agent_storyboard_gen" => "storyboard",
        "run_sub_agent_production_supervision" => "supervision",
        "run_sub_agent_director_plan" => "director",
        "run_sub_agent_storyboard_table" => "storyboard-table",
        "run_sub_agent_generate_assets" => "asset-image",
        "run_sub_agent_derive_assets" => "assets",
        "run_sub_agent_storySkeleton" => "story-skeleton",
        "run_sub_agent_adaptationStrategy" => "adaptation",
        "run_sub_agent_script" => "script",
        "run_supervision_agent" => "supervision",
        _ => tool_name,
    }
}

pub(super) fn compact_exact_scope_auto_memory_entry(entry: &str) -> String {
    let mut tool_alias = None;
    let mut summary = None;
    let mut review = None;
    let mut fallback_segments = Vec::new();
    for segment in entry.split(" | ").map(str::trim).filter(|s| !s.is_empty()) {
        if let Some(value) = segment.strip_prefix("tool=") {
            tool_alias = Some(compact_auto_memory_tool_alias(value));
            continue;
        }
        if let Some(value) = segment.strip_prefix("summary=") {
            summary = compact_auto_memory_summary_text(value);
            continue;
        }
        if let Some(value) = segment.strip_prefix("result=") {
            summary = compact_auto_memory_summary_text(value);
            continue;
        }
        if let Some(value) = segment.strip_prefix("review=") {
            review = compact_auto_memory_review_text(value);
            continue;
        }
        fallback_segments.push(segment.to_string());
    }
    let headline = summary.or(review);
    match (tool_alias, headline) {
        (Some(tool_alias), Some(headline)) => format!("{tool_alias}: {headline}"),
        (None, Some(headline)) => headline,
        (Some(tool_alias), None) if fallback_segments.is_empty() => tool_alias.to_string(),
        _ => entry.trim().to_string(),
    }
}

pub(super) fn summarize_result_excerpt(text: &str) -> Option<String> {
    let normalized = normalize_whitespace(text);
    if normalized.is_empty() {
        return None;
    }
    let compacted = normalized
        .split(['。', '！', '？', '；'])
        .map(compact_auto_memory_result_fragment)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>()
        .join("，");
    let compacted = normalize_whitespace(compacted.trim());
    (!compacted.is_empty()).then(|| truncate_chars(&compacted, 180))
}

pub(super) fn infer_rework_goal(reason: &str) -> &'static str {
    if contains_any(reason, &["穿帮", "串脸", "长相", "服装", "身份", "视线"]) {
        "修正人物一致性与镜头连续性"
    } else if contains_any(reason, &["情绪", "朗读", "台词", "表演", "没情绪"]) {
        "补强情绪表达与台词表演"
    } else if contains_any(reason, &["节奏", "重复", "动作", "平"]) {
        "打破重复动作并拉开镜头节奏"
    } else if contains_any(reason, &["格式", "字段", "缺失", "编号"]) {
        "完成结构修复并补齐缺失字段"
    } else {
        "只修当前失败点，不重写无关内容"
    }
}

pub(super) fn compact_rework_reason(reason: &str) -> Option<String> {
    let compact = truncate_chars(&normalize_whitespace(reason), REWORK_REASON_MAX_CHARS);
    (!compact.is_empty()).then_some(compact)
}

pub(super) fn build_rework_context_note(arguments: &Value) -> Option<String> {
    let reason = arguments.get("reason").and_then(Value::as_str)?;
    let reason = compact_rework_reason(reason)?;
    let goal = infer_rework_goal(&reason);
    let scope = scope_summary(arguments).unwrap_or_else(|| "只读当前对象的局部上下文".to_string());
    Some(format!(
        "Repair brief: failure_reason={reason}; fix_goal={goal}; local_scope={scope}. 只围绕这个范围补读与修复，不要把整个项目上下文重新拉满。"
    ))
}
