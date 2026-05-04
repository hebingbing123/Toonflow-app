use crate::production::workbench::meta::common::negative_constraint_conflicts_with_storyboard_style;
use crate::production::workbench::meta::generate::constraints::VideoPromptConstraintPressure;
use crate::production::workbench::video_prompt_memory::{
    clip_prompt_fragment, compact_video_style_prompt_note, normalize_prompt_text,
    parse_structured_storyboard_description, select_prioritized_video_style_note,
    select_project_video_style_memory_notes_for_storyboard,
    select_script_video_style_memory_notes_for_storyboard,
    select_subject_role_video_style_memory_notes_for_storyboard, split_prompt_note_fragments,
    AgentMemoryRow, StoryboardPromptSeedRow, StructuredStoryboardDescription,
};

use super::fragment_operations::negative_fragment_is_covered;
use super::fragment_parsing::{canonical_negative_fragment, negative_fragment_family};
use super::negative_prompt_builder::negative_prompt_scene_prefers_restrained_emotional_guard;

pub(super) fn resolve_negative_filter_style_note(
    selected_rows: &[AgentMemoryRow],
    storyboard_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    selected_style_note: Option<String>,
    subject_candidates: &[String],
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let role_style_note = select_subject_role_video_style_memory_notes_for_storyboard(
        selected_rows,
        subject_candidates,
        storyboard_row,
    )
    .into_iter()
    .find(|note| !note.is_empty());
    let exact_style_note = selected_style_note.filter(|note| {
        !negative_filter_exact_style_note_should_yield_to_role_memory(
            note,
            role_style_note.as_deref(),
        )
    });

    exact_style_note
        .or(role_style_note)
        .or_else(|| {
            select_prioritized_video_style_note(
                selected_rows,
                storyboard_id,
                current_prompt_seed,
                storyboard_row,
            )
            .and_then(|note| {
                compact_contextual_negative_style_note(&note, storyboard_row).or_else(|| {
                    storyboard_row
                        .and_then(|row| row.video_desc.as_deref())
                        .and_then(parse_structured_storyboard_description)
                        .filter(|context| style_note_context_evidence(&note, context) >= 2)
                        .and_then(|_| compact_video_style_prompt_note(&note))
                })
            })
        })
        .or_else(|| {
            select_contextual_summary_style_note(
                selected_rows,
                storyboard_row,
                subject_candidates,
                recent_quality_pressure,
            )
        })
}

fn negative_filter_exact_style_note_should_yield_to_role_memory(
    exact_note: &str,
    role_style_note: Option<&str>,
) -> bool {
    role_style_note.is_some()
        && negative_filter_exact_style_note_is_low_signal_local_camera(exact_note)
}

fn negative_filter_exact_style_note_is_low_signal_local_camera(note: &str) -> bool {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    !fragments.is_empty()
        && fragments
            .iter()
            .all(|fragment| negative_filter_low_signal_local_camera_style_fragment(fragment))
}

fn negative_filter_low_signal_local_camera_style_fragment(fragment: &str) -> bool {
    if !fragment.starts_with("镜头") {
        return false;
    }

    let body = normalize_prompt_text(fragment.trim_start_matches("镜头"));
    if body.is_empty() {
        return false;
    }
    if [
        "压迫", "冷峻", "紧张", "逆光", "光影", "情绪", "表演", "语气", "环境", "声场", "雨丝",
        "霓虹", "停顿", "哽咽",
    ]
    .iter()
    .any(|keyword| body.contains(keyword))
    {
        return false;
    }

    [
        "稳定",
        "稳定跟拍",
        "跟拍",
        "近景稳定",
        "中景稳定",
        "远景稳定",
        "特写稳定",
        "全景稳定",
        "近景",
        "中景",
        "远景",
        "特写",
        "全景",
    ]
    .iter()
    .any(|candidate| body == *candidate)
}

fn select_contextual_summary_style_note(
    selected_rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let context = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)?;

    select_subject_role_video_style_memory_notes_for_storyboard(
        selected_rows,
        subject_candidates,
        storyboard_row,
    )
    .into_iter()
    .chain(select_script_video_style_memory_notes_for_storyboard(
        selected_rows,
        storyboard_row,
    ))
    .chain(select_project_video_style_memory_notes_for_storyboard(
        selected_rows,
        storyboard_row,
    ))
    .filter_map(|note| {
        let evidence = style_note_context_evidence(&note, &context);
        let compacted =
            compact_contextual_negative_style_note(&note, storyboard_row).or_else(|| {
                let fallback = compact_video_style_prompt_note(&note)?;
                (evidence >= 2
                    && score_contextual_negative_style_note_bias(
                        &fallback,
                        recent_quality_pressure,
                    ) > 0)
                    .then_some(fallback)
            })?;
        let bias = score_contextual_negative_style_note_bias(&compacted, recent_quality_pressure);
        (evidence >= 2).then_some((evidence, bias, compacted))
    })
    .max_by(
        |(left_evidence, left_bias, left_note), (right_evidence, right_bias, right_note)| {
            left_evidence
                .cmp(right_evidence)
                .then(left_bias.cmp(right_bias))
                .then_with(|| right_note.chars().count().cmp(&left_note.chars().count()))
        },
    )
    .map(|(_, _, note)| note)
}

fn score_contextual_negative_style_note_bias(
    note: &str,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let Some(pressure) = recent_quality_pressure else {
        return 0;
    };

    split_prompt_note_fragments(note).fold(0, |score, fragment| {
        score
            + score_contextual_negative_style_fragment_bias(&fragment, pressure)
            + if pressure.has_emotion_guardrail
                && matches!(
                    negative_style_fragment_axis(&fragment),
                    "performance" | "voice" | "emotion"
                )
            {
                2
            } else {
                0
            }
    })
}

fn score_contextual_negative_style_fragment_bias(
    fragment: &str,
    pressure: VideoPromptConstraintPressure,
) -> i32 {
    match negative_style_fragment_axis(fragment) {
        "performance" => {
            if pressure.prefer_delivery_memory_recall {
                12
            } else {
                2
            }
        }
        "voice" => {
            if pressure.prefer_delivery_memory_recall {
                10
            } else {
                1
            }
        }
        "emotion" => {
            if pressure.prefer_delivery_memory_recall {
                8
            } else {
                1
            }
        }
        "lighting" | "environment" | "sound" => {
            if pressure.prefer_visual_continuity_memory_recall {
                9
            } else {
                1
            }
        }
        "camera" | "motion" => {
            if pressure.prefer_visual_continuity_memory_recall {
                5
            } else {
                0
            }
        }
        _ => 0,
    }
}

fn negative_style_fragment_axis(fragment: &str) -> &'static str {
    if fragment.starts_with("表演") {
        return "performance";
    }
    if fragment.starts_with("语气") {
        return "voice";
    }
    if fragment.starts_with("情绪") {
        return "emotion";
    }
    if fragment.starts_with("光影") {
        return "lighting";
    }
    if fragment.starts_with("环境") {
        return "environment";
    }
    if fragment.starts_with("声场") {
        return "sound";
    }
    if fragment.starts_with("镜头") {
        return "camera";
    }
    if fragment.starts_with("动作") {
        return "motion";
    }
    "other"
}

fn compact_contextual_negative_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return compact_video_style_prompt_note(&normalized);
    };

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let fragments = split_prompt_note_fragments(&normalized)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            negative_style_fragment_matches_storyboard(fragment, &fields, &expected_camera)
        })
        .filter_map(|fragment| trim_negative_style_fragment_against_storyboard(&fragment, &fields))
        .map(|fragment| clip_prompt_fragment(&fragment, 56))
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(&fragments.join("，"), 56))
}

fn negative_style_fragment_matches_storyboard(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    if fragment.starts_with("镜头") {
        return negative_style_fragment_overlaps_field(fragment, &fields.shot, expected_camera)
            || negative_style_fragment_overlaps_field(
                fragment,
                &fields.camera_move,
                expected_camera,
            );
    }
    if fragment.starts_with("情绪") {
        return negative_style_fragment_overlaps_field(fragment, &fields.mood, expected_camera);
    }
    if fragment.starts_with("光影") {
        return negative_style_fragment_overlaps_field(fragment, &fields.lighting, expected_camera);
    }
    false
}

fn trim_negative_style_fragment_against_storyboard(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    if fragment.starts_with("镜头") {
        return trim_negative_style_fragment_prefix(
            fragment,
            "镜头",
            &[fields.shot.as_str(), fields.camera_move.as_str()],
        );
    }
    if fragment.starts_with("情绪") {
        return trim_negative_style_fragment_prefix(fragment, "情绪", &[fields.mood.as_str()]);
    }
    if fragment.starts_with("光影") {
        return trim_negative_style_fragment_prefix(fragment, "光影", &[fields.lighting.as_str()]);
    }
    Some(fragment.to_string())
}

fn trim_negative_style_fragment_prefix(
    fragment: &str,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    let body = fragment.strip_prefix(prefix).unwrap_or(fragment);
    let mut residual = normalize_prompt_text(body);
    for field in fields {
        let normalized_field = normalize_prompt_text(field);
        if normalized_field.is_empty() {
            continue;
        }
        if residual == normalized_field {
            return None;
        }
        residual = residual.replace(&normalized_field, "");
    }
    let residual = normalize_prompt_text(&residual);
    if residual.is_empty() {
        None
    } else {
        Some(format!("{prefix}{residual}"))
    }
}

fn negative_style_fragment_overlaps_field(
    fragment: &str,
    field: &str,
    expected_camera: &str,
) -> bool {
    let normalized_field = normalize_prompt_text(field);
    if normalized_field.is_empty() {
        return false;
    }
    let canonical = canonical_negative_style_fragment(fragment);
    !canonical.is_empty()
        && (canonical == normalized_field
            || canonical.contains(&normalized_field)
            || normalized_field.contains(&canonical)
            || (!expected_camera.is_empty()
                && canonical == expected_camera
                && (expected_camera.contains(&normalized_field)
                    || normalized_field.contains(expected_camera))))
}

fn canonical_negative_style_fragment(fragment: &str) -> String {
    normalize_prompt_text(
        fragment
            .strip_prefix("镜头")
            .or_else(|| fragment.strip_prefix("情绪"))
            .or_else(|| fragment.strip_prefix("光影"))
            .unwrap_or(fragment),
    )
}

fn style_note_context_evidence(
    style_note: &str,
    context: &StructuredStoryboardDescription,
) -> usize {
    let note = normalize_prompt_text(style_note);
    let mut evidence = 0usize;

    let mood = normalize_prompt_text(&context.mood);
    if !mood.is_empty() && note.contains(&mood) {
        evidence += 1;
    }

    let lighting = normalize_prompt_text(&context.lighting);
    if !lighting.is_empty() && note.contains(&lighting) {
        evidence += 1;
    }

    let shot = normalize_prompt_text(&context.shot);
    let camera_move = normalize_prompt_text(&context.camera_move);
    if (!shot.is_empty() && note.contains(&shot))
        || (!camera_move.is_empty() && note.contains(&camera_move))
    {
        evidence += 1;
    }

    evidence
}

pub(super) fn filter_conflicting_review_fragments(
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

pub(super) fn filter_conflicting_negative_fragments(
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

pub(super) fn compact_review_fragments_against_rejected_memory(
    review_fragments: Vec<String>,
    rejected_fragments: &[String],
) -> Vec<String> {
    review_fragments
        .into_iter()
        .filter_map(|fragment| {
            compact_review_fragment_against_rejected_memory(&fragment, rejected_fragments)
        })
        .collect()
}

pub(super) fn compact_rejected_fragments_against_review_focus(
    rejected_fragments: Vec<String>,
    review_fragments: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return rejected_fragments;
    };
    if !negative_prompt_scene_prefers_restrained_emotional_guard(&fields) {
        return rejected_fragments;
    }
    let review_has_performance_guard = review_fragments
        .iter()
        .any(|fragment| negative_fragment_family(fragment) == "performance_delivery");
    if !review_has_performance_guard {
        return rejected_fragments;
    }

    rejected_fragments
        .into_iter()
        .filter(|fragment| canonical_negative_fragment(fragment) != "avoid frantic mood")
        .collect()
}

fn compact_review_fragment_against_rejected_memory(
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

#[allow(dead_code)]
pub(super) fn review_fragment_conflicts_with_selected_style(
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

pub(super) fn review_fragment_is_irrelevant_to_storyboard(
    fragment: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    matches!(negative_fragment_family(fragment), "lip_sync_mismatch")
        && storyboard_row.is_some_and(storyboard_has_no_dialogue)
}

fn storyboard_has_no_dialogue(row: &StoryboardPromptSeedRow) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| storyboard_dialogue_is_empty(&fields.dialogue))
}

pub(super) fn storyboard_dialogue_is_empty(dialogue: &str) -> bool {
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
pub(super) fn compact_negative_constraint_against_storyboard_style(
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

fn compact_negative_constraint_fragments_against_storyboard_style(
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
