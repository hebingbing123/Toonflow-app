use super::*;

mod focus;
mod optimize;
mod store;

pub(crate) use focus::{
    compact_selected_video_memory_for_focus, selected_video_memory_is_low_signal,
};
pub(crate) use optimize::optimize_scoped_video_memory;
pub(crate) use store::{
    clear_selected_video_memory, persist_selected_video_memory, refresh_script_video_style_memory,
};

pub(crate) fn split_prompt_note_fragments(note: &str) -> impl Iterator<Item = String> + '_ {
    note.split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
}

pub(crate) fn build_selected_video_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let note = selected_video_memory_note(row)?;
    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    let mut selected_subject = None;
    let mut residual_subject_hint = None;
    let mut residual_action_hint = None;
    if let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    {
        residual_subject_hint = Some(selected_memory_identity_source(&fields.subject));
        residual_action_hint = compact_selected_memory_action(
            &fields.action,
            Some(fields.subject.as_str()),
            Some(fields.subject.as_str()),
            Some(fields.subject_refs.as_str()),
            Some(fields.setting.as_str()),
            &fields.mood,
        );
        if let Some(subject) =
            selected_memory_subject_identity(&fields.subject, &fields.subject_refs)
        {
            selected_subject = Some(subject.clone());
            parts.push(format!("subject={subject}"));
            let subject_aliases =
                selected_memory_subject_aliases(&fields.subject, &fields.subject_refs)
                    .into_iter()
                    .filter(|alias| alias != &subject)
                    .collect::<Vec<_>>();
            if !subject_aliases.is_empty() {
                parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
            }
        }
    }
    let structured_delivery = selected_video_memory_delivery_from_row(row);
    let style = style_only_note(&note);
    if let Some(style) = style.as_ref() {
        parts.push(format!("style={style}"));
        if let Some(delivery) = structured_delivery
            .as_ref()
            .cloned()
            .or_else(|| selected_video_delivery_value_from_note(style))
            .filter(|value| value != style)
        {
            parts.push(format!("delivery={delivery}"));
        }
    }
    let residual_note = if style.is_some() {
        non_style_note(&note)
    } else {
        Some(note)
    };
    if let Some(note) = residual_note.and_then(|note| {
        let style_coverage = style.as_ref().map(|style| {
            if let Some(delivery) = structured_delivery.as_deref() {
                clip_prompt_fragment(
                    &format!("{style}，{delivery}"),
                    VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                )
            } else {
                style.clone()
            }
        });
        compact_selected_memory_residual_note(
            &note,
            selected_subject
                .as_deref()
                .or(residual_subject_hint.as_deref())
                .filter(|value| !value.is_empty()),
            style_coverage.as_deref(),
            selected_subject.is_some(),
            residual_action_hint.as_deref(),
        )
    }) {
        parts.push(format!("note={note}"));
    }
    let focus_tags = focus::selected_video_memory_focus_tags_from_content_parts(&parts);
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    Some(parts.join(" | "))
}

fn selected_video_memory_delivery_from_row(row: &StoryboardPromptSeedRow) -> Option<String> {
    let fields = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let visible_speech_risk =
        selected_memory_has_visible_speech_performance_risk(&fields, row.prompt.as_deref());
    let performance =
        compact_selected_memory_performance_style(&fields.action, &fields.dialogue, &fields.mood)
            .filter(|_| {
            visible_speech_risk
                || selected_memory_has_high_signal_visual_performance_cue(&fields.action)
        })?;
    let voice = visible_speech_risk
        .then(|| {
            compact_selected_memory_voice_style(&fields.action, &fields.dialogue, &fields.mood)
        })
        .flatten()?;
    compact_selected_memory_delivery_style(Some(&performance), Some(&voice))
}

pub(super) fn compact_summary_video_style_memory_for_focus(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    focus::compact_summary_video_style_memory_for_focus(content, bias)
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn prepare_selected_video_memory_for_storage(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    focus::prepare_selected_video_memory_for_storage(content, bias)
}

pub(super) fn selected_video_memory_focus_tags_from_bias(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Vec<String> {
    focus::selected_video_memory_focus_tags_from_bias(bias)
}

pub(super) fn selected_visual_only_memory_keep_priority(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> (i32, i32, i32) {
    focus::selected_visual_only_memory_keep_priority(content, bias)
}

pub(super) async fn load_selected_video_memory_optimization_bias(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Option<SelectedVideoMemoryOptimizationBias>, ApiError> {
    optimize::load_selected_video_memory_optimization_bias(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await
}

pub(super) async fn load_project_video_memory_optimization_bias(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
) -> Result<Option<SelectedVideoMemoryOptimizationBias>, ApiError> {
    optimize::load_project_video_memory_optimization_bias(pool, user_id, project_numeric_id).await
}

#[cfg_attr(not(test), allow(dead_code))]
pub(super) fn plan_selected_video_memory_optimization(
    rows: &[SelectedVideoMemoryOptimizationCandidate],
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> SelectedVideoMemoryOptimizationPlan {
    optimize::plan_selected_video_memory_optimization(rows, bias)
}
