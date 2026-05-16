//! Prompt builder and diagnostics logic.

use super::super::builder_parts::coverage::{
    fragment_mostly_repeats_prompt_mood, trim_fragment_by_exact_field_overlap,
};
use super::super::*;
use super::*;

#[derive(Debug, Clone, Copy)]
pub enum ScriptAssetAnchorKind {
    Role,
    Scene,
    Tool,
}

pub struct ScriptAssetPromptAnchor {
    pub asset_type: String,
    pub value: String,
}

pub fn build_script_role_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_role_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let subject = structured_fields
        .map(|fields| normalize_prompt_text(&fields.subject))
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let subject_refs = structured_fields
        .map(structured_subject_ref_names)
        .unwrap_or_default();
    let role_anchor_limit = if subject_refs.len() > 1
        && structured_fields.is_some_and(video_prompt_scene_supports_multi_role_anchors)
    {
        VIDEO_PROMPT_MULTI_ROLE_ANCHOR_LIMIT.min(subject_refs.len())
    } else {
        1
    };
    let mut scored = Vec::new();
    for (idx, anchor) in ctx.script_role_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Role,
        ) else {
            continue;
        };
        let score = score_script_asset_anchor(&name, &description, &subject, &action)
            + score_subject_ref_match(&name, &subject_refs);
        if name.is_empty() || score <= 0 {
            continue;
        }
        scored.push((score, idx, anchor));
    }
    select_script_asset_anchors(scored, role_anchor_limit)
}

pub fn build_script_scene_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_scene_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let setting = structured_fields
        .map(|fields| normalize_prompt_text(&fields.setting))
        .unwrap_or_default();
    let setting_refs = structured_fields
        .map(structured_setting_ref_names)
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let mut scored = Vec::new();
    let mut directly_referenced_anchor_names = Vec::new();
    for (idx, anchor) in ctx.script_scene_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Scene,
        ) else {
            continue;
        };
        let ref_match_score =
            score_scene_ref_match(&name, &description, &setting, &setting_refs, &action);
        let score =
            score_script_asset_anchor(&name, &description, &setting, &action) + ref_match_score;
        if name.is_empty() || score <= 0 {
            continue;
        }
        if ref_match_score > 0 {
            directly_referenced_anchor_names.push(name.clone());
        }
        scored.push((score, idx, anchor));
    }
    let allows_multi_scene_anchors = directly_referenced_anchor_names.len() > 1
        && directly_referenced_anchor_names
            .iter()
            .filter(|name| !scene_anchor_name_is_generic_location(name))
            .count()
            > 1;
    let scene_anchor_limit = if allows_multi_scene_anchors {
        VIDEO_PROMPT_MULTI_SCENE_ANCHOR_LIMIT.min(directly_referenced_anchor_names.len())
    } else {
        1
    };
    select_script_asset_anchors(scored, scene_anchor_limit)
}

pub fn build_script_tool_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_tool_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let subject = structured_fields
        .map(|fields| normalize_prompt_text(&fields.subject))
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let subject_refs = structured_fields
        .map(structured_subject_ref_names)
        .unwrap_or_default();
    let mut scored = Vec::new();
    let mut directly_referenced_anchor_count = 0usize;
    for (idx, anchor) in ctx.script_tool_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Tool,
        ) else {
            continue;
        };
        let ref_match_score = score_subject_ref_match(&name, &subject_refs);
        let score =
            score_script_asset_anchor(&name, &description, &subject, &action) + ref_match_score;
        if name.is_empty() || score <= 0 {
            continue;
        }
        if ref_match_score > 0 {
            directly_referenced_anchor_count += 1;
        }
        scored.push((score, idx, anchor));
    }
    let tool_anchor_limit = if directly_referenced_anchor_count > 1 {
        VIDEO_PROMPT_MULTI_TOOL_ANCHOR_LIMIT.min(directly_referenced_anchor_count)
    } else {
        1
    };
    select_script_asset_anchors(scored, tool_anchor_limit)
}

pub fn score_script_asset_anchor(
    name: &str,
    description: &str,
    primary: &str,
    secondary: &str,
) -> i32 {
    if name.is_empty() {
        return 0;
    }
    let mut score = 0;
    let primary_head = primary
        .split(['/', '／', '、', '，', ',', ' '])
        .map(normalize_prompt_text)
        .find(|part| !part.is_empty());
    if primary_head.as_deref() == Some(name) {
        score += 160;
    }
    if !primary.is_empty() && primary == name {
        score += 120;
    } else if !primary.is_empty() && (primary.contains(name) || name.contains(primary)) {
        score += 96;
        if primary.starts_with(name) {
            score += 96;
        }
        if let Some(idx) = primary.find(name) {
            score += 24 - idx.min(24) as i32;
        }
    }
    if !secondary.is_empty() && secondary.contains(name) {
        score += 48;
        if let Some(idx) = secondary.find(name) {
            score += 12 - idx.min(12) as i32;
        }
    }
    if !description.is_empty() && description.contains(name) {
        score += 36;
        if let Some(idx) = description.find(name) {
            score += 8 - idx.min(8) as i32;
        }
    }
    score - name.chars().count() as i32
}

pub fn score_subject_ref_match(name: &str, subject_refs: &[String]) -> i32 {
    if name.is_empty() {
        return 0;
    }

    subject_refs
        .iter()
        .enumerate()
        .find_map(|(idx, subject_ref)| {
            (subject_ref == name || subject_ref.contains(name) || name.contains(subject_ref))
                .then_some(220 - (idx.min(4) as i32 * 8))
        })
        .unwrap_or(0)
}

pub fn score_scene_ref_match(
    name: &str,
    description: &str,
    setting: &str,
    setting_refs: &[String],
    action: &str,
) -> i32 {
    if name.is_empty() {
        return 0;
    }

    let mut best = setting_refs
        .iter()
        .enumerate()
        .find_map(|(idx, setting_ref)| {
            (setting_ref == name || setting_ref.contains(name) || name.contains(setting_ref))
                .then_some(220 - (idx.min(4) as i32 * 8))
        })
        .unwrap_or(0);
    for suffix in scene_anchor_suffix_candidates(name) {
        let Some(prefix) = name.strip_suffix(&suffix).map(normalize_prompt_text) else {
            continue;
        };
        let prefix_matches_context = !prefix.is_empty()
            && [description, setting, action]
                .into_iter()
                .any(|field| field.contains(&prefix));
        if !prefix_matches_context {
            continue;
        }
        if setting.contains(&suffix) {
            best = best.max(120 - suffix.chars().count() as i32);
        }
        if action.contains(&suffix) {
            best = best.max(72 - suffix.chars().count() as i32);
        }
        if description.contains(&suffix) {
            best = best.max(48 - suffix.chars().count() as i32);
        }
    }
    best
}

pub fn scene_anchor_suffix_candidates(name: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(name);
    if normalized.chars().count() < 4 {
        return Vec::new();
    }

    let chars = normalized.chars().collect::<Vec<_>>();
    let mut suffixes = Vec::new();
    for len in 2..=4 {
        if chars.len() <= len {
            continue;
        }
        let suffix = chars[chars.len() - len..].iter().collect::<String>();
        if scene_anchor_suffix_looks_specific(&suffix)
            && !suffixes.iter().any(|existing| existing == &suffix)
        {
            suffixes.push(suffix);
        }
    }
    suffixes
}

pub fn scene_anchor_suffix_looks_specific(suffix: &str) -> bool {
    !suffix.is_empty()
        && [
            "门厅", "走廊", "街口", "巷口", "门口", "楼梯", "楼道", "雨巷", "包间", "车内", "车门",
            "客厅", "卧室", "仓库", "天台", "屋顶", "尽头",
        ]
        .iter()
        .any(|keyword| suffix.ends_with(keyword))
}

pub fn structured_subject_ref_names(fields: &StructuredStoryboardDescription) -> Vec<String> {
    fields
        .subject_refs
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut refs, value| {
            if !refs.iter().any(|existing| existing == &value) {
                refs.push(value);
            }
            refs
        })
}

pub fn structured_setting_ref_names(fields: &StructuredStoryboardDescription) -> Vec<String> {
    fields
        .setting
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut refs, value| {
            if !refs.iter().any(|existing| existing == &value) {
                refs.push(value);
            }
            refs
        })
}

fn video_prompt_scene_supports_multi_role_anchors(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.subject.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
        fields.mood.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "两人", "二人", "对峙", "对视", "互相", "相望", "对话", "争执", "擦肩", "并肩",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn scene_anchor_name_is_generic_location(name: &str) -> bool {
    matches!(
        normalize_prompt_text(name).as_str(),
        "门厅" | "走廊" | "街口" | "门口" | "楼梯口" | "巷口" | "客厅" | "卧室"
    )
}

pub fn select_script_asset_anchors(
    mut scored: Vec<(i32, usize, String)>,
    limit: usize,
) -> Vec<String> {
    if limit == 0 {
        return Vec::new();
    }
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let mut selected = Vec::new();
    for (_, _, anchor) in scored {
        if selected.iter().any(|existing| existing == &anchor) {
            continue;
        }
        selected.push(anchor);
        if selected.len() >= limit {
            break;
        }
    }
    selected
}

pub fn compact_selected_script_asset_anchor(
    name: &str,
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    kind: ScriptAssetAnchorKind,
) -> Option<String> {
    let normalized_name = normalize_prompt_text(name);
    if normalized_name.is_empty() {
        return None;
    }
    if script_asset_anchor_note_is_generic_placeholder(note) {
        return None;
    }

    let mut fragments = note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_script_asset_anchor_fragment_against_storyboard_fields(
                fragment,
                structured_fields,
                kind,
            )
        })
        .filter(|fragment| {
            !script_asset_anchor_fragment_is_covered(
                fragment,
                structured_fields,
                prompt_coverage,
                kind,
            )
        })
        .collect::<Vec<_>>();
    fragments.dedup();

    if fragments.is_empty() {
        return None;
    }

    Some(format!("{normalized_name}:{}", fragments.join("，")))
}

pub fn script_asset_anchor_note_is_generic_placeholder(note: &str) -> bool {
    matches!(
        normalize_prompt_text(note).as_str(),
        "视觉设定延续" | "场景设定延续" | "道具设定延续"
    )
}

pub fn script_asset_anchor_fragment_is_covered(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    kind: ScriptAssetAnchorKind,
) -> bool {
    if prompt_fragment_is_covered(fragment, prompt_coverage) {
        return true;
    }

    let Some(fields) = structured_fields else {
        return false;
    };
    match kind {
        ScriptAssetAnchorKind::Role => fragment_mostly_repeats_prompt_mood(fragment, &fields.mood),
        ScriptAssetAnchorKind::Scene | ScriptAssetAnchorKind::Tool => false,
    }
}

pub fn trim_script_asset_anchor_fragment_against_storyboard_fields(
    fragment: String,
    structured_fields: Option<&StructuredStoryboardDescription>,
    kind: ScriptAssetAnchorKind,
) -> Option<String> {
    let Some(fields) = structured_fields else {
        return Some(fragment);
    };

    let mut trimmed = fragment;
    for field in script_asset_anchor_overlap_fields(fields, kind) {
        trimmed = trim_fragment_by_exact_field_overlap(&trimmed, field)?;
    }
    Some(trimmed)
}

pub fn script_asset_anchor_overlap_fields(
    fields: &StructuredStoryboardDescription,
    kind: ScriptAssetAnchorKind,
) -> Vec<&str> {
    let mut overlap_fields = match kind {
        ScriptAssetAnchorKind::Role => vec![fields.subject.as_str(), fields.action.as_str()],
        ScriptAssetAnchorKind::Scene => vec![fields.setting.as_str()],
        ScriptAssetAnchorKind::Tool => Vec::new(),
    };
    overlap_fields.push(fields.mood.as_str());
    overlap_fields.push(fields.lighting.as_str());
    overlap_fields
}

pub fn compact_script_asset_anchor(
    row: ScriptRolePromptSeedRow,
) -> Option<ScriptAssetPromptAnchor> {
    let asset_type = normalize_prompt_text(&row.asset_type).to_lowercase();
    let max_chars = match asset_type.as_str() {
        "role" => 24,
        "scene" => 22,
        "tool" => 20,
        _ => return None,
    };
    let name = row
        .name
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text: &String| !text.is_empty())?;
    let describe = row
        .describe
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text: &String| !text.is_empty())
        .map(|text| clip_prompt_fragment(&text, max_chars))?;
    Some(ScriptAssetPromptAnchor {
        asset_type,
        value: format!("{name}: {describe}"),
    })
}
