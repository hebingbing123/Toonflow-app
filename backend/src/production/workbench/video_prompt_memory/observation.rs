use super::*;

pub(super) fn build_script_video_observation_memory_with_bias(
    rows: &[AgentMemoryRow],
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Option<String> {
    build_video_observation_memory(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds")
                    .map(|storyboard_id| format!("script:{storyboard_id}")),
                None,
            )
        }),
        None,
        bias,
    )
}

pub(super) fn build_project_video_observation_memory_with_bias(
    rows: &[ScopedAgentMemoryRow],
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Option<String> {
    build_video_observation_memory(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                    format!(
                        "{}:{storyboard_id}",
                        row.episodes_id
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "project".to_string())
                    )
                }),
                row.episodes_id.map(|value| value.to_string()),
            )
        }),
        Some(PROJECT_VIDEO_OBSERVATION_MEMORY_MAX_SAMPLES_PER_SCRIPT),
        bias,
    )
}

pub(super) fn build_script_role_video_observation_memories_with_bias(
    rows: &[AgentMemoryRow],
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    build_role_video_observation_memories(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds")
                    .map(|storyboard_id| format!("script:{storyboard_id}")),
                None,
            )
        }),
        bias,
    )
}

pub(super) fn build_project_role_video_observation_memories_with_bias(
    rows: &[ScopedAgentMemoryRow],
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    build_role_video_observation_memories(
        rows.iter().map(|row| {
            (
                row.name.as_str(),
                row.content.as_str(),
                extract_key_value(&row.content, "storyboardIds").map(|storyboard_id| {
                    format!(
                        "{}:{storyboard_id}",
                        row.episodes_id
                            .map(|value| value.to_string())
                            .unwrap_or_else(|| "project".to_string())
                    )
                }),
                row.episodes_id.map(|value| value.to_string()),
            )
        }),
        bias,
    )
}

#[allow(dead_code)] // Unbiased entry points; production uses `*_with_bias`.
fn build_script_video_observation_memory(rows: &[AgentMemoryRow]) -> Option<String> {
    build_script_video_observation_memory_with_bias(rows, None)
}

#[allow(dead_code)] // Unbiased entry points; production uses `*_with_bias`.
fn build_project_video_observation_memory(rows: &[ScopedAgentMemoryRow]) -> Option<String> {
    build_project_video_observation_memory_with_bias(rows, None)
}

#[allow(dead_code)]
fn build_script_role_video_observation_memories(rows: &[AgentMemoryRow]) -> Vec<String> {
    build_script_role_video_observation_memories_with_bias(rows, None)
}

fn build_video_observation_memory<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    max_samples_per_scope: Option<usize>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Option<String> {
    let samples = distinct_rejected_video_observation_samples(rows, max_samples_per_scope);
    if samples.len() < 2 {
        return None;
    }

    let fragments = summarize_observation_fragments(
        samples.iter().map(|sample| sample.avoid.as_str()),
        REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT,
        bias,
    );
    if fragments.is_empty() {
        return None;
    }

    let risk_tags = summarize_observation_risk_tags(&samples, bias);
    let mut parts = vec![format!("sampleCount={}", samples.len())];
    if !risk_tags.is_empty() {
        parts.push(format!("riskTags={}", risk_tags.join("/")));
    }
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

fn build_role_video_observation_memories<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    #[derive(Default)]
    struct RoleObservationGroup {
        primary_subject: String,
        aliases: Vec<String>,
        samples: Vec<RejectedObservationSample>,
    }

    let mut grouped = Vec::<RoleObservationGroup>::new();
    for sample in distinct_rejected_video_observation_samples(rows, None) {
        if sample.subject.is_empty() || sample.subject_aliases.is_empty() {
            continue;
        }
        if let Some(existing) = grouped.iter_mut().find(|group| {
            group.aliases.iter().any(|alias| {
                sample
                    .subject_aliases
                    .iter()
                    .any(|candidate| candidate == alias)
            })
        }) {
            if existing.primary_subject.is_empty() {
                existing.primary_subject = sample.subject.clone();
            }
            existing.aliases.extend(sample.subject_aliases.clone());
            existing.aliases.sort();
            existing.aliases.dedup();
            existing.samples.push(sample);
            continue;
        }

        grouped.push(RoleObservationGroup {
            primary_subject: sample.subject.clone(),
            aliases: sample.subject_aliases.clone(),
            samples: vec![sample],
        });
    }

    grouped
        .into_iter()
        .filter_map(|group| {
            if group.samples.len() < 2 {
                return None;
            }
            let fragments = summarize_observation_fragments(
                group.samples.iter().map(|sample| sample.avoid.as_str()),
                REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT,
                bias,
            );
            if fragments.is_empty() {
                return None;
            }
            let risk_tags = summarize_observation_risk_tags(&group.samples, bias);
            let primary_subject = clip_prompt_fragment(&group.primary_subject, 16);
            let subject_aliases = group
                .aliases
                .into_iter()
                .filter(|alias| alias != &group.primary_subject)
                .collect::<Vec<_>>();
            let mut parts = vec![
                format!("subject={primary_subject}"),
                format!("sampleCount={}", group.samples.len()),
            ];
            if !subject_aliases.is_empty() {
                parts.push(format!("subjectAliases={}", subject_aliases.join("/")));
            }
            if !risk_tags.is_empty() {
                parts.push(format!("riskTags={}", risk_tags.join("/")));
            }
            parts.push(format!("avoid={}", fragments.join(", ")));
            Some(parts.join(" | "))
        })
        .collect()
}

#[derive(Debug, Clone)]
struct RejectedObservationSample {
    subject: String,
    subject_aliases: Vec<String>,
    avoid: String,
    risk_tags: Vec<String>,
}

fn distinct_rejected_video_observation_samples<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    max_samples_per_scope: Option<usize>,
) -> Vec<RejectedObservationSample> {
    let mut storyboard_keys = Vec::new();
    let mut sample_keys = Vec::new();
    let mut scope_counts = Vec::<(String, usize)>::new();
    let mut samples = Vec::new();

    for (name, content, scoped_storyboard_key, scope_key) in rows {
        if name != REJECTED_VIDEO_NEGATIVE_MEMORY_NAME
            || rejected_video_negative_rejection_count(content)
                < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        {
            continue;
        }
        let Some(avoid) = extract_key_value(content, "avoid")
            .map(|value| compact_rejected_negative_avoid(&value))
        else {
            continue;
        };
        if avoid.is_empty() {
            continue;
        }

        if let Some(storyboard_key) = scoped_storyboard_key {
            if storyboard_keys
                .iter()
                .any(|existing| existing == &storyboard_key)
            {
                continue;
            }
            storyboard_keys.push(storyboard_key);
        } else {
            let prompt_seed = extract_key_value(content, "promptSeed").unwrap_or_default();
            let scope_key = scope_key.unwrap_or_else(|| "script".to_string());
            let sample_key = if prompt_seed.is_empty() {
                format!("{scope_key}|{avoid}")
            } else {
                format!("{scope_key}|{prompt_seed}")
            };
            if sample_keys.iter().any(|existing| existing == &sample_key) {
                continue;
            }
            if let Some(limit) = max_samples_per_scope {
                let count = scope_counts
                    .iter_mut()
                    .find(|(existing_scope, _)| existing_scope == &scope_key);
                match count {
                    Some((_, count)) if *count >= limit => continue,
                    Some((_, count)) => *count += 1,
                    None => scope_counts.push((scope_key.clone(), 1)),
                }
            }
            sample_keys.push(sample_key);
        }

        let subject = extract_key_value(content, "subject")
            .map(|value| normalize_prompt_text(&value))
            .unwrap_or_default();
        samples.push(RejectedObservationSample {
            subject,
            subject_aliases: role_memory_subject_candidates(content),
            avoid,
            risk_tags: extract_rejected_video_risk_tags(content),
        });
    }

    samples
}

fn summarize_observation_fragments<'a>(
    avoids: impl Iterator<Item = &'a str>,
    limit: usize,
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let mut counts = Vec::<(String, usize, i32)>::new();
    for avoid in avoids {
        let mut seen = Vec::<String>::new();
        for fragment in ranked_rejected_negative_fragments(avoid) {
            if seen.iter().any(|existing| existing == &fragment) {
                continue;
            }
            seen.push(fragment.clone());
            if let Some((_, count, _)) = counts
                .iter_mut()
                .find(|(existing, _, _)| existing == &fragment)
            {
                *count += 1;
            } else {
                counts.push((
                    fragment.clone(),
                    1,
                    score_rejected_negative_fragment(&fragment),
                ));
            }
        }
    }
    counts.sort_by(|a, b| {
        score_rejected_video_memory_bias_for_fragment(&b.0, bias)
            .cmp(&score_rejected_video_memory_bias_for_fragment(&a.0, bias))
            .then(b.1.cmp(&a.1))
            .then(b.2.cmp(&a.2))
            .then(a.0.cmp(&b.0))
    });

    let mut selected = Vec::new();
    for (fragment, count, _) in counts {
        if count < 2 {
            continue;
        }
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= limit {
            break;
        }
    }
    selected
}

fn summarize_observation_risk_tags(
    samples: &[RejectedObservationSample],
    bias: Option<VideoPromptMemorySelectionBias>,
) -> Vec<String> {
    let mut counts = Vec::<(String, usize)>::new();
    for sample in samples {
        let mut seen = Vec::<String>::new();
        for tag in &sample.risk_tags {
            if seen.iter().any(|existing| existing == tag) {
                continue;
            }
            seen.push(tag.clone());
            if let Some((_, count)) = counts.iter_mut().find(|(existing, _)| existing == tag) {
                *count += 1;
            } else {
                counts.push((tag.clone(), 1));
            }
        }
    }
    counts.sort_by(|a, b| {
        observation_risk_tag_bias_score(&b.0, bias)
            .cmp(&observation_risk_tag_bias_score(&a.0, bias))
            .then(b.1.cmp(&a.1))
            .then(a.0.cmp(&b.0))
    });
    counts
        .into_iter()
        .filter(|(_, count)| *count >= 2)
        .map(|(tag, _)| tag)
        .take(REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT)
        .collect()
}

fn observation_risk_tag_bias_score(tag: &str, bias: Option<VideoPromptMemorySelectionBias>) -> i32 {
    let Some(bias) = bias else {
        return 0;
    };
    match tag {
        "performance" if bias.prefer_delivery => 5,
        "dialogue" | "emotion" if bias.prefer_delivery => 4,
        "identity" if bias.prefer_visual_continuity => 5,
        "lighting" if bias.prefer_visual_continuity => 4,
        "framing" if bias.prefer_visual_continuity => 3,
        "motion" if bias.prefer_visual_continuity => 2,
        _ => 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_script_video_observation_memory_summarizes_recurring_failure_guards() {
        let summary = build_script_video_observation_memory(&[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | rejectionCount=2 | riskTags=motion/lighting | avoid=avoid shaky handheld motion, avoid flat cold lighting".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=10 | rejectionCount=3 | riskTags=motion/lighting | avoid=avoid shaky handheld motion, avoid harsh backlight silhouette".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=11 | rejectionCount=2 | riskTags=motion | avoid=avoid shaky handheld motion".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"), "{summary}");
        assert!(summary.contains("riskTags=motion/lighting"), "{summary}");
        assert!(
            summary.contains("avoid=avoid shaky handheld motion"),
            "{summary}"
        );
        assert!(!summary.contains("harsh backlight"), "{summary}");
    }

    #[test]
    fn build_script_video_observation_memory_prefers_performance_guard_over_generic_mood_tone() {
        let summary = build_script_video_observation_memory(&[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | rejectionCount=2 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid oppressive or frantic mood".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=10 | rejectionCount=2 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid heavy tragic mood".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("avoid blank expression or monotone delivery"));
        assert!(!summary.contains("oppressive or frantic mood"), "{summary}");
        assert!(!summary.contains("heavy tragic mood"), "{summary}");
    }

    #[test]
    fn build_script_video_observation_memory_with_bias_prefers_delivery_guard_over_visual_tie() {
        let summary = build_script_video_observation_memory_with_bias(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=9 | rejectionCount=2 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid flat cold lighting".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=10 | rejectionCount=2 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid harsh backlight silhouette".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=11 | rejectionCount=2 | riskTags=lighting/motion | avoid=avoid flat cold lighting, avoid shaky handheld motion".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | riskTags=lighting/motion | avoid=avoid flat cold lighting, avoid shaky handheld motion".into(),
                },
            ],
            Some(VideoPromptMemorySelectionBias {
                prefer_delivery: true,
                prefer_visual_continuity: false,
            }),
        )
        .expect("summary");

        assert!(
            summary.contains("riskTags=performance/dialogue"),
            "{summary}"
        );
        assert!(
            summary.contains("avoid blank expression or monotone delivery"),
            "{summary}"
        );
        assert!(summary.contains("avoid flat cold lighting"), "{summary}");
        assert!(
            !summary.contains("avoid shaky handheld motion"),
            "{summary}"
        );
    }

    #[test]
    fn build_project_video_observation_memory_with_bias_prefers_visual_continuity_guard() {
        let summary = build_project_video_observation_memory_with_bias(
            &[
                ScopedAgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=3 | rejectionCount=2 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid flat cold lighting".into(),
                    episodes_id: Some(1),
                },
                ScopedAgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=9 | rejectionCount=2 | riskTags=dialogue/performance | avoid=avoid blank expression or monotone delivery, avoid harsh backlight silhouette".into(),
                    episodes_id: Some(2),
                },
                ScopedAgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=17 | rejectionCount=2 | riskTags=identity/lighting | avoid=avoid face distortion or identity drift, avoid harsh backlight silhouette".into(),
                    episodes_id: Some(3),
                },
                ScopedAgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=18 | rejectionCount=2 | riskTags=identity/lighting | avoid=avoid face distortion or identity drift, avoid harsh backlight silhouette".into(),
                    episodes_id: Some(4),
                },
            ],
            Some(VideoPromptMemorySelectionBias {
                prefer_delivery: false,
                prefer_visual_continuity: true,
            }),
        )
        .expect("summary");

        assert!(summary.contains("riskTags=identity/lighting"), "{summary}");
        assert!(
            summary.contains("avoid face distortion or identity drift"),
            "{summary}"
        );
        assert!(
            summary.contains("avoid harsh backlight silhouette"),
            "{summary}"
        );
        assert!(
            !summary.contains("avoid blank expression or monotone delivery"),
            "{summary}"
        );
    }

    #[test]
    fn build_script_role_video_observation_memories_groups_subject_specific_failures() {
        let summaries = build_script_role_video_observation_memories(&[
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=10 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=3 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
            },
        ]);

        assert_eq!(summaries.len(), 1);
        let summary = &summaries[0];
        assert!(
            summary.contains("subject=林晚") || summary.contains("subject=晚晚"),
            "{summary}"
        );
        assert!(summary.contains("subjectAliases="), "{summary}");
        assert!(
            summary.contains("riskTags=dialogue/identity")
                || summary.contains("riskTags=identity/dialogue"),
            "{summary}"
        );
        assert!(summary.contains("avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery"), "{summary}");
    }

    #[test]
    fn build_script_role_video_observation_memories_with_bias_prioritizes_visual_identity_guard() {
        let summaries = build_script_role_video_observation_memories_with_bias(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=9 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=10 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=identity/dialogue | avoid=avoid face distortion or identity drift, avoid blank expression or monotone delivery".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=11 | subject=林晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=lighting/motion | avoid=avoid harsh backlight silhouette, avoid shaky handheld motion".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | subject=晚晚 | subjectAliases=林晚/晚晚 | rejectionCount=2 | riskTags=lighting/motion | avoid=avoid harsh backlight silhouette, avoid shaky handheld motion".into(),
                },
            ],
            Some(VideoPromptMemorySelectionBias {
                prefer_delivery: false,
                prefer_visual_continuity: true,
            }),
        );

        assert_eq!(summaries.len(), 1);
        let summary = &summaries[0];
        assert!(
            summary.contains(
                "avoid=avoid face distortion or identity drift, avoid harsh backlight silhouette"
            ),
            "{summary}"
        );
        assert!(summary.contains("riskTags=identity/lighting"), "{summary}");
        assert!(
            !summary.contains("avoid blank expression or monotone delivery"),
            "{summary}"
        );
    }
}
