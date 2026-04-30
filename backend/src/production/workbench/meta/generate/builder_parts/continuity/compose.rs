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
            notes.truncate(1);
        }
    }
    notes
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
