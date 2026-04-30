use super::super::*;

pub(in crate::production::workbench::meta::generate) fn trim_fragment_by_exact_field_overlap(
    fragment: &str,
    field: &str,
) -> Option<String> {
    let normalized_fragment = normalize_prompt_text(fragment);
    let normalized_field = normalize_prompt_text(field);
    if normalized_fragment.is_empty() || normalized_field.is_empty() {
        return Some(normalized_fragment);
    }
    if !normalized_fragment.contains(&normalized_field) {
        return Some(normalized_fragment);
    }

    let residual = normalize_prompt_text(&normalized_fragment.replace(&normalized_field, ""));
    if residual.chars().count() <= 2 {
        None
    } else {
        Some(residual)
    }
}

pub(in crate::production::workbench::meta::generate) fn fragment_mostly_repeats_prompt_mood(
    fragment: &str,
    mood: &str,
) -> bool {
    let fragment = normalize_prompt_text(fragment);
    let mood = normalize_prompt_text(mood);
    if fragment.is_empty() || mood.is_empty() || !fragment.contains(&mood) {
        return false;
    }

    let residual = fragment.replace(&mood, "");
    normalize_prompt_text(&residual).chars().count() <= 2
}

pub(in crate::production::workbench::meta::generate) fn collect_prompt_coverage(
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Vec<String> {
    let Some(fields) = structured_fields else {
        return Vec::new();
    };
    let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(", ");
    [
        fields.subject.as_str(),
        fields.action.as_str(),
        fields.setting.as_str(),
        fields.mood.as_str(),
        fields.lighting.as_str(),
        camera.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .filter(|fragment| !fragment.is_empty())
    .collect()
}

pub(in crate::production::workbench::meta::generate) fn extend_prompt_coverage(
    target: &mut Vec<String>,
    anchors: &[String],
) {
    for anchor in anchors {
        for fragment in expand_prompt_coverage_fragments(anchor) {
            if target.iter().any(|existing| existing == &fragment) {
                continue;
            }
            target.push(fragment);
        }
    }
}

pub(in crate::production::workbench::meta::generate) fn expand_prompt_coverage_fragments(
    anchor: &str,
) -> Vec<String> {
    let mut fragments = Vec::new();
    for fragment in anchor
        .split([':', '：', ';', '；', ',', '，'])
        .map(normalize_prompt_text)
    {
        if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
            continue;
        }
        fragments.push(fragment);
    }
    fragments
}

pub(in crate::production::workbench::meta::generate) fn prompt_fragment_is_covered(
    fragment: &str,
    coverage: &[String],
) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }
    coverage.iter().any(|existing| {
        let canonical_existing = canonical_prompt_fragment(existing);
        if canonical_existing.is_empty() {
            return false;
        }
        canonical_existing == canonical_fragment
            || (canonical_fragment.chars().count() >= 4
                && canonical_existing.contains(&canonical_fragment))
            || (canonical_existing.chars().count() >= 4
                && canonical_fragment.contains(&canonical_existing))
    })
}

pub(in crate::production::workbench::meta::generate) fn prompt_style_field_is_covered(
    field: &str,
    coverage: &[String],
) -> bool {
    prompt_fragment_is_covered(field, coverage)
        || coverage
            .iter()
            .any(|fragment| style_fragment_semantically_covers_field(fragment, field))
}

pub(in crate::production::workbench::meta::generate) fn style_fragment_semantically_covers_field(
    fragment: &str,
    field: &str,
) -> bool {
    let canonical_field = canonical_prompt_fragment(field);
    if canonical_field.is_empty() {
        return false;
    }

    let canonical_fragment = canonical_continuity_fragment(fragment);
    if canonical_fragment.is_empty() || !canonical_fragment.contains(&canonical_field) {
        return false;
    }

    let trimmed = canonical_style_field_fragment(&canonical_fragment);
    !trimmed.is_empty()
        && (trimmed == canonical_field
            || (trimmed.contains(&canonical_field)
                && normalize_prompt_text(&trimmed.replace(&canonical_field, "")).is_empty()))
}

pub(in crate::production::workbench::meta::generate) fn canonical_style_field_fragment(
    fragment: &str,
) -> String {
    [
        "风格",
        "质感",
        "氛围",
        "情绪",
        "光影",
        "色调",
        "影调",
        "气质",
        "颗粒",
        "电影感",
        "感",
    ]
    .into_iter()
    .fold(normalize_prompt_text(fragment), |acc, token| {
        acc.replace(token, "")
    })
}

pub(in crate::production::workbench::meta::generate) fn canonical_prompt_fragment(
    fragment: &str,
) -> String {
    normalize_prompt_text(fragment)
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，' | '.' | '。')
        })
        .to_string()
}

pub(in crate::production::workbench::meta::generate) fn prompt_fragment_has_direct_coverage(
    fragment: &str,
    coverage: &[String],
) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }
    coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .any(|existing| !existing.is_empty() && existing == canonical_fragment)
}

pub(in crate::production::workbench::meta::generate) fn prompt_clause_key_is_covered_by_anchor(
    fragment: &str,
    coverage: &[String],
) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    coverage.iter().any(|entry| {
        entry.split_once(':').is_some_and(|(anchor_key, _)| {
            let canonical_anchor = canonical_prompt_fragment(anchor_key);
            !canonical_anchor.is_empty() && canonical_anchor == canonical_fragment
        })
    })
}
