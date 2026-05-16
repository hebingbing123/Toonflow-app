use super::super::super::*;
use super::super::continuity_pressure::continuity_note_pressure_score;
use super::compact::compact_continuity_note;
use super::risk::continuity_note_matches_storyboard_risk;

pub(in crate::production::workbench::meta::generate) fn build_continuity_notes(
    context: Option<&VideoPromptContext>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    memory_budget_tier: VideoPromptMemoryBudgetTier,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<String> {
    let mut notes = context
        .map(|ctx| {
            ctx.continuity_notes
                .iter()
                .filter_map(|note| {
                    compact_continuity_note(note, structured_fields, prompt_coverage)
                })
                .filter(|note| continuity_note_matches_storyboard_risk(note, structured_fields))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    if notes.is_empty() {
        if let (Some(ctx), Some(fields)) = (context, structured_fields) {
            if let Some(fallback) = ctx
                .continuity_notes
                .iter()
                .find_map(|note| fallback_high_signal_continuity_note(note, fields))
            {
                notes.push(fallback);
            }
        }
    }
    notes.sort_by(|a, b| {
        continuity_note_pressure_score(b, constraint_pressure)
            .cmp(&continuity_note_pressure_score(a, constraint_pressure))
            .then(
                super::super::super::builder::score_continuity_specificity(b).cmp(
                    &super::super::super::builder::score_continuity_specificity(a),
                ),
            )
            .then(
                super::super::super::builder::score_continuity_note(b, structured_fields).cmp(
                    &super::super::super::builder::score_continuity_note(a, structured_fields),
                ),
            )
            .then(a.len().cmp(&b.len()))
            .then(a.cmp(b))
    });
    if let Some(pressure) = constraint_pressure.filter(|pressure| pressure.forces_compact_memory) {
        let has_guardrail_specific_note = notes
            .iter()
            .any(|note| continuity_note_pressure_score(note, Some(pressure)) > 0);
        if has_guardrail_specific_note {
            notes.retain(|note| continuity_note_pressure_score(note, Some(pressure)) > 0);
        }
    }
    match memory_budget_tier {
        VideoPromptMemoryBudgetTier::Expanded => {
            notes.truncate(VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT);
        }
        VideoPromptMemoryBudgetTier::Lean => {
            notes.retain(|note| continuity_note_is_lean_critical(note));
            notes
                .retain(|note| note.chars().count() <= VIDEO_PROMPT_LEAN_CONTINUITY_NOTE_MAX_CHARS);
            let keep_two_axis_notes = constraint_pressure.is_some_and(|pressure| {
                pressure.forces_compact_memory
                    && (pressure.has_identity_guardrail || pressure.has_dialogue_guardrail)
            });
            if keep_two_axis_notes {
                let mut seen_axes = Vec::new();
                notes.retain(|note| {
                    let axis = normalize_prompt_text(note);
                    let family = if axis.contains("视线") || axis.contains("方向") {
                        "direction"
                    } else if axis.contains("站位")
                        || axis.contains("走位")
                        || axis.contains("跳轴")
                    {
                        "positioning"
                    } else {
                        "other"
                    };
                    if seen_axes.contains(&family) {
                        return false;
                    }
                    seen_axes.push(family);
                    true
                });
                notes.truncate(2);
            } else {
                notes.truncate(1);
            }
        }
    }
    notes
}

fn fallback_high_signal_continuity_note(
    note: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }

    if normalized.contains("视线方向一致")
        && [
            fields.subject.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
        ]
        .into_iter()
        .any(|value| {
            ["对视", "看向", "望向", "抬眼", "回头"]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
    {
        return Some("视线方向一致".to_string());
    }
    if normalized.contains("站位")
        && normalized.contains("跳轴")
        && continuity_note_matches_storyboard_risk("站位不要跳轴", Some(fields))
    {
        return Some("站位不要跳轴".to_string());
    }

    None
}

pub(in crate::production::workbench::meta::generate) fn continuity_note_is_lean_critical(
    note: &str,
) -> bool {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty()
        || !super::super::super::builder::continuity_note_adds_specific_guidance(&normalized)
    {
        return false;
    }

    ["跳轴", "视线", "构图", "方向", "站位", "走位", "前后景"]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}
