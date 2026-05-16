use super::*;

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
                super::persist::memory_matches_rejected_video_risk_tags(
                    &row.content,
                    &storyboard_tags,
                )
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
                super::persist::memory_matches_rejected_video_risk_tags(
                    &row.content,
                    &storyboard_tags,
                )
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
        let overlap_priority =
            usize::MAX - rejected_video_risk_tag_overlap(&row.content, &storyboard_tags);
        let fallback_priority = storyboard_fallback_priority(
            &row.content,
            storyboard_numeric_id,
            allow_subject_scoped_negative_fallback,
        );
        let focus_bias_score = score_rejected_video_memory_bias_for_content(&row.content, bias);
        let storyboard_distance =
            storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                .unwrap_or(i32::MAX);

        let ranked = retain_storyboard_matching_fragments(
            ranked_rejected_negative_fragments(&avoid),
            &storyboard_tags,
        );
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
        let overlap_priority =
            usize::MAX - rejected_video_risk_tag_overlap(&row.content, &storyboard_tags);
        let fallback_priority = storyboard_fallback_priority(
            &row.content,
            storyboard_numeric_id,
            allow_subject_scoped_observation_fallback,
        );
        let focus_bias_score = score_rejected_video_memory_bias_for_content(&row.content, bias);
        let storyboard_distance =
            storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                .unwrap_or(i32::MAX);

        let ranked = retain_storyboard_matching_fragments(
            ranked_observation_fragments(&avoid),
            &storyboard_tags,
        );
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
            true,
        )
    } else {
        select_ranked_rejected_video_memory_negative_notes(negative_scored, bias)
    };
    let observation_notes = if observation_scored.is_empty() {
        select_rejected_video_observation_summary_notes(
            rows,
            &normalized_subject_candidates,
            storyboard_row,
            bias,
            false,
        )
    } else {
        select_ranked_rejected_video_memory_observation_notes(observation_scored, bias)
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
    bias: Option<VideoPromptMemorySelectionBias>,
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
    let selected = normalize_negative_note_output_fragments(trim_rejected_fragments_for_bias(
        drop_motion_fillers_when_performance_exists(selected),
        bias,
    ));
    (!selected.is_empty())
        .then(|| vec![selected.join(", ")])
        .unwrap_or_default()
}

fn select_ranked_rejected_video_memory_observation_notes(
    mut scored: Vec<(i32, usize, usize, usize, u8, i32, usize, String)>,
    bias: Option<VideoPromptMemorySelectionBias>,
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
    let notes = drop_motion_fillers_when_performance_exists(notes);
    if bias.is_some_and(|bias| bias.prefer_delivery && !bias.prefer_visual_continuity) {
        trim_rejected_fragments_for_bias(notes, bias)
    } else {
        notes
    }
}
