use super::continuity::summarize_recurring_prefixed_fragment;
use super::style_rank::selected_video_style_value_from_content;
use super::*;

pub(super) fn distinct_selected_video_style_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    distinct_selected_video_style_notes_by_scope(
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
    )
}

pub(super) fn distinct_project_selected_video_style_notes(
    rows: &[ScopedAgentMemoryRow],
) -> Vec<String> {
    distinct_selected_video_style_notes_by_scope(
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
        Some(PROJECT_VIDEO_STYLE_MEMORY_MAX_SAMPLES_PER_SCRIPT),
    )
}

pub(super) fn distinct_selected_video_style_notes_with_subject<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
) -> Vec<(String, Vec<String>, String)> {
    let mut storyboard_keys = Vec::new();
    let mut sample_keys = Vec::new();
    let mut notes = Vec::new();

    for (name, content, scoped_storyboard_key, scope_key) in rows {
        if name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        let Some(subject) = extract_key_value(content, "subject")
            .map(|value| normalize_prompt_text(&value))
            .filter(|value| !value.is_empty())
        else {
            continue;
        };
        let aliases = role_memory_subject_candidates(content);
        let Some(note) = selected_video_style_value_from_content(content) else {
            continue;
        };
        if let Some(storyboard_key) = scoped_storyboard_key {
            let dedupe_key = format!("{subject}|{storyboard_key}");
            if storyboard_keys
                .iter()
                .any(|existing| existing == &dedupe_key)
            {
                continue;
            }
            storyboard_keys.push(dedupe_key);
        } else {
            let prompt_seed = extract_key_value(content, "promptSeed").unwrap_or_default();
            let sample_key = format!(
                "{}|{}|{}",
                subject,
                scope_key.unwrap_or_else(|| "script".to_string()),
                if prompt_seed.is_empty() {
                    note.clone()
                } else {
                    prompt_seed
                }
            );
            if sample_keys.iter().any(|existing| existing == &sample_key) {
                continue;
            }
            sample_keys.push(sample_key);
        }
        notes.push((subject, aliases, note));
    }

    notes
}

pub(super) fn role_memory_subject_candidates(content: &str) -> Vec<String> {
    let mut subjects = Vec::new();
    if let Some(subject) = extract_key_value(content, "subject")
        .map(|value| normalize_prompt_text(&value))
        .filter(|value| !value.is_empty())
    {
        subjects.push(subject);
    }
    if let Some(aliases) = extract_key_value(content, "subjectAliases") {
        subjects.extend(
            aliases
                .split(['/', '／', '、', ',', '，'])
                .map(normalize_prompt_text)
                .filter(|value| !value.is_empty()),
        );
    }
    subjects.sort();
    subjects.dedup();
    subjects
}

pub(super) fn distinct_selected_video_style_notes_by_scope<'a>(
    rows: impl Iterator<Item = (&'a str, &'a str, Option<String>, Option<String>)>,
    max_samples_per_scope: Option<usize>,
) -> Vec<String> {
    let mut storyboard_keys = Vec::new();
    let mut sample_keys = Vec::new();
    let mut scope_counts = Vec::<(String, usize)>::new();
    let mut notes = Vec::new();

    for (name, content, scoped_storyboard_key, scope_key) in rows {
        if name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        let Some(note) = selected_video_style_value_from_content(content) else {
            continue;
        };
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
            let sample_key = prompt_seed;
            if sample_key.is_empty() || sample_keys.iter().any(|existing| existing == &sample_key) {
                continue;
            }
            sample_keys.push(sample_key);
        }
        if let (Some(scope_key), Some(limit)) = (scope_key, max_samples_per_scope) {
            if let Some((_, count)) = scope_counts.iter_mut().find(|(key, _)| key == &scope_key) {
                if *count >= limit {
                    continue;
                }
                *count += 1;
            } else {
                scope_counts.push((scope_key, 1));
            }
        }
        notes.push(note);
    }

    notes
}

pub(super) fn recurring_style_fragments(notes: &[String]) -> Vec<String> {
    let parsed = notes
        .iter()
        .map(|note| split_prompt_note_fragments(note).collect::<Vec<_>>())
        .collect::<Vec<_>>();
    let mut recurring = Vec::new();

    for prefix in STYLE_PROMPT_PREFIXES {
        if let Some(fragment) = summarize_recurring_prefixed_fragment(&parsed, prefix) {
            recurring.push(fragment);
        }
    }

    recurring
}
