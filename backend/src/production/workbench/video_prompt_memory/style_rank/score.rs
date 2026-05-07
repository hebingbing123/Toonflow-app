//! Scoring and comparison logic for video style notes.

use super::super::*;

pub(in super::super) fn select_best_selected_video_style_note(
    notes: Vec<String>,
) -> Option<String> {
    notes.into_iter().max_by(|a, b| {
        score_selected_video_style_note(a)
            .cmp(&score_selected_video_style_note(b))
            .then(count_selected_video_style_axes(a).cmp(&count_selected_video_style_axes(b)))
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

pub(in super::super) fn score_selected_video_style_note(note: &str) -> i32 {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    if fragments.is_empty() {
        return 0;
    }

    let mut score = 0i32;
    for fragment in &fragments {
        if fragment.starts_with("表演") {
            score += 10;
        } else if fragment.starts_with("语气") {
            score += 9;
        } else if fragment.starts_with("情绪") {
            score += 7;
        } else if fragment.starts_with("光影") {
            score += 5;
        } else if fragment.starts_with("镜头") {
            score += if is_local_framing_only_fragment(fragment) {
                1
            } else {
                3
            };
        } else if fragment.starts_with("声场") {
            score += 4;
        } else if fragment.starts_with("动作") {
            score += 3;
        } else {
            score += 2;
        }
    }
    if count_selected_video_style_axes(note) >= 2 {
        score += 2;
    }
    if note_contains_selected_video_delivery_signal(&fragments) {
        score += 4;
    }
    if note_contains_selected_video_emotion_signal(&fragments) {
        score += 2;
    }
    score
}

pub(in super::super) fn count_selected_video_style_axes(note: &str) -> usize {
    let fragments = split_prompt_note_fragments(note).collect::<Vec<_>>();
    [
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("镜头")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("情绪")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("光影")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("表演")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("语气")),
        fragments
            .iter()
            .any(|fragment| fragment.starts_with("声场")),
    ]
    .into_iter()
    .filter(|present| *present)
    .count()
}

fn note_contains_selected_video_delivery_signal(fragments: &[String]) -> bool {
    fragments
        .iter()
        .any(|fragment| fragment.starts_with("表演") || fragment.starts_with("语气"))
}

fn note_contains_selected_video_emotion_signal(fragments: &[String]) -> bool {
    fragments
        .iter()
        .any(|fragment| fragment.starts_with("情绪") || fragment.starts_with("表演"))
}

pub(in super::super) fn is_local_framing_only_fragment(fragment: &str) -> bool {
    fragment == "镜头近景"
        || fragment == "镜头中景"
        || fragment == "镜头远景"
        || fragment == "镜头特写"
        || fragment == "镜头全景"
}

pub(in super::super) fn score_ranked_style_note(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> i32 {
    let mut score = note.score;
    if note.source_name == SELECTED_VIDEO_MEMORY_NAME {
        score -= neighbor_selected_style_distance_penalty(note.storyboard_distance);
        score -= neighbor_selected_character_state_mismatch_penalty(note, context);
    }
    let fragments = split_prompt_note_fragments(&note.note)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    for fragment in fragments {
        if fragment.is_empty() {
            continue;
        }
        if note.source_name == SELECTED_VIDEO_MEMORY_NAME
            && fragment.starts_with("镜头")
            && local_shot_framing_fragment(&fragment)
        {
            score -= 18;
        }
        if !context.mood.is_empty()
            && fragment.starts_with("情绪")
            && fragment.contains(&context.mood)
        {
            score += 24;
        }
        if !context.lighting.is_empty()
            && fragment.starts_with("光影")
            && fragment.contains(&context.lighting)
        {
            score += 24;
        }
        if fragment.starts_with("镜头")
            && ((!context.shot.is_empty() && fragment.contains(&context.shot))
                || (!context.camera_move.is_empty() && fragment.contains(&context.camera_move)))
        {
            score += 24;
        }
        if !context.subject.is_empty() && fragment.contains(&context.subject) {
            score += 18;
        }
        if !context.action.is_empty() && fragment.contains(&context.action) {
            score += 14;
        }
        if !context.description.is_empty() && context.description.contains(&fragment) {
            score += 12;
        }
    }
    score
}

fn neighbor_selected_style_distance_penalty(distance: Option<i32>) -> i32 {
    match distance.unwrap_or(2) {
        i32::MIN..=1 => 10,
        2 => 16,
        3 => 22,
        _ => 28,
    }
}

fn neighbor_selected_character_state_mismatch_penalty(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> i32 {
    let mut penalty = 0;
    if selected_voice_family_conflicts_with_context(&note.note, context) {
        penalty += if current_context_voice_family(context) == Some("fragile") {
            34
        } else {
            18
        };
    }
    if selected_generic_restrained_mood_lags_fragile_scene(&note.note, context) {
        penalty += 8;
    }
    penalty
}

fn selected_voice_family_conflicts_with_context(
    note: &str,
    context: &StyleNoteSelectionContext,
) -> bool {
    let Some(note_family) = style_voice_family(note) else {
        return false;
    };
    let context_voice = current_context_voice_family(context);
    matches!(context_voice, Some(context_family) if context_family != note_family)
}

fn current_context_voice_family(context: &StyleNoteSelectionContext) -> Option<&'static str> {
    [context.dialogue.as_str(), context.action.as_str()]
        .into_iter()
        .find_map(style_voice_family)
}

fn context_is_fragile_voice_turn(context: &StyleNoteSelectionContext) -> bool {
    current_context_voice_family(context) == Some("fragile")
        || [
            context.dialogue.as_str(),
            context.action.as_str(),
            context.mood.as_str(),
        ]
        .into_iter()
        .any(|field| {
            [
                "哽咽", "失声", "哑声", "发颤", "颤声", "鼻音", "抽气", "含泪", "哭",
            ]
            .iter()
            .any(|keyword| field.contains(keyword))
        })
}

fn style_voice_family(text: &str) -> Option<&'static str> {
    [
        ("哽咽", "fragile"),
        ("发哽", "fragile"),
        ("失声", "fragile"),
        ("哑声", "fragile"),
        ("颤声", "fragile"),
        ("鼻音", "fragile"),
        ("抽气", "fragile"),
        ("发颤", "fragile"),
        ("低声", "low"),
        ("压低", "low"),
        ("轻声", "light"),
        ("轻轻", "light"),
        ("呢喃", "murmur"),
        ("喃喃", "murmur"),
        ("耳语", "murmur"),
        ("短促", "clipped"),
        ("急促", "clipped"),
    ]
    .into_iter()
    .find_map(|(keyword, family)| text.contains(keyword).then_some(family))
}

const ROLE_STYLE_VOICE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
    &["低声", "压低声音", "低低开口"],
    &["轻声", "轻轻开口", "轻轻说道"],
    &["呢喃", "喃喃", "喃喃道", "喃喃说"],
    &["哽咽", "带着哽意", "声音发哽"],
    &["短促", "短促开口", "短促出声"],
];

const ROLE_STYLE_PERFORMANCE_SHARED_KEYWORD_FAMILIES: &[&[&str]] = &[
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

fn role_style_note_matches_shared_keyword_family(
    note: &str,
    fields: &[&str],
    families: &[&[&str]],
) -> bool {
    let normalized_note = normalize_prompt_text(note);
    if normalized_note.is_empty() {
        return false;
    }

    let normalized_fields = fields
        .iter()
        .map(|field| normalize_prompt_text(field))
        .filter(|field| !field.is_empty())
        .collect::<Vec<_>>();
    families.iter().any(|family| {
        family
            .iter()
            .any(|keyword| normalized_note.contains(keyword))
            && normalized_fields
                .iter()
                .any(|field| family.iter().any(|keyword| field.contains(keyword)))
    })
}

fn selected_generic_restrained_mood_lags_fragile_scene(
    note: &str,
    context: &StyleNoteSelectionContext,
) -> bool {
    note.contains("情绪克制")
        && [
            context.dialogue.as_str(),
            context.action.as_str(),
            context.mood.as_str(),
        ]
        .into_iter()
        .any(|field| {
            ["哽咽", "泪", "发颤", "哭", "失声", "哑声", "鼻音", "抽气"]
                .iter()
                .any(|keyword| field.contains(keyword))
        })
        && !note.contains("哽咽")
        && !note.contains("发颤")
}

pub(in super::super) fn ranked_style_note_is_worth_recalling(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> bool {
    if style_note_selection_context_is_empty(context) {
        return true;
    }

    let evidence = score_style_note_context_evidence(note, context);
    match note.source_name.as_str() {
        SELECTED_VIDEO_MEMORY_NAME => evidence >= 1,
        SCRIPT_VIDEO_STYLE_MEMORY_NAME => evidence >= 2,
        SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => evidence >= 1,
        PROJECT_VIDEO_STYLE_MEMORY_NAME => evidence >= 3,
        PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => evidence >= 2,
        _ => false,
    }
}

pub(in super::super) fn style_note_selection_context_is_empty(
    context: &StyleNoteSelectionContext,
) -> bool {
    [
        context.description.as_str(),
        context.subject.as_str(),
        context.action.as_str(),
        context.shot.as_str(),
        context.camera_move.as_str(),
        context.mood.as_str(),
        context.lighting.as_str(),
    ]
    .into_iter()
    .all(|value| value.is_empty())
}

pub(in super::super) fn score_style_note_context_evidence(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> usize {
    let mut evidence = 0usize;
    let fragments = split_prompt_note_fragments(&note.context_note)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();

    if fragments.iter().any(|fragment| {
        fragment.starts_with("情绪") && !context.mood.is_empty() && fragment.contains(&context.mood)
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("光影")
            && !context.lighting.is_empty()
            && fragment.contains(&context.lighting)
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("镜头")
            && ((!context.shot.is_empty() && fragment.contains(&context.shot))
                || (!context.camera_move.is_empty() && fragment.contains(&context.camera_move)))
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("语气")
            && ((!context.dialogue.is_empty()
                && context
                    .dialogue
                    .contains(fragment.trim_start_matches("语气")))
                || (!context.mood.is_empty() && fragment.contains(&context.mood))
                || role_style_note_matches_shared_keyword_family(
                    fragment,
                    &[context.action.as_str(), context.dialogue.as_str()],
                    ROLE_STYLE_VOICE_SHARED_KEYWORD_FAMILIES,
                )
                || (context_is_fragile_voice_turn(context)
                    && style_voice_family(fragment) == Some("fragile")))
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("声场")
            && ((!context.sound.is_empty()
                && context.sound.contains(fragment.trim_start_matches("声场")))
                || (!context.description.is_empty()
                    && context
                        .description
                        .contains(fragment.trim_start_matches("声场"))))
    }) {
        evidence += 2;
    }
    if fragments.iter().any(|fragment| {
        fragment.starts_with("表演")
            && ((!context.action.is_empty()
                && context.action.contains(fragment.trim_start_matches("表演")))
                || (!context.dialogue.is_empty()
                    && context
                        .dialogue
                        .contains(fragment.trim_start_matches("表演")))
                || (!context.mood.is_empty() && fragment.contains(&context.mood))
                || role_style_note_matches_shared_keyword_family(
                    fragment,
                    &[context.action.as_str(), context.dialogue.as_str()],
                    ROLE_STYLE_PERFORMANCE_SHARED_KEYWORD_FAMILIES,
                )
                || (context_is_fragile_voice_turn(context) && fragment.contains("呼吸发颤")))
    }) {
        evidence += 2;
    }
    if !context.subject.is_empty()
        && fragments
            .iter()
            .any(|fragment| fragment.contains(&context.subject))
    {
        evidence += 1;
    }
    if !context.action.is_empty()
        && fragments
            .iter()
            .any(|fragment| fragment.contains(&context.action))
    {
        evidence += 1;
    }
    if !context.description.is_empty()
        && fragments
            .iter()
            .any(|fragment| context.description.contains(fragment))
    {
        evidence += 1;
    }

    evidence
}
