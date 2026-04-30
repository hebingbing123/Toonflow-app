//! Prompt clause compaction: strip/normalize subject, setting, action clauses.

use super::super::super::*;
use super::super::coverage::{
    prompt_clause_key_is_covered_by_anchor, prompt_fragment_has_direct_coverage,
};
use super::dialogue::{
    canonical_dialogue_fragment, dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech,
};

#[derive(Debug, Clone, Copy)]
pub(in crate::production::workbench::meta::generate) enum PromptClauseKind {
    Subject,
    Setting,
    Action,
}

pub(in crate::production::workbench::meta::generate) fn compact_prompt_clause(
    raw: &str,
    asset_coverage: &[String],
    setting: Option<&str>,
    kind: PromptClauseKind,
) -> Option<String> {
    let normalized = normalize_prompt_text(raw);
    if normalized.is_empty() || prompt_fragment_has_direct_coverage(&normalized, asset_coverage) {
        return None;
    }

    let mut compacted = strip_action_setting_prefix(&normalized, setting, kind);
    compacted = strip_leading_covered_prompt_fragment(&compacted, asset_coverage);
    compacted = strip_action_object_prefix(&compacted, asset_coverage, kind);
    compacted = normalize_prompt_clause_compaction(&compacted, kind);
    if compacted.is_empty() {
        return None;
    }
    Some(compacted)
}

pub(in crate::production::workbench::meta::generate) fn strip_action_object_prefix(
    fragment: &str,
    coverage: &[String],
    kind: PromptClauseKind,
) -> String {
    if !matches!(kind, PromptClauseKind::Action) {
        return fragment.to_string();
    }

    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 2 {
                continue;
            }
            for verb in ACTION_OBJECT_PREFIX_VERBS {
                let Some(stripped) = compacted.strip_prefix(verb) else {
                    continue;
                };
                let Some(stripped) = stripped.strip_prefix(candidate) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            ':' | '：'
                                | ';'
                                | '；'
                                | ','
                                | '，'
                                | '/'
                                | '／'
                                | '、'
                                | '的'
                                | '着'
                                | '后'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(in crate::production::workbench::meta::generate) fn strip_leading_covered_prompt_fragment(
    fragment: &str,
    coverage: &[String],
) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 2 {
                continue;
            }
            let stripped = strip_prompt_prefix_candidate(&compacted, candidate);
            let Some(stripped) = stripped else { continue };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ':' | '：'
                            | ';'
                            | '；'
                            | ','
                            | '，'
                            | '/'
                            | '／'
                            | '、'
                            | '的'
                            | '在'
                            | '向'
                            | '朝'
                            | '往'
                            | '从'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(in crate::production::workbench::meta::generate) fn strip_prompt_prefix_candidate<'a>(
    fragment: &'a str,
    candidate: &str,
) -> Option<&'a str> {
    fragment.strip_prefix(candidate).or_else(|| {
        strip_prompt_leading_bridge(fragment).and_then(|value| value.strip_prefix(candidate))
    })
}

pub(in crate::production::workbench::meta::generate) fn strip_prompt_leading_bridge(
    fragment: &str,
) -> Option<&str> {
    let trimmed = fragment.trim_start();
    PROMPT_LEADING_BRIDGES
        .into_iter()
        .find_map(|prefix| trimmed.strip_prefix(prefix))
}

pub(in crate::production::workbench::meta::generate) fn strip_action_setting_prefix(
    fragment: &str,
    setting: Option<&str>,
    kind: PromptClauseKind,
) -> String {
    if !matches!(kind, PromptClauseKind::Action) {
        return fragment.to_string();
    }

    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = build_prompt_setting_prefix_candidates(setting);
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 4 {
                continue;
            }
            let Some(stripped) = strip_prompt_prefix_candidate(&compacted, candidate) else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(in crate::production::workbench::meta::generate) fn strip_prompt_setting_subject_prefix(
    setting: &str,
    prompt_coverage: &[String],
) -> String {
    let mut compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }

    let mut coverage = prompt_coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    coverage.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &coverage {
            if candidate.chars().count() < 2 || !compacted.starts_with(candidate) {
                continue;
            }
            let rest = compacted[candidate.len()..].trim_start();
            for suffix in SETTING_SUBJECT_LEAD_IN_SUFFIXES {
                let Some(stripped) = rest.strip_prefix(suffix) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(in crate::production::workbench::meta::generate) fn strip_prompt_setting_context_prefix(
    setting: &str,
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return None;
    }

    let locative_lead_in = prompt_setting_locative_lead_in(&compacted)?;
    if locative_lead_in.chars().count() < 4 {
        return None;
    }

    let covered_by_context = subject
        .into_iter()
        .chain(action)
        .flat_map(prompt_context_variants)
        .any(|candidate| candidate.starts_with(&locative_lead_in));
    if !covered_by_context {
        return None;
    }

    let (_, suffix) = strip_prompt_setting_descriptive_lead_in(&compacted)?;
    let suffix = suffix.trim_start_matches(|ch: char| {
        ch.is_whitespace()
            || matches!(
                ch,
                '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
            )
    });
    (suffix.chars().count() >= 2).then(|| suffix.to_string())
}

pub(in crate::production::workbench::meta::generate) fn build_prompt_setting_prefix_candidates(
    setting: Option<&str>,
) -> Vec<String> {
    let mut candidates = Vec::new();
    let Some(setting) = setting
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return candidates;
    };

    candidates.push(setting.clone());
    if let Some(stripped) = strip_prompt_leading_bridge(&setting) {
        candidates.push(stripped.to_string());
    }
    if let Some((prefix, _)) = strip_prompt_setting_descriptive_lead_in(&setting) {
        candidates.push(prefix.to_string());
        if let Some(stripped) = strip_prompt_leading_bridge(prefix) {
            candidates.push(stripped.to_string());
        }
    }
    candidates.sort();
    candidates.dedup();
    candidates
}

pub(in crate::production::workbench::meta::generate) fn prompt_setting_locative_lead_in(
    setting: &str,
) -> Option<String> {
    let normalized = normalize_prompt_text(setting);
    let (prefix, _) = strip_prompt_setting_descriptive_lead_in(&normalized)?;
    let prefix = strip_prompt_leading_bridge(prefix).unwrap_or(prefix);
    let prefix = normalize_prompt_text(prefix);
    (!prefix.is_empty()).then_some(prefix)
}

pub(in crate::production::workbench::meta::generate) fn strip_prompt_setting_descriptive_lead_in(
    setting: &str,
) -> Option<(&str, &str)> {
    let normalized = setting.trim();
    let split_at = normalized.find('的')?;
    let (prefix, suffix_with_marker) = normalized.split_at(split_at);
    let suffix = suffix_with_marker.strip_prefix('的')?;
    let prefix = prefix.trim();
    let suffix = suffix.trim();
    (!prefix.is_empty() && !suffix.is_empty()).then_some((prefix, suffix))
}

pub(in crate::production::workbench::meta::generate) fn prompt_context_variants(
    value: &str,
) -> Vec<String> {
    let normalized = normalize_prompt_text(value);
    if normalized.is_empty() {
        return Vec::new();
    }

    let mut variants = vec![normalized.clone()];
    if let Some(stripped) = strip_prompt_subject_role_prefix(&normalized) {
        variants.push(stripped.to_string());
        if let Some(bridge) = strip_prompt_leading_bridge(stripped) {
            variants.push(bridge.to_string());
        }
    }
    if let Some(stripped) = strip_prompt_leading_bridge(&normalized) {
        variants.push(stripped.to_string());
    }
    variants.sort();
    variants.dedup();
    variants
}

pub(in crate::production::workbench::meta::generate) fn strip_prompt_subject_role_prefix(
    value: &str,
) -> Option<&str> {
    ACTION_SUBJECT_PREFIXES.iter().find_map(|prefix| {
        value.strip_prefix(prefix).map(|stripped| {
            stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            })
        })
    })
}

pub(in crate::production::workbench::meta::generate) fn trim_subject_action_overlap(
    subject: &str,
    action: Option<&str>,
) -> Option<String> {
    let subject = normalize_prompt_text(subject);
    let action = action.map(normalize_prompt_text).unwrap_or_default();
    if subject.is_empty() || action.is_empty() {
        return None;
    }

    let identity_tail = strip_prompt_subject_role_prefix(&subject)?;
    if identity_tail.chars().count() < 3 {
        return None;
    }

    for overlap_len in (3..=identity_tail.chars().count().min(12)).rev() {
        let overlap = identity_tail.chars().take(overlap_len).collect::<String>();
        if overlap.chars().count() < 3 || !action.contains(&overlap) {
            continue;
        }
        let Some(trimmed) = subject.strip_suffix(&overlap) else {
            continue;
        };
        let trimmed = normalize_prompt_clause_compaction(trimmed, PromptClauseKind::Subject);
        if trimmed.chars().count() < 2
            || canonical_prompt_fragment(&trimmed) == canonical_prompt_fragment(&subject)
        {
            continue;
        }
        return Some(trimmed);
    }

    None
}

pub(in crate::production::workbench::meta::generate) fn normalize_prompt_clause_compaction(
    fragment: &str,
    kind: PromptClauseKind,
) -> String {
    let compacted = normalize_prompt_text(fragment)
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、' | '和' | '与'
                )
        })
        .to_string();
    if compacted.is_empty() {
        return compacted;
    }
    match kind {
        PromptClauseKind::Setting => compacted.trim_start_matches('的').to_string(),
        PromptClauseKind::Subject | PromptClauseKind::Action => compacted,
    }
}

pub(in crate::production::workbench::meta::generate) fn strip_dialogue_covered_action_suffix(
    action: &str,
    dialogue: &str,
) -> Option<String> {
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty() {
        return None;
    }

    let normalized_action = normalize_prompt_text(action);
    if normalized_action.is_empty() {
        return None;
    }

    for speech_prefix in [
        "低声说",
        "轻声说",
        "小声说",
        "喃喃道",
        "喃喃说",
        "呢喃",
        "说道",
        "说出",
        "说",
        "喊道",
        "喊出",
        "大喊",
        "呼喊",
        "叫喊",
        "质问",
        "回答",
        "回应",
        "重复",
    ] {
        let patterns = [
            format!("并{speech_prefix}{canonical_dialogue}"),
            format!("后{speech_prefix}{canonical_dialogue}"),
            format!("再{speech_prefix}{canonical_dialogue}"),
            format!("{speech_prefix}{canonical_dialogue}"),
        ];
        for pattern in patterns {
            let Some(prefix) = normalized_action.strip_suffix(&pattern) else {
                continue;
            };
            let normalized_prefix = normalize_prompt_text(prefix);
            let trimmed = normalized_prefix.trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '、' | '并' | '后' | '再'
                    )
            });
            if trimmed.chars().count() < 2 || action_fragment_is_speech_delivery_only(trimmed) {
                continue;
            }
            return Some(trimmed.to_string());
        }
    }

    None
}

pub(in crate::production::workbench::meta::generate) fn strip_low_visibility_dialogue_payload_from_action(
    action: &str,
    canonical_dialogue: &str,
) -> Option<String> {
    let normalized_action = normalize_prompt_text(action);
    if normalized_action.is_empty() || canonical_dialogue.is_empty() {
        return None;
    }

    for speech_prefix in [
        "低声说",
        "轻声说",
        "小声说",
        "喃喃道",
        "喃喃说",
        "呢喃",
        "说道",
        "说出",
        "说",
        "喊道",
        "喊出",
        "大喊",
        "呼喊",
        "叫喊",
        "质问",
        "回答",
        "回应",
        "重复",
    ] {
        let patterns = [
            format!("并{speech_prefix}{canonical_dialogue}"),
            format!("后{speech_prefix}{canonical_dialogue}"),
            format!("再{speech_prefix}{canonical_dialogue}"),
            format!("{speech_prefix}{canonical_dialogue}"),
        ];
        for pattern in patterns {
            let Some(prefix) = normalized_action.strip_suffix(&pattern) else {
                continue;
            };
            let normalized_prefix = normalize_prompt_text(prefix);
            let trimmed = normalized_prefix.trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '、' | '并' | '后' | '再'
                    )
            });
            if trimmed.chars().count() >= 2 && !action_fragment_is_speech_delivery_only(trimmed) {
                return Some(trimmed.to_string());
            }

            return compact_low_visibility_speech_delivery(trimmed, speech_prefix);
        }
    }

    None
}

pub(in crate::production::workbench::meta::generate) fn compact_low_visibility_speech_delivery(
    fragment: &str,
    speech_prefix: &str,
) -> Option<String> {
    let normalized = normalize_prompt_text(fragment);
    if !normalized.is_empty() && !action_fragment_is_speech_delivery_only(&normalized) {
        return None;
    }

    Some(
        if speech_prefix.contains("低声") || speech_prefix.contains("小声") {
            "低声开口"
        } else if speech_prefix.contains("轻声") {
            "轻声开口"
        } else if speech_prefix.contains("喃喃") || speech_prefix.contains("呢喃") {
            "呢喃开口"
        } else if speech_prefix.contains("喊") {
            "急喊示意"
        } else if speech_prefix == "质问" {
            "开口质问"
        } else if speech_prefix == "回答" || speech_prefix == "回应" {
            "开口回应"
        } else if speech_prefix == "重复" {
            "重复示意"
        } else {
            "开口示意"
        }
        .to_string(),
    )
}

pub(in crate::production::workbench::meta::generate) fn action_fragment_is_speech_delivery_only(
    fragment: &str,
) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "低声",
            "轻声",
            "小声",
            "喃喃",
            "呢喃",
            "压低声音",
            "提高嗓门",
        ]
        .iter()
        .any(|value| normalized == *value)
}

pub(in crate::production::workbench::meta::generate) fn prompt_clauses_substantially_overlap(
    lhs: Option<&str>,
    rhs: Option<&str>,
) -> bool {
    let Some(lhs) = lhs
        .map(canonical_prompt_fragment)
        .filter(|value| !value.is_empty())
    else {
        return false;
    };
    let Some(rhs) = rhs
        .map(canonical_prompt_fragment)
        .filter(|value| !value.is_empty())
    else {
        return false;
    };
    lhs == rhs
        || (lhs.chars().count() >= 6 && rhs.contains(&lhs))
        || (rhs.chars().count() >= 6 && lhs.contains(&rhs))
}

pub(in crate::production::workbench::meta::generate) fn compact_subject_clause(
    subject: &str,
    asset_coverage: &[String],
    _prompt_coverage: &[String],
    action: Option<&str>,
) -> Option<String> {
    let subject = trim_subject_action_overlap(subject, action).unwrap_or_else(|| subject.into());
    let compacted =
        compact_prompt_clause(&subject, asset_coverage, None, PromptClauseKind::Subject)?;
    (!prompt_clause_key_is_covered_by_anchor(&compacted, asset_coverage)).then_some(compacted)
}

pub(in crate::production::workbench::meta::generate) fn compact_setting_clause(
    setting: &str,
    asset_coverage: &[String],
    prompt_coverage: &[String],
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let compacted = strip_prompt_setting_subject_prefix(setting, prompt_coverage);
    let compacted =
        strip_prompt_setting_context_prefix(&compacted, subject, action).unwrap_or(compacted);
    let compacted =
        compact_prompt_clause(&compacted, asset_coverage, None, PromptClauseKind::Setting)?;
    let compacted = normalize_prompt_clause_compaction(&compacted, PromptClauseKind::Setting);
    (!compacted.is_empty()
        && !prompt_clause_key_is_covered_by_anchor(&compacted, asset_coverage)
        && !prompt_fragment_has_direct_coverage(&compacted, asset_coverage)
        && !prompt_fragment_has_direct_coverage(&compacted, prompt_coverage))
    .then_some(compacted)
}

pub(in crate::production::workbench::meta::generate) fn compact_action_clause(
    action: &str,
    asset_coverage: &[String],
    _prompt_coverage: &[String],
    dialogue: Option<&str>,
    setting: Option<&str>,
) -> Option<String> {
    let compacted =
        compact_prompt_clause(action, asset_coverage, setting, PromptClauseKind::Action)?;

    let trimmed = dialogue
        .and_then(|line| strip_dialogue_covered_action_suffix(&compacted, line))
        .unwrap_or(compacted);
    (!trimmed.is_empty()).then_some(trimmed)
}

pub(in crate::production::workbench::meta::generate) fn compact_hidden_speech_action_clause(
    action: &str,
    dialogue: &str,
    fields: &StructuredStoryboardDescription,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let prompt = context
        .and_then(|value| value.storyboard_prompt.as_deref())
        .unwrap_or_default();
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty()
        || !dialogue_clause_is_low_gain_for_offscreen_or_low_visibility_speech(
            &canonical_dialogue,
            fields,
            prompt,
        )
    {
        return Some(action.to_string());
    }

    strip_low_visibility_dialogue_payload_from_action(action, &canonical_dialogue)
        .or_else(|| Some(action.to_string()))
}
