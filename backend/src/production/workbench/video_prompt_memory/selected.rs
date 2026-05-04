use super::style_compact::{
    selected_style_fragment_is_generic_restrained_mood, selected_style_fragment_is_low_gain_motion,
    selected_style_fragment_is_low_gain_voice,
};
use super::*;

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
    let focus_tags = selected_video_memory_focus_tags_from_content_parts(&parts);
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

pub(crate) fn compact_selected_video_memory_for_focus(
    content: &str,
    focus_tags: &[String],
) -> String {
    let bias = selected_video_memory_focus_bias_from_tags(focus_tags);
    if bias == SelectedVideoMemoryOptimizationBias::default() {
        return content.to_string();
    }

    let style = extract_key_value(content, "style");
    let delivery = extract_key_value(content, "delivery");
    let subject_present = extract_key_value(content, "subject")
        .map(|value| !normalize_prompt_text(&value).is_empty())
        .unwrap_or(false)
        || extract_key_value(content, "subjectAliases")
            .map(|value| !normalize_prompt_text(&value).is_empty())
            .unwrap_or(false);

    let compacted_style = style.as_deref().and_then(|style| {
        compact_selected_video_memory_style_for_focus(
            style,
            delivery.as_deref(),
            bias,
            subject_present,
            false,
        )
    });
    let mut rebuilt = Vec::new();

    for part in content.split('|') {
        let part = part.trim();
        if part.is_empty() {
            continue;
        }
        if part.starts_with("style=") {
            if let Some(style) = compacted_style.as_deref() {
                rebuilt.push(format!("style={style}"));
            }
            continue;
        }
        rebuilt.push(part.to_string());
    }

    rebuilt.join(" | ")
}

pub(crate) fn selected_video_memory_is_low_signal(content: &str) -> bool {
    selected_video_memory_is_scope_filler(content)
}

pub(crate) async fn persist_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let optimization_bias = load_selected_video_memory_optimization_bias(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;
    let Some(content) = prepare_selected_video_memory_for_storage(content, optimization_bias)
    else {
        return Ok(());
    };
    let latest_same_scope = load_latest_selected_video_memory_for_scope(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &content,
    )
    .await?;

    if latest_same_scope.as_deref() == Some(content.as_str()) {
        return Ok(());
    }
    if latest_same_scope.as_deref().is_some_and(|existing| {
        selected_video_memory_update_would_reduce_quality_with_bias(
            existing,
            &content,
            optimization_bias,
        )
    }) {
        return Ok(());
    }

    delete_selected_video_memory_for_scope(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &content,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(&content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(super) fn prepare_selected_video_memory_for_storage(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let focus_tags = selected_video_memory_focus_tags_from_bias(bias);
    let compacted = if focus_tags.is_empty() {
        strip_key_from_memory_content(content, "focusTags")
    } else {
        compact_selected_video_memory_for_focus(content, &focus_tags)
    };
    if selected_video_memory_is_low_signal(&compacted) {
        return None;
    }

    let stripped = strip_key_from_memory_content(&compacted, "focusTags");
    let rebuilt_focus_tags = selected_video_memory_focus_tags_from_content_parts(
        &stripped
            .split('|')
            .map(str::trim)
            .filter(|part| !part.is_empty())
            .map(ToString::to_string)
            .collect::<Vec<_>>(),
    );

    Some(rebuild_memory_content_with_focus_tags(
        &stripped,
        &rebuilt_focus_tags,
    ))
}

async fn load_latest_selected_video_memory_for_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<Option<String>, ApiError> {
    let Some(scope) = selected_video_memory_scope(content) else {
        return Ok(None);
    };

    let rows = sqlx::query_scalar::<_, String>(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .find(|existing| selected_video_memory_scope(existing).as_ref() == Some(&scope)))
}

async fn delete_selected_video_memory_for_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let Some(scope) = selected_video_memory_scope(content) else {
        return Ok(());
    };

    let rows = sqlx::query_as::<_, (i64, String)>(
        r#"
        SELECT id, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let duplicate_ids = rows
        .into_iter()
        .filter_map(|(id, existing)| {
            (selected_video_memory_scope(&existing).as_ref() == Some(&scope)).then_some(id)
        })
        .collect::<Vec<_>>();
    if duplicate_ids.is_empty() {
        return Ok(());
    }

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id = ANY($1)
        "#,
    )
    .bind(&duplicate_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn optimize_scoped_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<VideoMemoryOptimizationResult, ApiError> {
    let rows = sqlx::query_as::<_, OptimizableAgentMemoryRow>(
        r#"
        SELECT id, content, create_time_ms
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC, id DESC
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let optimization_bias = load_selected_video_memory_optimization_bias(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;

    let plan = plan_selected_video_memory_optimization(
        &rows
            .into_iter()
            .map(|row| SelectedVideoMemoryOptimizationCandidate {
                id: row.id,
                content: row.content,
                create_time_ms: row.create_time_ms,
            })
            .collect::<Vec<_>>(),
        optimization_bias,
    );
    if plan.delete_ids.is_empty() {
        return Ok(VideoMemoryOptimizationResult {
            removed_rows: 0,
            removed_chars: 0,
            removed_visual_rows: 0,
            removed_duplicate_rows: 0,
            refreshed_script_summary: false,
            refreshed_project_summary: false,
        });
    }

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id = ANY($1)
        "#,
    )
    .bind(&plan.delete_ids)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    refresh_script_video_style_memory(pool, user_id, project_numeric_id, script_numeric_id).await?;
    refresh_project_video_style_memory(pool, user_id, project_numeric_id).await?;

    Ok(VideoMemoryOptimizationResult {
        removed_rows: plan.delete_ids.len(),
        removed_chars: plan.removed_chars,
        removed_visual_rows: plan.removed_visual_rows,
        removed_duplicate_rows: plan.removed_duplicate_rows,
        refreshed_script_summary: true,
        refreshed_project_summary: true,
    })
}

pub(crate) async fn refresh_script_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(), ApiError> {
    let optimization_bias = load_selected_video_memory_optimization_bias(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;
    let selected_rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let rejected_rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summarized = build_script_video_style_memory_with_bias(
        &selected_rows,
        &rejected_rows,
        optimization_bias,
    );
    let observation_summary = build_script_video_observation_memory_with_bias(
        &rejected_rows,
        selected_optimization_bias_to_rejected_selection_bias(optimization_bias),
    );
    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_STYLE_MEMORY_NAME,
        summarized.as_deref(),
        SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME,
        build_script_role_video_style_memories(&selected_rows),
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME,
        build_video_generation_brief_memory(
            summarized.as_deref(),
            observation_summary.as_deref(),
            optimization_bias,
        )
        .as_deref(),
        SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME,
        observation_summary.as_deref(),
        SCRIPT_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await?;

    replace_summary_memories(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME,
        build_script_role_video_observation_memories_with_bias(
            &rejected_rows,
            selected_optimization_bias_to_rejected_selection_bias(optimization_bias),
        ),
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_KEEP_ROWS,
    )
    .await
}

pub(super) async fn load_selected_video_memory_optimization_bias(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Option<SelectedVideoMemoryOptimizationBias>, ApiError> {
    let rows = sqlx::query_as::<_, OptimizationQualityFocusDbRow>(
        r#"
        SELECT model_params->'diagnostics'->'feedbackMemory'->'focusTags' as feedback_memory_focus_tags
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND script_id = $3
          AND target_type IN ('storyboard', 'output', 'video', 'asset')
        ORDER BY created_at DESC
        LIMIT 16
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut bias = SelectedVideoMemoryOptimizationBias::default();
    for row in rows {
        for tag in row
            .feedback_memory_focus_tags
            .as_ref()
            .and_then(serde_json::Value::as_array)
            .into_iter()
            .flat_map(|items| items.iter())
            .filter_map(serde_json::Value::as_str)
        {
            match tag {
                "delivery_realism" => bias.prefer_delivery = true,
                "emotion_arc" => bias.prefer_emotion = true,
                "identity_continuity" => bias.prefer_identity = true,
                "lighting_realism" => bias.prefer_lighting = true,
                _ => {}
            }
        }
    }

    Ok((bias.prefer_delivery
        || bias.prefer_emotion
        || bias.prefer_identity
        || bias.prefer_lighting)
        .then_some(bias))
}

pub(super) async fn load_project_video_memory_optimization_bias(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
) -> Result<Option<SelectedVideoMemoryOptimizationBias>, ApiError> {
    let rows = sqlx::query_as::<_, OptimizationQualityFocusDbRow>(
        r#"
        SELECT model_params->'diagnostics'->'feedbackMemory'->'focusTags' as feedback_memory_focus_tags
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND target_type IN ('storyboard', 'output', 'video', 'asset')
        ORDER BY created_at DESC
        LIMIT 32
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut bias = SelectedVideoMemoryOptimizationBias::default();
    for row in rows {
        for tag in row
            .feedback_memory_focus_tags
            .as_ref()
            .and_then(serde_json::Value::as_array)
            .into_iter()
            .flat_map(|items| items.iter())
            .filter_map(serde_json::Value::as_str)
        {
            match tag {
                "delivery_realism" => bias.prefer_delivery = true,
                "emotion_arc" => bias.prefer_emotion = true,
                "identity_continuity" => bias.prefer_identity = true,
                "lighting_realism" => bias.prefer_lighting = true,
                _ => {}
            }
        }
    }

    Ok((bias.prefer_delivery
        || bias.prefer_emotion
        || bias.prefer_identity
        || bias.prefer_lighting)
        .then_some(bias))
}

pub(super) fn plan_selected_video_memory_optimization(
    rows: &[SelectedVideoMemoryOptimizationCandidate],
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> SelectedVideoMemoryOptimizationPlan {
    if rows.is_empty() {
        return SelectedVideoMemoryOptimizationPlan::default();
    }

    let mut delete_ids = Vec::<i64>::new();
    let mut delete_chars = 0usize;
    let mut removed_duplicate_rows = 0usize;
    let mut seen_keys = std::collections::HashSet::<String>::new();
    let mut kept_rows = Vec::<EffectiveSelectedVideoMemoryOptimizationCandidate>::new();
    let allow_low_signal_fallback = rows.len() > 1;

    for row in rows {
        let effective_content = match prepare_selected_video_memory_for_storage(&row.content, bias)
        {
            Some(content) => content,
            None if allow_low_signal_fallback => row.content.clone(),
            None => {
                delete_ids.push(row.id);
                delete_chars += row.content.chars().count();
                continue;
            }
        };
        let dedupe_key = selected_video_memory_semantic_dedupe_key(&effective_content);
        if !dedupe_key.is_empty() && !seen_keys.insert(dedupe_key) {
            delete_ids.push(row.id);
            delete_chars += row.content.chars().count();
            removed_duplicate_rows += 1;
            continue;
        }
        kept_rows.push(EffectiveSelectedVideoMemoryOptimizationCandidate {
            row,
            content: effective_content,
        });
    }

    let mut scope_groups = std::collections::HashMap::<
        String,
        Vec<&EffectiveSelectedVideoMemoryOptimizationCandidate>,
    >::new();
    for row in &kept_rows {
        let key = selected_video_memory_storyboard_scope_key(&row.content);
        if key.is_empty() {
            continue;
        }
        scope_groups.entry(key).or_default().push(row);
    }
    for group in scope_groups.into_values() {
        if group.len() < 2 {
            continue;
        }
        let mut ranked = group
            .into_iter()
            .map(|row| {
                (
                    selected_video_memory_bias_alignment_score(&row.content, bias),
                    selected_video_memory_quality_score(&row.content),
                    row.row.create_time_ms,
                    row.row.id,
                    row,
                )
            })
            .collect::<Vec<_>>();
        ranked.sort_by(|a, b| {
            b.0.cmp(&a.0)
                .then(b.1.cmp(&a.1))
                .then(b.2.cmp(&a.2))
                .then(b.3.cmp(&a.3))
        });
        let active_focus_mask = selected_video_memory_active_focus_mask(bias);
        let best_alignment = ranked.first().map(|entry| entry.0).unwrap_or_default();
        let best_score = ranked.first().map(|entry| entry.1).unwrap_or_default();
        let best_is_focus_aligned = ranked.first().is_some_and(|entry| entry.0 > 0);
        let best_content = ranked
            .first()
            .map(|entry| entry.4.content.as_str())
            .unwrap_or_default();
        let best_focus_mask = ranked
            .first()
            .map(|entry| selected_video_memory_focus_mask(&entry.4.content) & active_focus_mask)
            .unwrap_or_default();
        let best_focus_coverage = ranked
            .first()
            .map(|entry| selected_video_memory_focus_coverage_score(&entry.4.content, bias))
            .unwrap_or_default();
        let best_priority = best_alignment * 4 + best_focus_coverage * 10 + best_score;
        for (alignment_score, score, _, _, row) in ranked.into_iter().skip(1) {
            if delete_ids.contains(&row.row.id) {
                continue;
            }
            if bias.is_none()
                && selected_video_memory_is_scope_filler(&row.content)
                && selected_video_memory_visual_signal_count(&row.content) > 0
                && !selected_video_memory_is_visual_only(&row.content)
            {
                continue;
            }
            if bias.is_none()
                && selected_video_memory_is_visual_only(&row.content)
                && !selected_video_memory_is_visual_only(best_content)
            {
                continue;
            }
            let candidate_focus_mask =
                selected_video_memory_focus_mask(&row.content) & active_focus_mask;
            let candidate_focus_coverage =
                selected_video_memory_focus_coverage_score(&row.content, bias);
            let adds_unique_focus = candidate_focus_mask & !best_focus_mask != 0;
            let is_focus_redundant =
                active_focus_mask != 0 && best_focus_mask != 0 && !adds_unique_focus;
            let candidate_priority = alignment_score * 4 + candidate_focus_coverage * 10 + score;
            let threshold = if best_is_focus_aligned && alignment_score == 0 {
                8
            } else if is_focus_redundant {
                6
            } else {
                14
            };
            let should_delete_scope_row = selected_video_memory_is_scope_filler(&row.content)
                || (is_focus_redundant && (alignment_score < best_alignment || score < best_score));
            if should_delete_scope_row && best_priority >= candidate_priority + threshold {
                delete_ids.push(row.row.id);
                delete_chars += row.row.content.chars().count();
            }
        }
    }

    let delivery_rows = kept_rows
        .iter()
        .filter(|row| selected_video_memory_has_delivery_anchor(&row.content))
        .count();
    let visual_rows = kept_rows
        .iter()
        .filter(|row| selected_video_memory_is_visual_only(&row.content))
        .collect::<Vec<_>>();
    let keep_visual_ids = selected_visual_only_memory_keep_ids(&visual_rows, bias);
    let should_prune_visual_rows = (delivery_rows > 0 && visual_rows.len() > keep_visual_ids.len())
        || visual_focus_bias_is_hot(bias)
        || visual_rows.len() > keep_visual_ids.len().saturating_add(1);
    if should_prune_visual_rows {
        for row in visual_rows {
            if delete_ids.contains(&row.row.id) || keep_visual_ids.contains(&row.row.id) {
                continue;
            }
            delete_ids.push(row.row.id);
            delete_chars += row.row.content.chars().count();
        }
    }

    if let Some(active_bias) =
        bias.filter(|value| *value != SelectedVideoMemoryOptimizationBias::default())
    {
        let surviving_rows = kept_rows
            .iter()
            .filter(|row| !delete_ids.contains(&row.row.id))
            .collect::<Vec<_>>();
        let focus_anchor_count = surviving_rows
            .iter()
            .filter(|row| {
                selected_video_memory_bias_alignment_score(&row.content, Some(active_bias)) > 0
                    && !selected_video_memory_is_scope_filler(&row.content)
            })
            .count();
        let best_focus_priority = surviving_rows
            .iter()
            .filter_map(|row| {
                let alignment =
                    selected_video_memory_bias_alignment_score(&row.content, Some(active_bias));
                (alignment > 0)
                    .then_some(alignment + selected_video_memory_quality_score(&row.content))
            })
            .max()
            .unwrap_or_default();
        let best_focus_tag_coverage = surviving_rows
            .iter()
            .map(|row| selected_video_memory_tag_coverage_score(&row.row.content, active_bias))
            .max()
            .unwrap_or_default();

        if (focus_anchor_count >= 2 || (focus_anchor_count == 1 && best_focus_tag_coverage >= 3))
            && best_focus_priority > 0
        {
            for row in surviving_rows {
                if !selected_video_memory_is_scope_filler(&row.content) {
                    continue;
                }
                let row_quality = selected_video_memory_quality_score(&row.content);
                if best_focus_priority >= row_quality + 18 {
                    delete_ids.push(row.row.id);
                    delete_chars += row.row.content.chars().count();
                }
            }
        }
    }

    delete_ids.sort_unstable();
    delete_ids.dedup();
    let removed_visual_rows = delete_ids
        .iter()
        .filter(|id| {
            rows.iter()
                .any(|row| row.id == **id && selected_video_memory_is_visual_only(&row.content))
        })
        .count()
        .saturating_sub(removed_duplicate_rows);

    SelectedVideoMemoryOptimizationPlan {
        delete_ids,
        removed_chars: delete_chars,
        removed_visual_rows,
        removed_duplicate_rows,
    }
}

pub(super) fn selected_visual_only_memory_keep_priority(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> (i32, i32, i32) {
    (
        selected_video_memory_bias_alignment_score(content, bias),
        selected_video_memory_focus_coverage_score(content, bias),
        selected_video_memory_quality_score(content),
    )
}

fn selected_visual_only_memory_keep_ids(
    rows: &[&EffectiveSelectedVideoMemoryOptimizationCandidate<'_>],
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> std::collections::HashSet<i64> {
    let mut keep_ids = std::collections::HashSet::new();
    let Some(bias) = bias else {
        if let Some(best) = select_best_visual_only_memory_row(rows, None, None) {
            keep_ids.insert(best.row.id);
        }
        return keep_ids;
    };

    if bias.prefer_identity {
        if let Some(best) = select_best_visual_only_memory_row(
            rows,
            Some(selected_video_memory_has_identity_anchor),
            Some(bias),
        ) {
            keep_ids.insert(best.row.id);
        }
    }
    if bias.prefer_lighting {
        if let Some(best) = select_best_visual_only_memory_row(
            rows,
            Some(selected_video_memory_has_lighting_anchor),
            Some(bias),
        ) {
            keep_ids.insert(best.row.id);
        }
    }
    if keep_ids.is_empty() {
        if let Some(best) = select_best_visual_only_memory_row(rows, None, Some(bias)) {
            keep_ids.insert(best.row.id);
        }
    }
    keep_ids
}

fn select_best_visual_only_memory_row<'a>(
    rows: &'a [&'a EffectiveSelectedVideoMemoryOptimizationCandidate<'a>],
    predicate: Option<fn(&str) -> bool>,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<&'a EffectiveSelectedVideoMemoryOptimizationCandidate<'a>> {
    rows.iter()
        .copied()
        .filter(|row| match predicate {
            Some(check) => check(&row.content),
            None => true,
        })
        .max_by(|left, right| {
            if bias.is_none() {
                left.row
                    .create_time_ms
                    .cmp(&right.row.create_time_ms)
                    .then(
                        selected_visual_only_memory_keep_priority(&left.content, bias).cmp(
                            &selected_visual_only_memory_keep_priority(&right.content, bias),
                        ),
                    )
                    .then(left.row.id.cmp(&right.row.id))
            } else {
                selected_visual_only_memory_keep_priority(&left.content, bias)
                    .cmp(&selected_visual_only_memory_keep_priority(
                        &right.content,
                        bias,
                    ))
                    .then(left.row.create_time_ms.cmp(&right.row.create_time_ms))
                    .then(left.row.id.cmp(&right.row.id))
            }
        })
}

fn visual_focus_bias_is_hot(bias: Option<SelectedVideoMemoryOptimizationBias>) -> bool {
    bias.is_some_and(|bias| bias.prefer_identity || bias.prefer_lighting)
}

fn selected_video_memory_bias_alignment_score(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };

    let mut score = 0;
    let focus_tags = selected_video_memory_focus_tags_from_content(content);
    if bias.prefer_delivery
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "delivery_realism",
            selected_video_memory_has_delivery_anchor,
        )
    {
        score += 16;
    }
    if bias.prefer_emotion
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "emotion_arc",
            selected_video_memory_has_emotion_anchor,
        )
    {
        score += 14;
    }
    if bias.prefer_identity
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "identity_continuity",
            selected_video_memory_has_identity_anchor,
        )
    {
        score += 12;
    }
    if bias.prefer_lighting
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "lighting_realism",
            selected_video_memory_has_lighting_anchor,
        )
    {
        score += 12;
    }
    score
}

fn selected_video_memory_focus_coverage_score(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };

    let focus_tags = selected_video_memory_focus_tags_from_content(content);
    let mut score = 0;
    if bias.prefer_delivery
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "delivery_realism",
            selected_video_memory_has_delivery_anchor,
        )
    {
        score += 1;
    }
    if bias.prefer_emotion
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "emotion_arc",
            selected_video_memory_has_emotion_anchor,
        )
    {
        score += 1;
    }
    if bias.prefer_identity
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "identity_continuity",
            selected_video_memory_has_identity_anchor,
        )
    {
        score += 1;
    }
    if bias.prefer_lighting
        && selected_video_memory_tag_or_anchor_matches(
            &focus_tags,
            content,
            "lighting_realism",
            selected_video_memory_has_lighting_anchor,
        )
    {
        score += 1;
    }

    score
}

fn selected_video_memory_tag_coverage_score(
    content: &str,
    bias: SelectedVideoMemoryOptimizationBias,
) -> i32 {
    let focus_tags = selected_video_memory_focus_tags_from_content(content);
    let mut score = 0;
    if bias.prefer_delivery && focus_tags.iter().any(|tag| tag == "delivery_realism") {
        score += 1;
    }
    if bias.prefer_emotion && focus_tags.iter().any(|tag| tag == "emotion_arc") {
        score += 1;
    }
    if bias.prefer_identity && focus_tags.iter().any(|tag| tag == "identity_continuity") {
        score += 1;
    }
    if bias.prefer_lighting && focus_tags.iter().any(|tag| tag == "lighting_realism") {
        score += 1;
    }
    score
}

fn selected_video_memory_active_focus_mask(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> u8 {
    let Some(bias) = bias else {
        return 0;
    };

    let mut mask = 0;
    if bias.prefer_delivery {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_DELIVERY;
    }
    if bias.prefer_emotion {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_EMOTION;
    }
    if bias.prefer_identity {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_IDENTITY;
    }
    if bias.prefer_lighting {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_LIGHTING;
    }
    mask
}

fn selected_video_memory_focus_mask(content: &str) -> u8 {
    let mut mask = 0;
    if selected_video_memory_has_delivery_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_DELIVERY;
    }
    if selected_video_memory_has_emotion_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_EMOTION;
    }
    if selected_video_memory_has_identity_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_IDENTITY;
    }
    if selected_video_memory_has_lighting_anchor(content) {
        mask |= SELECTED_VIDEO_MEMORY_FOCUS_LIGHTING;
    }
    mask
}

fn selected_video_memory_tag_or_anchor_matches(
    focus_tags: &[String],
    content: &str,
    tag: &str,
    anchor_check: fn(&str) -> bool,
) -> bool {
    focus_tags.iter().any(|value| value == tag) || anchor_check(content)
}

fn selected_video_memory_focus_bias_from_tags(
    focus_tags: &[String],
) -> SelectedVideoMemoryOptimizationBias {
    let mut bias = SelectedVideoMemoryOptimizationBias::default();
    for tag in focus_tags {
        match tag.as_str() {
            "delivery_realism" => bias.prefer_delivery = true,
            "emotion_arc" => bias.prefer_emotion = true,
            "identity_continuity" => bias.prefer_identity = true,
            "lighting_realism" => bias.prefer_lighting = true,
            _ => {}
        }
    }
    bias
}

pub(super) fn selected_video_memory_focus_tags_from_bias(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Vec<String> {
    let Some(bias) = bias else {
        return Vec::new();
    };
    let mut tags = Vec::new();
    if bias.prefer_delivery {
        tags.push("delivery_realism".to_string());
    }
    if bias.prefer_emotion {
        tags.push("emotion_arc".to_string());
    }
    if bias.prefer_identity {
        tags.push("identity_continuity".to_string());
    }
    if bias.prefer_lighting {
        tags.push("lighting_realism".to_string());
    }
    tags
}

fn selected_video_memory_focus_tags_from_content(content: &str) -> Vec<String> {
    extract_key_value(content, "focusTags")
        .map(|value| {
            value
                .split('/')
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

fn selected_video_memory_focus_tags_from_content_parts(parts: &[String]) -> Vec<String> {
    let style = parts
        .iter()
        .find_map(|part| part.strip_prefix("style="))
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let delivery = parts
        .iter()
        .find_map(|part| part.strip_prefix("delivery="))
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let note = parts
        .iter()
        .find_map(|part| part.strip_prefix("note="))
        .map(normalize_prompt_text)
        .unwrap_or_default();
    let subject_present = parts.iter().any(|part| {
        part.strip_prefix("subject=")
            .map(normalize_prompt_text)
            .filter(|value| !value.is_empty())
            .is_some()
            || part
                .strip_prefix("subjectAliases=")
                .map(normalize_prompt_text)
                .filter(|value| !value.is_empty())
                .is_some()
    });

    let combined = [style.as_str(), delivery.as_str(), note.as_str()].join(" ");
    let mut tags = Vec::new();
    let mut push_tag = |tag: &str| {
        if !tags.iter().any(|existing| existing == tag) {
            tags.push(tag.to_string());
        }
    };

    if selected_video_memory_has_delivery_anchor(&combined) {
        push_tag("delivery_realism");
    }
    if selected_video_memory_has_emotion_anchor(&combined) {
        push_tag("emotion_arc");
    }
    if subject_present || selected_video_memory_has_identity_anchor(&combined) {
        push_tag("identity_continuity");
    }
    if selected_video_memory_has_lighting_anchor(&combined) {
        push_tag("lighting_realism");
    }

    tags
}

fn strip_key_from_memory_content(content: &str, key: &str) -> String {
    content
        .split('|')
        .map(str::trim)
        .filter(|part| !part.is_empty() && !part.starts_with(&format!("{key}=")))
        .collect::<Vec<_>>()
        .join(" | ")
}

fn rebuild_memory_content_with_focus_tags(content: &str, focus_tags: &[String]) -> String {
    let mut parts = content
        .split('|')
        .map(str::trim)
        .filter(|part| !part.is_empty() && !part.starts_with("focusTags="))
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    parts.join(" | ")
}

fn selected_video_memory_has_emotion_anchor(content: &str) -> bool {
    [
        "情绪",
        "强忍泪意",
        "眼眶发红",
        "抬眼停顿",
        "垂眼停顿",
        "欲言又止",
        "呼吸发颤",
        "哽咽",
        "眉心紧锁",
        "嘴角发僵",
        "emotion",
    ]
    .into_iter()
    .any(|keyword| content.contains(keyword))
}

fn selected_video_memory_has_identity_anchor(content: &str) -> bool {
    extract_key_value(content, "subject")
        .map(|value| !normalize_prompt_text(&value).is_empty())
        .unwrap_or(false)
        || extract_key_value(content, "subjectAliases")
            .map(|value| !normalize_prompt_text(&value).is_empty())
            .unwrap_or(false)
        || CONTINUITY_NOTE_KEYWORDS
            .iter()
            .any(|keyword| content.contains(keyword))
}

fn selected_video_memory_has_lighting_anchor(content: &str) -> bool {
    [
        "光影",
        "光线",
        "逆光",
        "暖光",
        "冷光",
        "霓虹",
        "窗光",
        "侧逆光",
        "lighting",
    ]
    .into_iter()
    .any(|keyword| content.contains(keyword))
}

fn selected_video_memory_semantic_dedupe_key(content: &str) -> String {
    let semantic = [
        extract_key_value(content, "delivery"),
        extract_key_value(content, "note"),
        extract_key_value(content, "avoid"),
        extract_key_value(content, "style"),
    ]
    .into_iter()
    .flatten()
    .find(|value| !normalize_prompt_text(value).is_empty())
    .unwrap_or_else(|| content.to_string());
    normalize_prompt_text(&semantic)
}

fn selected_video_memory_storyboard_scope_key(content: &str) -> String {
    let ids = extract_storyboard_ids(content);
    if ids.is_empty() {
        return String::new();
    }
    ids.into_iter()
        .map(|id| id.to_string())
        .collect::<Vec<_>>()
        .join(",")
}

fn selected_video_memory_has_delivery_anchor(content: &str) -> bool {
    extract_key_value(content, "delivery")
        .as_ref()
        .map(|value| !normalize_prompt_text(value).is_empty())
        .unwrap_or(false)
        || selected_video_memory_delivery_signal_count(content) > 0
}

fn selected_video_memory_is_visual_only(content: &str) -> bool {
    !selected_video_memory_has_delivery_anchor(content)
        && selected_video_memory_visual_signal_count(content) > 0
}

fn selected_video_memory_delivery_signal_count(content: &str) -> usize {
    [
        "表演",
        "语气",
        "呼吸",
        "停顿",
        "眼神",
        "微表情",
        "哽咽",
        "喉结",
        "尾音",
        "delivery",
        "emotion",
        "expression",
    ]
    .into_iter()
    .filter(|keyword| content.contains(keyword))
    .count()
}

fn selected_video_memory_visual_signal_count(content: &str) -> usize {
    [
        "镜头", "光影", "光线", "逆光", "暖光", "冷光", "运镜", "构图", "机位", "近景", "中景",
        "远景", "camera", "lighting", "framing",
    ]
    .into_iter()
    .filter(|keyword| content.contains(keyword))
    .count()
}

fn selected_video_memory_is_scope_filler(content: &str) -> bool {
    let Some(style) = selected_video_style_value_from_content(content) else {
        return match extract_key_value(content, "note")
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        {
            Some(note) => is_low_signal_selected_memory_note(&note),
            None => true,
        };
    };

    let fragments = split_prompt_note_fragments(&style).collect::<Vec<_>>();
    if fragments.is_empty() {
        return true;
    }

    let has_specific_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            || fragment.starts_with("光影")
            || fragment.starts_with("环境")
            || fragment.starts_with("声场")
            || (fragment.starts_with("镜头") && !local_shot_framing_fragment(fragment))
    });
    if has_specific_signal {
        return false;
    }

    fragments.iter().all(|fragment| {
        fragment
            .strip_prefix("语气")
            .map(normalize_prompt_text)
            .is_some_and(|voice| selected_style_fragment_is_low_gain_voice(&voice))
            || fragment
                .strip_prefix("情绪")
                .map(normalize_prompt_text)
                .is_some_and(|mood| selected_style_fragment_is_generic_restrained_mood(&mood))
            || fragment
                .strip_prefix("动作")
                .map(normalize_prompt_text)
                .is_some_and(|action| selected_style_fragment_is_low_gain_motion(&action))
            || is_local_framing_only_fragment(fragment)
    })
}

fn compact_selected_video_memory_style_for_focus(
    style: &str,
    delivery: Option<&str>,
    bias: SelectedVideoMemoryOptimizationBias,
    subject_present: bool,
    compact_delivery_into_visual_summary: bool,
) -> Option<String> {
    let mut fragments = split_prompt_note_fragments(style).collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    let has_specific_performance = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    let has_lighting_or_environment = fragments.iter().any(|fragment| {
        fragment.starts_with("光影") || fragment.starts_with("环境") || fragment.starts_with("声场")
    });
    let has_delivery_anchor = delivery
        .is_some_and(|value| !normalize_prompt_text(value).is_empty())
        || has_specific_performance;

    if (bias.prefer_delivery || bias.prefer_emotion) && has_delivery_anchor {
        fragments.retain(|fragment| {
            if compact_delivery_into_visual_summary
                && delivery.is_some()
                && has_lighting_or_environment
                && fragment.starts_with("表演")
            {
                return false;
            }
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_voice(&voice);
            }
            if let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) {
                return !selected_style_fragment_is_generic_restrained_mood(&mood);
            }
            if let Some(action) = fragment.strip_prefix("动作").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_motion(&action);
            }
            true
        });
    }

    if (bias.prefer_lighting || bias.prefer_identity) && has_lighting_or_environment {
        fragments.retain(|fragment| {
            !(is_local_framing_only_fragment(fragment)
                && (bias.prefer_lighting || (bias.prefer_identity && subject_present)))
        });
    }

    if fragments.is_empty() {
        return None;
    }

    compact_video_style_prompt_note(&fragments.join("，"))
}

pub(super) fn compact_summary_video_style_memory_for_focus(
    content: &str,
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<String> {
    let Some(bias) = bias else {
        return Some(content.to_string());
    };
    if bias == SelectedVideoMemoryOptimizationBias::default() {
        return Some(content.to_string());
    }

    let style = extract_key_value(content, "style")?;
    let delivery = extract_key_value(content, "delivery");
    let style = compact_selected_video_memory_style_for_focus(
        &style,
        delivery.as_deref(),
        bias,
        false,
        true,
    )?;

    let mut parts = Vec::new();
    if let Some(sample_count) =
        extract_key_value(content, "sampleCount").filter(|value| !value.is_empty())
    {
        parts.push(format!("sampleCount={sample_count}"));
    }
    parts.push(format!("style={style}"));
    if let Some(delivery) = delivery
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .filter(|value| !value.is_empty() && value != &style)
    {
        parts.push(format!("delivery={delivery}"));
    }
    Some(parts.join(" | "))
}
