//! Production and storyboard scope construction logic with auto-memory compaction.

use serde_json::Value;

use super::{
    contains_any, normalize_whitespace, parse_asset_type_list, parse_positive_id_list,
    truncate_chars, ScopeSignature, AUTO_MEMORY_MAX_CHARS, REWORK_REASON_MAX_CHARS,
};

pub(in crate::harness::sub_agent) fn production_scope_note(arguments: &Value) -> Option<String> {
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

pub(in crate::harness::sub_agent) fn compact_auto_memory_entry_for_scope(
    entry: &str,
    current_scope: &ScopeSignature,
) -> String {
    use super::project::has_scope;
    if !has_scope(current_scope) {
        return entry.trim().to_string();
    }
    let candidate_scope = super::project::parse_scope_signature(entry);
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

pub(in crate::harness::sub_agent) fn compact_auto_memory_result_fragment(fragment: &str) -> String {
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

pub(in crate::harness::sub_agent) fn compact_auto_memory_summary_text(
    text: &str,
) -> Option<String> {
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

pub(in crate::harness::sub_agent) fn compact_auto_memory_review_text(
    review: &str,
) -> Option<String> {
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

pub(in crate::harness::sub_agent) fn compact_auto_memory_tool_alias(tool_name: &str) -> &str {
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

pub(in crate::harness::sub_agent) fn compact_exact_scope_auto_memory_entry(entry: &str) -> String {
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

pub(in crate::harness::sub_agent) fn summarize_result_excerpt(text: &str) -> Option<String> {
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

pub(in crate::harness::sub_agent) fn infer_rework_goal(reason: &str) -> &'static str {
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

pub(in crate::harness::sub_agent) fn compact_rework_reason(reason: &str) -> Option<String> {
    let compact = truncate_chars(&normalize_whitespace(reason), REWORK_REASON_MAX_CHARS);
    (!compact.is_empty()).then_some(compact)
}

pub(in crate::harness::sub_agent) fn build_rework_context_note(
    arguments: &Value,
) -> Option<String> {
    let reason = arguments.get("reason").and_then(Value::as_str)?;
    let reason = compact_rework_reason(reason)?;
    let goal = infer_rework_goal(&reason);
    let scope = super::project::scope_summary(arguments)
        .unwrap_or_else(|| "只读当前对象的局部上下文".to_string());
    Some(format!(
        "Repair brief: failure_reason={reason}; fix_goal={goal}; local_scope={scope}. 只围绕这个范围补读与修复，不要把整个项目上下文重新拉满。"
    ))
}
