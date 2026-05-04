use super::super::super::*;
use super::super::clauses::compact::strip_leading_covered_prompt_fragment;
use super::super::coverage::prompt_fragment_is_covered;

pub(in crate::production::workbench::meta::generate) fn compact_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let Some(fields) = structured_fields else {
        let clipped = clip_prompt_fragment(&normalized, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
        return (!prompt_fragment_is_covered(&clipped, prompt_coverage)).then_some(clipped);
    };
    if !normalized.contains(['，', ',', '；', ';', '。', '\n'])
        && normalized.contains("视线方向一致")
        && [
            fields.subject.as_str(),
            fields.action.as_str(),
            fields.dialogue.as_str(),
        ]
        .into_iter()
        .map(normalize_prompt_text)
        .any(|value| {
            !value.is_empty()
                && ["对视", "看向", "望向", "抬眼", "回头"]
                    .iter()
                    .any(|keyword| value.contains(keyword))
        })
    {
        return Some("视线方向一致".to_string());
    }

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_continuity_fragment_against_storyboard_fields(&fragment, fields)
        })
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .map(|fragment| {
            trim_continuity_fragment_against_prompt_coverage(&fragment, prompt_coverage)
        })
        .filter(|fragment| {
            let normalized_core = continuity_fragment_core(fragment);
            !super::super::super::builder::continuity_fragment_matches_fields(
                fragment,
                fields,
                &expected_camera,
            ) && !super::super::super::builder::continuity_fragment_is_generic_quality_tail_overlap(
                fragment,
            ) && !super::super::super::builder::continuity_fragment_is_semantically_covered(
                fragment,
                prompt_coverage,
            ) && normalized_core.as_deref().is_none_or(|core| {
                !super::super::super::builder::continuity_fragment_is_semantically_covered(
                    core,
                    prompt_coverage,
                )
            })
        })
        .filter(|fragment| {
            !matches!(
                normalize_prompt_text(fragment).as_str(),
                "衔接统一" | "镜头衔接统一" | "上一镜头衔接统一"
            )
        })
        .collect::<Vec<_>>();

    if fragments.is_empty() {
        return fallback_high_signal_continuity_fragment(&normalized);
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn fallback_high_signal_continuity_fragment(note: &str) -> Option<String> {
    note.split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .map(|fragment| compact_continuity_fragment_wording(&fragment))
        .find(|fragment| {
            ["视线", "方向", "站位", "走位", "跳轴", "构图"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
        })
        .map(|fragment| clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
}

pub(in crate::production::workbench::meta::generate) fn compact_continuity_fragment_wording(
    fragment: &str,
) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for (from, to) in [
        ("保持方向连续", "方向连续"),
        ("保留方向连续", "方向连续"),
        ("延续方向连续", "方向连续"),
        ("保持视线方向一致", "视线方向一致"),
        ("保留视线方向一致", "视线方向一致"),
        ("延续视线方向一致", "视线方向一致"),
        ("保持上一镜头衔接统一", "衔接统一"),
        ("保留上一镜头衔接统一", "衔接统一"),
        ("延续上一镜头衔接统一", "衔接统一"),
        ("保持上一镜头动作节奏连续", "动作节奏连续"),
        ("保留上一镜头动作节奏连续", "动作节奏连续"),
        ("延续上一镜头动作节奏连续", "动作节奏连续"),
        ("保持站位不要跳轴", "站位不要跳轴"),
        ("保留站位不要跳轴", "站位不要跳轴"),
        ("延续站位不要跳轴", "站位不要跳轴"),
        ("人物站位不要跳轴", "站位不要跳轴"),
        ("角色站位不要跳轴", "站位不要跳轴"),
        ("保持站位连续", "站位连续"),
        ("保留站位连续", "站位连续"),
        ("延续站位连续", "站位连续"),
        ("人物站位连续", "站位连续"),
        ("角色站位连续", "站位连续"),
        ("人物走位连续", "走位连续"),
        ("角色走位连续", "走位连续"),
        ("人物视线方向一致", "视线方向一致"),
        ("角色视线方向一致", "视线方向一致"),
        ("镜头方向连续", "方向连续"),
        ("人物动作节奏", "动作节奏"),
        ("角色动作节奏", "动作节奏"),
        ("人物前后景", "前后景"),
        ("角色前后景", "前后景"),
    ] {
        compacted = compacted.replace(from, to);
    }

    if compacted.contains("不要") {
        for prefix in ["保持", "保留", "延续"] {
            if let Some(stripped) = compacted.strip_prefix(prefix) {
                compacted = normalize_prompt_text(stripped);
                break;
            }
        }
    }

    normalize_prompt_text(&compacted)
}

pub(in crate::production::workbench::meta::generate) fn trim_continuity_fragment_against_prompt_coverage(
    fragment: &str,
    prompt_coverage: &[String],
) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return normalized;
    }

    let trimmed = strip_leading_covered_prompt_fragment(&normalized, prompt_coverage);
    if trimmed == normalized || trimmed.is_empty() {
        return normalized;
    }

    if continuity_fragment_still_specific_after_coverage_trim(&trimmed) {
        trimmed
    } else {
        normalized
    }
}

pub(in crate::production::workbench::meta::generate) fn continuity_fragment_still_specific_after_coverage_trim(
    fragment: &str,
) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }

    [
        "保持", "保留", "延续", "走位", "站位", "方向", "构图", "衔接", "连续", "统一", "一致",
        "跳轴",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

pub(in crate::production::workbench::meta::generate) fn trim_continuity_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return None;
    }

    let (prefix, body) = continuity_fragment_prefix_and_body(&normalized);
    let mut trimmed = body.to_string();
    for field in [
        fields.shot.as_str(),
        fields.camera_move.as_str(),
        fields.mood.as_str(),
        fields.lighting.as_str(),
        fields.setting.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .filter(|field| !field.is_empty())
    {
        trimmed = trimmed.replace(&field, "");
    }
    trimmed = trim_continuity_fragment_storyboard_lead_in(&trimmed, fields);
    let trimmed = trimmed
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ',' | '，' | ';' | '；' | ':' | '：' | '/' | '／' | '、' | '|' | '-' | ' '
                )
        })
        .to_string();
    if trimmed.is_empty()
        || ["镜头", "情绪", "光影", "场景"]
            .iter()
            .any(|prefix| trimmed == *prefix)
    {
        None
    } else if prefix.is_empty() {
        Some(trimmed)
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub(in crate::production::workbench::meta::generate) fn trim_continuity_fragment_storyboard_lead_in(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> String {
    const CONTINUITY_LEAD_ROLE_PREFIXES: [&str; 10] = [
        "主角", "女主", "男主", "反派", "女孩", "男孩", "女人", "男人", "老人", "孩子",
    ];
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for field in [fields.subject.as_str(), fields.action.as_str()]
        .into_iter()
        .map(normalize_prompt_text)
        .filter(|field| !field.is_empty())
    {
        let candidate = compacted.replace(&field, "");
        let candidate = candidate
            .trim_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '/' | '／' | '、' | '|' | '-' | ' '
                    )
            })
            .to_string();
        if candidate.is_empty()
            || !candidate.contains("上一镜头")
                && ![
                    "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
                ]
                .iter()
                .any(|keyword| candidate.contains(keyword))
        {
            continue;
        }
        compacted = candidate;
    }

    loop {
        let mut changed = false;
        for prefix in CONTINUITY_LEAD_ROLE_PREFIXES {
            let Some(stripped) = compacted.strip_prefix(prefix) else {
                continue;
            };
            let candidate = stripped
                .trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                })
                .to_string();
            if candidate.is_empty()
                || !candidate.contains("上一镜头")
                    && ![
                        "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
                    ]
                    .iter()
                    .any(|keyword| candidate.contains(keyword))
            {
                continue;
            }
            compacted = candidate;
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

pub(in crate::production::workbench::meta::generate) fn continuity_fragment_core(
    fragment: &str,
) -> Option<String> {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return None;
    }
    [
        "保持上一镜头已确认的",
        "保持上一镜头已确认",
        "保留上一镜头已确认的",
        "保留上一镜头已确认",
        "延续上一镜头已确认的",
        "延续上一镜头已确认",
        "保持上一镜头的",
        "保留上一镜头的",
        "延续上一镜头的",
        "保持上一镜头",
        "保留上一镜头",
        "延续上一镜头",
        "保持",
        "保留",
        "延续",
    ]
    .into_iter()
    .find_map(|prefix| {
        normalized
            .strip_prefix(prefix)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    })
}

pub(in crate::production::workbench::meta::generate) fn continuity_fragment_prefix_and_body(
    fragment: &str,
) -> (String, String) {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return (String::new(), String::new());
    }
    for prefix in [
        "保持上一镜头已确认的",
        "保持上一镜头已确认",
        "保留上一镜头已确认的",
        "保留上一镜头已确认",
        "延续上一镜头已确认的",
        "延续上一镜头已确认",
        "保持上一镜头的",
        "保留上一镜头的",
        "延续上一镜头的",
        "保持上一镜头",
        "保留上一镜头",
        "延续上一镜头",
        "保持",
        "保留",
        "延续",
    ] {
        if let Some(body) = normalized.strip_prefix(prefix).map(str::trim) {
            if !body.is_empty() {
                return (prefix.to_string(), body.to_string());
            }
        }
    }
    (String::new(), normalized)
}
