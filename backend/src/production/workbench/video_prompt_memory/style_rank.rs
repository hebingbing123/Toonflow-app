use super::style_role_select::role_style_storyboard_focus_score;
use super::*;

pub(crate) fn select_prioritized_video_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let context = build_style_note_selection_context(storyboard_row);
    let subject_candidates = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
        .map(|fields| selected_memory_subject_aliases(&fields.subject, &fields.subject_refs))
        .unwrap_or_default();
    let mut candidates = collect_ranked_video_style_note_candidates(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
        &subject_candidates,
    )
    .into_iter()
    .filter(|candidate| ranked_style_note_is_worth_recalling(candidate, &context))
    .collect::<Vec<_>>();
    let locked_storyboard_focus = candidates
        .iter()
        .map(|candidate| candidate.storyboard_focus)
        .max()
        .unwrap_or(0);
    if locked_storyboard_focus > 0 {
        candidates.retain(|candidate| candidate.storyboard_focus == locked_storyboard_focus);
    }
    let locked_subject_priority = candidates
        .iter()
        .map(|candidate| candidate.subject_priority)
        .min();
    if let Some(locked_subject_priority) = locked_subject_priority {
        if locked_subject_priority != usize::MAX {
            candidates.retain(|candidate| candidate.subject_priority == locked_subject_priority);
        }
    }
    candidates.sort_by(|a, b| {
        b.storyboard_focus
            .cmp(&a.storyboard_focus)
            .then(a.subject_priority.cmp(&b.subject_priority))
            .then(score_ranked_style_note(b, &context).cmp(&score_ranked_style_note(a, &context)))
            .then(a.note.chars().count().cmp(&b.note.chars().count()))
            .then(b.score.cmp(&a.score))
            .then(a.recency_idx.cmp(&b.recency_idx))
            .then(a.note.cmp(&b.note))
    });
    candidates.into_iter().find_map(|candidate| {
        compact_video_style_prompt_note(&candidate.note).filter(|note| !note.is_empty())
    })
}

#[allow(dead_code)]
pub(crate) fn select_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    select_selected_video_memory_notes_for_storyboard(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        None,
    )
}

pub(crate) fn select_selected_video_memory_notes_for_storyboard(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 {
        return Vec::new();
    }
    let should_prefer_delivery = should_prefer_selected_delivery_for_storyboard(storyboard_row);
    let allow_unseeded_fallback = !has_exact_prompt_seed_memory_match(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        &[SELECTED_VIDEO_MEMORY_NAME],
    );
    let mut style_notes = Vec::new();
    let mut fallback_notes = Vec::new();
    for row in rows {
        if row.name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        if !memory_matches_storyboard(&row.content, storyboard_numeric_id) {
            continue;
        }
        if !memory_matches_prompt_seed_with_fallback(
            &row.content,
            current_prompt_seed,
            allow_unseeded_fallback,
        ) {
            continue;
        }
        if should_prefer_delivery {
            if let Some(note) = selected_video_delivery_value_from_content(&row.content) {
                if style_notes.iter().all(|existing| existing != &note) {
                    style_notes.push(note);
                }
                continue;
            }
        }
        if let Some(note) = selected_video_style_value(row) {
            if style_notes.iter().all(|existing| existing != &note) {
                style_notes.push(note);
            }
            continue;
        }

        let Some(note) = extract_key_value(&row.content, "note")
            .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
            .filter(|value| !is_low_signal_selected_memory_note(value))
        else {
            continue;
        };
        if fallback_notes.iter().all(|existing| existing != &note) {
            fallback_notes.push(note);
        }
    }

    if let Some(note) = select_best_selected_video_style_note(style_notes) {
        return vec![note];
    }
    fallback_notes.into_iter().take(1).collect()
}

fn select_best_selected_video_style_note(notes: Vec<String>) -> Option<String> {
    notes.into_iter().max_by(|a, b| {
        score_selected_video_style_note(a)
            .cmp(&score_selected_video_style_note(b))
            .then(count_selected_video_style_axes(a).cmp(&count_selected_video_style_axes(b)))
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

fn score_selected_video_style_note(note: &str) -> i32 {
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

fn count_selected_video_style_axes(note: &str) -> usize {
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

pub(super) fn is_local_framing_only_fragment(fragment: &str) -> bool {
    fragment == "镜头近景"
        || fragment == "镜头中景"
        || fragment == "镜头远景"
        || fragment == "镜头特写"
        || fragment == "镜头全景"
}

#[allow(dead_code)]
pub(crate) fn select_neighbor_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    limit: usize,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 || limit == 0 {
        return Vec::new();
    }
    let mut scored = rows
        .iter()
        .enumerate()
        .filter_map(|(idx, row)| {
            if row.name != SELECTED_VIDEO_MEMORY_NAME {
                return None;
            }
            let storyboard_ids = extract_storyboard_ids(&row.content);
            if storyboard_ids.is_empty() || storyboard_ids.contains(&storyboard_numeric_id) {
                return None;
            }
            let distance = storyboard_ids
                .iter()
                .map(|id| (storyboard_numeric_id - *id).abs())
                .min()?;
            let note = extract_key_value(&row.content, "style")
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                .or_else(|| {
                    extract_key_value(&row.content, "note").and_then(|value| {
                        let fragments = value
                            .split(['，', ',', '；', ';', '。', '\n'])
                            .map(normalize_prompt_text)
                            .filter(|fragment| {
                                STYLE_NOTE_PREFIXES
                                    .iter()
                                    .any(|prefix| fragment.starts_with(prefix))
                            })
                            .collect::<Vec<_>>();
                        if fragments.is_empty() {
                            None
                        } else {
                            Some(clip_prompt_fragment(
                                &fragments.join("，"),
                                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                            ))
                        }
                    })
                })
                .or_else(|| selected_video_style_value(row))?;
            Some((distance, idx, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)));

    let mut notes = Vec::new();
    for (_, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= limit {
            break;
        }
    }
    notes
}

pub(super) fn build_style_note_selection_context(
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> StyleNoteSelectionContext {
    let description = storyboard_row
        .and_then(|row| {
            row.video_desc
                .as_deref()
                .map(normalize_prompt_text)
                .filter(|text| !text.is_empty())
                .or_else(|| {
                    row.prompt
                        .as_deref()
                        .map(normalize_prompt_text)
                        .filter(|text| !text.is_empty())
                })
        })
        .unwrap_or_default();
    let fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    StyleNoteSelectionContext {
        description,
        subject: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.subject))
            .unwrap_or_default(),
        action: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.action))
            .unwrap_or_default(),
        shot: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.shot))
            .unwrap_or_default(),
        camera_move: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.camera_move))
            .unwrap_or_default(),
        mood: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.mood))
            .unwrap_or_default(),
        lighting: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.lighting))
            .unwrap_or_default(),
        dialogue: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.dialogue))
            .unwrap_or_default(),
        sound: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.sound))
            .unwrap_or_default(),
    }
}

fn collect_ranked_video_style_note_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    _current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
    subject_candidates: &[String],
) -> Vec<RankedStyleNote> {
    let mut candidates = Vec::new();
    for (idx, row) in rows.iter().enumerate() {
        let (base_score, note, context_note) = match row.name.as_str() {
            SELECTED_VIDEO_MEMORY_NAME => {
                if !memory_row_is_neighbor_selected_style(row, storyboard_numeric_id) {
                    continue;
                }
                let note = extract_selected_memory_style_note_for_storyboard(row, storyboard_row);
                (120, note, selected_video_style_value(row))
            }
            SCRIPT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
                let note = generation_brief_style_memory_value(row);
                (96, note.clone(), note)
            }
            SCRIPT_VIDEO_STYLE_MEMORY_NAME => {
                let note = extract_style_note_value(row);
                (90, note.clone(), note)
            }
            SCRIPT_ROLE_VIDEO_STYLE_MEMORY_NAME => (
                102,
                role_style_memory_value_for_storyboard(row, storyboard_row),
                selected_video_style_value(row),
            ),
            PROJECT_VIDEO_GENERATION_BRIEF_MEMORY_NAME => {
                let note = generation_brief_style_memory_value(row);
                (76, note.clone(), note)
            }
            PROJECT_VIDEO_STYLE_MEMORY_NAME => {
                let note = extract_style_note_value(row);
                (70, note.clone(), note)
            }
            PROJECT_ROLE_VIDEO_STYLE_MEMORY_NAME => (
                82,
                role_style_memory_value_for_storyboard(row, storyboard_row),
                selected_video_style_value(row),
            ),
            _ => continue,
        };
        let Some(note) = note else {
            continue;
        };
        let context_note = context_note.unwrap_or_else(|| note.clone());
        let sample_count = extract_key_value(&row.content, "sampleCount")
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(1)
            .clamp(1, 8);
        candidates.push(RankedStyleNote {
            note,
            context_note,
            score: base_score + sample_count * 4,
            recency_idx: idx,
            source_name: row.name.clone(),
            storyboard_distance: (row.name == SELECTED_VIDEO_MEMORY_NAME)
                .then(|| {
                    storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                })
                .flatten(),
            storyboard_focus: role_style_storyboard_focus_score(&row.content, storyboard_row),
            subject_priority: memory_subject_match_priority(&row.content, subject_candidates),
        });
    }
    candidates
}

fn memory_row_is_neighbor_selected_style(row: &AgentMemoryRow, storyboard_numeric_id: i32) -> bool {
    let storyboard_ids = extract_storyboard_ids(&row.content);
    !storyboard_ids.is_empty() && !storyboard_ids.contains(&storyboard_numeric_id)
}

fn extract_style_note_value(row: &AgentMemoryRow) -> Option<String> {
    selected_video_style_value_from_content(&row.content)
}

pub(super) fn extract_selected_memory_style_note_for_storyboard(
    row: &AgentMemoryRow,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    if should_prefer_selected_delivery_for_storyboard(storyboard_row) {
        if let Some(delivery) = selected_video_delivery_value_from_content(&row.content) {
            return Some(delivery);
        }
    }
    selected_video_style_value(row)
}

pub(super) fn selected_video_style_value_from_content(content: &str) -> Option<String> {
    if let Some(value) = extract_key_value(content, "style") {
        return compact_video_style_prompt_note(&value);
    }
    extract_key_value(content, "note")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

fn score_ranked_style_note(note: &RankedStyleNote, context: &StyleNoteSelectionContext) -> i32 {
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
    &["停顿", "顿住", "停了停"],
    &["迟疑", "犹疑", "犹豫"],
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

fn ranked_style_note_is_worth_recalling(
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

pub(super) fn style_note_selection_context_is_empty(context: &StyleNoteSelectionContext) -> bool {
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

pub(super) fn score_style_note_context_evidence(
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
