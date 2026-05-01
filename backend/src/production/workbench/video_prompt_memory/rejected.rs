use super::*;

pub(crate) fn build_rejected_video_negative_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let fields = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let mut fragments = Vec::new();
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.shot),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.camera_move),
    );
    push_rejected_negative_fragment(&mut fragments, map_rejected_mood_fragment(&fields.mood));
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_lighting_fragment(&fields.lighting),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_performance_fragment(&fields.action, &fields.dialogue, &fields.mood),
    );
    let fragments = compact_rejected_negative_memory_fragments_for_storage(
        fragments.into_iter().map(str::to_string).collect(),
    );
    if fragments.is_empty() {
        return None;
    }
    let risk_tags = rejected_video_negative_risk_tags(&fields, &fragments);
    let focus_tags = rejected_video_focus_tags_from_avoid(&fragments.join(", "));

    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if let Some(subject) = selected_memory_subject_identity(&fields.subject, &fields.subject_refs) {
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
    parts.push("rejectionCount=1".to_string());
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

fn rejected_video_negative_risk_tags(
    fields: &StructuredStoryboardDescription,
    fragments: &[String],
) -> Vec<&'static str> {
    let families = fragments
        .iter()
        .map(|fragment| observation_note_family(fragment))
        .collect::<Vec<_>>();
    let mut tags = Vec::new();

    if families.iter().any(|family| {
        matches!(
            *family,
            "camera_motion_stability" | "flicker_motion_jitter" | "shot_change_framing"
        )
    }) && selected_memory_scene_has_motion_risk(fields)
    {
        tags.push("motion");
    }
    if families
        .iter()
        .any(|family| *family == "character_consistency")
        && rejected_negative_scene_has_identity_risk(fields)
    {
        tags.push("identity");
    }
    if families
        .iter()
        .any(|family| matches!(*family, "camera_framing" | "shot_change_framing"))
        && rejected_negative_scene_has_framing_risk(fields)
    {
        tags.push("framing");
    }
    if families
        .iter()
        .any(|family| matches!(*family, "lighting_backlight" | "lighting_reflection"))
        && rejected_negative_scene_has_lighting_risk(fields)
    {
        tags.push("lighting");
    }
    if families.iter().any(|family| *family == "mood_tone")
        && rejected_negative_scene_needs_emotional_guard(fields)
    {
        tags.push("emotion");
    }
    if families
        .iter()
        .any(|family| *family == "performance_delivery")
        && rejected_negative_scene_needs_expressive_performance_guard(fields)
    {
        tags.push("performance");
    }
    if families.iter().any(|family| *family == "lip_sync")
        && rejected_negative_scene_has_dialogue_guard(fields)
    {
        tags.push("dialogue");
    }

    tags
}

pub(super) fn rejected_negative_scene_has_framing_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && [
                    "近景",
                    "特写",
                    "仰拍",
                    "俯拍",
                    "倾斜",
                    "跟拍",
                    "推进",
                    "拉远",
                    "摇镜",
                    "甩镜",
                    "切换",
                    "转场",
                    "close-up",
                    "tight close-up",
                    "low angle",
                    "high angle",
                    "dutch angle",
                    "follow",
                    "push in",
                    "pull back",
                    "whip",
                    "pan",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        })
}

pub(super) fn rejected_negative_scene_has_lighting_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.setting.as_str(),
        fields.lighting.as_str(),
        fields.sound.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "霓虹",
                "反光",
                "玻璃",
                "雨",
                "逆光",
                "背光",
                "剪影",
                "车灯",
                "冷光",
                "冷调",
                "阴天",
                "曝光",
                "reflection",
                "wet street",
                "headlight reflection",
                "silhouette",
                "backlight",
                "flat lighting",
                "cold lighting",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn rejected_negative_scene_needs_emotional_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    [
        fields.mood.as_str(),
        fields.action.as_str(),
        fields.dialogue.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "哭",
                "泪",
                "哽咽",
                "颤",
                "停顿",
                "压抑",
                "克制",
                "愤怒",
                "惊慌",
                "紧张",
                "压迫",
                "冷峻",
                "崩溃",
                "隐忍",
                "欲言又止",
                "迟疑",
                "回头",
                "犹豫",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

pub(super) fn rejected_negative_scene_needs_expressive_performance_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    rejected_negative_scene_needs_emotional_guard(fields)
        && (!selected_memory_field_looks_silent(&fields.dialogue)
            || [fields.mood.as_str(), fields.action.as_str()]
                .into_iter()
                .map(normalize_prompt_text)
                .any(|value| {
                    !value.is_empty()
                        && [
                            "欲言又止",
                            "隐忍",
                            "哽咽",
                            "低声",
                            "轻声",
                            "迟疑",
                            "停顿",
                            "犹豫",
                            "强忍",
                            "颤",
                        ]
                        .iter()
                        .any(|keyword| value.contains(keyword))
                }))
}

pub(super) fn rejected_negative_scene_has_dialogue_guard(
    fields: &StructuredStoryboardDescription,
) -> bool {
    !selected_memory_field_looks_silent(&fields.dialogue)
}

fn compact_rejected_negative_memory_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = compact_rejected_negative_fragment_risk_budget(fragments);
    let has_cold_lighting = compacted
        .iter()
        .any(|fragment| canonical_observation_note(fragment) == "avoid flat cold lighting");
    if has_cold_lighting {
        compacted.retain(|fragment| {
            canonical_observation_note(fragment) != "avoid overly cold emotional tone"
        });
    }
    let has_performance_delivery_guard = compacted
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    if has_performance_delivery_guard {
        compacted.retain(|fragment| observation_note_family(fragment) != "mood_tone");
    }

    if compacted.len() == 1
        && compacted
            .first()
            .is_some_and(|fragment| rejected_negative_memory_fragment_is_low_signal(fragment))
    {
        return Vec::new();
    }

    compacted
}

fn compact_rejected_negative_memory_fragments_for_storage(fragments: Vec<String>) -> Vec<String> {
    compact_rejected_negative_memory_fragments_for_storage_with_bias(fragments, None)
}

pub(super) fn compact_rejected_negative_memory_fragments_for_storage_with_bias(
    fragments: Vec<String>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let mut ranked = compact_rejected_negative_memory_fragments(
        compact_rejected_negative_fragment_families(fragments),
    )
    .into_iter()
    .enumerate()
    .map(|(idx, fragment)| {
        (
            score_rejected_negative_fragment(&fragment)
                + score_rejected_video_memory_bias_for_fragment(&fragment, bias),
            idx,
            fragment,
        )
    })
    .collect::<Vec<_>>();
    ranked.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let ordered = ranked
        .into_iter()
        .map(|(_, _, fragment)| fragment)
        .collect::<Vec<_>>();
    prioritize_rejected_negative_fragments_for_bias(ordered, bias)
        .into_iter()
        .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
        .collect()
}

fn prioritize_rejected_negative_fragments_for_bias(
    ordered: Vec<String>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let Some(bias) = bias else {
        return ordered;
    };
    let focus_match = |fragment: &String| {
        let tags = negative_fragment_storyboard_risk_tags(fragment);
        if bias.prefer_delivery && !bias.prefer_visual_continuity {
            return tags
                .iter()
                .any(|tag| matches!(*tag, "dialogue" | "performance" | "emotion"));
        }
        if bias.prefer_visual_continuity && !bias.prefer_delivery {
            return tags
                .iter()
                .any(|tag| matches!(*tag, "identity" | "lighting" | "motion" | "framing"));
        }
        false
    };

    let mut prioritized = ordered.into_iter().partition::<Vec<_>, _>(focus_match);
    prioritized.0.extend(prioritized.1);
    prioritized.0
}

pub(super) fn selected_optimization_bias_to_rejected_selection_bias(
    bias: Option<SelectedVideoMemoryOptimizationBias>,
) -> Option<VideoPromptMemorySelectionBias> {
    let Some(bias) = bias else {
        return None;
    };
    Some(VideoPromptMemorySelectionBias {
        prefer_delivery: bias.prefer_delivery || bias.prefer_emotion,
        prefer_visual_continuity: bias.prefer_identity || bias.prefer_lighting,
    })
}

fn storyboard_memory_key(storyboard_numeric_id: i32) -> Option<String> {
    if storyboard_numeric_id > 0 {
        Some(format!("storyboardIds={storyboard_numeric_id}"))
    } else {
        None
    }
}

pub(crate) async fn persist_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let selection_bias = selected_optimization_bias_to_rejected_selection_bias(
        load_selected_video_memory_optimization_bias(
            pool,
            user_id,
            project_numeric_id,
            script_numeric_id,
        )
        .await?,
    );
    let Some(content) = prepare_rejected_video_negative_memory_for_storage(content, selection_bias)
    else {
        return Ok(());
    };
    let Some(storyboard_numeric_id) = extract_key_value(&content, "storyboardIds")
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)
    else {
        return Ok(());
    };
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    let latest: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_content = if let Some(latest) = latest.as_deref() {
        merge_rejected_video_negative_memory_with_bias(latest, &content, selection_bias)
    } else {
        content
    };

    if latest.as_deref() == Some(next_content.as_str()) {
        return Ok(());
    }

    clear_rejected_video_negative_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
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
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(&next_content)
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
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let Some(storyboard_key) = storyboard_memory_key(storyboard_numeric_id) else {
        return Ok(());
    };
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
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[allow(dead_code)]
pub(crate) fn select_rejected_video_negative_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[],
        None,
    )
    .negative_notes
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub(crate) struct RejectedVideoMemorySelection {
    pub(crate) negative_notes: Vec<String>,
    pub(crate) observation_notes: Vec<String>,
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(crate) struct VideoPromptMemorySelectionBias {
    pub(crate) prefer_delivery: bool,
    pub(crate) prefer_visual_continuity: bool,
}

pub(crate) fn select_rejected_video_memory_notes_and_observation_candidates_for_subject(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> RejectedVideoMemorySelection {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
        None,
    )
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> RejectedVideoMemorySelection {
    let allow_unseeded_fallback = !has_exact_prompt_seed_memory_match(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[REJECTED_VIDEO_NEGATIVE_MEMORY_NAME],
    );
    let normalized_subject_candidates = subject_candidates
        .iter()
        .map(|value| normalize_prompt_text(value))
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    let exact_candidate_rows = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
        .filter_map(|(idx, row)| {
            memory_matches_storyboard(&row.content, storyboard_numeric_id)
                .then_some((idx, row))
                .filter(|(_, row)| {
                    memory_matches_prompt_seed_with_fallback(
                        &row.content,
                        current_prompt_seed,
                        allow_unseeded_fallback,
                    )
                })
        })
        .collect::<Vec<_>>();
    let storyboard_tags = storyboard_risk_tags_for_subject_fallback(storyboard_row);
    let negative_exact_candidate_rows = exact_candidate_rows
        .iter()
        .copied()
        .filter(|(_, row)| {
            rejected_video_negative_rejection_count(&row.content)
                >= REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        })
        .collect::<Vec<_>>();
    let observation_exact_candidate_rows = exact_candidate_rows
        .iter()
        .copied()
        .filter(|(_, row)| {
            rejected_video_negative_rejection_count(&row.content)
                < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        })
        .collect::<Vec<_>>();
    let allow_subject_scoped_negative_fallback =
        negative_exact_candidate_rows.is_empty() && !storyboard_tags.is_empty();
    let negative_candidate_rows = if allow_subject_scoped_negative_fallback {
        rows.iter()
            .enumerate()
            .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
            .filter(|(_, row)| {
                rejected_video_negative_rejection_count(&row.content)
                    >= REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
            })
            .filter(|(_, row)| {
                memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
            })
            .filter(|(_, row)| {
                memory_matches_rejected_video_risk_tags(&row.content, &storyboard_tags)
            })
            .collect::<Vec<_>>()
    } else {
        negative_exact_candidate_rows
    };
    let allow_subject_scoped_observation_fallback =
        observation_exact_candidate_rows.is_empty() && !storyboard_tags.is_empty();
    let observation_candidate_rows = if allow_subject_scoped_observation_fallback {
        rows.iter()
            .enumerate()
            .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
            .filter(|(_, row)| {
                rejected_video_negative_rejection_count(&row.content)
                    < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
            })
            .filter(|(_, row)| {
                memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
            })
            .filter(|(_, row)| {
                memory_matches_rejected_video_risk_tags(&row.content, &storyboard_tags)
            })
            .collect::<Vec<_>>()
    } else {
        observation_exact_candidate_rows
    };
    let has_matching_negative_subject = !normalized_subject_candidates.is_empty()
        && negative_candidate_rows.iter().any(|(_, row)| {
            memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        });
    let has_matching_observation_subject = !normalized_subject_candidates.is_empty()
        && observation_candidate_rows.iter().any(|(_, row)| {
            memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        });
    let negative_candidate_rows = negative_candidate_rows
        .into_iter()
        .filter(|(_, row)| {
            !has_matching_negative_subject
                || memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        })
        .collect::<Vec<_>>();
    let observation_candidate_rows = observation_candidate_rows
        .into_iter()
        .filter(|(_, row)| {
            !has_matching_observation_subject
                || memory_matches_subject_candidates(&row.content, &normalized_subject_candidates)
        })
        .collect::<Vec<_>>();

    let mut negative_scored = Vec::new();
    let mut observation_scored = Vec::new();
    for (idx, row) in negative_candidate_rows {
        let Some(avoid) = extract_key_value(&row.content, "avoid") else {
            continue;
        };
        let subject_priority =
            memory_subject_match_priority(&row.content, &normalized_subject_candidates);
        let overlap_priority = reversed_risk_tag_overlap_priority(&row.content, &storyboard_tags);
        let fallback_priority = storyboard_fallback_priority(
            &row.content,
            storyboard_numeric_id,
            allow_subject_scoped_negative_fallback,
        );
        let focus_bias_score = score_rejected_video_memory_bias_for_content(&row.content, bias);
        let storyboard_distance =
            storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                .unwrap_or(i32::MAX);

        let ranked = ranked_rejected_negative_fragments(&avoid);
        if ranked.is_empty() {
            let note = clip_prompt_fragment(&avoid, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            negative_scored.push((
                score_rejected_negative_fragment_for_storyboard(&note, &storyboard_tags)
                    + score_rejected_video_memory_bias_for_fragment(&note, bias)
                    + focus_bias_score,
                subject_priority,
                idx,
                overlap_priority,
                fallback_priority,
                storyboard_distance,
                0usize,
                note,
            ));
        } else {
            negative_scored.extend(ranked.into_iter().enumerate().map(|(fragment_idx, note)| {
                (
                    score_rejected_negative_fragment_for_storyboard(&note, &storyboard_tags)
                        + score_rejected_video_memory_bias_for_fragment(&note, bias)
                        + focus_bias_score,
                    subject_priority,
                    idx,
                    overlap_priority,
                    fallback_priority,
                    storyboard_distance,
                    fragment_idx,
                    note,
                )
            }));
        }
    }

    for (idx, row) in observation_candidate_rows {
        let Some(avoid) = extract_key_value(&row.content, "avoid") else {
            continue;
        };
        let subject_priority =
            memory_subject_match_priority(&row.content, &normalized_subject_candidates);
        let overlap_priority = reversed_risk_tag_overlap_priority(&row.content, &storyboard_tags);
        let fallback_priority = storyboard_fallback_priority(
            &row.content,
            storyboard_numeric_id,
            allow_subject_scoped_observation_fallback,
        );
        let focus_bias_score = score_rejected_video_memory_bias_for_content(&row.content, bias);
        let storyboard_distance =
            storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                .unwrap_or(i32::MAX);

        let ranked = ranked_observation_fragments(&avoid);
        if ranked.len() == 1
            && ranked
                .first()
                .is_some_and(|note| rejected_negative_memory_fragment_is_low_signal(note))
        {
            continue;
        }
        if ranked.is_empty() {
            let note = clip_prompt_fragment(&avoid, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            observation_scored.push((
                score_pending_observation_note_for_storyboard(&note, &storyboard_tags)
                    + score_rejected_video_memory_bias_for_fragment(&note, bias)
                    + focus_bias_score,
                subject_priority,
                idx,
                overlap_priority,
                fallback_priority,
                storyboard_distance,
                0usize,
                note,
            ));
        } else {
            observation_scored.extend(ranked.into_iter().enumerate().map(
                |(fragment_idx, note)| {
                    (
                        score_pending_observation_note_for_storyboard(&note, &storyboard_tags)
                            + score_rejected_video_memory_bias_for_fragment(&note, bias)
                            + focus_bias_score,
                        subject_priority,
                        idx,
                        overlap_priority,
                        fallback_priority,
                        storyboard_distance,
                        fragment_idx,
                        note,
                    )
                },
            ));
        }
    }

    let negative_notes = if negative_scored.is_empty() {
        select_rejected_video_observation_summary_notes(
            rows,
            &normalized_subject_candidates,
            storyboard_row,
            bias,
        )
    } else {
        select_ranked_rejected_video_memory_negative_notes(negative_scored)
    };
    let observation_notes = if observation_scored.is_empty() {
        select_rejected_video_observation_summary_notes(
            rows,
            &normalized_subject_candidates,
            storyboard_row,
            bias,
        )
    } else {
        select_ranked_rejected_video_memory_observation_notes(observation_scored)
    };

    RejectedVideoMemorySelection {
        negative_notes,
        observation_notes,
    }
}

#[allow(dead_code)]
pub(crate) fn select_rejected_video_negative_memory_notes_for_subject(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    select_rejected_video_negative_memory_notes_for_subject_with_bias(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
        None,
    )
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_rejected_video_negative_memory_notes_for_subject_with_bias(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
        bias,
    )
    .negative_notes
}

fn select_rejected_video_observation_summary_notes(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let storyboard_tags = storyboard_risk_tags_for_subject_fallback(storyboard_row);
    if storyboard_tags.is_empty() {
        return Vec::new();
    }

    let mut scored = rows
        .iter()
        .enumerate()
        .filter(|row| {
            matches!(
                row.1.name.as_str(),
                SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_VIDEO_OBSERVATION_MEMORY_NAME
            )
        })
        .filter(|row| memory_matches_rejected_video_risk_tags(&row.1.content, &storyboard_tags))
        .filter(|row| {
            if matches!(
                row.1.name.as_str(),
                SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
            ) {
                memory_matches_subject_candidates(&row.1.content, subject_candidates)
            } else {
                true
            }
        })
        .flat_map(|(row_idx, row)| {
            let row_overlap = rejected_video_risk_tag_overlap(&row.content, &storyboard_tags);
            let sample_count = observation_summary_sample_count(&row.content);
            let scope_priority = rejected_observation_summary_scope_priority(row.name.as_str());
            let subject_priority = memory_subject_match_priority(&row.content, subject_candidates);
            let focus_bias_score = score_rejected_video_memory_bias_for_content(&row.content, bias);
            let Some(avoid) = extract_key_value(&row.content, "avoid") else {
                return Vec::new();
            };
            let fragments = ranked_rejected_negative_fragments(&avoid);
            fragments
                .into_iter()
                .enumerate()
                .map(|(fragment_idx, fragment)| {
                    (
                        score_rejected_observation_summary_fragment_for_storyboard(
                            &fragment,
                            &storyboard_tags,
                        ) + score_rejected_video_memory_bias_for_fragment(&fragment, bias)
                            + focus_bias_score,
                        subject_priority,
                        fragment_storyboard_risk_overlap(&fragment, &storyboard_tags),
                        row_overlap,
                        scope_priority,
                        sample_count,
                        row_idx,
                        fragment_idx,
                        fragment,
                    )
                })
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(b.2.cmp(&a.2))
            .then(b.3.cmp(&a.3))
            .then(a.4.cmp(&b.4))
            .then(b.5.cmp(&a.5))
            .then(a.6.cmp(&b.6))
            .then(a.7.cmp(&b.7))
    });

    let mut selected = Vec::new();
    for (_, _, _, _, _, _, _, _, fragment) in scored {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            return vec![selected.join(", ")];
        }
    }
    (!selected.is_empty())
        .then(|| vec![selected.join(", ")])
        .unwrap_or_default()
}

fn rejected_observation_summary_scope_priority(name: &str) -> u8 {
    match name {
        SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME => 0,
        SCRIPT_VIDEO_OBSERVATION_MEMORY_NAME => 1,
        PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME => 2,
        PROJECT_VIDEO_OBSERVATION_MEMORY_NAME => 3,
        _ => u8::MAX,
    }
}

fn score_rejected_observation_summary_fragment_for_storyboard(
    fragment: &str,
    storyboard_tags: &[String],
) -> i32 {
    score_pending_observation_note_for_storyboard(fragment, storyboard_tags)
        + score_rejected_negative_fragment_for_storyboard(fragment, storyboard_tags)
}

fn observation_summary_sample_count(content: &str) -> usize {
    extract_key_value(content, "sampleCount")
        .and_then(|value| value.parse::<usize>().ok())
        .unwrap_or(0)
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_pending_rejected_video_observation_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Option<String> {
    select_pending_rejected_video_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[],
        None,
    )
    .into_iter()
    .next()
}

#[allow(dead_code)]
pub(crate) fn select_pending_rejected_video_observation_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_pending_rejected_video_observation_candidates_for_subject(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[],
        None,
    )
}

pub(crate) fn select_pending_rejected_video_observation_candidates_for_subject(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    select_pending_rejected_video_observation_candidates_for_subject_with_bias(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
        None,
    )
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_pending_rejected_video_observation_candidates_for_subject_with_bias(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    select_rejected_video_memory_notes_and_observation_candidates_for_subject_with_bias(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        subject_candidates,
        storyboard_row,
        bias,
    )
    .observation_notes
}

fn select_ranked_rejected_video_memory_negative_notes(
    mut scored: Vec<(i32, usize, usize, usize, u8, i32, usize, String)>,
) -> Vec<String> {
    scored.sort_by(|a, b| {
        a.1.cmp(&b.1)
            .then(b.0.cmp(&a.0))
            .then(a.3.cmp(&b.3))
            .then(a.4.cmp(&b.4))
            .then(a.5.cmp(&b.5))
            .then(a.2.cmp(&b.2))
            .then(a.6.cmp(&b.6))
            .then(a.7.cmp(&b.7))
    });

    let locked_subject_priority = scored.first().map(|entry| entry.1);
    let mut selected = Vec::new();
    for (_, subject_priority, _, _, _, _, _, fragment) in scored {
        if locked_subject_priority.is_some_and(|locked| subject_priority > locked) {
            continue;
        }
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    (!selected.is_empty())
        .then(|| vec![selected.join(", ")])
        .unwrap_or_default()
}

fn select_ranked_rejected_video_memory_observation_notes(
    mut scored: Vec<(i32, usize, usize, usize, u8, i32, usize, String)>,
) -> Vec<String> {
    scored.sort_by(|a, b| {
        a.1.cmp(&b.1)
            .then(b.0.cmp(&a.0))
            .then(a.3.cmp(&b.3))
            .then(a.4.cmp(&b.4))
            .then(a.5.cmp(&b.5))
            .then(a.2.cmp(&b.2))
            .then(a.6.cmp(&b.6))
            .then(a.7.cmp(&b.7))
    });

    let locked_subject_priority = scored.first().map(|entry| entry.1);
    let mut notes = Vec::new();
    for (_, subject_priority, _, _, _, _, _, note) in scored {
        if locked_subject_priority.is_some_and(|locked| subject_priority > locked) {
            continue;
        }
        if observation_note_is_covered(&note, &notes) {
            continue;
        }
        notes.retain(|existing| !observation_note_covers(&note, existing));
        notes.push(note);
    }
    notes
}

fn ranked_observation_fragments(avoid: &str) -> Vec<String> {
    let mut ranked = rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            let note = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            (score_pending_observation_note(&note), idx, note)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut notes = Vec::new();
    for (_, _, note) in ranked {
        if observation_note_is_covered(&note, &notes) {
            continue;
        }
        notes.retain(|existing| !observation_note_covers(&note, existing));
        notes.push(note);
    }
    notes
}

fn rejected_negative_fragments(avoid: &str) -> Vec<String> {
    compact_rejected_negative_fragment_risk_budget(compact_rejected_negative_fragment_families(
        stitch_rejected_negative_fragments(split_prompt_note_fragments(avoid).collect()),
    ))
}

fn stitch_rejected_negative_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut stitched = Vec::with_capacity(fragments.len());
    let mut idx = 0usize;
    while idx < fragments.len() {
        if let Some((combined, consumed)) =
            match_known_rejected_negative_fragment_sequence(&fragments[idx..])
        {
            stitched.push(combined);
            idx += consumed;
            continue;
        }
        stitched.push(fragments[idx].clone());
        idx += 1;
    }
    stitched
}

fn match_known_rejected_negative_fragment_sequence(parts: &[String]) -> Option<(String, usize)> {
    const KNOWN_COMPOSITES: &[(&str, usize)] = &[
        ("avoid overly cold, oppressive, or frantic mood", 3),
        ("avoid warped anatomy, blur, flicker", 3),
        ("avoid face distortion, identity drift, costume drift", 3),
    ];

    for &(candidate, consumed) in KNOWN_COMPOSITES {
        if parts.len() < consumed {
            continue;
        }
        let joined = parts[..consumed].join(", ");
        if normalize_prompt_text(&joined) == normalize_prompt_text(candidate) {
            return Some((candidate.to_string(), consumed));
        }
    }
    None
}

pub(super) fn compact_rejected_negative_avoid(avoid: &str) -> String {
    let mut scored = ranked_rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| (score_rejected_negative_fragment(&fragment), idx, fragment))
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));

    let mut selected = Vec::new();
    for (_, _, fragment) in scored {
        if selected.iter().any(|existing| existing == &fragment) {
            continue;
        }
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    selected.join(", ")
}

pub(super) fn ranked_rejected_negative_fragments(avoid: &str) -> Vec<String> {
    let mut ranked = rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            let note = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            (score_rejected_negative_fragment(&note), idx, note)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut selected = Vec::new();
    for (_, _, fragment) in ranked {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
    }
    selected
}

pub(super) fn score_rejected_negative_fragment(fragment: &str) -> i32 {
    let normalized = normalize_prompt_text(fragment).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "follow", "stable", "shot", "framing", "镜头",
        "运镜", "抖动", "跳轴", "机位",
    ] {
        if normalized.contains(keyword) {
            score += 20;
        }
    }
    for keyword in [
        "flicker", "jitter", "stutter", "blur", "warped", "anatom", "face", "identity", "costume",
        "flash", "闪烁", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "lighting",
        "light",
        "silhouette",
        "backlight",
        "cold",
        "neon",
        "flat",
        "光影",
        "逆光",
        "冷光",
        "曝光",
        "反光",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "tone",
        "monotone",
        "expression",
        "delivery",
        "情绪",
        "压迫",
        "冷调",
        "悲怆",
        "台词",
        "表演",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 8
}

fn score_rejected_negative_fragment_for_storyboard(
    fragment: &str,
    storyboard_tags: &[String],
) -> i32 {
    score_rejected_negative_fragment(fragment)
        + fragment_storyboard_risk_overlap(fragment, storyboard_tags) as i32 * 18
}

fn score_pending_observation_note(note: &str) -> i32 {
    let normalized = normalize_prompt_text(note).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "镜头", "运镜", "抖动", "跳轴", "站位", "走位",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "lighting", "light", "flat", "flicker", "冷光", "光影", "曝光", "闪烁", "色温",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "blur", "warped", "anatom", "face", "identity", "costume", "模糊", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "monotone",
        "expression",
        "delivery",
        "情绪",
        "压迫",
        "节奏",
        "表演",
        "台词",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 6
}

fn score_pending_observation_note_for_storyboard(note: &str, storyboard_tags: &[String]) -> i32 {
    score_pending_observation_note(note)
        + fragment_storyboard_risk_overlap(note, storyboard_tags) as i32 * 18
}

pub(super) fn score_rejected_video_memory_bias_for_fragment(
    fragment: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };
    let tags = negative_fragment_storyboard_risk_tags(fragment);
    let mut score = 0;
    for tag in tags {
        score += match *tag {
            "performance" if bias.prefer_delivery => 42,
            "dialogue" | "emotion" if bias.prefer_delivery => 36,
            "identity" if bias.prefer_visual_continuity => 42,
            "lighting" if bias.prefer_visual_continuity => 36,
            "framing" if bias.prefer_visual_continuity => 24,
            "motion" if bias.prefer_visual_continuity => 18,
            _ => 0,
        };
    }
    score
}

fn score_rejected_video_memory_bias_for_content(
    content: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };
    let tags = extract_rejected_video_focus_tags(content);
    if tags.is_empty() {
        return 0;
    }

    let mut score = 0;
    if bias.prefer_delivery
        && tags
            .iter()
            .any(|tag| matches!(tag.as_str(), "delivery_realism"))
    {
        score += 28;
    }
    if bias.prefer_visual_continuity
        && tags
            .iter()
            .any(|tag| matches!(tag.as_str(), "identity_continuity"))
    {
        score += 24;
    }
    if bias.prefer_visual_continuity
        && tags
            .iter()
            .any(|tag| matches!(tag.as_str(), "lighting_realism"))
    {
        score += 20;
    }
    score
}

fn reversed_risk_tag_overlap_priority(content: &str, storyboard_tags: &[String]) -> usize {
    usize::MAX - rejected_video_risk_tag_overlap(content, storyboard_tags)
}

fn compact_rejected_negative_fragment_risk_budget(fragments: Vec<String>) -> Vec<String> {
    if fragments.len() < 2 {
        return fragments;
    }

    let has_high_signal_visual_guard = fragments
        .iter()
        .any(|fragment| rejected_negative_fragment_is_high_signal_visual_guard(fragment));
    if !has_high_signal_visual_guard {
        return fragments;
    }

    let filtered = fragments
        .iter()
        .filter(|fragment| !rejected_negative_fragment_is_low_priority_style_retry(fragment))
        .cloned()
        .collect::<Vec<_>>();
    if filtered.is_empty() {
        fragments
    } else {
        filtered
    }
}

fn rejected_negative_fragment_is_high_signal_visual_guard(fragment: &str) -> bool {
    matches!(
        canonical_observation_note(fragment).as_str(),
        "avoid face distortion, identity drift, costume drift"
            | "avoid warped anatomy, blur, flicker"
    )
}

fn rejected_negative_fragment_is_low_priority_style_retry(fragment: &str) -> bool {
    if rejected_negative_memory_fragment_is_low_signal(fragment) {
        return true;
    }

    matches!(
        observation_note_family(fragment),
        "camera_framing" | "lighting_backlight" | "lighting_reflection"
    )
}

pub(super) fn observation_note_is_covered(candidate: &str, existing_notes: &[String]) -> bool {
    existing_notes
        .iter()
        .any(|existing| observation_note_covers(existing, candidate))
}

pub(super) fn observation_note_covers(existing: &str, candidate: &str) -> bool {
    if observation_note_same_family(existing, candidate) {
        return score_pending_observation_note(existing)
            >= score_pending_observation_note(candidate);
    }
    observation_note_contains(existing, candidate)
}

fn observation_note_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_observation_note(existing);
    let candidate = canonical_observation_note(candidate);
    if existing.is_empty() || candidate.is_empty() {
        return false;
    }
    if existing == candidate {
        return true;
    }
    let min_overlap_len = 12;
    existing.len() >= candidate.len()
        && candidate.len() >= min_overlap_len
        && existing.contains(&candidate)
}

fn observation_note_same_family(existing: &str, candidate: &str) -> bool {
    let existing = observation_note_family(existing);
    let candidate = observation_note_family(candidate);
    !existing.is_empty() && existing == candidate
}

fn observation_note_family(value: &str) -> &'static str {
    let canonical = canonical_observation_note(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" | "avoid extra shot changes or wrong framing" => {
            "shot_change_framing"
        }
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid warped hands or limbs"
        | "avoid warped anatomy"
        | "avoid blur"
        | "avoid warped anatomy, blur, flicker" => "visual_error",
        "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => {
            if canonical.contains("shaky")
                || canonical.contains("handheld")
                || canonical.contains("stable follow camera")
                || canonical.contains("follow camera")
            {
                "camera_motion_stability"
            } else if canonical.contains("shot change")
                || canonical.contains("wrong framing")
                || canonical.contains("unnecessary shot")
            {
                "shot_change_framing"
            } else if canonical.contains("tragic")
                || canonical.contains("oppressive")
                || canonical.contains("frantic")
                || canonical.contains("cold emotional tone")
            {
                "mood_tone"
            } else if canonical.contains("blank expression")
                || canonical.contains("monotone")
                || canonical.contains("delivery")
            {
                "performance_delivery"
            } else if canonical.contains("neon reflection") || canonical.contains("reflection") {
                "lighting_reflection"
            } else if canonical.contains("lip-sync") {
                "lip_sync"
            } else {
                ""
            }
        }
    }
}

pub(super) fn canonical_observation_note(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

#[derive(Debug, Default)]
struct ObservationCharacterConsistencyFlags {
    face_distortion: bool,
    identity_drift: bool,
    costume_drift: bool,
}

#[derive(Debug, Default)]
struct ObservationVisualErrorFlags {
    warped_anatomy: bool,
    blur: bool,
    flicker: bool,
}

#[derive(Debug, Default)]
struct ObservationVisualStyleConstraintFlags {
    extreme_camera_angle: bool,
    tight_close_up: bool,
    oppressive_or_frantic_mood: bool,
    overly_cold_emotional_tone: bool,
    blank_expression_or_monotone_delivery: bool,
    flat_cold_lighting: bool,
    harsh_backlight_silhouette: bool,
}

fn compact_rejected_negative_fragment_families(fragments: Vec<String>) -> Vec<String> {
    let mut character_flags = ObservationCharacterConsistencyFlags::default();
    let mut visual_error_flags = ObservationVisualErrorFlags::default();
    let mut visual_style_flags = ObservationVisualStyleConstraintFlags::default();
    let mut retained = Vec::new();

    for fragment in fragments {
        if let Some(parsed) = parse_observation_character_consistency_fragment(&fragment) {
            character_flags.face_distortion |= parsed.face_distortion;
            character_flags.identity_drift |= parsed.identity_drift;
            character_flags.costume_drift |= parsed.costume_drift;
            continue;
        }
        if let Some(parsed) = parse_observation_visual_error_fragment(&fragment) {
            visual_error_flags.warped_anatomy |= parsed.warped_anatomy;
            visual_error_flags.blur |= parsed.blur;
            visual_error_flags.flicker |= parsed.flicker;
            continue;
        }
        if let Some(parsed) = parse_observation_visual_style_constraint_fragment(&fragment) {
            visual_style_flags.extreme_camera_angle |= parsed.extreme_camera_angle;
            visual_style_flags.tight_close_up |= parsed.tight_close_up;
            visual_style_flags.oppressive_or_frantic_mood |= parsed.oppressive_or_frantic_mood;
            visual_style_flags.overly_cold_emotional_tone |= parsed.overly_cold_emotional_tone;
            visual_style_flags.blank_expression_or_monotone_delivery |=
                parsed.blank_expression_or_monotone_delivery;
            visual_style_flags.flat_cold_lighting |= parsed.flat_cold_lighting;
            visual_style_flags.harsh_backlight_silhouette |= parsed.harsh_backlight_silhouette;
            continue;
        }
        retained.push(fragment);
    }

    retained.extend(render_observation_character_consistency_fragment(
        character_flags,
    ));
    retained.extend(render_observation_visual_error_fragments(
        visual_error_flags,
    ));
    retained.extend(render_observation_visual_style_constraint_fragments(
        visual_style_flags,
    ));
    retained
}

fn parse_observation_character_consistency_fragment(
    fragment: &str,
) -> Option<ObservationCharacterConsistencyFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid face distortion" => Some(ObservationCharacterConsistencyFlags {
            face_distortion: true,
            ..Default::default()
        }),
        "avoid identity drift" | "avoid face distortion or identity drift" => {
            Some(ObservationCharacterConsistencyFlags {
                face_distortion: canonical_observation_note(fragment)
                    == "avoid face distortion or identity drift",
                identity_drift: true,
                ..Default::default()
            })
        }
        "avoid costume drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => {
            let canonical = canonical_observation_note(fragment);
            Some(ObservationCharacterConsistencyFlags {
                face_distortion: matches!(
                    canonical.as_str(),
                    "avoid face drift or costume inconsistency"
                        | "avoid face distortion, identity drift, costume drift"
                ),
                identity_drift: matches!(
                    canonical.as_str(),
                    "avoid face drift or costume inconsistency"
                        | "avoid face distortion, identity drift, costume drift"
                ),
                costume_drift: true,
            })
        }
        _ => None,
    }
}

fn render_observation_character_consistency_fragment(
    flags: ObservationCharacterConsistencyFlags,
) -> Vec<String> {
    if flags.face_distortion && flags.identity_drift && flags.costume_drift {
        return vec!["avoid face distortion, identity drift, costume drift".to_string()];
    }
    if flags.face_distortion && flags.identity_drift {
        return vec!["avoid face distortion or identity drift".to_string()];
    }
    if flags.identity_drift && flags.costume_drift {
        return vec!["avoid face drift or costume inconsistency".to_string()];
    }
    if flags.costume_drift {
        return vec!["avoid costume or character drift".to_string()];
    }
    if flags.identity_drift {
        return vec!["avoid identity drift".to_string()];
    }
    if flags.face_distortion {
        return vec!["avoid face distortion".to_string()];
    }
    Vec::new()
}

fn parse_observation_visual_error_fragment(fragment: &str) -> Option<ObservationVisualErrorFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid warped hands or limbs" | "avoid warped anatomy" => {
            Some(ObservationVisualErrorFlags {
                warped_anatomy: true,
                ..Default::default()
            })
        }
        "avoid blur" => Some(ObservationVisualErrorFlags {
            blur: true,
            ..Default::default()
        }),
        "avoid flicker" | "avoid flicker or motion jitter" => Some(ObservationVisualErrorFlags {
            flicker: true,
            ..Default::default()
        }),
        "avoid warped anatomy, blur, flicker" => Some(ObservationVisualErrorFlags {
            warped_anatomy: true,
            blur: true,
            flicker: true,
        }),
        _ => None,
    }
}

fn render_observation_visual_error_fragments(flags: ObservationVisualErrorFlags) -> Vec<String> {
    if flags.warped_anatomy && flags.blur && flags.flicker {
        return vec!["avoid warped anatomy, blur, flicker".to_string()];
    }

    let mut fragments = Vec::new();
    if flags.warped_anatomy {
        fragments.push("avoid warped anatomy".to_string());
    }
    if flags.blur {
        fragments.push("avoid blur".to_string());
    }
    if flags.flicker {
        fragments.push("avoid flicker".to_string());
    }
    fragments
}

fn parse_observation_visual_style_constraint_fragment(
    fragment: &str,
) -> Option<ObservationVisualStyleConstraintFlags> {
    match canonical_observation_note(fragment).as_str() {
        "avoid extreme camera angle" => Some(ObservationVisualStyleConstraintFlags {
            extreme_camera_angle: true,
            ..Default::default()
        }),
        "avoid overly tight close-up framing" => Some(ObservationVisualStyleConstraintFlags {
            tight_close_up: true,
            ..Default::default()
        }),
        "avoid extreme camera angle or overly tight close-up framing" => {
            Some(ObservationVisualStyleConstraintFlags {
                extreme_camera_angle: true,
                tight_close_up: true,
                ..Default::default()
            })
        }
        "avoid oppressive or frantic mood" => Some(ObservationVisualStyleConstraintFlags {
            oppressive_or_frantic_mood: true,
            ..Default::default()
        }),
        "avoid overly cold emotional tone" => Some(ObservationVisualStyleConstraintFlags {
            overly_cold_emotional_tone: true,
            ..Default::default()
        }),
        "avoid blank expression or monotone delivery" => {
            Some(ObservationVisualStyleConstraintFlags {
                blank_expression_or_monotone_delivery: true,
                ..Default::default()
            })
        }
        "avoid overly cold, oppressive, or frantic mood" => {
            Some(ObservationVisualStyleConstraintFlags {
                oppressive_or_frantic_mood: true,
                overly_cold_emotional_tone: true,
                ..Default::default()
            })
        }
        "avoid flat cold lighting" => Some(ObservationVisualStyleConstraintFlags {
            flat_cold_lighting: true,
            ..Default::default()
        }),
        "avoid harsh backlight silhouette" => Some(ObservationVisualStyleConstraintFlags {
            harsh_backlight_silhouette: true,
            ..Default::default()
        }),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            Some(ObservationVisualStyleConstraintFlags {
                flat_cold_lighting: true,
                harsh_backlight_silhouette: true,
                ..Default::default()
            })
        }
        _ => None,
    }
}

fn render_observation_visual_style_constraint_fragments(
    flags: ObservationVisualStyleConstraintFlags,
) -> Vec<String> {
    let mut fragments = Vec::new();
    if flags.extreme_camera_angle && flags.tight_close_up {
        fragments.push("avoid extreme camera angle or overly tight close-up framing".to_string());
    } else if flags.extreme_camera_angle {
        fragments.push("avoid extreme camera angle".to_string());
    } else if flags.tight_close_up {
        fragments.push("avoid overly tight close-up framing".to_string());
    }

    if flags.oppressive_or_frantic_mood && flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold, oppressive, or frantic mood".to_string());
    } else if flags.oppressive_or_frantic_mood {
        fragments.push("avoid oppressive or frantic mood".to_string());
    } else if flags.overly_cold_emotional_tone {
        fragments.push("avoid overly cold emotional tone".to_string());
    }
    if flags.blank_expression_or_monotone_delivery {
        fragments.push("avoid blank expression or monotone delivery".to_string());
    }

    if flags.flat_cold_lighting && flags.harsh_backlight_silhouette {
        fragments.push("avoid flat cold lighting or harsh backlight silhouette".to_string());
    } else if flags.flat_cold_lighting {
        fragments.push("avoid flat cold lighting".to_string());
    } else if flags.harsh_backlight_silhouette {
        fragments.push("avoid harsh backlight silhouette".to_string());
    }

    fragments
}

pub(crate) fn rejected_video_negative_rejection_count(content: &str) -> u32 {
    extract_key_value(content, "rejectionCount")
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|count| *count > 0)
        .unwrap_or(1)
}

fn rejected_video_memory_prompt_seed(content: &str) -> Option<String> {
    extract_key_value(content, "promptSeed")
}

fn extract_rejected_video_risk_tags(content: &str) -> Vec<String> {
    extract_key_value(content, "riskTags")
        .map(|value| {
            value
                .split(['/', ',', '，', ';', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

fn storyboard_risk_tags_for_subject_fallback(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return Vec::new();
    };
    let mut tags = Vec::new();
    if selected_memory_scene_has_motion_risk(&fields) {
        tags.push("motion".to_string());
    }
    if rejected_negative_scene_has_identity_risk(&fields) {
        tags.push("identity".to_string());
    }
    if rejected_negative_scene_has_framing_risk(&fields) {
        tags.push("framing".to_string());
    }
    if rejected_negative_scene_has_lighting_risk(&fields) {
        tags.push("lighting".to_string());
    }
    if rejected_negative_scene_needs_emotional_guard(&fields) {
        tags.push("emotion".to_string());
    }
    if rejected_negative_scene_needs_expressive_performance_guard(&fields) {
        tags.push("performance".to_string());
    }
    if rejected_negative_scene_has_dialogue_guard(&fields) {
        tags.push("dialogue".to_string());
    }
    tags
}

fn rejected_video_risk_tag_overlap(content: &str, storyboard_tags: &[String]) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    memory_tags
        .iter()
        .filter(|memory_tag| storyboard_tags.iter().any(|tag| tag == *memory_tag))
        .count()
}

fn fragment_storyboard_risk_overlap(fragment: &str, storyboard_tags: &[String]) -> usize {
    if storyboard_tags.is_empty() {
        return 0;
    }
    negative_fragment_storyboard_risk_tags(fragment)
        .iter()
        .filter(|tag| storyboard_tags.iter().any(|value| value == **tag))
        .count()
}

fn negative_fragment_storyboard_risk_tags(fragment: &str) -> &'static [&'static str] {
    match canonical_observation_note(fragment).as_str() {
        "avoid rushed motion"
        | "avoid rushed or jerky motion"
        | "avoid flicker"
        | "avoid flicker or motion jitter" => &["motion"],
        "avoid unnecessary shot changes"
        | "avoid extra shot changes or wrong framing"
        | "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => &["framing"],
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette"
        | "avoid distracting neon reflections" => &["lighting"],
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => &["identity"],
        "avoid lip-sync mismatch" => &["dialogue"],
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => &["performance", "dialogue", "emotion"],
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => &["emotion"],
        _ => &[],
    }
}

pub(super) fn rejected_negative_scene_has_identity_risk(
    fields: &StructuredStoryboardDescription,
) -> bool {
    let has_subject = !normalize_prompt_text(&fields.subject).is_empty();
    if !has_subject {
        return false;
    }

    if rejected_negative_scene_needs_expressive_performance_guard(fields)
        || rejected_negative_scene_has_dialogue_guard(fields)
    {
        return true;
    }

    [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.action.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .any(|value| {
        !value.is_empty()
            && [
                "近景",
                "中近景",
                "半身",
                "特写",
                "脸部",
                "面部",
                "肖像",
                "抬眼",
                "回头",
                "对视",
                "凝视",
                "眼神",
                "唇",
                "喉结",
                "眉",
                "泪",
                "close-up",
                "medium close-up",
                "portrait",
                "face",
                "eye",
                "gaze",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    })
}

fn memory_matches_rejected_video_risk_tags(content: &str, storyboard_tags: &[String]) -> bool {
    if storyboard_tags.is_empty() {
        return false;
    }
    let memory_tags = extract_rejected_video_risk_tags(content);
    !memory_tags.is_empty()
        && memory_tags
            .iter()
            .any(|memory_tag| storyboard_tags.iter().any(|tag| tag == memory_tag))
}

fn storyboard_fallback_priority(
    content: &str,
    storyboard_numeric_id: i32,
    allow_subject_scoped_fallback: bool,
) -> u8 {
    if memory_matches_storyboard(content, storyboard_numeric_id) {
        0
    } else if allow_subject_scoped_fallback {
        1
    } else {
        0
    }
}

fn merged_subject_aliases(existing: &str, incoming: &str, subject: &str) -> String {
    let mut aliases = role_memory_subject_candidates(existing);
    aliases.extend(role_memory_subject_candidates(incoming));
    aliases.retain(|alias| alias != subject);
    aliases.sort();
    aliases.dedup();
    aliases.join("/")
}

#[allow(dead_code)]
pub(super) fn merge_rejected_video_negative_memory(existing: &str, incoming: &str) -> String {
    merge_rejected_video_negative_memory_with_bias(existing, incoming, None)
}

fn merge_rejected_video_negative_memory_with_bias(
    existing: &str,
    incoming: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> String {
    let incoming_prompt_seed = rejected_video_memory_prompt_seed(incoming);
    let existing_prompt_seed = rejected_video_memory_prompt_seed(existing);
    if incoming_prompt_seed != existing_prompt_seed {
        return prepare_rejected_video_negative_memory_for_storage(incoming, bias)
            .unwrap_or_else(|| incoming.to_string());
    }

    let storyboard_numeric_id = extract_key_value(incoming, "storyboardIds")
        .or_else(|| extract_key_value(existing, "storyboardIds"))
        .unwrap_or_default();
    let prompt_seed = incoming_prompt_seed
        .or(existing_prompt_seed)
        .unwrap_or_default();
    let subject = extract_key_value(incoming, "subject")
        .or_else(|| extract_key_value(existing, "subject"))
        .unwrap_or_default();
    let subject_aliases = merged_subject_aliases(existing, incoming, &subject);
    let rejection_count = rejected_video_negative_rejection_count(existing).saturating_add(1);
    let avoid = merge_rejected_negative_avoid_with_bias(
        extract_key_value(existing, "avoid").as_deref(),
        extract_key_value(incoming, "avoid").as_deref(),
        bias,
    );
    let risk_tags = rejected_video_risk_tags_from_avoid(&avoid);
    let focus_tags = rejected_video_focus_tags_from_avoid(&avoid);

    let mut parts = Vec::new();
    if !storyboard_numeric_id.is_empty() {
        parts.push(format!("storyboardIds={storyboard_numeric_id}"));
    }
    if !prompt_seed.is_empty() {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if !subject.is_empty() {
        parts.push(format!("subject={subject}"));
    }
    if !subject_aliases.is_empty() {
        parts.push(format!("subjectAliases={subject_aliases}"));
    }
    parts.push(format!("rejectionCount={rejection_count}"));
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    if !avoid.is_empty() {
        parts.push(format!("avoid={avoid}"));
    }
    parts.join(" | ")
}

fn memory_matches_subject_candidates(content: &str, subject_candidates: &[String]) -> bool {
    memory_subject_match_priority(content, subject_candidates) != usize::MAX
}

pub(super) fn memory_subject_match_priority(content: &str, subject_candidates: &[String]) -> usize {
    if subject_candidates.is_empty() {
        return usize::MAX;
    }
    let memory_subjects = role_memory_subject_candidates(content);
    if memory_subjects.is_empty() {
        return usize::MAX;
    }

    subject_candidates
        .iter()
        .enumerate()
        .find_map(|(idx, candidate)| {
            memory_subjects
                .iter()
                .any(|memory_subject| {
                    candidate == memory_subject
                        || candidate.contains(memory_subject)
                        || memory_subject.contains(candidate)
                })
                .then_some(idx)
        })
        .unwrap_or(usize::MAX)
}

pub(super) fn merge_rejected_negative_avoid_with_bias(
    existing: Option<&str>,
    incoming: Option<&str>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> String {
    let mut fragments = Vec::new();
    for value in [existing, incoming].into_iter().flatten() {
        for fragment in split_prompt_note_fragments(value) {
            if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
                continue;
            }
            fragments.push(fragment);
        }
    }
    compact_rejected_negative_memory_fragments_for_storage_with_bias(fragments, bias).join(", ")
}

fn rejected_video_risk_tags_from_avoid(avoid: &str) -> Vec<String> {
    let mut tags = split_prompt_note_fragments(avoid)
        .flat_map(|fragment| {
            negative_fragment_storyboard_risk_tags(&fragment)
                .iter()
                .map(|tag| (*tag).to_string())
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    tags.sort();
    tags.dedup();
    tags
}

fn rejected_video_focus_tags_from_avoid(avoid: &str) -> Vec<String> {
    let mut tags = Vec::new();
    let mut push_tag = |candidate: &str| {
        if !tags.iter().any(|existing| existing == candidate) {
            tags.push(candidate.to_string());
        }
    };

    for fragment in split_prompt_note_fragments(avoid) {
        match observation_note_family(&fragment) {
            "performance_delivery" | "lip_sync_mismatch" | "mood_tone" => {
                push_tag("delivery_realism");
            }
            "character_consistency"
            | "shot_change_only"
            | "shot_change_framing"
            | "camera_framing"
            | "rushed_motion"
            | "flicker_motion_jitter" => {
                push_tag("identity_continuity");
            }
            "lighting_backlight" | "lighting_reflection" => {
                push_tag("lighting_realism");
            }
            _ => {}
        }
    }

    tags
}

fn extract_rejected_video_focus_tags(content: &str) -> Vec<String> {
    extract_key_value(content, "focusTags")
        .map(|value| {
            value
                .split(['/', ',', ';', '，', '；'])
                .map(normalize_prompt_text)
                .filter(|tag| !tag.is_empty())
                .collect::<Vec<_>>()
        })
        .filter(|tags| !tags.is_empty())
        .unwrap_or_else(|| {
            extract_key_value(content, "avoid")
                .map(|avoid| rejected_video_focus_tags_from_avoid(&avoid))
                .unwrap_or_default()
        })
}

#[allow(dead_code)]
fn negative_fragment_family(value: &str) -> &'static str {
    let canonical = canonical_negative_fragment(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" => "shot_change_only",
        "avoid extra shot changes or wrong framing" => "shot_change_framing",
        "avoid rushed motion" | "avoid rushed or jerky motion" => "rushed_motion",
        "avoid blank expression"
        | "avoid monotone delivery"
        | "avoid blank expression or monotone delivery" => "performance_delivery",
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid oppressive mood"
        | "avoid frantic mood"
        | "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid distracting neon reflections" => "lighting_reflection",
        "avoid lip-sync mismatch" => "lip_sync_mismatch",
        "avoid face distortion"
        | "avoid identity drift"
        | "avoid costume drift"
        | "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => "",
    }
}

#[allow(dead_code)]
fn canonical_negative_fragment(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

pub(super) fn prepare_rejected_video_negative_memory_for_storage(
    content: &str,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Option<String> {
    let avoid = extract_key_value(content, "avoid")?;
    let fragments = split_prompt_note_fragments(&avoid).collect::<Vec<_>>();
    let compacted =
        compact_rejected_negative_memory_fragments_for_storage_with_bias(fragments, bias);
    if compacted.is_empty() {
        return None;
    }

    let risk_tags = rejected_video_risk_tags_from_avoid(&compacted.join(", "));
    let focus_tags = rejected_video_focus_tags_from_avoid(&compacted.join(", "));
    let mut parts = Vec::new();
    for key in [
        "storyboardIds",
        "promptSeed",
        "subject",
        "subjectAliases",
        "rejectionCount",
    ] {
        if let Some(value) = extract_key_value(content, key).filter(|value| !value.is_empty()) {
            parts.push(format!("{key}={value}"));
        }
    }
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    if !focus_tags.is_empty() {
        parts.push(format!("focusTags={}", focus_tags.join("/")));
    }
    parts.push(format!("avoid={}", compacted.join(", ")));
    Some(parts.join(" | "))
}

fn push_rejected_negative_fragment(
    target: &mut Vec<&'static str>,
    candidate: Option<&'static str>,
) {
    let Some(candidate) = candidate else {
        return;
    };
    if target.iter().any(|existing| existing == &candidate) {
        return;
    }
    target.push(candidate);
}

fn map_rejected_shot_or_camera_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("手持") {
        return Some("avoid shaky handheld motion");
    }
    if value.contains("稳定跟拍")
        || value.contains("跟拍")
        || value.contains("推进")
        || value.contains("慢推")
    {
        return Some("avoid repeating stable follow camera");
    }
    if value.contains("低机位") || value.contains("高机位") {
        return Some("avoid extreme camera angle");
    }
    if value.contains("特写") || value.contains("近景") {
        return Some("avoid overly tight close-up framing");
    }
    None
}

fn map_rejected_mood_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("压迫") || value.contains("紧张") || value.contains("急迫") {
        return Some("avoid oppressive or frantic mood");
    }
    if value.contains("冷峻") || value.contains("冷调") || value.contains("冷色") {
        return Some("avoid overly cold emotional tone");
    }
    if value.contains("悲怆") {
        return Some("avoid heavy tragic mood");
    }
    None
}

fn map_rejected_performance_fragment(
    action: &str,
    dialogue: &str,
    mood: &str,
) -> Option<&'static str> {
    let action = normalize_prompt_text(action);
    let dialogue = normalize_prompt_text(dialogue);
    let mood = normalize_prompt_text(mood);
    let has_dialogue = !dialogue.is_empty()
        && !["无台词", "沉默", "静默", "无对白"]
            .iter()
            .any(|token| dialogue.contains(token));
    let has_restrained_emotional_signal = [action.as_str(), dialogue.as_str(), mood.as_str()]
        .into_iter()
        .any(|value| {
            !value.is_empty()
                && [
                    "欲言又止",
                    "隐忍",
                    "哽咽",
                    "低声",
                    "轻声",
                    "迟疑",
                    "停顿",
                    "犹豫",
                    "压低声音",
                    "强忍",
                    "颤",
                    "克制",
                ]
                .iter()
                .any(|keyword| value.contains(keyword))
        });
    if has_dialogue && has_restrained_emotional_signal {
        return Some("avoid blank expression or monotone delivery");
    }

    let has_silent_high_signal = [action.as_str(), mood.as_str()].into_iter().any(|value| {
        !value.is_empty()
            && [
                "欲言又止",
                "隐忍",
                "哽咽",
                "迟疑",
                "停顿",
                "犹豫",
                "强忍",
                "颤",
                "喉结",
                "嘴角发僵",
                "下颌绷紧",
                "指尖发颤",
            ]
            .iter()
            .any(|keyword| value.contains(keyword))
    });
    has_silent_high_signal.then_some("avoid blank expression or monotone delivery")
}

fn map_rejected_lighting_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("逆光") {
        return Some("avoid harsh backlight silhouette");
    }
    if value.contains("冷光") || value.contains("阴天冷光") || value.contains("冷调") {
        return Some("avoid flat cold lighting");
    }
    if value.contains("霓虹") || value.contains("反光") {
        return Some("avoid distracting neon reflections");
    }
    None
}

fn rejected_negative_memory_fragment_is_low_signal(fragment: &str) -> bool {
    matches!(
        canonical_observation_note(fragment).as_str(),
        "avoid repeating stable follow camera"
            | "avoid oppressive or frantic mood"
            | "avoid overly cold emotional tone"
            | "avoid heavy tragic mood"
            | "avoid overly cold, oppressive, or frantic mood"
    )
}
