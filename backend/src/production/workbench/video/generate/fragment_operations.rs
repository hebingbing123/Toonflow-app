use super::fragment_parsing::*;
use super::quality_control::score_review_negative_fragment_bias;
use super::*;

pub(super) fn merge_negative_prompts(
    manual: Option<&str>,
    automatic: Option<&str>,
) -> Option<String> {
    merge_negative_prompt_fragment_groups(&[
        split_negative_prompt_fragments(manual),
        split_negative_prompt_fragments(automatic),
    ])
}

pub(super) fn merge_negative_prompt_fragment_groups(groups: &[Vec<String>]) -> Option<String> {
    let fragments = compact_negative_prompt_fragment_groups(groups);
    let joined = fragments.join(", ");
    let budgeted = if joined.chars().count() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS {
        fragments
    } else {
        prioritize_negative_prompt_fragments_for_budget(fragments)
    };
    if budgeted.is_empty() {
        None
    } else {
        Some(budgeted.join(", "))
    }
}

fn compact_negative_prompt_fragment_groups(groups: &[Vec<String>]) -> Vec<String> {
    let mut fragments = Vec::new();
    for group in groups {
        for fragment in group {
            push_negative_fragment_without_budget(&mut fragments, fragment);
        }
    }
    compact_negative_fragment_families(fragments)
}

fn prioritize_negative_prompt_fragments_for_budget(fragments: Vec<String>) -> Vec<String> {
    let mut prioritized = fragments
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            (
                score_negative_prompt_budget_fragment(&fragment),
                negative_fragment_information_score(&fragment),
                idx,
                fragment,
            )
        })
        .collect::<Vec<_>>();
    prioritized.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.cmp(&b.3))
    });

    let mut budgeted = Vec::new();
    for (_, _, _, fragment) in prioritized {
        push_negative_fragment_with_budget(
            &mut budgeted,
            &fragment,
            VideoNegativePromptBudgetTier::Expanded,
        );
    }
    budgeted
}

pub(super) fn merge_prioritized_negative_prompt_fragment_groups(
    groups: &[Vec<String>],
    budget_tier: VideoNegativePromptBudgetTier,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> Option<String> {
    let mut candidates = Vec::new();
    for (group_idx, group) in groups.iter().enumerate() {
        for (fragment_idx, fragment) in group.iter().enumerate() {
            candidates.push(PrioritizedNegativePromptFragment {
                score: score_negative_prompt_budget_fragment_with_pressure(
                    fragment,
                    recent_quality_pressure,
                ),
                char_len: negative_fragment_information_score(fragment),
                group_idx,
                fragment_idx,
                fragment: fragment.clone(),
            });
        }
    }
    candidates.sort_by(|a, b| {
        b.score
            .cmp(&a.score)
            .then(a.char_len.cmp(&b.char_len))
            .then(a.group_idx.cmp(&b.group_idx))
            .then(a.fragment_idx.cmp(&b.fragment_idx))
            .then(a.fragment.cmp(&b.fragment))
    });

    let mut fragments = Vec::new();
    for candidate in candidates {
        push_negative_fragment_without_budget(&mut fragments, &candidate.fragment);
    }
    fragments = compact_negative_fragment_families(fragments);
    fragments =
        prune_negative_prompt_fragments_for_recent_quality(fragments, recent_quality_pressure);
    fragments.sort_by(|left, right| {
        score_negative_prompt_budget_fragment_with_pressure(right, recent_quality_pressure)
            .cmp(&score_negative_prompt_budget_fragment_with_pressure(
                left,
                recent_quality_pressure,
            ))
            .then(
                negative_fragment_information_score(left)
                    .cmp(&negative_fragment_information_score(right)),
            )
            .then(left.cmp(right))
    });

    let mut budgeted = Vec::new();
    for fragment in fragments {
        push_negative_fragment_with_budget(&mut budgeted, &fragment, budget_tier);
    }
    if budgeted.is_empty() {
        None
    } else {
        Some(budgeted.join(", "))
    }
}

pub(super) fn prune_negative_prompt_fragments_for_recent_quality(
    fragments: Vec<String>,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> Vec<String> {
    let Some(pressure) = recent_quality_pressure else {
        return fragments;
    };
    if fragments.len() <= 1 {
        return fragments;
    }

    let has_performance_guard = fragments
        .iter()
        .any(|fragment| negative_fragment_family(fragment) == "performance_delivery");
    let has_visual_continuity_guard = fragments.iter().any(|fragment| {
        matches!(
            negative_fragment_family(fragment),
            "character_consistency"
                | "lighting_backlight"
                | "lighting_reflection"
                | "shot_change_only"
                | "shot_change_framing"
                | "camera_framing"
                | "rushed_motion"
                | "flicker_motion_jitter"
        )
    });
    let has_specific_framing_guard = fragments.iter().any(|fragment| {
        matches!(
            negative_fragment_family(fragment),
            "shot_change_framing" | "camera_framing"
        )
    });

    let pruned = fragments
        .into_iter()
        .filter(|fragment| {
            let family = negative_fragment_family(fragment);
            if family == "mood_tone"
                && ((pressure.prefer_delivery_memory_recall && has_performance_guard)
                    || (pressure.prefer_visual_continuity_memory_recall
                        && has_visual_continuity_guard))
            {
                return false;
            }
            if family == "shot_change_only"
                && pressure.prefer_visual_continuity_memory_recall
                && has_specific_framing_guard
            {
                return false;
            }
            true
        })
        .collect::<Vec<_>>();

    if pruned.is_empty() {
        Vec::new()
    } else {
        pruned
    }
}

#[derive(Debug)]
struct PrioritizedNegativePromptFragment {
    score: i32,
    char_len: usize,
    group_idx: usize,
    fragment_idx: usize,
    fragment: String,
}

fn score_negative_prompt_budget_fragment(fragment: &str) -> i32 {
    score_negative_prompt_budget_fragment_with_pressure(fragment, None)
}

fn score_negative_prompt_budget_fragment_with_pressure(
    fragment: &str,
    recent_quality_pressure: Option<VideoPromptConstraintPressure>,
) -> i32 {
    let canonical = canonical_negative_fragment(fragment);
    let family_score = match negative_fragment_family(fragment) {
        "flicker_motion_jitter" => 36,
        "shot_change_only" => 30,
        "shot_change_framing" | "camera_framing" => 34,
        "performance_delivery" => 26,
        "lighting_backlight" | "lighting_reflection" => 22,
        "mood_tone" => 16,
        _ => 14,
    };
    let detail_score = if canonical.contains("face")
        || canonical.contains("costume")
        || canonical.contains("character")
    {
        40
    } else if canonical.contains("warped")
        || canonical.contains("anatom")
        || canonical.contains("blur")
    {
        38
    } else if canonical.contains("setting") {
        18
    } else {
        0
    };
    let breadth_score = [
        canonical.contains("warped") || canonical.contains("anatom"),
        canonical.contains("blur"),
        canonical.contains("flicker") || canonical.contains("jitter"),
        canonical.contains("face") || canonical.contains("identity"),
        canonical.contains("costume") || canonical.contains("character"),
    ]
    .into_iter()
    .filter(|present| *present)
    .count() as i32
        * 4;
    family_score
        + detail_score
        + breadth_score
        + score_review_negative_fragment_bias(fragment, recent_quality_pressure)
        - negative_fragment_information_score(fragment) as i32 / 8
}

fn compact_negative_fragment_families(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = Vec::with_capacity(fragments.len());
    let mut character_flags = CharacterConsistencyFlags::default();
    let mut character_idx = None;
    let mut character_fragment = None;
    let mut character_fragment_count = 0usize;
    let mut visual_style_flags = VisualStyleConstraintFlags::default();
    let mut visual_style_idx = None;
    let mut visual_error_flags = VisualErrorFlags::default();
    let mut visual_error_idx = None;
    let mut visual_error_fragment = None;
    let mut visual_error_fragment_count = 0usize;
    let mut visual_error_uses_motion_jitter_wording = false;

    for (idx, fragment) in fragments.into_iter().enumerate() {
        if let Some(flags) = parse_character_consistency_fragment(&fragment) {
            character_idx.get_or_insert(idx);
            character_fragment_count += 1;
            if character_fragment.is_none() {
                character_fragment = Some(fragment.clone());
            }
            character_flags.face_distortion |= flags.face_distortion;
            character_flags.identity_drift |= flags.identity_drift;
            character_flags.costume_inconsistency |= flags.costume_inconsistency;
            continue;
        }
        if let Some(flags) = parse_visual_style_constraint_fragment(&fragment) {
            visual_style_idx.get_or_insert(idx);
            visual_style_flags.unnecessary_shot_changes |= flags.unnecessary_shot_changes;
            visual_style_flags.extreme_camera_angle |= flags.extreme_camera_angle;
            visual_style_flags.tight_close_up |= flags.tight_close_up;
            visual_style_flags.oppressive_mood |= flags.oppressive_mood;
            visual_style_flags.frantic_mood |= flags.frantic_mood;
            visual_style_flags.blank_expression_or_monotone_delivery |=
                flags.blank_expression_or_monotone_delivery;
            visual_style_flags.overly_cold_emotional_tone |= flags.overly_cold_emotional_tone;
            visual_style_flags.flat_cold_lighting |= flags.flat_cold_lighting;
            visual_style_flags.harsh_backlight_silhouette |= flags.harsh_backlight_silhouette;
            continue;
        }
        if let Some(flags) = parse_visual_error_fragment(&fragment) {
            visual_error_idx.get_or_insert(idx);
            visual_error_fragment_count += 1;
            if visual_error_fragment.is_none() {
                visual_error_fragment = Some(fragment.clone());
            }
            if canonical_negative_fragment(&fragment) == "avoid flicker or motion jitter" {
                visual_error_uses_motion_jitter_wording = true;
            }
            visual_error_flags.warped_anatomy |= flags.warped_anatomy;
            visual_error_flags.blur |= flags.blur;
            visual_error_flags.flicker |= flags.flicker;
            continue;
        }
        compacted.push((idx, fragment));
    }

    if let Some(idx) = character_idx {
        let fragment = if character_fragment_count == 1 {
            character_fragment
                .unwrap_or_else(|| render_character_consistency_fragment(character_flags))
        } else {
            render_character_consistency_fragment(character_flags)
        };
        compacted.push((idx, fragment));
    }
    if let Some(idx) = visual_style_idx {
        for fragment in render_visual_style_constraint_fragments(visual_style_flags) {
            compacted.push((idx, fragment));
        }
    }
    if let Some(idx) = visual_error_idx {
        let rendered_fragments = if visual_error_fragment_count == 1 {
            vec![visual_error_fragment.unwrap_or_else(|| {
                render_visual_error_fragments_for_budget(
                    visual_error_flags,
                    visual_error_uses_motion_jitter_wording,
                )
                .join(", ")
            })]
        } else {
            render_visual_error_fragments_for_budget(
                visual_error_flags,
                visual_error_uses_motion_jitter_wording,
            )
        };
        for fragment in rendered_fragments {
            compacted.push((idx, fragment));
        }
    }
    compacted.sort_by_key(|item| item.0);
    compact_rushed_motion_and_jerky_fragment_pair(
        compacted
            .into_iter()
            .map(|(_, fragment)| fragment)
            .collect(),
    )
}

pub(super) fn split_negative_prompt_fragments(prompt: Option<&str>) -> Vec<String> {
    let mut raw_fragments = Vec::new();
    if let Some(prompt) = prompt {
        for fragment in prompt.split([',', ';', '，', '；', '\n']) {
            let fragment = fragment.trim();
            if fragment.is_empty() {
                continue;
            }
            raw_fragments.push(fragment.to_string());
        }
    }

    let mut fragments = Vec::new();
    for fragment in stitch_split_negative_fragments(raw_fragments) {
        if negative_fragment_is_covered(&fragment, &fragments) {
            continue;
        }
        fragments.retain(|existing| !negative_fragment_covers(&fragment, existing));
        fragments.push(fragment);
    }
    fragments
}

fn stitch_split_negative_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut stitched = Vec::with_capacity(fragments.len());
    let mut idx = 0usize;
    while idx < fragments.len() {
        if let Some((combined, consumed)) =
            match_known_negative_fragment_sequence(&fragments[idx..])
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

fn match_known_negative_fragment_sequence(parts: &[String]) -> Option<(String, usize)> {
    const KNOWN_COMPOSITES: &[(&str, usize)] = &[
        ("avoid overly cold, oppressive, or frantic mood", 3),
        ("avoid warped anatomy, blur, flicker", 3),
        ("avoid face distortion, identity drift, costume drift", 3),
        ("avoid flat cold lighting or harsh backlight silhouette", 1),
    ];

    for &(candidate, consumed) in KNOWN_COMPOSITES {
        if parts.len() < consumed {
            continue;
        }
        let joined = parts[..consumed].join(", ");
        if canonical_negative_fragment(&joined) == canonical_negative_fragment(candidate) {
            return Some((candidate.to_string(), consumed));
        }
    }
    None
}

pub(super) fn push_negative_fragment_without_budget(target: &mut Vec<String>, candidate: &str) {
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    target.push(candidate.to_string());
}

fn push_negative_fragment_with_budget(
    target: &mut Vec<String>,
    candidate: &str,
    budget_tier: VideoNegativePromptBudgetTier,
) {
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    let mut next = target.clone();
    next.push(candidate.to_string());
    let joined = next.join(", ");
    if next.len() <= negative_prompt_fragment_budget(budget_tier)
        && joined.chars().count() <= negative_prompt_char_budget(budget_tier)
    {
        *target = next;
        return;
    }

    let clipped = clip_negative_prompt(candidate, budget_tier);
    if clipped.is_empty() || negative_fragment_is_covered(&clipped, target) {
        return;
    }
    let mut clipped_next = target.clone();
    clipped_next.push(clipped);
    let clipped_joined = clipped_next.join(", ");
    if clipped_next.len() <= negative_prompt_fragment_budget(budget_tier)
        && clipped_joined.chars().count() <= negative_prompt_char_budget(budget_tier)
    {
        *target = clipped_next;
    }
}

pub(super) fn negative_fragment_is_covered(candidate: &str, existing_fragments: &[String]) -> bool {
    existing_fragments
        .iter()
        .any(|existing| negative_fragment_covers(existing, candidate))
}

fn negative_fragment_same_family(existing: &str, candidate: &str) -> bool {
    let existing = negative_fragment_family(existing);
    let candidate = negative_fragment_family(candidate);
    !existing.is_empty() && existing == candidate
}

fn negative_fragment_covers(existing: &str, candidate: &str) -> bool {
    if let (Some(existing_flags), Some(candidate_flags)) = (
        parse_visual_error_fragment(existing),
        parse_visual_error_fragment(candidate),
    ) {
        if visual_error_flags_cover(existing_flags, candidate_flags) {
            return negative_fragment_information_score(existing)
                >= negative_fragment_information_score(candidate);
        }
        return false;
    }
    if let (Some(existing_flags), Some(candidate_flags)) = (
        parse_character_consistency_fragment(existing),
        parse_character_consistency_fragment(candidate),
    ) {
        return character_consistency_flags_cover(existing_flags, candidate_flags);
    }
    if let (Some(existing_flags), Some(candidate_flags)) = (
        parse_visual_style_constraint_fragment(existing),
        parse_visual_style_constraint_fragment(candidate),
    ) {
        return visual_style_constraint_flags_cover(existing_flags, candidate_flags);
    }
    if negative_fragment_same_family(existing, candidate) {
        return negative_fragment_information_score(existing)
            >= negative_fragment_information_score(candidate);
    }
    negative_fragment_contains(existing, candidate)
}

fn compact_rushed_motion_and_jerky_fragment_pair(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = Vec::with_capacity(fragments.len());
    let mut saw_rushed_motion = false;
    let mut saw_motion_jitter = false;
    let mut insertion_idx = None;

    for fragment in fragments {
        match canonical_negative_fragment(&fragment).as_str() {
            "avoid rushed motion" => {
                saw_rushed_motion = true;
                insertion_idx.get_or_insert(compacted.len());
            }
            "avoid flicker or motion jitter" => {
                saw_motion_jitter = true;
                insertion_idx.get_or_insert(compacted.len());
            }
            _ => compacted.push(fragment),
        }
    }

    let insertion_idx = insertion_idx.unwrap_or(compacted.len());
    if saw_rushed_motion && saw_motion_jitter {
        compacted.insert(insertion_idx, "avoid rushed or jerky motion".to_string());
    } else {
        if saw_rushed_motion {
            compacted.insert(insertion_idx, "avoid rushed motion".to_string());
        }
        if saw_motion_jitter {
            compacted.insert(insertion_idx, "avoid flicker or motion jitter".to_string());
        }
    }

    compacted
}

fn render_visual_error_fragments_for_budget(
    flags: VisualErrorFlags,
    use_motion_jitter_wording: bool,
) -> Vec<String> {
    if flags.warped_anatomy && flags.blur && flags.flicker {
        return vec!["avoid warped anatomy, blur, flicker".to_string()];
    }
    if flags.warped_anatomy && flags.blur {
        return vec!["avoid warped anatomy or blur".to_string()];
    }

    let mut fragments = Vec::new();
    if flags.warped_anatomy {
        fragments.push("avoid warped hands or limbs".to_string());
    }
    if flags.blur {
        fragments.push("avoid blur".to_string());
    }
    if flags.flicker {
        fragments.push(if use_motion_jitter_wording {
            "avoid flicker or motion jitter".to_string()
        } else {
            "avoid flicker".to_string()
        });
    }
    fragments
}

fn negative_fragment_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_negative_fragment(existing);
    let candidate = canonical_negative_fragment(candidate);
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

fn negative_prompt_char_budget(budget_tier: VideoNegativePromptBudgetTier) -> usize {
    match budget_tier {
        VideoNegativePromptBudgetTier::Lean => VIDEO_NEGATIVE_PROMPT_LEAN_MAX_CHARS,
        VideoNegativePromptBudgetTier::Expanded => VIDEO_NEGATIVE_PROMPT_MAX_CHARS,
    }
}

fn negative_prompt_fragment_budget(budget_tier: VideoNegativePromptBudgetTier) -> usize {
    match budget_tier {
        VideoNegativePromptBudgetTier::Lean => VIDEO_NEGATIVE_PROMPT_LEAN_FRAGMENT_LIMIT,
        VideoNegativePromptBudgetTier::Expanded => usize::MAX,
    }
}

pub(super) fn clip_negative_prompt(
    prompt: &str,
    budget_tier: VideoNegativePromptBudgetTier,
) -> String {
    let normalized = prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut chars = normalized.chars();
    let clipped = chars
        .by_ref()
        .take(negative_prompt_char_budget(budget_tier))
        .collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}
