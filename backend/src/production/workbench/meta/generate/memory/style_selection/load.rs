use super::*;

pub(in crate::production::workbench::meta::generate) fn rejected_video_memory_selection_bias(
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<VideoPromptMemorySelectionBias> {
    constraint_pressure.and_then(|pressure| {
        let bias = VideoPromptMemorySelectionBias {
            prefer_delivery: pressure.prefer_delivery_memory_recall,
            prefer_visual_continuity: pressure.prefer_visual_continuity_memory_recall,
        };
        (bias.prefer_delivery || bias.prefer_visual_continuity).then_some(bias)
    })
}

#[allow(clippy::too_many_arguments)]
pub(in crate::production::workbench::meta::generate) async fn load_video_prompt_memory_notes(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> Result<(Vec<String>, Vec<String>), ApiError> {
    let rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN ('selected_video_memory', 'script_video_style_memory', 'script_video_generation_brief_memory', 'script_role_video_style_memory', 'auto_scope_memory'))
            OR (episodes_id IS NULL AND name IN ('project_video_style_memory', 'project_video_generation_brief_memory', 'project_role_video_style_memory'))
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(VIDEO_PROMPT_MEMORY_ROW_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(build_video_prompt_memory_notes_with_pressure(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        constraint_pressure,
    ))
}

#[cfg_attr(not(test), allow(dead_code))]
pub(in crate::production::workbench::meta::generate) fn build_video_prompt_memory_notes(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
) -> (Vec<String>, Vec<String>) {
    build_video_prompt_memory_notes_with_pressure(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        None,
    )
}

pub(in crate::production::workbench::meta::generate) fn build_video_prompt_memory_notes_with_pressure(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
    constraint_pressure: Option<VideoPromptConstraintPressure>,
) -> (Vec<String>, Vec<String>) {
    let subject_candidates = storyboard_row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let rows = trim_video_prompt_memory_rows_with_context(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &subject_candidates,
        Some(storyboard_row),
        constraint_pressure,
    );
    let style_notes = super::compact::compact_guardrail_sensitive_style_notes(
        super::select::select_video_prompt_style_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            storyboard_row,
            constraint_pressure,
        ),
        storyboard_row,
        constraint_pressure,
    );
    let style_notes = super::compact::restore_runtime_exact_style_note_fragments(
        style_notes,
        &rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
    );
    let continuity_notes = {
        let selected = select_video_prompt_memory_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            Some(storyboard_row),
        );
        if selected.is_empty() {
            super::select::select_runtime_action_continuity_fallback(
                &rows,
                storyboard_numeric_id,
                current_prompt_seed,
                storyboard_row,
            )
            .into_iter()
            .collect()
        } else {
            selected
        }
    };
    (style_notes.into_iter().collect(), continuity_notes)
}
