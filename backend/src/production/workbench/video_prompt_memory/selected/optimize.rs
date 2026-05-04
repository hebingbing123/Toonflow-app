use super::focus::{
    prepare_selected_video_memory_for_storage, selected_video_memory_active_focus_mask,
    selected_video_memory_bias_alignment_score, selected_video_memory_focus_coverage_score,
    selected_video_memory_focus_mask, selected_video_memory_has_delivery_anchor,
    selected_video_memory_has_identity_anchor, selected_video_memory_has_lighting_anchor,
    selected_video_memory_is_scope_filler, selected_video_memory_is_visual_only,
    selected_video_memory_semantic_dedupe_key, selected_video_memory_storyboard_scope_key,
    selected_video_memory_tag_coverage_score, selected_video_memory_visual_signal_count,
};
use super::*;

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
          AND target_type IN ('storyboard', 'output', 'video')
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

    optimization_bias_from_rows(rows)
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
          AND target_type IN ('storyboard', 'output', 'video')
        ORDER BY created_at DESC
        LIMIT 32
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    optimization_bias_from_rows(rows)
}

fn optimization_bias_from_rows(
    rows: Vec<OptimizationQualityFocusDbRow>,
) -> Result<Option<SelectedVideoMemoryOptimizationBias>, ApiError> {
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
