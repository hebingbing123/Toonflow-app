use super::*;

pub(in crate::production::workbench::video_prompt_memory) fn select_rejected_video_observation_summary_notes(
    rows: &[AgentMemoryRow],
    subject_candidates: &[String],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    bias: Option<VideoPromptMemorySelectionBias>,
    join_fragments: bool,
) -> Vec<String> {
    let storyboard_tags = storyboard_risk_tags_for_subject_fallback(storyboard_row);
    if storyboard_tags.is_empty() {
        return Vec::new();
    }
    let matching_role_summary_count = rows
        .iter()
        .filter(|row| {
            matches!(
                row.name.as_str(),
                SCRIPT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
                    | PROJECT_ROLE_VIDEO_OBSERVATION_MEMORY_NAME
            )
        })
        .filter(|row| {
            super::persist::memory_matches_rejected_video_risk_tags(&row.content, &storyboard_tags)
        })
        .filter(|row| memory_matches_subject_candidates(&row.content, subject_candidates))
        .count();

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
        .filter(|row| {
            super::persist::memory_matches_rejected_video_risk_tags(
                &row.1.content,
                &storyboard_tags,
            )
        })
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
            let fragments = prioritize_observation_summary_fragments_for_storyboard(
                retain_storyboard_matching_fragments(
                    ranked_rejected_negative_fragments(&avoid),
                    &storyboard_tags,
                ),
                &storyboard_tags,
            );
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
    let available_fragments = scored
        .iter()
        .map(|(_, _, _, _, _, _, _, _, fragment)| fragment.clone())
        .collect::<Vec<_>>();
    let mut selected = Vec::new();
    for (_, _, _, _, _, _, _, _, fragment) in scored {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            let selected = backfill_observation_summary_fragments_for_storyboard(
                selected,
                &available_fragments,
                &storyboard_tags,
            );
            return if join_fragments {
                vec![order_observation_summary_negative_output_fragments(
                    selected,
                    &available_fragments,
                    matching_role_summary_count,
                )
                .join(", ")]
            } else if should_join_pending_observation_summary_fragments(
                &selected,
                matching_role_summary_count,
            ) {
                vec![selected.join(", ")]
            } else {
                trim_pending_observation_summary_fragments(selected)
            };
        }
    }
    let selected = backfill_observation_summary_fragments_for_storyboard(
        selected,
        &available_fragments,
        &storyboard_tags,
    );
    (!selected.is_empty())
        .then(|| {
            if join_fragments {
                vec![order_observation_summary_negative_output_fragments(
                    selected,
                    &available_fragments,
                    matching_role_summary_count,
                )
                .join(", ")]
            } else if should_join_pending_observation_summary_fragments(
                &selected,
                matching_role_summary_count,
            ) {
                vec![selected.join(", ")]
            } else {
                trim_pending_observation_summary_fragments(selected)
            }
        })
        .unwrap_or_default()
}

fn should_join_pending_observation_summary_fragments(
    selected: &[String],
    matching_role_summary_count: usize,
) -> bool {
    if matching_role_summary_count < 2 {
        return false;
    }
    let has_identity = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    let has_performance = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    has_identity && has_performance
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

pub(in crate::production::workbench::video_prompt_memory) fn retain_storyboard_matching_fragments(
    mut fragments: Vec<String>,
    storyboard_tags: &[String],
) -> Vec<String> {
    if storyboard_tags.is_empty() {
        return fragments;
    }
    let has_matching_fragment = fragments
        .iter()
        .any(|fragment| fragment_storyboard_risk_overlap(fragment, storyboard_tags) > 0);
    if has_matching_fragment {
        fragments
            .retain(|fragment| fragment_storyboard_risk_overlap(fragment, storyboard_tags) > 0);
    }
    fragments
}

fn prioritize_observation_summary_fragments_for_storyboard(
    fragments: Vec<String>,
    storyboard_tags: &[String],
) -> Vec<String> {
    if fragments.len() < 2 || storyboard_tags.is_empty() {
        return fragments;
    }

    let has_storyboard_tag = |candidate: &str| storyboard_tags.iter().any(|tag| tag == candidate);
    let dialogue_scene = has_storyboard_tag("dialogue");
    let identity_scene = has_storyboard_tag("identity");
    let lighting_scene = has_storyboard_tag("lighting");
    let has_lighting_fragment = fragments.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "lighting_backlight" | "lighting_reflection"
        )
    });
    let mut remaining = fragments;
    let mut prioritized = Vec::new();
    let take_family = |family: &str, prioritized: &mut Vec<String>, remaining: &mut Vec<String>| {
        if let Some(idx) = remaining
            .iter()
            .position(|fragment| observation_note_family(fragment) == family)
        {
            prioritized.push(remaining.remove(idx));
        }
    };

    if dialogue_scene && identity_scene && has_lighting_fragment {
        take_family("performance_delivery", &mut prioritized, &mut remaining);
        take_family("character_consistency", &mut prioritized, &mut remaining);
    } else if identity_scene && lighting_scene {
        take_family("character_consistency", &mut prioritized, &mut remaining);
        take_family("lighting_backlight", &mut prioritized, &mut remaining);
        take_family("lighting_reflection", &mut prioritized, &mut remaining);
    }

    prioritized.extend(remaining);
    prioritized
}

fn backfill_observation_summary_fragments_for_storyboard(
    mut selected: Vec<String>,
    available: &[String],
    storyboard_tags: &[String],
) -> Vec<String> {
    if storyboard_tags.is_empty() {
        return selected;
    }

    let has_storyboard_tag = |candidate: &str| storyboard_tags.iter().any(|tag| tag == candidate);
    let first_available_family = |family: &str| {
        available
            .iter()
            .find(|fragment| observation_note_family(fragment) == family)
            .cloned()
    };
    let has_selected_identity = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    let has_selected_lighting = selected.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "lighting_backlight" | "lighting_reflection"
        )
    });

    if (has_storyboard_tag("identity") || has_storyboard_tag("dialogue")) && !has_selected_identity
    {
        if let Some(identity) = first_available_family("character_consistency") {
            if has_storyboard_tag("dialogue") {
                if let Some(idx) = selected.iter().position(|fragment| {
                    matches!(
                        observation_note_family(fragment),
                        "lighting_backlight" | "lighting_reflection"
                    )
                }) {
                    selected[idx] = identity;
                } else if let Some(idx) = selected.iter().position(|fragment| {
                    !matches!(
                        observation_note_family(fragment),
                        "performance_delivery" | "character_consistency"
                    )
                }) {
                    selected[idx] = identity;
                } else if selected.len() < REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
                    selected.push(identity);
                }
            } else if let Some(idx) = selected
                .iter()
                .position(|fragment| observation_note_family(fragment) == "performance_delivery")
            {
                selected[idx] = identity;
            } else if selected.len() < REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
                selected.push(identity);
            }
        }
    }

    if has_storyboard_tag("lighting") && !has_storyboard_tag("dialogue") && !has_selected_lighting {
        if let Some(lighting) = first_available_family("lighting_backlight")
            .or_else(|| first_available_family("lighting_reflection"))
        {
            if selected.len() < REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
                selected.push(lighting);
            } else if let Some(idx) = selected
                .iter()
                .position(|fragment| observation_note_family(fragment) != "character_consistency")
            {
                selected[idx] = lighting;
            }
        }
    }

    let mut deduped = Vec::new();
    for fragment in selected {
        if observation_note_is_covered(&fragment, &deduped) {
            continue;
        }
        deduped.retain(|existing| !observation_note_covers(&fragment, existing));
        deduped.push(fragment);
        if deduped.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    if !available.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "lighting_backlight" | "lighting_reflection"
        )
    }) && deduped.len() >= 2
    {
        let first_identity_idx = available
            .iter()
            .position(|fragment| observation_note_family(fragment) == "character_consistency");
        let first_performance_idx = available
            .iter()
            .position(|fragment| observation_note_family(fragment) == "performance_delivery");
        if matches!((first_identity_idx, first_performance_idx), (Some(i), Some(p)) if i < p) {
            deduped.sort_by_key(|fragment| match observation_note_family(fragment) {
                "character_consistency" => 0usize,
                "performance_delivery" => 1usize,
                _ => 2usize,
            });
        }
    }
    deduped
}

fn trim_pending_observation_summary_fragments(selected: Vec<String>) -> Vec<String> {
    let has_performance = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    let has_identity = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    if has_performance && !has_identity {
        return selected
            .into_iter()
            .filter(|fragment| observation_note_family(fragment) == "performance_delivery")
            .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
            .collect();
    }
    selected
}

pub(in crate::production::workbench::video_prompt_memory) fn trim_rejected_fragments_for_bias(
    selected: Vec<String>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let Some(bias) = bias else {
        return selected;
    };
    if bias.prefer_delivery && !bias.prefer_visual_continuity {
        let performance = selected
            .iter()
            .filter(|fragment| observation_note_family(fragment) == "performance_delivery")
            .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
            .cloned()
            .collect::<Vec<_>>();
        if !performance.is_empty() {
            return performance;
        }
    }
    selected
}

pub(in crate::production::workbench::video_prompt_memory) fn drop_motion_fillers_when_performance_exists(
    selected: Vec<String>,
) -> Vec<String> {
    let has_performance = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    let has_identity = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    if !has_performance || has_identity {
        return selected;
    }
    let filtered = selected
        .into_iter()
        .filter(|fragment| observation_note_family(fragment) != "camera_motion_stability")
        .collect::<Vec<_>>();
    if filtered.is_empty() {
        Vec::new()
    } else {
        filtered
    }
}

pub(in crate::production::workbench::video_prompt_memory) fn normalize_negative_note_output_fragments(
    mut selected: Vec<String>,
) -> Vec<String> {
    let has_motion = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "flicker_motion_jitter");
    let has_lighting = selected.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "lighting_backlight" | "lighting_reflection"
        )
    });
    let has_identity = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    let has_performance = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    if has_motion {
        for fragment in &mut selected {
            if canonical_observation_note(fragment)
                == "avoid flat cold lighting or harsh backlight silhouette"
            {
                *fragment = "avoid flat cold lighting".to_string();
            }
        }
        selected.sort_by_key(|fragment| match observation_note_family(fragment) {
            "flicker_motion_jitter" => 0usize,
            "lighting_backlight" | "lighting_reflection" => 1usize,
            _ => 2usize,
        });
    } else if has_identity && has_performance && !has_lighting {
        selected.sort_by_key(|fragment| match observation_note_family(fragment) {
            "character_consistency" => 0usize,
            "performance_delivery" => 1usize,
            _ => 2usize,
        });
    }
    selected
}

fn order_observation_summary_negative_output_fragments(
    selected: Vec<String>,
    available_fragments: &[String],
    matching_role_summary_count: usize,
) -> Vec<String> {
    let mut selected = normalize_negative_note_output_fragments(selected);
    let has_identity = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "character_consistency");
    let has_performance = selected
        .iter()
        .any(|fragment| observation_note_family(fragment) == "performance_delivery");
    if !has_identity || !has_performance {
        return selected;
    }
    let available_has_lighting = available_fragments.iter().any(|fragment| {
        matches!(
            observation_note_family(fragment),
            "lighting_backlight" | "lighting_reflection"
        )
    });
    if matching_role_summary_count >= 2 || available_has_lighting {
        selected.sort_by_key(|fragment| match observation_note_family(fragment) {
            "performance_delivery" => 0usize,
            "character_consistency" => 1usize,
            _ => 2usize,
        });
    }
    selected
}

pub(in crate::production::workbench::video_prompt_memory) fn ranked_observation_fragments(
    avoid: &str,
) -> Vec<String> {
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

pub(in crate::production::workbench::video_prompt_memory) fn rejected_negative_fragments(
    avoid: &str,
) -> Vec<String> {
    compact_rejected_negative_fragment_risk_budget(compact_rejected_negative_fragment_families(
        stitch_rejected_negative_fragments(split_prompt_note_fragments(avoid).collect()),
    ))
}

pub(in crate::production::workbench::video_prompt_memory) fn stitch_rejected_negative_fragments(
    fragments: Vec<String>,
) -> Vec<String> {
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
