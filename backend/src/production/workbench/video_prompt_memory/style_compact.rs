use super::continuity::extract_style_keywords;
use super::*;

pub(crate) fn compact_video_style_prompt_note(note: &str) -> Option<String> {
    let mut fragments = Vec::new();
    let mut fallback_shot = None;

    for fragment in split_prompt_note_fragments(note) {
        if let Some(compacted) = compact_prompt_style_fragment(&fragment) {
            if fragments.iter().any(|existing| existing == &compacted) {
                continue;
            }
            fragments.push(compacted);
        } else if fragment.starts_with("镜头") && fallback_shot.is_none() {
            fallback_shot = Some(clip_prompt_fragment(
                &fragment,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            ));
        }
    }

    compact_cross_fragment_style_redundancy(&mut fragments);
    if fallback_shot.as_ref().is_some_and(|fragment| {
        selected_memory_high_signal_camera_fragment(fragment)
            && !fragments
                .iter()
                .any(|existing| existing.starts_with("镜头"))
    }) {
        fragments.push(fallback_shot.clone().expect("fallback shot present"));
    }

    if fragments.is_empty() {
        return fallback_shot;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn selected_memory_high_signal_camera_fragment(fragment: &str) -> bool {
    fragment.starts_with("镜头")
        && !is_local_framing_only_fragment(fragment)
        && ["低机位", "高机位", "俯拍", "仰拍", "压迫感", "窥视感"]
            .iter()
            .any(|keyword| fragment.contains(keyword))
}

fn compact_prompt_style_fragment(fragment: &str) -> Option<String> {
    if fragment.starts_with("镜头") {
        return compact_prompt_shot_style_fragment(fragment);
    }
    if fragment.starts_with("情绪") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "情绪",
            &MOOD_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("光影") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "光影",
            &LIGHTING_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("动作") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "动作",
            &MOTION_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("表演") {
        if performance_fragment_contains_voice_delivery(fragment) {
            return Some(clip_prompt_fragment(
                fragment,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            ));
        }
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "表演",
            &PERFORMANCE_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("环境") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "环境",
            &ENVIRONMENT_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("语气") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "语气",
            &VOICE_STYLE_KEYWORDS,
        ));
    }
    if fragment.starts_with("声场") {
        return Some(compact_prefixed_style_fragment_with_keywords(
            fragment,
            "声场",
            &SOUND_STAGE_STYLE_KEYWORDS,
        ));
    }
    None
}

fn performance_fragment_contains_voice_delivery(fragment: &str) -> bool {
    fragment.starts_with("表演")
        && PERFORMANCE_STYLE_KEYWORDS
            .iter()
            .any(|keyword| fragment.contains(keyword))
        && VOICE_STYLE_KEYWORDS
            .iter()
            .any(|keyword| fragment.contains(keyword))
}

fn compact_cross_fragment_style_redundancy(fragments: &mut Vec<String>) {
    if fragments.len() < 2 {
        return;
    }

    let lighting_fragments = fragments
        .iter()
        .filter_map(|fragment| fragment.strip_prefix("光影"))
        .map(normalize_prompt_text)
        .collect::<Vec<_>>();
    if lighting_fragments.is_empty() {
        return;
    }

    fragments.retain(|fragment| {
        let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) else {
            return true;
        };
        if !matches!(mood.as_str(), "冷调" | "冷色") {
            return true;
        }
        !lighting_fragments
            .iter()
            .any(|lighting| lighting_fragment_covers_generic_mood_tone(lighting, &mood))
    });

    let has_high_value_character_signal = fragments.iter().any(|fragment| {
        fragment.starts_with("表演") || fragment.starts_with("语气") || fragment.starts_with("动作")
    });
    if has_high_value_character_signal {
        fragments.retain(|fragment| {
            let Some(mood) = fragment.strip_prefix("情绪").map(normalize_prompt_text) else {
                return true;
            };
            !selected_style_fragment_is_generic_restrained_mood(&mood)
        });
    }

    let has_performance_signal = fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演"));
    if has_performance_signal {
        let performance_fragments = fragments
            .iter()
            .filter(|fragment| fragment.starts_with("表演"))
            .cloned()
            .collect::<Vec<_>>();
        fragments.retain(|fragment| {
            if let Some(voice) = fragment.strip_prefix("语气").map(normalize_prompt_text) {
                return !selected_style_fragment_is_low_gain_voice(&voice)
                    || !performance_fragments.iter().any(|performance| {
                        selected_memory_voice_fragment_is_redundant_with_performance(
                            performance,
                            &format!("语气{voice}"),
                            None,
                        )
                    });
            }
            true
        });
    }

    let has_non_camera_style_signal = fragments.iter().any(|fragment| {
        !fragment.starts_with("镜头")
            && ((fragment.starts_with("情绪")
                && fragment
                    .strip_prefix("情绪")
                    .map(normalize_prompt_text)
                    .is_some_and(|mood| {
                        !selected_style_fragment_is_generic_restrained_mood(&mood)
                    }))
                || fragment.starts_with("光影")
                || fragment.starts_with("动作")
                || fragment.starts_with("表演")
                || fragment.starts_with("环境")
                || fragment.starts_with("语气")
                || fragment.starts_with("声场"))
    });
    if has_non_camera_style_signal {
        fragments.retain(|fragment| !is_local_framing_only_fragment(fragment));
    }
}

fn lighting_fragment_covers_generic_mood_tone(lighting: &str, mood: &str) -> bool {
    match mood {
        "冷调" | "冷色" => ["冷调", "冷色", "冷光"]
            .iter()
            .any(|keyword| lighting.contains(keyword)),
        _ => lighting.contains(mood),
    }
}

pub(super) fn selected_style_fragment_is_generic_restrained_mood(mood: &str) -> bool {
    let normalized = normalize_prompt_text(mood);
    !normalized.is_empty()
        && normalized
            .split(['/', '／', '、', '，', ',', ' '])
            .map(normalize_prompt_text)
            .filter(|part| !part.is_empty())
            .all(|part| {
                matches!(
                    part.as_str(),
                    "克制" | "隐忍" | "压抑" | "沉静" | "沉稳" | "冷静"
                )
            })
}

pub(super) fn selected_style_fragment_is_low_gain_voice(voice: &str) -> bool {
    matches!(voice, "低声克制" | "轻声克制" | "呢喃")
}

pub(super) fn selected_style_fragment_is_low_gain_motion(action: &str) -> bool {
    matches!(action, "从容克制" | "克制自然" | "自然" | "简洁平滑")
}

fn compact_prefixed_style_fragment_with_keywords(
    fragment: &str,
    prefix: &str,
    keywords: &[&'static str],
) -> String {
    let body = fragment.strip_prefix(prefix).unwrap_or(fragment).trim();
    if body.is_empty() {
        return clip_prompt_fragment(fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
    }

    let compacted = compact_style_body_by_keywords(body, keywords)
        .filter(|value| value != body)
        .map(|value| format!("{prefix}{value}"))
        .unwrap_or_else(|| fragment.to_string());
    clip_prompt_fragment(&compacted, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
}

fn compact_style_body_by_keywords(body: &str, keywords: &[&'static str]) -> Option<String> {
    let mut matches = keywords
        .iter()
        .enumerate()
        .filter_map(|(priority, keyword)| {
            body.find(keyword)
                .map(|start| (start, start + keyword.len(), keyword, priority))
        })
        .collect::<Vec<_>>();
    if matches.is_empty() {
        return None;
    }
    matches.sort_by(|a, b| {
        a.0.cmp(&b.0)
            .then((b.1 - b.0).cmp(&(a.1 - a.0)))
            .then(a.3.cmp(&b.3))
    });

    let mut covered = vec![false; body.len()];
    let mut selected = Vec::new();
    let mut covered_len = 0usize;

    for (start, end, keyword, _) in matches {
        if (start..end).any(|idx| covered[idx]) {
            continue;
        }
        for idx in start..end {
            covered[idx] = true;
        }
        covered_len += end - start;
        selected.push(*keyword);
    }

    if selected.is_empty() || covered_len * 2 < body.len() {
        return None;
    }

    Some(selected.join(""))
}

fn compact_prompt_shot_style_fragment(fragment: &str) -> Option<String> {
    let matched = extract_style_keywords(fragment, "镜头", &STABLE_PROMPT_SHOT_KEYWORDS);
    if matched.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &format!("镜头{}", matched.join("")),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

pub(super) fn style_only_note(note: &str) -> Option<String> {
    let fragments = split_prompt_note_fragments(note)
        .filter(|fragment| {
            STYLE_NOTE_PREFIXES
                .iter()
                .any(|prefix| fragment.starts_with(prefix))
        })
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }
    compact_video_style_prompt_note(&fragments.join("，"))
}

pub(super) fn non_style_note(note: &str) -> Option<String> {
    let fragments = split_prompt_note_fragments(note)
        .filter(|fragment| {
            !fragment.is_empty()
                && !STYLE_NOTE_PREFIXES
                    .iter()
                    .any(|prefix| fragment.starts_with(prefix))
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

pub(super) fn compact_selected_memory_residual_note(
    note: &str,
    subject: Option<&str>,
    style: Option<&str>,
    subject_is_stored: bool,
    action_hint: Option<&str>,
) -> Option<String> {
    let normalized_subject = subject
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    let normalized_style = style
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    let normalized_action_hint = action_hint
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    let mut fragments = split_prompt_note_fragments(note)
        .filter(|fragment| !selected_memory_field_looks_silent(fragment))
        .collect::<Vec<_>>();
    if let Some(subject) = normalized_subject.as_deref() {
        if fragments.len() > 1 {
            fragments.retain(|fragment| fragment != subject);
        }
        if fragments.len() == 1 {
            let fragment = normalize_prompt_text(&fragments[0]);
            let fragment = fragment
                .strip_prefix(subject)
                .map(normalize_prompt_text)
                .unwrap_or(fragment);
            if !subject_is_stored {
                if let Some(action) = normalized_action_hint.as_deref() {
                    let action = normalize_prompt_text(action);
                    if !action.is_empty() {
                        fragments = vec![subject.to_string(), action];
                        if let Some(style) = normalized_style.as_deref() {
                            fragments = fragments
                                .into_iter()
                                .filter_map(|fragment| {
                                    trim_selected_memory_fragment_covered_by_style(&fragment, style)
                                })
                                .collect();
                        }
                        fragments.retain(|fragment| {
                            !fragment.is_empty()
                                && !low_signal_subject_pose_fragment(fragment)
                                && !low_signal_object_hold_fragment(fragment)
                                && !low_signal_action_residue_fragment(fragment)
                        });
                        if fragments.is_empty() {
                            return None;
                        }
                        return Some(clip_prompt_fragment(
                            &fragments.join("，"),
                            VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                        ));
                    }
                }
            }
            if fragment.is_empty() || low_signal_subject_pose_fragment(&fragment) {
                return None;
            }
            fragments[0] = fragment;
        }
    }
    if let Some(style) = normalized_style.as_deref() {
        fragments = fragments
            .into_iter()
            .filter_map(|fragment| {
                trim_selected_memory_fragment_covered_by_style(&fragment, style).and_then(
                    |fragment| {
                        let fragment = normalize_prompt_text(&fragment);
                        (!fragment.is_empty()
                            && !low_signal_subject_pose_fragment(&fragment)
                            && !low_signal_object_hold_fragment(&fragment)
                            && !low_signal_action_residue_fragment(&fragment))
                        .then_some(fragment)
                    },
                )
            })
            .collect();
    }
    if subject_is_stored {
        if let Some(subject) = normalized_subject.as_deref() {
            if fragments.len() > 1
                && fragments
                    .first()
                    .is_some_and(|fragment| fragment == subject)
                && fragments.get(1).is_some()
            {
                let second = normalize_prompt_text(&fragments[1]);
                let keep_subject_separate = ["后", "回望", "回头", "转身", "停步"]
                    .iter()
                    .any(|keyword| second.contains(keyword));
                if keep_subject_separate {
                    // Keep explicit subject + follow-up action for residual beats like "主角，推门后回望".
                } else {
                    fragments[1] = format!("{subject}{second}");
                    fragments.remove(0);
                }
            }
            if fragments.len() == 1
                && !fragments[0].starts_with(subject)
                && (fragments[0].contains("推门") || fragments[0].contains("冲出"))
            {
                if fragments[0].contains("回望") || fragments[0].contains("回头") {
                    fragments.insert(0, subject.to_string());
                } else {
                    fragments[0] = format!("{subject}{}", fragments[0]);
                }
            }
            let original_fragments = fragments.clone();
            fragments = fragments
                .into_iter()
                .filter_map(|fragment| {
                    if fragment == subject {
                        return Some(fragment);
                    }
                    if fragment.starts_with(subject)
                        && fragment.chars().count() > subject.chars().count() + 1
                    {
                        let stripped = fragment
                            .strip_prefix(subject)
                            .map(normalize_prompt_text)
                            .unwrap_or_else(|| normalize_prompt_text(&fragment));
                        if stripped.is_empty()
                            || low_signal_subject_pose_fragment(&stripped)
                            || low_signal_object_hold_fragment(&stripped)
                            || low_signal_action_residue_fragment(&stripped)
                        {
                            return None;
                        }
                        if original_fragments
                            .iter()
                            .any(|other| other != &fragment && other.starts_with(&stripped))
                        {
                            return Some(stripped);
                        }
                        return Some(fragment);
                    }
                    let stripped = fragment
                        .strip_prefix(subject)
                        .map(normalize_prompt_text)
                        .unwrap_or(fragment);
                    let stripped = normalize_prompt_text(&stripped);
                    (!stripped.is_empty()
                        && !low_signal_subject_pose_fragment(&stripped)
                        && !low_signal_object_hold_fragment(&stripped)
                        && !low_signal_action_residue_fragment(&stripped))
                    .then_some(stripped)
                })
                .collect();
        }
    }
    fragments = compact_selected_memory_residual_fragments(fragments);
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn compact_selected_memory_residual_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut compacted: Vec<String> = Vec::new();
    for fragment in fragments {
        let fragment = normalize_prompt_text(
            &fragment
                .replace("推门后推门", "推门")
                .replace("回头后回头", "回头")
                .replace("转身后转身", "转身"),
        );
        if fragment.is_empty() {
            continue;
        }
        if let Some(last) = compacted.last_mut() {
            if fragment.starts_with(last.as_str())
                && fragment.chars().count() > last.chars().count()
            {
                *last = fragment;
                continue;
            }
            if last.starts_with(fragment.as_str()) {
                continue;
            }
        }
        compacted.push(fragment);
    }
    compacted
}

fn low_signal_subject_pose_fragment(fragment: &str) -> bool {
    LOW_SIGNAL_SUBJECT_POSE_PREFIXES
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
}

fn low_signal_object_hold_fragment(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    ACTION_OBJECT_PREFIX_VERBS.iter().any(|prefix| {
        normalized.starts_with(prefix)
            && normalized.chars().count() <= 6
            && ![
                "转", "冲", "跑", "推", "拉", "挡", "扑", "扑向", "回望", "回头", "走", "穿",
            ]
            .iter()
            .any(|keyword| normalized.contains(keyword))
    })
}

fn low_signal_action_residue_fragment(fragment: &str) -> bool {
    matches!(
        normalize_prompt_text(fragment).as_str(),
        "缓缓" | "慢慢" | "轻轻" | "静静" | "默默" | "片刻" | "一下" | "一下子"
    )
}

fn trim_selected_memory_fragment_covered_by_style(fragment: &str, style: &str) -> Option<String> {
    let mut normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return None;
    }

    if style.contains("表演欲言又止") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "迟迟没有开口",
                "没有开口",
                "欲言又止",
                "话到嘴边",
                "张了张嘴",
            ],
        );
    }
    if style.contains("表演抬眼停顿") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "抬眼后停顿片刻",
                "抬眼停顿",
                "抬眼",
                "停顿片刻",
                "迟迟没有开口",
                "没有开口",
            ],
        );
    }
    if style.contains("表演垂眼停顿") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["垂眼停顿", "垂眼", "低头停顿", "低头", "停顿片刻"],
        );
    }
    if style.contains("表演喉结滚动") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["喉结滚动", "喉头滚动", "喉结滑动", "喉头滑动"],
        );
    }
    if style.contains("表演指尖发颤") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["指尖发颤", "手指发颤", "指尖轻颤", "手指轻颤"],
        );
    }
    if style.contains("表演嘴角发僵") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["嘴角发僵", "嘴角僵住", "嘴角绷紧", "唇角发僵"],
        );
    }
    if style.contains("表演下颌绷紧") {
        normalized = remove_fragment_phrases(
            &normalized,
            &["下颌绷紧", "下巴绷紧", "下颌发紧", "下巴发紧"],
        );
    }
    if style.contains("语气低声") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "低声开口",
                "低声说道",
                "低声说",
                "压低声音开口",
                "压低声音",
                "压低嗓音",
                "压低",
            ],
        );
    } else if style.contains("表演") && (style.contains("低声") || style.contains("压低")) {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "低声开口",
                "低声说道",
                "低声说",
                "压低声音开口",
                "压低声音",
                "压低嗓音",
                "压低",
            ],
        );
    } else if style.contains("语气轻声") || style.contains("语气呢喃") {
        normalized = remove_fragment_phrases(
            &normalized,
            &[
                "轻声开口",
                "轻声说道",
                "轻声说",
                "呢喃开口",
                "呢喃说道",
                "呢喃",
                "耳语开口",
                "耳语",
            ],
        );
    }

    normalized = normalize_prompt_text(
        normalized
            .replace("后后", "后")
            .trim_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, ',' | '，' | ';' | '；' | '.' | '。' | ':' | '：' | '、')
            })
            .trim_start_matches('后')
            .trim_start_matches('又')
            .trim_start_matches('再')
            .trim_start_matches('便')
            .trim_start_matches('才'),
    );
    if normalized.is_empty() {
        return None;
    }
    Some(normalized)
}

fn remove_fragment_phrases(fragment: &str, phrases: &[&str]) -> String {
    let mut normalized = normalize_prompt_text(fragment);
    for phrase in phrases {
        normalized = normalized.replace(phrase, "");
    }
    normalize_prompt_text(&normalized)
}
