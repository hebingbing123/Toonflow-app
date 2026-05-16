use super::*;

pub(crate) fn compact_video_continuity_note(note: &str) -> Option<String> {
    let fragments = split_prompt_note_fragments(note)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            STYLE_NOTE_PREFIXES
                .iter()
                .any(|prefix| fragment.starts_with(prefix))
                || CONTINUITY_NOTE_KEYWORDS
                    .iter()
                    .any(|keyword| fragment.contains(keyword))
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn pick_recurring_prefixed_fragment(parsed_notes: &[Vec<String>], prefix: &str) -> Option<String> {
    let min_support = recurring_fragment_support_threshold(parsed_notes.len());
    let mut counts: Vec<(String, usize, usize)> = Vec::new();
    for (note_idx, fragments) in parsed_notes.iter().enumerate() {
        for fragment in fragments {
            if !fragment.starts_with(prefix) {
                continue;
            }
            if let Some(existing) = counts.iter_mut().find(|(value, _, _)| value == fragment) {
                existing.1 += 1;
                existing.2 = existing.2.min(note_idx);
            } else {
                counts.push((fragment.clone(), 1, note_idx));
            }
        }
    }

    counts
        .into_iter()
        .filter(|(_, count, _)| *count >= min_support)
        .max_by(|a, b| a.1.cmp(&b.1).then_with(|| b.2.cmp(&a.2)))
        .map(|(value, _, _)| value)
}

pub(super) fn summarize_recurring_prefixed_fragment(
    parsed_notes: &[Vec<String>],
    prefix: &str,
) -> Option<String> {
    if prefix == "镜头" {
        summarize_recurring_style_keywords(parsed_notes, prefix)
            .or_else(|| summarize_recurring_stable_shot_fragment(parsed_notes))
    } else {
        pick_recurring_prefixed_fragment(parsed_notes, prefix)
            .or_else(|| summarize_recurring_style_keywords(parsed_notes, prefix))
    }
}

fn summarize_recurring_stable_shot_fragment(parsed_notes: &[Vec<String>]) -> Option<String> {
    pick_recurring_prefixed_fragment(parsed_notes, "镜头").and_then(|fragment| {
        let matched = extract_style_keywords(&fragment, "镜头", &SHOT_STYLE_KEYWORDS);
        if matched.is_empty() {
            None
        } else {
            Some(format!("镜头{}", matched.join("")))
        }
    })
}

fn summarize_recurring_style_keywords(
    parsed_notes: &[Vec<String>],
    prefix: &str,
) -> Option<String> {
    let keywords = match prefix {
        "镜头" => &SHOT_STYLE_KEYWORDS[..],
        "情绪" => &MOOD_STYLE_KEYWORDS[..],
        "光影" => &LIGHTING_STYLE_KEYWORDS[..],
        "动作" => &MOTION_STYLE_KEYWORDS[..],
        "表演" => &PERFORMANCE_STYLE_KEYWORDS[..],
        "环境" => &ENVIRONMENT_STYLE_KEYWORDS[..],
        "语气" => &VOICE_STYLE_KEYWORDS[..],
        "声场" => &SOUND_STAGE_STYLE_KEYWORDS[..],
        _ => return None,
    };
    let min_support = recurring_fragment_support_threshold(parsed_notes.len());

    let mut counts = Vec::<(&'static str, usize)>::new();
    for fragments in parsed_notes {
        let matched = fragments
            .iter()
            .filter(|fragment| fragment.starts_with(prefix))
            .flat_map(|fragment| extract_style_keywords(fragment, prefix, keywords))
            .collect::<Vec<_>>();
        for keyword in matched {
            if let Some(existing) = counts.iter_mut().find(|(value, _)| *value == keyword) {
                existing.1 += 1;
            } else {
                counts.push((keyword, 1));
            }
        }
    }

    let summary = keywords
        .iter()
        .filter(|keyword| {
            counts
                .iter()
                .any(|(value, count)| value == *keyword && *count >= min_support)
        })
        .take(match prefix {
            "镜头" => 3,
            "环境" => 1,
            "声场" => 1,
            _ => 2,
        })
        .copied()
        .collect::<Vec<_>>();
    if summary.is_empty() {
        return None;
    }

    Some(format!("{prefix}{}", summary.join("")))
}

fn recurring_fragment_support_threshold(sample_count: usize) -> usize {
    match sample_count {
        0 | 1 => usize::MAX,
        2 | 3 => 2,
        _ => (sample_count / 2) + 1,
    }
}

pub(super) fn extract_style_keywords<'a>(
    fragment: &str,
    prefix: &str,
    keywords: &'a [&'static str],
) -> Vec<&'a str> {
    let value = fragment.strip_prefix(prefix).unwrap_or(fragment);
    let mut matched = Vec::new();
    for keyword in keywords {
        if !value.contains(keyword) || matched.iter().any(|existing: &&str| existing == keyword) {
            continue;
        }
        if matched
            .iter()
            .any(|existing: &&str| existing.contains(keyword) || keyword.contains(existing))
        {
            continue;
        }
        matched.push(*keyword);
    }
    matched
}

pub(super) fn compact_selected_memory_environment(
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    let context = normalize_prompt_text(
        &[
            fields.setting.as_str(),
            fields.action.as_str(),
            fields.sound.as_str(),
            fields.lighting.as_str(),
        ]
        .into_iter()
        .filter(|part| !part.trim().is_empty())
        .collect::<Vec<_>>()
        .join(" "),
    );
    if context.is_empty() {
        return None;
    }

    let candidates: [(&[&str], &str); 13] = [
        (&["咖啡"], "咖啡热气"),
        (&["手机", "屏幕"], "手机屏幕亮灭"),
        (&["雨", "玻璃"], "雨丝玻璃"),
        (&["窗帘"], "窗帘轻摆"),
        (&["车流"], "车流反光"),
        (&["霓虹"], "霓虹反光"),
        (&["烛火"], "烛火轻晃"),
        (&["竹"], "竹影摇动"),
        (&["水", "波"], "水波微晃"),
        (&["烟"], "烟雾流动"),
        (&["花瓣"], "花瓣飘落"),
        (&["树叶"], "树叶轻摆"),
        (&["雪"], "雪花飘落"),
    ];

    candidates.into_iter().find_map(|(tokens, cue)| {
        tokens
            .iter()
            .all(|token| context.contains(*token))
            .then_some(cue.to_string())
    })
}
