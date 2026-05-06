use crate::production::workbench::meta::common::negative_constraint_conflicts_with_storyboard_style;
use crate::production::workbench::video_prompt_memory::{
    normalize_prompt_text, parse_structured_storyboard_description, StoryboardPromptSeedRow,
};

use super::super::fragment_operations::negative_fragment_is_covered;
use super::super::fragment_parsing::canonical_negative_fragment;

pub(super) fn compact_negative_constraint_fragments_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    let conflicts = |value: &str| {
        negative_constraint_conflicts_with_storyboard_style(
            value.trim(),
            selected_style_note,
            storyboard_row,
        )
    };
    match canonical_negative_fragment(trimmed).as_str() {
        "avoid extreme camera angle or overly tight close-up framing" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid extreme camera angle",
                "avoid overly tight close-up framing",
                conflicts,
            )
            .into_iter()
            .collect()
        }
        "avoid oppressive or frantic mood" | "avoid overly cold, oppressive, or frantic mood" => {
            if selected_style_note.is_some()
                && conflicts("avoid oppressive mood")
                && conflicts("avoid overly cold emotional tone")
            {
                return Vec::new();
            }
            compact_conflicting_mood_constraints(trimmed, conflicts)
        }
        "avoid flat cold lighting or harsh backlight silhouette" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid flat cold lighting",
                "avoid harsh backlight silhouette",
                conflicts,
            )
            .into_iter()
            .collect()
        }
        "avoid distracting neon reflections" => (!conflicts(trimmed))
            .then_some(trimmed.to_string())
            .into_iter()
            .collect(),
        "avoid frantic mood"
            if selected_style_note.is_some()
                && conflicts("avoid oppressive mood")
                && conflicts("avoid overly cold emotional tone") =>
        {
            Vec::new()
        }
        _ => (!conflicts(trimmed))
            .then_some(trimmed.to_string())
            .into_iter()
            .collect(),
    }
}

fn compact_conflicting_negative_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_conflicts = conflicts(lhs);
    let rhs_conflicts = conflicts(rhs);
    match (lhs_conflicts, rhs_conflicts) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}

fn compact_conflicting_mood_constraints(
    original: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Vec<String> {
    let canonical = canonical_negative_fragment(original);
    let (allow_oppressive, allow_frantic, allow_cold) = match canonical.as_str() {
        "avoid oppressive or frantic mood" => (true, true, false),
        "avoid overly cold, oppressive, or frantic mood" => (true, true, true),
        "avoid oppressive mood" => (true, false, false),
        "avoid frantic mood" => (false, true, false),
        "avoid overly cold emotional tone" => (false, false, true),
        _ => return vec![original.to_string()],
    };

    render_mood_tone_constraint_fragments(
        allow_oppressive && !conflicts("avoid oppressive mood"),
        allow_frantic && !conflicts("avoid frantic mood"),
        allow_cold && !conflicts("avoid overly cold emotional tone"),
    )
}

fn render_mood_tone_constraint_fragments(
    oppressive: bool,
    frantic: bool,
    cold: bool,
) -> Vec<String> {
    if oppressive && frantic && cold {
        return vec!["avoid overly cold, oppressive, or frantic mood".to_string()];
    }
    if oppressive && frantic {
        return vec!["avoid oppressive or frantic mood".to_string()];
    }

    let mut fragments = Vec::new();
    if oppressive {
        fragments.push("avoid oppressive mood".to_string());
    }
    if frantic {
        fragments.push("avoid frantic mood".to_string());
    }
    if cold {
        fragments.push("avoid overly cold emotional tone".to_string());
    }
    fragments
}

pub(in crate::production::workbench::video::generate) fn filter_conflicting_review_fragments(
    fragments: Vec<String>,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    fragments
        .into_iter()
        .flat_map(|fragment| {
            compact_review_fragments_against_storyboard_style(
                &fragment,
                selected_style_note,
                storyboard_row,
            )
        })
        .filter(|fragment| !review_fragment_is_irrelevant_to_storyboard(fragment, storyboard_row))
        .collect()
}

pub(in crate::production::workbench::video::generate) fn filter_conflicting_negative_fragments(
    fragments: Vec<String>,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    fragments
        .into_iter()
        .flat_map(|fragment| {
            compact_negative_constraint_fragments_against_storyboard_style(
                &fragment,
                selected_style_note,
                storyboard_row,
            )
        })
        .filter(|fragment| !review_fragment_is_irrelevant_to_storyboard(fragment, storyboard_row))
        .collect()
}

fn compact_review_fragments_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let mut compacted = compact_negative_constraint_fragments_against_storyboard_style(
        fragment,
        selected_style_note,
        storyboard_row,
    );
    let conflicts = |value: &str| {
        negative_constraint_conflicts_with_storyboard_style(
            value,
            selected_style_note,
            storyboard_row,
        )
    };

    match canonical_negative_fragment(fragment).as_str() {
        "avoid extreme camera angle or overly tight close-up framing"
            if conflicts("avoid overly tight close-up framing") =>
        {
            compacted
                .retain(|value| canonical_negative_fragment(value) != "avoid extreme camera angle");
        }
        "avoid oppressive or frantic mood" | "avoid overly cold, oppressive, or frantic mood"
            if conflicts("avoid oppressive mood")
                && conflicts("avoid overly cold emotional tone") =>
        {
            compacted.retain(|value| canonical_negative_fragment(value) != "avoid frantic mood");
        }
        _ => {}
    }

    compacted
}

#[allow(dead_code)]
pub(in crate::production::workbench::video::generate) fn review_fragment_conflicts_with_selected_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    negative_constraint_conflicts_with_storyboard_style(
        &canonical_negative_fragment(fragment),
        selected_style_note,
        storyboard_row,
    )
}

pub(in crate::production::workbench::video::generate) fn review_fragment_is_irrelevant_to_storyboard(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    use super::super::fragment_parsing::negative_fragment_family;
    matches!(negative_fragment_family(fragment), "lip_sync_mismatch")
        && storyboard_row.is_some_and(storyboard_has_no_dialogue)
}

fn storyboard_has_no_dialogue(row: &StoryboardPromptSeedRow) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| storyboard_dialogue_is_empty(&fields.dialogue))
}

pub(in crate::production::workbench::video::generate) fn storyboard_dialogue_is_empty(
    dialogue: &str,
) -> bool {
    let normalized = normalize_prompt_text(dialogue);
    let normalized_ascii = normalized.to_ascii_lowercase();
    normalized.is_empty()
        || [
            "无台词",
            "无对白",
            "无旁白",
            "无语音",
            "no dialogue",
            "no voice-over",
            "silent",
        ]
        .iter()
        .map(|marker| normalize_prompt_text(marker).to_ascii_lowercase())
        .any(|marker| normalized_ascii == marker)
}

#[allow(dead_code)]
pub(in crate::production::workbench::video::generate) fn compact_negative_constraint_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let compacted = compact_negative_constraint_fragments_against_storyboard_style(
        fragment,
        selected_style_note,
        storyboard_row,
    );
    match compacted.len() {
        0 => None,
        1 => compacted.into_iter().next(),
        _ => Some(compacted.join(", ")),
    }
}

pub(super) fn compact_review_fragment_against_rejected_memory(
    fragment: &str,
    rejected_fragments: &[String],
) -> Option<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }
    let covered = |value: &str| negative_fragment_is_covered(value, rejected_fragments);
    match canonical_negative_fragment(trimmed).as_str() {
        "avoid extra shot changes or wrong framing" => compact_rejected_overlap_pair(
            trimmed,
            "avoid unnecessary shot changes",
            "avoid extreme camera angle or overly tight close-up framing",
            covered,
        ),
        "avoid rushed or jerky motion" => compact_rejected_overlap_pair(
            trimmed,
            "avoid rushed motion",
            "avoid flicker or motion jitter",
            covered,
        ),
        _ => (!covered(trimmed)).then_some(trimmed.to_string()),
    }
}

fn compact_rejected_overlap_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    covered: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_covered = covered(lhs);
    let rhs_covered = covered(rhs);
    match (lhs_covered, rhs_covered) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}
