use super::*;

pub(super) fn compact_selected_memory_subject(subject: &str, action: &str) -> Option<String> {
    let subject = trim_selected_memory_subject_action_overlap(subject, action)
        .unwrap_or_else(|| normalize_prompt_text(subject));
    if subject.is_empty() {
        return None;
    }
    if prompt_fragments_substantially_overlap(&subject, action) {
        return None;
    }
    Some(subject)
}

pub(crate) fn selected_memory_subject_identity(
    subject: &str,
    subject_refs: &str,
) -> Option<String> {
    selected_memory_subject_aliases(subject, subject_refs)
        .into_iter()
        .next()
}

pub(crate) fn selected_memory_subject_aliases(subject: &str, subject_refs: &str) -> Vec<String> {
    let mut aliases = Vec::new();
    let subject_hint =
        normalize_selected_memory_identity_candidate(&selected_memory_identity_source(subject));
    let refs = normalize_prompt_text(subject_refs);
    if !refs.is_empty() {
        for candidate in refs
            .split(['/', '／', '、', ',', '，'])
            .map(normalize_prompt_text)
            .filter(|value| !value.is_empty())
        {
            if let Some(identity) = normalize_selected_memory_identity_candidate_with_hint(
                &candidate,
                subject_hint.as_deref(),
            ) {
                aliases.push(identity);
            }
        }
    }
    if let Some(identity) = subject_hint {
        aliases.push(identity);
    }
    let mut deduped = Vec::new();
    for alias in aliases {
        if deduped.iter().any(|existing| existing == &alias) {
            continue;
        }
        deduped.push(alias);
    }
    let mut aliases = deduped;
    aliases.truncate(4);
    aliases
}

pub(super) fn selected_memory_identity_source(candidate: &str) -> String {
    let normalized = normalize_prompt_text(candidate);
    if normalized.is_empty() {
        return normalized;
    }
    if let Some(role_prefix) = ACTION_SUBJECT_PREFIXES
        .iter()
        .find(|prefix| normalized.starts_with(**prefix))
    {
        let remainder = normalize_prompt_text(normalized.trim_start_matches(role_prefix));
        if generic_subject_role_is_followed_by_actionish_fragment(&remainder) {
            return (*role_prefix).to_string();
        }
    }
    let Some((split_idx, _)) = SUBJECT_IDENTITY_TAIL_MARKERS
        .iter()
        .filter_map(|marker| normalized.find(marker).map(|idx| (idx, *marker)))
        .min_by_key(|(idx, _)| *idx)
    else {
        return normalized;
    };
    let prefix = normalized[..split_idx].trim_end();
    if (2..=6).contains(&prefix.chars().count()) {
        prefix.to_string()
    } else {
        normalized
    }
}

fn generic_subject_role_is_followed_by_actionish_fragment(remainder: &str) -> bool {
    let remainder = normalize_prompt_text(remainder);
    !remainder.is_empty()
        && (GENERIC_SUBJECT_ACTION_LEADERS
            .iter()
            .any(|prefix| remainder.starts_with(prefix))
            || SUBJECT_IDENTITY_TAIL_MARKERS
                .iter()
                .any(|marker| remainder.starts_with(marker)))
}

fn normalize_selected_memory_identity_candidate(candidate: &str) -> Option<String> {
    normalize_selected_memory_identity_candidate_with_hint(candidate, None)
}

fn normalize_selected_memory_identity_candidate_with_hint(
    candidate: &str,
    subject_hint: Option<&str>,
) -> Option<String> {
    let normalized = normalize_prompt_text(candidate);
    if normalized.is_empty() {
        return None;
    }
    let normalized = selected_memory_identity_source(&normalized);
    if ACTION_SUBJECT_PREFIXES
        .iter()
        .any(|prefix| normalized == *prefix)
    {
        return Some(normalized);
    }
    let stripped = strip_selected_memory_subject_role_prefix(&normalized)
        .map(normalize_prompt_text)
        .unwrap_or(normalized);
    if stripped.is_empty()
        || ACTION_SUBJECT_PREFIXES
            .iter()
            .any(|prefix| stripped == *prefix)
        || selected_memory_identity_looks_like_non_character_fragment(&stripped, subject_hint)
    {
        return None;
    }
    let clipped = clip_prompt_fragment(&stripped, 12);
    (clipped.chars().count() >= 2).then_some(clipped)
}

fn selected_memory_identity_looks_like_non_character_fragment(
    candidate: &str,
    subject_hint: Option<&str>,
) -> bool {
    candidate.contains('的')
        || subject_hint.is_some_and(|hint| {
            let remainder = candidate.strip_prefix(hint).map(normalize_prompt_text);
            remainder
                .as_deref()
                .is_some_and(generic_subject_role_is_followed_by_actionish_fragment)
        })
        || NON_CHARACTER_ALIAS_SUFFIXES
            .iter()
            .any(|suffix| candidate.ends_with(suffix))
        || subject_hint.is_some_and(|hint| {
            !hint.is_empty()
                && candidate != hint
                && !candidate.contains(hint)
                && !hint.contains(candidate)
                && NON_CHARACTER_ALIAS_SUFFIXES
                    .iter()
                    .any(|suffix| candidate.ends_with(suffix))
        })
}

fn trim_selected_memory_subject_action_overlap(subject: &str, action: &str) -> Option<String> {
    let subject = normalize_prompt_text(subject);
    let action = normalize_prompt_text(action);
    if subject.is_empty() || action.is_empty() {
        return None;
    }
    let Some(identity_tail) = strip_selected_memory_subject_role_prefix(&subject) else {
        return None;
    };
    if identity_tail.chars().count() < 3 {
        return None;
    }
    for overlap_len in (3..=identity_tail.chars().count().min(12)).rev() {
        let overlap = identity_tail.chars().take(overlap_len).collect::<String>();
        if !action.contains(&overlap) {
            continue;
        }
        let Some(trimmed) = subject.strip_suffix(&overlap) else {
            continue;
        };
        let trimmed = normalize_prompt_text(trimmed)
            .trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、')
            })
            .to_string();
        if trimmed.chars().count() < 2 || trimmed == subject {
            continue;
        }
        return Some(trimmed);
    }
    None
}

pub(super) fn merge_selected_memory_subject_action(
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let subject = subject.map(normalize_prompt_text)?;
    let action = action.map(normalize_prompt_text)?;
    let simplified_subject = normalize_prompt_text(
        &subject
            .replace(['后', '又', '再', '便', '才'], "")
            .trim()
            .to_string(),
    );
    let simplified_action = normalize_prompt_text(
        &action
            .replace(['后', '又', '再', '便', '才'], "")
            .trim()
            .to_string(),
    );
    if subject.is_empty()
        || action.is_empty()
        || subject == action
        || (!simplified_subject.is_empty()
            && !simplified_action.is_empty()
            && simplified_subject.contains(&simplified_action))
        || subject.contains('在')
        || action.chars().count() < 4
    {
        return None;
    }
    let subject_chars = subject.chars().count();
    let action_chars = action.chars().count();
    let max_overlap = action_chars.min(4);
    for overlap_len in (2..=max_overlap).rev() {
        let overlap = action
            .chars()
            .rev()
            .take(overlap_len)
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .collect::<String>();
        let Some(start) = subject.find(&overlap) else {
            continue;
        };
        if start == 0 {
            continue;
        }
        let end = start + overlap.len();
        let merged = format!("{}{}{}", &subject[..start], action, &subject[end..]);
        let merged = normalize_prompt_text(&merged);
        if merged == subject
            || merged == action
            || merged.chars().count() >= subject_chars + action_chars
            || merged.contains("，，")
        {
            continue;
        }
        return Some(merged);
    }
    None
}

pub(super) fn compact_selected_memory_action(
    action: &str,
    subject: Option<&str>,
    subject_source: Option<&str>,
    subject_coverage: Option<&str>,
    setting: Option<&str>,
    mood: &str,
) -> Option<String> {
    let mut action = normalize_prompt_text(action);
    if action.is_empty() {
        return None;
    }
    if let Some(subject) = subject
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    {
        if action == subject {
            return None;
        }
        if let Some(stripped) = action.strip_prefix(&subject) {
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            });
            if stripped.chars().count() >= 2 {
                action = stripped.to_string();
            }
        }
        if let Some(prefix) = ACTION_SUBJECT_PREFIXES.iter().find(|prefix| {
            action.starts_with(**prefix)
                && (subject.starts_with(**prefix) || subject.contains(**prefix))
        }) {
            if let Some(stripped) = action.strip_prefix(prefix) {
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
                });
                if stripped.chars().count() >= 2 {
                    action = stripped.to_string();
                }
            }
        }
    }
    action = strip_selected_memory_action_subject_overlap(&action, subject_source);
    action = strip_selected_memory_action_object_prefix(&action, subject_coverage);
    action = strip_selected_memory_action_setting_prefix(&action, setting);
    if !normalize_prompt_text(mood).is_empty() {
        for prefix in ACTION_PACE_PREFIXES {
            if let Some(stripped) = action.strip_prefix(prefix) {
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace() || matches!(ch, '地' | '着' | ':' | '：' | ',' | '，' | '、')
                });
                if stripped.chars().count() >= 2 {
                    action = stripped.to_string();
                    break;
                }
            }
        }
    }
    if subject.is_some_and(|value| prompt_fragments_substantially_overlap(value, &action)) {
        return None;
    }
    Some(action)
}

fn strip_selected_memory_action_subject_overlap(
    action: &str,
    subject_source: Option<&str>,
) -> String {
    let mut compacted = normalize_prompt_text(action);
    if compacted.is_empty() {
        return compacted;
    }
    let Some(subject_source) = subject_source
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return compacted;
    };
    let Some(subject_tail) = strip_selected_memory_subject_role_prefix(&subject_source)
        .map(normalize_prompt_text)
        .filter(|value| value.chars().count() >= 3)
    else {
        return compacted;
    };
    for overlap_len in (3..=subject_tail.chars().count().min(12)).rev() {
        let overlap = subject_tail.chars().take(overlap_len).collect::<String>();
        let Some(start) = compacted.find(&overlap) else {
            continue;
        };
        if start == 0 {
            continue;
        }
        let end = start + overlap.len();
        let prefix = compacted[..start].trim_end_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ',' | '，' | '、' | ';' | '；')
        });
        let suffix = compacted[end..].trim_start_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ',' | '，' | '、' | ';' | '；')
        });
        if prefix.chars().count() < 2 || suffix.chars().count() < 2 {
            continue;
        }
        if !matches!(
            suffix.chars().next(),
            Some('后' | '再' | '并' | '且' | '仍')
        ) {
            continue;
        }
        let merged = normalize_prompt_text(&format!("{prefix}{suffix}"));
        if merged.chars().count() < 4 || merged == compacted {
            continue;
        }
        compacted = merged;
        break;
    }
    compacted
}

fn strip_selected_memory_action_object_prefix(
    action: &str,
    subject_coverage: Option<&str>,
) -> String {
    let mut compacted = normalize_prompt_text(action);
    if compacted.is_empty() {
        return compacted;
    }
    let mut coverage = subject_coverage
        .map(normalize_prompt_text)
        .unwrap_or_default()
        .split(['/', '／', '、', ',', '，'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    coverage.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));
    loop {
        let mut changed = false;
        for candidate in &coverage {
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

fn strip_selected_memory_action_setting_prefix(action: &str, setting: Option<&str>) -> String {
    let mut compacted = normalize_prompt_text(action);
    if compacted.is_empty() {
        return compacted;
    }
    let mut candidates = build_selected_memory_setting_prefix_candidates(setting);
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));
    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 4 {
                continue;
            }
            let Some(stripped) = strip_selected_memory_prefix_candidate(&compacted, candidate)
            else {
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

pub(super) fn compact_selected_memory_setting(
    setting: &str,
    subject: Option<&str>,
    subject_coverage: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let mut setting = normalize_prompt_text(setting);
    if setting.is_empty() {
        return None;
    }
    setting = strip_selected_memory_setting_subject_prefix(&setting, subject_coverage);
    setting = strip_selected_memory_setting_context_prefix(&setting, subject, action);
    if subject.is_some_and(|value| prompt_fragments_substantially_overlap(value, &setting))
        || action.is_some_and(|value| prompt_fragments_substantially_overlap(value, &setting))
    {
        return None;
    }
    Some(setting)
}

fn strip_selected_memory_setting_subject_prefix(
    setting: &str,
    subject_coverage: Option<&str>,
) -> String {
    let mut compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }
    let mut coverage = subject_coverage
        .map(normalize_prompt_text)
        .unwrap_or_default()
        .split(['/', '／', '、', ',', '，'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
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

fn strip_selected_memory_setting_context_prefix(
    setting: &str,
    subject: Option<&str>,
    action: Option<&str>,
) -> String {
    let compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }
    let Some(locative_lead_in) = selected_memory_setting_locative_lead_in(&compacted) else {
        return compacted;
    };
    if locative_lead_in.chars().count() < 4 {
        return compacted;
    }
    let covered_by_context = subject
        .into_iter()
        .chain(action)
        .map(selected_memory_context_variants)
        .flatten()
        .any(|candidate| candidate.starts_with(&locative_lead_in));
    if !covered_by_context {
        return compacted;
    }
    let Some((_, suffix)) = strip_selected_memory_setting_descriptive_lead_in(&compacted) else {
        return compacted;
    };
    let suffix = suffix.trim_start_matches(|ch: char| {
        ch.is_whitespace()
            || matches!(
                ch,
                '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
            )
    });
    if suffix.chars().count() < 2 {
        return compacted;
    }
    suffix.to_string()
}

fn build_selected_memory_setting_prefix_candidates(setting: Option<&str>) -> Vec<String> {
    let mut candidates = Vec::new();
    let Some(setting) = setting
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return candidates;
    };
    candidates.push(setting.clone());
    if let Some(stripped) = strip_selected_memory_leading_bridge(&setting) {
        candidates.push(stripped.to_string());
    }
    if let Some((prefix, _)) = strip_selected_memory_setting_descriptive_lead_in(&setting) {
        candidates.push(prefix.to_string());
        if let Some(stripped) = strip_selected_memory_leading_bridge(prefix) {
            candidates.push(stripped.to_string());
        }
    }
    candidates.sort();
    candidates.dedup();
    candidates
}

fn selected_memory_setting_locative_lead_in(setting: &str) -> Option<String> {
    let normalized = normalize_prompt_text(setting);
    let (prefix, _) = strip_selected_memory_setting_descriptive_lead_in(&normalized)?;
    let prefix = strip_selected_memory_leading_bridge(prefix).unwrap_or(prefix);
    let prefix = normalize_prompt_text(prefix);
    (!prefix.is_empty()).then_some(prefix)
}

fn strip_selected_memory_setting_descriptive_lead_in(setting: &str) -> Option<(&str, &str)> {
    let normalized = setting.trim();
    let split_at = normalized.find('的')?;
    let (prefix, suffix_with_marker) = normalized.split_at(split_at);
    let suffix = suffix_with_marker.strip_prefix('的')?;
    let prefix = prefix.trim();
    let suffix = suffix.trim();
    (!prefix.is_empty() && !suffix.is_empty()).then_some((prefix, suffix))
}

fn selected_memory_context_variants(value: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(value);
    if normalized.is_empty() {
        return Vec::new();
    }
    let mut variants = vec![normalized.clone()];
    if let Some(stripped) = strip_selected_memory_subject_role_prefix(&normalized) {
        variants.push(stripped.to_string());
        if let Some(bridge) = strip_selected_memory_leading_bridge(stripped) {
            variants.push(bridge.to_string());
        }
    }
    if let Some(stripped) = strip_selected_memory_leading_bridge(&normalized) {
        variants.push(stripped.to_string());
    }
    variants.sort();
    variants.dedup();
    variants
}

fn strip_selected_memory_subject_role_prefix(value: &str) -> Option<&str> {
    ACTION_SUBJECT_PREFIXES.iter().find_map(|prefix| {
        value.strip_prefix(prefix).map(|stripped| {
            stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            })
        })
    })
}

fn strip_selected_memory_prefix_candidate<'a>(
    fragment: &'a str,
    candidate: &str,
) -> Option<&'a str> {
    fragment.strip_prefix(candidate).or_else(|| {
        strip_selected_memory_leading_bridge(fragment)
            .and_then(|value| value.strip_prefix(candidate))
    })
}

fn strip_selected_memory_leading_bridge(fragment: &str) -> Option<&str> {
    let trimmed = fragment.trim_start();
    PROMPT_LEADING_BRIDGES
        .into_iter()
        .find_map(|prefix| trimmed.strip_prefix(prefix))
}

pub(super) fn prompt_fragments_substantially_overlap(lhs: &str, rhs: &str) -> bool {
    let lhs = normalize_prompt_text(lhs);
    let rhs = normalize_prompt_text(rhs);
    if lhs.is_empty() || rhs.is_empty() {
        return false;
    }
    lhs == rhs
        || (lhs.chars().count() >= 6 && rhs.contains(&lhs))
        || (rhs.chars().count() >= 6 && lhs.contains(&rhs))
}
