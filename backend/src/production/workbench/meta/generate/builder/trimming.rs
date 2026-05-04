//! Prompt builder and diagnostics logic.

use super::super::*;
use super::*;

pub const VOICE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["低声", "压低声音", "低低开口"],
    &["轻声", "轻轻开口", "轻轻说道"],
    &["呢喃", "喃喃", "喃喃道", "喃喃说"],
    &["哽咽", "带着哽意", "声音发哽"],
    &["短促", "短促开口", "短促出声"],
];

pub const SOUND_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["雨声", "雨滴声", "雨丝声", "雨点击窗"],
    &["风声", "风响", "风掠过", "风穿堂"],
    &["呼吸", "喘息", "呼吸声", "气息"],
    &["脚步", "足音", "步声", "脚步声"],
    &["门轴", "门响", "敲门", "开门声", "关门声", "门被推开"],
];

pub const PERFORMANCE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["欲言又止", "欲说还休"],
    &["抬眼", "抬眸", "抬起眼"],
    &[
        "停顿",
        "停顿片刻",
        "顿住",
        "停了停",
        "没有开口",
        "迟迟没有开口",
    ],
    &["迟疑", "迟迟", "犹疑", "犹豫"],
    &["回头", "回眸", "回身看"],
    &["看向", "望向", "望着", "看着", "注视"],
    &["唇线收紧", "抿唇", "嘴唇抿紧", "唇角绷紧", "嘴角绷紧"],
    &["眉心轻蹙", "蹙眉", "眉头轻蹙", "眉心微蹙"],
];

pub fn trim_style_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    if fragment.starts_with("镜头") {
        return trim_prefixed_style_fragment(
            fragment,
            "镜头",
            &[fields.shot.as_str(), fields.camera_move.as_str()],
        );
    }
    if fragment.starts_with("情绪") {
        return trim_prefixed_style_fragment(fragment, "情绪", &[fields.mood.as_str()]);
    }
    if fragment.starts_with("光影") {
        let trimmed = trim_prefixed_style_fragment(fragment, "光影", &[fields.lighting.as_str()]);
        return trim_pure_storyboard_lighting_residue(trimmed, "光影", &fields.lighting);
    }
    if fragment.starts_with("环境") {
        return trim_prefixed_style_fragment(
            fragment,
            "环境",
            &[
                fields.setting.as_str(),
                fields.action.as_str(),
                fields.sound.as_str(),
            ],
        );
    }
    if fragment.starts_with("动作") {
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "动作",
            &[fields.action.as_str(), fields.mood.as_str()],
        );
        return trim_style_fragment_by_shared_mood_keywords(trimmed, "动作", &fields.mood);
    }
    if fragment.starts_with("表演") {
        let original_fragment = fragment.to_string();
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "表演",
            &[
                fields.action.as_str(),
                fields.dialogue.as_str(),
                fields.mood.as_str(),
            ],
        );
        let trimmed = trim_style_fragment_by_shared_performance_keywords(
            trimmed,
            "表演",
            &[fields.action.as_str(), fields.dialogue.as_str()],
        );
        let trimmed = preserve_high_signal_performance_fragment(trimmed, &original_fragment);
        let trimmed = if trimmed.is_none()
            && video_prompt_scene_needs_identity_memory(fields)
            && performance_fragment_has_subject_locked_signal(
                fragment,
                &[fields.action.as_str(), fields.dialogue.as_str()],
            ) {
            Some(fragment.to_string())
        } else {
            trimmed
        };
        return trim_style_fragment_by_shared_mood_keywords(trimmed, "表演", &fields.mood);
    }
    if fragment.starts_with("语气") {
        if !storyboard_supports_voice_style(fields) {
            return None;
        }
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "语气",
            &[
                fields.action.as_str(),
                fields.dialogue.as_str(),
                fields.mood.as_str(),
            ],
        );
        let trimmed = trim_style_fragment_by_shared_voice_keywords(
            trimmed,
            "语气",
            &[fields.action.as_str(), fields.dialogue.as_str()],
        );
        return trim_style_fragment_by_shared_mood_keywords(trimmed, "语气", &fields.mood);
    }
    if fragment.starts_with("声场") {
        let trimmed = trim_prefixed_style_fragment(
            fragment,
            "声场",
            &[
                fields.sound.as_str(),
                fields.setting.as_str(),
                fields.action.as_str(),
            ],
        );
        return match trimmed {
            Some(compacted)
                if compacted
                    .strip_prefix("声场")
                    .is_some_and(sound_stage_fragment_too_generic_after_trim) =>
            {
                Some(fragment.to_string())
            }
            other => other,
        };
    }
    Some(fragment.to_string())
}

pub fn performance_fragment_has_subject_locked_signal(fragment: &str, fields: &[&str]) -> bool {
    performance_fragment_has_unique_micro_detail(fragment)
        || performance_fragment_shared_keyword_family_count(fragment, fields) >= 2
}

fn performance_fragment_shared_keyword_family_count(fragment: &str, fields: &[&str]) -> usize {
    let normalized_fragment = normalize_prompt_text(fragment);
    if normalized_fragment.is_empty() {
        return 0;
    }

    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    if normalized_fields.is_empty() {
        return 0;
    }

    PERFORMANCE_SHARED_KEYWORD_FAMILIES
        .iter()
        .filter(|family| {
            family
                .iter()
                .any(|keyword| normalized_fragment.contains(keyword))
                && normalized_fields
                    .iter()
                    .any(|field| family.iter().any(|keyword| field.contains(keyword)))
        })
        .count()
}

pub fn trim_prefixed_style_fragment(
    fragment: &str,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    let body = fragment.strip_prefix(prefix).unwrap_or(fragment).trim();
    if body.is_empty() {
        return None;
    }

    let mut trimmed = body.to_string();
    for field in fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
    {
        trimmed = trimmed.replace(&field, "");
    }
    let trimmed = trimmed
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ',' | '，' | ';' | '；' | ':' | '：' | '/' | '／' | '、' | '|' | '-' | ' '
                )
        })
        .to_string();
    if trimmed.is_empty() {
        None
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub fn trim_style_fragment_against_prompt_coverage(
    fragment: &str,
    prompt_coverage: &[String],
) -> Option<String> {
    let Some((prefix, body)) = style_fragment_prefix_and_body(fragment) else {
        return Some(fragment.to_string());
    };
    if !matches!(prefix, "表演" | "语气") {
        return Some(fragment.to_string());
    }

    let mut trimmed = body.clone();
    let mut candidates = prompt_coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));
    candidates.dedup();

    for candidate in candidates {
        if candidate.chars().count() < 2 || !trimmed.contains(&candidate) {
            continue;
        }
        let residual = normalize_prompt_text(&trimmed.replace(&candidate, ""));
        if residual.chars().count() >= 2 {
            trimmed = residual;
        }
    }

    let trimmed = normalize_prompt_text(&trimmed);
    if trimmed.is_empty() {
        None
    } else if trimmed == body {
        Some(fragment.to_string())
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub fn trim_style_fragment_by_shared_mood_keywords(
    fragment: Option<String>,
    prefix: &str,
    mood: &str,
) -> Option<String> {
    let fragment = fragment?;
    let body = fragment
        .strip_prefix(prefix)
        .unwrap_or(fragment.as_str())
        .trim();
    if body.is_empty() {
        return None;
    }

    let normalized_mood = normalize_prompt_text(mood);
    if normalized_mood.is_empty() {
        return Some(fragment);
    }

    let mut trimmed = body.to_string();
    for keyword in ["克制", "隐忍", "压抑", "平静", "冷静", "从容", "沉静"] {
        if !normalized_mood.contains(keyword) || !trimmed.contains(keyword) {
            continue;
        }
        let candidate = normalize_prompt_text(&trimmed.replace(keyword, ""));
        if candidate.chars().count() >= 2 {
            trimmed = candidate;
        }
    }

    if trimmed == body {
        return Some(fragment);
    }
    if trimmed.is_empty() {
        None
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

fn trim_pure_storyboard_lighting_residue(
    fragment: Option<String>,
    prefix: &str,
    lighting: &str,
) -> Option<String> {
    let fragment = fragment?;
    let body = fragment
        .strip_prefix(prefix)
        .unwrap_or(fragment.as_str())
        .trim();
    if body.is_empty() {
        return None;
    }

    let normalized_lighting = normalize_prompt_text(lighting);
    if normalized_lighting.is_empty() {
        return Some(fragment);
    }

    let mut trimmed = body.to_string();
    for keyword in normalized_lighting
        .split(['，', ',', '；', ';', '、', '/', ' '])
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
    {
        if !trimmed.contains(&keyword) {
            continue;
        }
        let candidate = normalize_prompt_text(&trimmed.replace(&keyword, ""));
        if candidate.chars().count() >= 2 {
            trimmed = candidate;
        } else if candidate.is_empty() {
            return None;
        }
    }

    if trimmed == body {
        return Some(fragment);
    }
    if trimmed.is_empty() {
        None
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}

pub fn trim_style_fragment_by_shared_voice_keywords(
    fragment: Option<String>,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    trim_fragment_by_shared_keyword_families(
        fragment,
        prefix,
        fields,
        VOICE_SHARED_KEYWORD_FAMILIES,
    )
}

pub fn trim_style_fragment_by_shared_performance_keywords(
    fragment: Option<String>,
    prefix: &str,
    fields: &[&str],
) -> Option<String> {
    trim_fragment_by_shared_keyword_families(
        fragment,
        prefix,
        fields,
        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    )
}

pub fn trim_director_performance_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &[&str],
) -> Option<String> {
    trim_fragment_by_shared_keyword_families(
        Some(fragment.to_string()),
        "",
        fields,
        PERFORMANCE_SHARED_KEYWORD_FAMILIES,
    )
}

pub fn trim_fragment_by_shared_keyword_families(
    fragment: Option<String>,
    prefix: &str,
    fields: &[&str],
    families: &[&[&str]],
) -> Option<String> {
    let fragment = fragment?;
    let body = if prefix.is_empty() {
        fragment.trim()
    } else {
        fragment
            .strip_prefix(prefix)
            .unwrap_or(fragment.as_str())
            .trim()
    };
    if body.is_empty() {
        return None;
    }

    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    if normalized_fields.is_empty() {
        return Some(fragment);
    }

    let mut trimmed = body.to_string();
    for family in families {
        if !family.iter().any(|keyword| trimmed.contains(keyword))
            || !normalized_fields
                .iter()
                .any(|field| family.iter().any(|keyword| field.contains(keyword)))
        {
            continue;
        }
        let candidate = family
            .iter()
            .fold(trimmed.clone(), |acc, keyword| acc.replace(keyword, ""));
        let candidate = normalize_prompt_text(&candidate);
        if candidate.is_empty() {
            trimmed = candidate;
            break;
        }
        if candidate.chars().count() >= 2 {
            trimmed = candidate;
        }
    }

    if trimmed == body {
        return Some(fragment);
    }
    if trimmed.is_empty() {
        None
    } else if prefix.is_empty() {
        Some(trimmed)
    } else {
        Some(format!("{prefix}{trimmed}"))
    }
}
