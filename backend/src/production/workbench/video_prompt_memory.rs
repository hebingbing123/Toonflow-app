use serde::Deserialize;
use sha2::{Digest, Sha256};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

const SELECTED_VIDEO_MEMORY_NAME: &str = "selected_video_memory";
const SCRIPT_VIDEO_STYLE_MEMORY_NAME: &str = "script_video_style_memory";
const PROJECT_VIDEO_STYLE_MEMORY_NAME: &str = "project_video_style_memory";
const REJECTED_VIDEO_NEGATIVE_MEMORY_NAME: &str = "rejected_video_negative_memory";
const SELECTED_VIDEO_MEMORY_KEEP_ROWS: i64 = 12;
const SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 1;
const PROJECT_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 1;
const PROJECT_VIDEO_STYLE_MEMORY_MAX_SAMPLES_PER_SCRIPT: usize = 2;
const REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS: i64 = 12;
const REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS: u32 = 2;
const REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT: usize = 2;
const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;
const STYLE_NOTE_PREFIXES: [&str; 4] = ["镜头", "情绪", "光影", "场景"];
const STYLE_PROMPT_PREFIXES: [&str; 3] = ["镜头", "情绪", "光影"];
const STABLE_PROMPT_SHOT_KEYWORDS: [&str; 8] = [
    "稳定跟拍",
    "手持跟拍",
    "慢推",
    "推进",
    "拉远",
    "环绕",
    "手持",
    "跟拍",
];
const PROMPT_SHOT_FRAMING_KEYWORDS: [&str; 7] =
    ["特写", "近景", "中景", "全景", "远景", "低机位", "高机位"];
const CONTINUITY_NOTE_KEYWORDS: [&str; 8] = [
    "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
];
const SHOT_STYLE_KEYWORDS: [&str; 9] = [
    "稳定跟拍",
    "手持跟拍",
    "慢推",
    "推进",
    "拉远",
    "环绕",
    "稳定",
    "手持",
    "跟拍",
];
const MOOD_STYLE_KEYWORDS: [&str; 11] = [
    "冷峻压迫",
    "紧张压迫",
    "压迫感",
    "压迫",
    "冷峻",
    "紧张",
    "克制",
    "悬疑",
    "冷调",
    "冷色",
    "悲怆",
];
const LIGHTING_STYLE_KEYWORDS: [&str; 12] = [
    "阴天冷光",
    "暖金逆光",
    "冷调逆光",
    "冷色逆光",
    "霓虹反光",
    "潮湿反光",
    "侧逆光",
    "逆光",
    "冷调",
    "冷光",
    "暖光",
    "霓虹",
];

#[derive(Debug, Deserialize, sqlx::FromRow)]
pub(crate) struct StoryboardPromptSeedRow {
    pub(crate) prompt: Option<String>,
    pub(crate) video_desc: Option<String>,
    pub(crate) duration: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
pub(crate) struct AgentMemoryRow {
    pub(crate) name: String,
    pub(crate) content: String,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct ScopedAgentMemoryRow {
    name: String,
    content: String,
    episodes_id: Option<i32>,
}

#[derive(Debug, Clone)]
pub(crate) struct StructuredStoryboardDescription {
    pub(crate) subject: String,
    pub(crate) setting: String,
    pub(crate) duration_seconds: Option<i32>,
    pub(crate) shot: String,
    pub(crate) camera_move: String,
    pub(crate) action: String,
    pub(crate) mood: String,
    pub(crate) lighting: String,
    pub(crate) dialogue: String,
    pub(crate) sound: String,
}

pub(crate) fn build_selected_video_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let note = selected_video_memory_note(row)?;
    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    if let Some(style) = style_only_note(&note) {
        parts.push(format!("style={style}"));
    }
    parts.push(format!("note={note}"));
    if let Some(duration) = resolve_duration_label(row) {
        parts.push(format!("duration={duration}"));
    }
    Some(parts.join(" | "))
}

pub(crate) fn build_rejected_video_negative_memory(
    storyboard_numeric_id: i32,
    row: &StoryboardPromptSeedRow,
) -> Option<String> {
    if storyboard_numeric_id <= 0 {
        return None;
    }

    let fields = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)?;
    let mut fragments = Vec::new();
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.shot),
    );
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_shot_or_camera_fragment(&fields.camera_move),
    );
    push_rejected_negative_fragment(&mut fragments, map_rejected_mood_fragment(&fields.mood));
    push_rejected_negative_fragment(
        &mut fragments,
        map_rejected_lighting_fragment(&fields.lighting),
    );
    if fragments.is_empty() {
        return None;
    }

    let mut parts = vec![format!("storyboardIds={storyboard_numeric_id}")];
    if let Some(prompt_seed) = storyboard_prompt_seed(row) {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    parts.push("rejectionCount=1".to_string());
    parts.push(format!("avoid={}", fragments.join(", ")));
    Some(parts.join(" | "))
}

fn storyboard_memory_key(storyboard_numeric_id: i32) -> Option<String> {
    if storyboard_numeric_id > 0 {
        Some(format!("storyboardIds={storyboard_numeric_id}"))
    } else {
        None
    }
}

pub(crate) async fn persist_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let latest: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if latest.as_deref() == Some(content) {
        return Ok(());
    }

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_selected_video_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn persist_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    content: &str,
) -> Result<(), ApiError> {
    let Some(storyboard_numeric_id) = extract_key_value(content, "storyboardIds")
        .and_then(|value| value.parse::<i32>().ok())
        .filter(|id| *id > 0)
    else {
        return Ok(());
    };
    let storyboard_key = format!("storyboardIds={storyboard_numeric_id}");
    let latest: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let next_content = if let Some(latest) = latest.as_deref() {
        merge_rejected_video_negative_memory(latest, content)
    } else {
        content.to_string()
    };

    if latest.as_deref() == Some(next_content.as_str()) {
        return Ok(());
    }

    clear_rejected_video_negative_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(&next_content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

pub(crate) async fn clear_rejected_video_negative_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<(), ApiError> {
    if storyboard_numeric_id <= 0 {
        return Ok(());
    }
    let Some(storyboard_key) = storyboard_memory_key(storyboard_numeric_id) else {
        return Ok(());
    };
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
          AND content LIKE $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
    .bind(format!("%{storyboard_key}%"))
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(crate) async fn refresh_script_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<(), ApiError> {
    let rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summarized = build_script_video_style_memory(&rows);
    replace_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        SCRIPT_VIDEO_STYLE_MEMORY_NAME,
        summarized.as_deref(),
        SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await
}

pub(crate) async fn refresh_project_video_style_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
) -> Result<(), ApiError> {
    let rows = sqlx::query_as::<_, ScopedAgentMemoryRow>(
        r#"
        SELECT name, content, episodes_id
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(SELECTED_VIDEO_MEMORY_NAME)
    .bind(SELECTED_VIDEO_MEMORY_KEEP_ROWS * 4)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let summarized = build_project_video_style_memory(&rows);
    replace_project_summary_memory(
        pool,
        user_id,
        project_numeric_id,
        PROJECT_VIDEO_STYLE_MEMORY_NAME,
        summarized.as_deref(),
        PROJECT_VIDEO_STYLE_MEMORY_KEEP_ROWS,
    )
    .await
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_script_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    rows.iter()
        .filter(|row| row.name == SCRIPT_VIDEO_STYLE_MEMORY_NAME)
        .filter_map(selected_video_style_value)
        .take(1)
        .collect()
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_project_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    rows.iter()
        .filter(|row| row.name == PROJECT_VIDEO_STYLE_MEMORY_NAME)
        .filter_map(selected_video_style_value)
        .take(1)
        .collect()
}

pub(crate) fn select_prioritized_video_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let context = build_style_note_selection_context(storyboard_row);
    let mut candidates = collect_ranked_video_style_note_candidates(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
    )
    .into_iter()
    .filter(|candidate| ranked_style_note_is_worth_recalling(candidate, &context))
    .collect::<Vec<_>>();
    candidates.sort_by(|a, b| {
        score_ranked_style_note(b, &context)
            .cmp(&score_ranked_style_note(a, &context))
            .then(b.score.cmp(&a.score))
            .then(a.recency_idx.cmp(&b.recency_idx))
            .then(a.note.cmp(&b.note))
    });
    candidates.into_iter().find_map(|candidate| {
        compact_video_style_prompt_note(&candidate.note).filter(|note| !note.is_empty())
    })
}

pub(crate) fn select_rejected_video_negative_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    let mut scored = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
        .filter_map(|(idx, row)| {
            (memory_matches_storyboard(&row.content, storyboard_numeric_id)
                && memory_matches_prompt_seed(&row.content, current_prompt_seed))
            .then_some((idx, row))
        })
        .filter(|row| {
            rejected_video_negative_rejection_count(&row.1.content)
                >= REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        })
        .filter_map(|(idx, row)| {
            let avoid = extract_key_value(&row.content, "avoid")?;
            let ranked = ranked_rejected_negative_fragments(&avoid);
            if ranked.is_empty() {
                let note = clip_prompt_fragment(&avoid, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
                return Some(vec![(
                    score_rejected_negative_fragment(&note),
                    idx,
                    0usize,
                    note,
                )]);
            }
            Some(
                ranked
                    .into_iter()
                    .enumerate()
                    .map(|(fragment_idx, note)| {
                        (
                            score_rejected_negative_fragment(&note),
                            idx,
                            fragment_idx,
                            note,
                        )
                    })
                    .collect::<Vec<_>>(),
            )
        })
        .flatten()
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.cmp(&b.3))
    });

    let mut selected = Vec::new();
    for (_, _, _, fragment) in scored {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    (!selected.is_empty())
        .then(|| selected.join(", "))
        .into_iter()
        .collect()
}

#[cfg_attr(not(test), allow(dead_code))]
pub(crate) fn select_pending_rejected_video_observation_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Option<String> {
    select_pending_rejected_video_observation_candidates(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
    )
    .into_iter()
    .next()
}

pub(crate) fn select_pending_rejected_video_observation_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    let mut scored = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| row.name == REJECTED_VIDEO_NEGATIVE_MEMORY_NAME)
        .filter_map(|(idx, row)| {
            memory_matches_storyboard(&row.content, storyboard_numeric_id).then_some((idx, row))
        })
        .filter(|(_, row)| memory_matches_prompt_seed(&row.content, current_prompt_seed))
        .filter(|(_, row)| {
            rejected_video_negative_rejection_count(&row.content)
                < REJECTED_VIDEO_NEGATIVE_MEMORY_MIN_REJECTIONS
        })
        .filter_map(|(idx, row)| {
            let avoid = extract_key_value(&row.content, "avoid")?;
            let ranked = ranked_observation_fragments(&avoid);
            if ranked.is_empty() {
                let note = clip_prompt_fragment(&avoid, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
                return Some(vec![(
                    score_pending_observation_note(&note),
                    idx,
                    0usize,
                    note,
                )]);
            }
            Some(
                ranked
                    .into_iter()
                    .enumerate()
                    .map(|(fragment_idx, note)| {
                        (
                            score_pending_observation_note(&note),
                            idx,
                            fragment_idx,
                            note,
                        )
                    })
                    .collect::<Vec<_>>(),
            )
        })
        .flatten()
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.cmp(&b.2))
            .then(a.3.cmp(&b.3))
    });

    let mut notes = Vec::new();
    for (_, _, _, note) in scored {
        if observation_note_is_covered(&note, &notes) {
            continue;
        }
        notes.retain(|existing| !observation_note_covers(&note, existing));
        notes.push(note);
    }
    notes
}

fn ranked_observation_fragments(avoid: &str) -> Vec<String> {
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

fn rejected_negative_fragments(avoid: &str) -> Vec<String> {
    avoid
        .split(',')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}

fn compact_rejected_negative_avoid(avoid: &str) -> String {
    let mut scored = ranked_rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| (score_rejected_negative_fragment(&fragment), idx, fragment))
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));

    let mut selected = Vec::new();
    for (_, _, fragment) in scored {
        if selected.iter().any(|existing| existing == &fragment) {
            continue;
        }
        selected.push(fragment);
        if selected.len() >= REJECTED_VIDEO_NEGATIVE_FRAGMENT_LIMIT {
            break;
        }
    }
    selected.join(", ")
}

fn ranked_rejected_negative_fragments(avoid: &str) -> Vec<String> {
    let mut ranked = rejected_negative_fragments(avoid)
        .into_iter()
        .enumerate()
        .map(|(idx, fragment)| {
            let note = clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
            (score_rejected_negative_fragment(&note), idx, note)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(a.1.cmp(&b.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut selected = Vec::new();
    for (_, _, fragment) in ranked {
        if observation_note_is_covered(&fragment, &selected) {
            continue;
        }
        selected.retain(|existing| !observation_note_covers(&fragment, existing));
        selected.push(fragment);
    }
    selected
}

fn score_rejected_negative_fragment(fragment: &str) -> i32 {
    let normalized = normalize_prompt_text(fragment).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "shot", "framing", "镜头", "运镜", "抖动", "跳轴",
        "机位",
    ] {
        if normalized.contains(keyword) {
            score += 20;
        }
    }
    for keyword in [
        "flicker", "jitter", "stutter", "blur", "warped", "anatom", "face", "identity", "costume",
        "flash", "闪烁", "变形", "崩坏",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "lighting",
        "light",
        "silhouette",
        "backlight",
        "cold",
        "neon",
        "flat",
        "光影",
        "逆光",
        "冷光",
        "曝光",
        "反光",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "tone",
        "情绪",
        "压迫",
        "冷调",
        "悲怆",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 8
}

fn score_pending_observation_note(note: &str) -> i32 {
    let normalized = normalize_prompt_text(note).to_lowercase();
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "shaky", "handheld", "motion", "camera", "镜头", "运镜", "抖动", "跳轴", "站位", "走位",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "lighting", "light", "flat", "flicker", "冷光", "光影", "曝光", "闪烁", "色温",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "oppressive",
        "frantic",
        "情绪",
        "压迫",
        "节奏",
        "表演",
    ] {
        if normalized.contains(keyword) {
            score += 8;
        }
    }
    score - normalized.chars().count() as i32 / 6
}

fn observation_note_is_covered(candidate: &str, existing_notes: &[String]) -> bool {
    existing_notes
        .iter()
        .any(|existing| observation_note_covers(existing, candidate))
}

fn observation_note_covers(existing: &str, candidate: &str) -> bool {
    if observation_note_same_family(existing, candidate) {
        return score_pending_observation_note(existing)
            >= score_pending_observation_note(candidate);
    }
    observation_note_contains(existing, candidate)
}

fn observation_note_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_observation_note(existing);
    let candidate = canonical_observation_note(candidate);
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

fn observation_note_same_family(existing: &str, candidate: &str) -> bool {
    let existing = observation_note_family(existing);
    let candidate = observation_note_family(candidate);
    !existing.is_empty() && existing == candidate
}

fn observation_note_family(value: &str) -> &'static str {
    match canonical_observation_note(value).as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" | "avoid extra shot changes or wrong framing" => {
            "shot_change_framing"
        }
        "avoid extreme camera angle"
        | "avoid overly tight close-up framing"
        | "avoid extreme camera angle or overly tight close-up framing" => "camera_framing",
        "avoid oppressive or frantic mood"
        | "avoid overly cold emotional tone"
        | "avoid overly cold, oppressive, or frantic mood" => "mood_tone",
        "avoid flat cold lighting"
        | "avoid harsh backlight silhouette"
        | "avoid flat cold lighting or harsh backlight silhouette" => "lighting_backlight",
        "avoid face distortion or identity drift"
        | "avoid costume or character drift"
        | "avoid face drift or costume inconsistency"
        | "avoid face distortion, identity drift, costume drift" => "character_consistency",
        _ => "",
    }
}

fn canonical_observation_note(value: &str) -> String {
    value
        .trim()
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ',' | ';' | '，' | '；' | '.' | '。' | ':' | '：')
        })
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

pub(crate) fn select_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<String> {
    if storyboard_numeric_id <= 0 {
        return Vec::new();
    }
    let mut notes = Vec::new();
    for row in rows {
        if row.name != SELECTED_VIDEO_MEMORY_NAME {
            continue;
        }
        if !memory_matches_storyboard(&row.content, storyboard_numeric_id) {
            continue;
        }
        if !memory_matches_prompt_seed(&row.content, current_prompt_seed) {
            continue;
        }
        let Some(note) = selected_video_style_value(row).or_else(|| {
            extract_key_value(&row.content, "note")
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        }) else {
            continue;
        };
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        break;
    }
    notes
}

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
                            .split('，')
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

pub(crate) fn normalize_prompt_text(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

pub(crate) fn clip_prompt_fragment(text: &str, max_chars: usize) -> String {
    let normalized = normalize_prompt_text(text);
    let mut chars = normalized.chars();
    let clipped = chars.by_ref().take(max_chars).collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}

pub(crate) fn parse_structured_storyboard_description(
    description: &str,
) -> Option<StructuredStoryboardDescription> {
    let normalized = description
        .trim()
        .trim_start_matches(['（', '('])
        .trim_end_matches(['）', ')'])
        .trim();
    if normalized.is_empty() {
        return None;
    }
    let parts = normalized
        .split('、')
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>();
    if parts.len() < 8 {
        return None;
    }
    Some(StructuredStoryboardDescription {
        subject: parts.first().cloned().unwrap_or_default(),
        setting: parts.get(1).cloned().unwrap_or_default(),
        duration_seconds: parts.get(3).and_then(|value| parse_positive_int(value)),
        shot: parts.get(4).cloned().unwrap_or_default(),
        camera_move: parts.get(5).cloned().unwrap_or_default(),
        action: parts.get(6).cloned().unwrap_or_default(),
        mood: parts.get(7).cloned().unwrap_or_default(),
        lighting: parts.get(8).cloned().unwrap_or_default(),
        dialogue: parts.get(9).cloned().unwrap_or_default(),
        sound: parts.get(10).cloned().unwrap_or_default(),
    })
}

pub(crate) fn parse_positive_int(text: &str) -> Option<i32> {
    let mut digits = String::new();
    for ch in text.chars() {
        if ch.is_ascii_digit() {
            digits.push(ch);
        } else if !digits.is_empty() {
            break;
        }
    }
    digits.parse::<i32>().ok().filter(|value| *value > 0)
}

pub(crate) fn extract_key_value(row: &str, key: &str) -> Option<String> {
    let marker = format!("{key}=");
    let start = row.find(&marker)? + marker.len();
    let rest = &row[start..];
    let end = rest
        .find(" | ")
        .or_else(|| rest.find("; "))
        .unwrap_or(rest.len());
    let value = normalize_prompt_text(rest[..end].trim());
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

fn rejected_video_negative_rejection_count(content: &str) -> u32 {
    extract_key_value(content, "rejectionCount")
        .and_then(|value| value.parse::<u32>().ok())
        .filter(|count| *count > 0)
        .unwrap_or(1)
}

fn rejected_video_memory_prompt_seed(content: &str) -> Option<String> {
    extract_key_value(content, "promptSeed")
}

fn merge_rejected_video_negative_memory(existing: &str, incoming: &str) -> String {
    let incoming_prompt_seed = rejected_video_memory_prompt_seed(incoming);
    let existing_prompt_seed = rejected_video_memory_prompt_seed(existing);
    if incoming_prompt_seed != existing_prompt_seed {
        return incoming.to_string();
    }

    let storyboard_numeric_id = extract_key_value(incoming, "storyboardIds")
        .or_else(|| extract_key_value(existing, "storyboardIds"))
        .unwrap_or_default();
    let prompt_seed = incoming_prompt_seed
        .or(existing_prompt_seed)
        .unwrap_or_default();
    let rejection_count = rejected_video_negative_rejection_count(existing).saturating_add(1);
    let avoid = merge_rejected_negative_avoid(
        extract_key_value(existing, "avoid").as_deref(),
        extract_key_value(incoming, "avoid").as_deref(),
    );

    let mut parts = Vec::new();
    if !storyboard_numeric_id.is_empty() {
        parts.push(format!("storyboardIds={storyboard_numeric_id}"));
    }
    if !prompt_seed.is_empty() {
        parts.push(format!("promptSeed={prompt_seed}"));
    }
    parts.push(format!("rejectionCount={rejection_count}"));
    if !avoid.is_empty() {
        parts.push(format!("avoid={avoid}"));
    }
    parts.join(" | ")
}

fn merge_rejected_negative_avoid(existing: Option<&str>, incoming: Option<&str>) -> String {
    let mut fragments = Vec::new();
    for value in [existing, incoming].into_iter().flatten() {
        for fragment in value.split(',') {
            let fragment = normalize_prompt_text(fragment);
            if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
                continue;
            }
            fragments.push(fragment);
        }
    }
    fragments.join(", ")
}

fn selected_video_memory_note(row: &StoryboardPromptSeedRow) -> Option<String> {
    if let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    {
        let mut fragments = Vec::new();
        let subject = compact_selected_memory_subject(&fields.subject, &fields.action);
        let setting = compact_selected_memory_setting(
            &fields.setting,
            subject.as_deref(),
            Some(fields.action.as_str()),
        );
        let action = compact_selected_memory_action(&fields.action, subject.as_deref());

        if let Some(subject) = subject {
            fragments.push(clip_prompt_fragment(&subject, 20));
        }
        let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<Vec<_>>()
            .join("");
        if !camera.is_empty() {
            fragments.push(format!("镜头{}", clip_prompt_fragment(&camera, 14)));
        }
        if let Some(action) = action {
            fragments.push(clip_prompt_fragment(&action, 18));
        }
        if !fields.mood.is_empty() {
            fragments.push(format!("情绪{}", clip_prompt_fragment(&fields.mood, 12)));
        }
        if !fields.lighting.is_empty() {
            fragments.push(format!(
                "光影{}",
                clip_prompt_fragment(&fields.lighting, 14)
            ));
        }
        if let Some(setting) = setting {
            fragments.push(format!("场景{}", clip_prompt_fragment(&setting, 12)));
        }
        let note = fragments.join("，");
        if !note.is_empty() {
            return Some(clip_prompt_fragment(
                &note,
                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
            ));
        }
    }

    row.prompt
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty())
        .map(|text| clip_prompt_fragment(&text, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .or_else(|| {
            row.video_desc
                .as_deref()
                .map(normalize_prompt_text)
                .filter(|text| !text.is_empty())
                .map(|text| clip_prompt_fragment(&text, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        })
}

fn compact_selected_memory_subject(subject: &str, action: &str) -> Option<String> {
    let subject = normalize_prompt_text(subject);
    if subject.is_empty() {
        return None;
    }
    if prompt_fragments_substantially_overlap(&subject, action) {
        return None;
    }
    Some(subject)
}

fn compact_selected_memory_action(action: &str, subject: Option<&str>) -> Option<String> {
    let action = normalize_prompt_text(action);
    if action.is_empty() {
        return None;
    }
    if subject.is_some_and(|value| prompt_fragments_substantially_overlap(value, &action)) {
        return None;
    }
    Some(action)
}

fn compact_selected_memory_setting(
    setting: &str,
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let setting = normalize_prompt_text(setting);
    if setting.is_empty() {
        return None;
    }
    if subject.is_some_and(|value| prompt_fragments_substantially_overlap(value, &setting))
        || action.is_some_and(|value| prompt_fragments_substantially_overlap(value, &setting))
    {
        return None;
    }
    Some(setting)
}

fn prompt_fragments_substantially_overlap(lhs: &str, rhs: &str) -> bool {
    let lhs = normalize_prompt_text(lhs);
    let rhs = normalize_prompt_text(rhs);
    if lhs.is_empty() || rhs.is_empty() {
        return false;
    }
    lhs == rhs
        || (lhs.chars().count() >= 6 && rhs.contains(&lhs))
        || (rhs.chars().count() >= 6 && lhs.contains(&rhs))
}

pub(crate) fn storyboard_prompt_seed(row: &StoryboardPromptSeedRow) -> Option<String> {
    let prompt = row
        .prompt
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let video_desc = row
        .video_desc
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let duration = row
        .duration
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .unwrap_or_default();
    let source = [prompt, video_desc, duration].join("\n");
    if source.trim().is_empty() {
        return None;
    }

    let mut hasher = Sha256::new();
    hasher.update(source.as_bytes());
    let hex = format!("{:x}", hasher.finalize());
    Some(hex[..12].to_string())
}

fn resolve_duration_label(row: &StoryboardPromptSeedRow) -> Option<String> {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .and_then(|fields| fields.duration_seconds)
        .map(|value| format!("{value}s"))
        .or_else(|| {
            row.duration
                .as_deref()
                .and_then(parse_positive_int)
                .map(|value| format!("{value}s"))
        })
}

fn memory_matches_storyboard(content: &str, storyboard_numeric_id: i32) -> bool {
    extract_storyboard_ids(content).contains(&storyboard_numeric_id)
}

fn memory_matches_prompt_seed(content: &str, current_prompt_seed: Option<&str>) -> bool {
    match current_prompt_seed {
        Some(seed) if !seed.is_empty() => {
            extract_key_value(content, "promptSeed").as_deref() == Some(seed)
        }
        _ => true,
    }
}

fn extract_storyboard_ids(content: &str) -> Vec<i32> {
    extract_key_value(content, "storyboardIds")
        .map(|raw| {
            raw.split(',')
                .filter_map(|value| value.trim().parse::<i32>().ok())
                .filter(|value| *value > 0)
                .collect()
        })
        .unwrap_or_default()
}

#[derive(Debug, Clone)]
struct StyleNoteSelectionContext {
    description: String,
    subject: String,
    action: String,
    shot: String,
    camera_move: String,
    mood: String,
    lighting: String,
}

#[derive(Debug, Clone)]
struct RankedStyleNote {
    note: String,
    score: i32,
    recency_idx: usize,
    source_name: String,
}

fn build_style_note_selection_context(
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
    }
}

fn collect_ranked_video_style_note_candidates(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<RankedStyleNote> {
    let mut candidates = Vec::new();
    for (idx, row) in rows.iter().enumerate() {
        let (base_score, note) = match row.name.as_str() {
            SELECTED_VIDEO_MEMORY_NAME => {
                if !memory_row_is_neighbor_selected_style(
                    row,
                    storyboard_numeric_id,
                    current_prompt_seed,
                ) {
                    continue;
                }
                (120, extract_style_note_value(row))
            }
            SCRIPT_VIDEO_STYLE_MEMORY_NAME => (90, extract_style_note_value(row)),
            PROJECT_VIDEO_STYLE_MEMORY_NAME => (70, extract_style_note_value(row)),
            _ => continue,
        };
        let Some(note) = note else {
            continue;
        };
        let sample_count = extract_key_value(&row.content, "sampleCount")
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(1)
            .clamp(1, 8);
        candidates.push(RankedStyleNote {
            note,
            score: base_score + sample_count * 4,
            recency_idx: idx,
            source_name: row.name.clone(),
        });
    }
    candidates
}

fn memory_row_is_neighbor_selected_style(
    row: &AgentMemoryRow,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> bool {
    if !memory_matches_prompt_seed(&row.content, current_prompt_seed) {
        return false;
    }
    let storyboard_ids = extract_storyboard_ids(&row.content);
    !storyboard_ids.is_empty() && !storyboard_ids.contains(&storyboard_numeric_id)
}

fn extract_style_note_value(row: &AgentMemoryRow) -> Option<String> {
    selected_video_style_value_from_content(&row.content)
}

fn selected_video_style_value_from_content(content: &str) -> Option<String> {
    if let Some(value) = extract_key_value(content, "style") {
        return compact_video_style_prompt_note(&value);
    }
    extract_key_value(content, "note")
        .and_then(|value| compact_video_style_prompt_note(&value))
        .filter(|value| !value.is_empty())
}

fn score_ranked_style_note(note: &RankedStyleNote, context: &StyleNoteSelectionContext) -> i32 {
    let mut score = note.score - note.recency_idx as i32;
    let fragments = note
        .note
        .split('，')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    score += fragments.len() as i32 * 12;
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
        PROJECT_VIDEO_STYLE_MEMORY_NAME => evidence >= 3,
        _ => false,
    }
}

fn style_note_selection_context_is_empty(context: &StyleNoteSelectionContext) -> bool {
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

fn score_style_note_context_evidence(
    note: &RankedStyleNote,
    context: &StyleNoteSelectionContext,
) -> usize {
    let mut evidence = 0usize;
    let fragments = note
        .note
        .split('，')
        .map(normalize_prompt_text)
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

fn local_shot_framing_fragment(fragment: &str) -> bool {
    ["低机位", "高机位", "特写", "近景", "中景", "全景", "远景"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
}

fn build_script_video_style_memory(rows: &[AgentMemoryRow]) -> Option<String> {
    let notes = distinct_selected_video_style_notes(rows);
    if notes.len() < 2 {
        return None;
    }

    let recurring = recurring_style_fragments(&notes);
    if recurring.is_empty() {
        return None;
    }

    let style = clip_prompt_fragment(&recurring.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
    Some(format!("sampleCount={} | style={}", notes.len(), style))
}

fn build_project_video_style_memory(rows: &[ScopedAgentMemoryRow]) -> Option<String> {
    let notes = distinct_project_selected_video_style_notes(rows);
    if notes.len() < 3 {
        return None;
    }

    let recurring = recurring_style_fragments(&notes);
    if recurring.is_empty() {
        return None;
    }

    let style = clip_prompt_fragment(&recurring.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
    Some(format!("sampleCount={} | style={}", notes.len(), style))
}

fn distinct_selected_video_style_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
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

fn distinct_project_selected_video_style_notes(rows: &[ScopedAgentMemoryRow]) -> Vec<String> {
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

fn distinct_selected_video_style_notes_by_scope<'a>(
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

fn recurring_style_fragments(notes: &[String]) -> Vec<String> {
    let parsed = notes
        .iter()
        .map(|note| {
            note.split('，')
                .map(normalize_prompt_text)
                .collect::<Vec<_>>()
        })
        .collect::<Vec<_>>();
    let mut recurring = Vec::new();

    for prefix in STYLE_PROMPT_PREFIXES {
        if let Some(fragment) = summarize_recurring_prefixed_fragment(&parsed, prefix) {
            recurring.push(fragment);
        }
    }

    recurring
}

pub(crate) fn compact_video_style_prompt_note(note: &str) -> Option<String> {
    let mut fragments = Vec::new();
    let mut fallback_shot = None;

    for fragment in note.split('，').map(normalize_prompt_text) {
        if fragment.is_empty() {
            continue;
        }
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

    if fragments.is_empty() {
        return fallback_shot;
    }
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn compact_prompt_style_fragment(fragment: &str) -> Option<String> {
    if fragment.starts_with("镜头") {
        return compact_prompt_shot_style_fragment(fragment);
    }
    if STYLE_PROMPT_PREFIXES
        .iter()
        .any(|prefix| *prefix != "镜头" && fragment.starts_with(prefix))
    {
        return Some(clip_prompt_fragment(
            fragment,
            VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
        ));
    }
    None
}

fn compact_prompt_shot_style_fragment(fragment: &str) -> Option<String> {
    let mut matched = extract_style_keywords(fragment, "镜头", &PROMPT_SHOT_FRAMING_KEYWORDS);
    for keyword in extract_style_keywords(fragment, "镜头", &STABLE_PROMPT_SHOT_KEYWORDS) {
        if matched.iter().any(|existing| {
            existing == &keyword || existing.contains(&keyword) || keyword.contains(existing)
        }) {
            continue;
        }
        matched.push(keyword);
    }
    if matched.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(
        &format!("镜头{}", matched.join("")),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn style_only_note(note: &str) -> Option<String> {
    let fragments = note
        .split('，')
        .map(normalize_prompt_text)
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

fn selected_video_style_value(row: &AgentMemoryRow) -> Option<String> {
    if let Some(value) = extract_key_value(&row.content, "style") {
        return compact_video_style_prompt_note(&value);
    }
    extract_key_value(&row.content, "note").and_then(|note| {
        compact_video_style_prompt_note(&note).or_else(|| {
            extract_key_value(&row.content, "note")
                .map(|raw| clip_prompt_fragment(&raw, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        })
    })
}

pub(crate) fn compact_video_continuity_note(note: &str) -> Option<String> {
    let fragments = note
        .split(['，', '；', ';', '。'])
        .map(normalize_prompt_text)
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

fn summarize_recurring_prefixed_fragment(
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

fn extract_style_keywords<'a>(
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

fn push_rejected_negative_fragment(
    target: &mut Vec<&'static str>,
    candidate: Option<&'static str>,
) {
    let Some(candidate) = candidate else {
        return;
    };
    if target.iter().any(|existing| existing == &candidate) {
        return;
    }
    target.push(candidate);
}

fn map_rejected_shot_or_camera_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("稳定跟拍")
        || value.contains("跟拍")
        || value.contains("推进")
        || value.contains("慢推")
    {
        return Some("avoid repeating stable follow camera");
    }
    if value.contains("手持") {
        return Some("avoid shaky handheld motion");
    }
    if value.contains("低机位") || value.contains("高机位") {
        return Some("avoid extreme camera angle");
    }
    if value.contains("特写") || value.contains("近景") {
        return Some("avoid overly tight close-up framing");
    }
    None
}

fn map_rejected_mood_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("压迫") || value.contains("紧张") || value.contains("急迫") {
        return Some("avoid oppressive or frantic mood");
    }
    if value.contains("冷峻") || value.contains("冷调") || value.contains("冷色") {
        return Some("avoid overly cold emotional tone");
    }
    if value.contains("悲怆") {
        return Some("avoid heavy tragic mood");
    }
    None
}

fn map_rejected_lighting_fragment(value: &str) -> Option<&'static str> {
    let value = normalize_prompt_text(value);
    if value.is_empty() {
        return None;
    }
    if value.contains("逆光") {
        return Some("avoid harsh backlight silhouette");
    }
    if value.contains("冷光") || value.contains("阴天冷光") || value.contains("冷调") {
        return Some("avoid flat cold lighting");
    }
    if value.contains("霓虹") || value.contains("反光") {
        return Some("avoid distracting neon reflections");
    }
    None
}

async fn replace_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    name: &str,
    content: Option<&str>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(content) = content else {
        return Ok(());
    };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, 'productionAgent', 'summary', 'assistant', $4, $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id = $3
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $4
          ORDER BY create_time_ms DESC
          OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(name)
    .bind(keep_rows)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

async fn replace_project_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    name: &str,
    content: Option<&str>,
    keep_rows: i64,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NULL
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = $3
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let Some(content) = content else {
        return Ok(());
    };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, NULL, 'productionAgent', 'summary', 'assistant', $3, $4, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id IS NULL
            AND agent_type = 'productionAgent'
            AND memory_type = 'summary'
            AND name = $3
          ORDER BY create_time_ms DESC
          OFFSET $4
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(name)
    .bind(keep_rows)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{
        build_project_video_style_memory, build_rejected_video_negative_memory,
        build_script_video_style_memory, build_selected_video_memory,
        clear_rejected_video_negative_memory, clear_selected_video_memory,
        compact_rejected_negative_avoid, compact_video_continuity_note,
        merge_rejected_video_negative_memory, parse_structured_storyboard_description,
        rejected_video_negative_rejection_count, select_neighbor_selected_video_memory_notes,
        select_pending_rejected_video_observation_candidates,
        select_pending_rejected_video_observation_note, select_project_video_style_memory_notes,
        select_rejected_video_negative_memory_notes, select_script_video_style_memory_notes,
        select_selected_video_memory_notes, storyboard_prompt_seed, AgentMemoryRow,
        ScopedAgentMemoryRow, StoryboardPromptSeedRow,
    };
    use sqlx::PgPool;
    use uuid::Uuid;

    #[test]
    fn parse_structured_storyboard_description_extracts_fields() {
        let fields = parse_structured_storyboard_description(
            "（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）",
        )
        .expect("fields");

        assert_eq!(fields.setting, "旧宅走廊");
        assert_eq!(fields.duration_seconds, Some(5));
        assert_eq!(fields.dialogue, "别回头");
        assert_eq!(fields.sound, "脚步声门响");
    }

    #[test]
    fn build_selected_video_memory_prefers_compact_structured_note() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在走廊里冲出门外".into()),
                video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("storyboardIds=12"));
        assert!(content.contains("promptSeed="));
        assert!(content.contains("style=镜头稳定跟拍，情绪急迫，光影阴天冷光"));
        assert!(content.contains("note=主角冲出旧宅"));
        assert!(content.contains("镜头中景稳定跟拍"));
        assert!(content.contains("情绪急迫"));
        assert!(content.contains("场景旧宅走廊"));
        assert!(content.contains("duration=5s"));
    }

    #[test]
    fn build_selected_video_memory_drops_duplicate_subject_and_scene_fragments() {
        let content = build_selected_video_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在旧宅走廊尽头停步回头".into()),
                video_desc: Some("（主角在旧宅走廊尽头停步回头、旧宅走廊尽头、主角、5秒、中景、稳定跟拍、主角在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(!content.contains("note=主角在旧宅走廊尽头停步回头"));
        assert!(content.contains("note=镜头中景稳定跟拍"));
        assert!(!content.contains("场景旧宅走廊尽头"));
        assert!(content.contains("情绪压抑"));
    }

    #[test]
    fn build_rejected_video_negative_memory_extracts_short_retry_constraints() {
        let content = build_rejected_video_negative_memory(
            12,
            &StoryboardPromptSeedRow {
                prompt: Some("主角在走廊里冲出门外".into()),
                video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
                duration: Some("5".into()),
            },
        )
        .expect("content");

        assert!(content.contains("storyboardIds=12"));
        assert!(content.contains("promptSeed="));
        assert!(content.contains("rejectionCount=1"));
        assert!(content.contains("avoid=avoid repeating stable follow camera"));
        assert!(content.contains("avoid oppressive or frantic mood"));
        assert!(content.contains("avoid flat cold lighting"));
    }

    #[test]
    fn select_selected_video_memory_notes_keeps_latest_matching_storyboard() {
        let notes = select_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=9 | note=别的镜头".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进".into(),
                },
                AgentMemoryRow {
                    name: "auto_scope_memory".into(),
                    content: "storyboardIds=12 | note=不应读取".into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(notes, vec!["情绪压迫".to_string()]);
    }

    #[test]
    fn select_neighbor_selected_video_memory_notes_prefers_nearest_storyboards() {
        let notes = select_neighbor_selected_video_memory_notes(
            &[
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=5 | style=镜头中景慢推，情绪压迫，光影暖金逆光 | note=主角推门而入，镜头中景慢推，情绪压迫，光影暖金逆光".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=16 | style=镜头中景稳定跟拍，情绪冷峻，光影冷色夜景 | note=反派逼近，镜头中景稳定跟拍，情绪冷峻，光影冷色夜景".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=11 | style=镜头近景稳定跟拍，情绪压迫 | note=女主贴墙前行，镜头近景稳定跟拍，情绪压迫".into(),
                },
                AgentMemoryRow {
                    name: "selected_video_memory".into(),
                    content: "storyboardIds=12 | note=当前镜头已确认".into(),
                },
            ],
            12,
            2,
        );

        assert_eq!(
            notes,
            vec![
                "镜头近景稳定跟拍，情绪压迫".to_string(),
                "镜头中景稳定跟拍，情绪冷峻，光影冷色夜景".to_string()
            ]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_keeps_matching_storyboard_only() {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=9 | rejectionCount=3 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid flat cold lighting, avoid oppressive or frantic mood"]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_skips_single_rejection_noise() {
        let notes = select_rejected_video_negative_memory_notes(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                    .into(),
            }],
            12,
            None,
        );

        assert!(notes.is_empty());
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_keeps_two_strongest_fragments() {
        let notes = select_rejected_video_negative_memory_notes(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=3 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting, avoid shaky handheld motion".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_combines_multiple_rows_without_extra_budget() {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=4 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood"
                            .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid shaky handheld motion, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_rejected_video_negative_memory_notes_deduplicates_weaker_family_across_rows() {
        let notes = select_rejected_video_negative_memory_notes(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flicker".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=3 | avoid=avoid flicker or motion jitter"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["avoid flicker or motion jitter, avoid flat cold lighting".to_string()]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_note_reads_single_rejection_noise() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion, avoid flat cold lighting".into(),
            }],
            12,
            None,
        );

        assert_eq!(note, Some("avoid shaky handheld motion".into()));
    }

    #[test]
    fn select_pending_rejected_video_observation_note_skips_promoted_noise() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid shaky handheld motion"
                    .into(),
            }],
            12,
            None,
        );

        assert_eq!(note, None);
    }

    #[test]
    fn merge_rejected_video_negative_memory_accumulates_rejection_count_and_deduplicates() {
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | rejectionCount=2 | avoid=avoid shaky handheld motion, avoid flat cold lighting",
            "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood",
        );

        assert_eq!(rejected_video_negative_rejection_count(&merged), 3);
        assert!(merged.contains("storyboardIds=12"));
        assert!(merged.contains("avoid=avoid shaky handheld motion, avoid flat cold lighting, avoid oppressive or frantic mood"));
    }

    #[test]
    fn merge_rejected_video_negative_memory_resets_when_prompt_seed_changes() {
        let incoming =
            "storyboardIds=12 | promptSeed=newseed000002 | rejectionCount=1 | avoid=avoid flat cold lighting";
        let merged = merge_rejected_video_negative_memory(
            "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=3 | avoid=avoid shaky handheld motion, avoid oppressive or frantic mood",
            incoming,
        );

        assert_eq!(merged, incoming);
        assert_eq!(rejected_video_negative_rejection_count(&merged), 1);
        assert!(merged.contains("promptSeed=newseed000002"));
        assert!(!merged.contains("avoid shaky handheld motion"));
    }

    #[test]
    fn storyboard_prompt_seed_changes_with_storyboard_version() {
        let first = storyboard_prompt_seed(&StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里冲出门外".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            duration: Some("5".into()),
        })
        .expect("first seed");
        let second = storyboard_prompt_seed(&StoryboardPromptSeedRow {
            prompt: Some("主角在楼梯口停步回望".into()),
            video_desc: Some("（主角停在楼梯口、旧宅楼梯、主角、5秒、近景、缓慢推进、停步回望、压迫、冷调逆光、无台词、风声、A12）".into()),
            duration: Some("5".into()),
        })
        .expect("second seed");

        assert_ne!(first, second);
    }

    #[test]
    fn select_selected_video_memory_notes_skips_stale_prompt_seed() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=oldseed000001 | style=镜头冷调近景，情绪压迫 | note=保持冷调近景和稳定推进".into(),
            }],
            12,
            Some("newseed000002"),
        );

        assert!(notes.is_empty());
    }

    #[test]
    fn select_pending_rejected_video_observation_note_skips_stale_prompt_seed() {
        let note = select_pending_rejected_video_observation_note(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | promptSeed=oldseed000001 | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
            }],
            12,
            Some("newseed000002"),
        );

        assert_eq!(note, None);
    }

    #[test]
    fn select_pending_rejected_video_observation_note_prefers_stronger_camera_warning() {
        let note = select_pending_rejected_video_observation_note(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(note, Some("avoid shaky handheld motion".into()));
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_orders_by_strength() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid shaky handheld motion"
                            .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid shaky handheld motion".to_string(),
                "avoid flat cold lighting".to_string(),
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_keeps_secondary_fragment_from_same_row()
    {
        let notes = select_pending_rejected_video_observation_candidates(
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting, avoid shaky handheld motion"
                        .into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid shaky handheld motion".to_string(),
                "avoid flat cold lighting".to_string(),
            ]
        );
    }

    #[test]
    fn select_pending_rejected_video_observation_candidates_deduplicates_weaker_family_member() {
        let notes = select_pending_rejected_video_observation_candidates(
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker".into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=1 | avoid=avoid flicker or motion jitter"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content: "storyboardIds=12 | rejectionCount=1 | avoid=avoid flat cold lighting"
                        .into(),
                },
            ],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec![
                "avoid flat cold lighting".to_string(),
                "avoid flicker or motion jitter".to_string(),
            ]
        );
    }

    #[test]
    fn compact_rejected_negative_avoid_preserves_original_order_for_same_priority() {
        let compacted = compact_rejected_negative_avoid(
            "avoid flat cold lighting, avoid harsh backlight silhouette, avoid oppressive or frantic mood",
        );

        assert_eq!(
            compacted,
            "avoid flat cold lighting, avoid harsh backlight silhouette"
        );
    }

    #[test]
    fn build_script_video_style_memory_extracts_recurring_style_fragments() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅楼梯 | note=女主贴墙前行，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅楼梯".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头近景手持跟拍，情绪紧张压迫，光影冷调逆光，场景旧宅走廊 | note=反派逼近，镜头近景手持跟拍，情绪紧张压迫，光影冷调逆光，场景旧宅走廊".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("镜头稳定跟拍"));
        assert!(!summary.contains("中景"));
        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影冷调逆光"));
        assert!(!summary.contains("场景旧宅走廊"));
        assert!(!summary.contains("女主"));
    }

    #[test]
    fn select_script_video_style_memory_notes_reads_summary_note() {
        let notes = select_script_video_style_memory_notes(&[
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=女主压门回望，镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | note=别的内容".into(),
            },
        ]);

        assert_eq!(
            notes,
            vec!["镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
        );
    }

    #[test]
    fn build_project_video_style_memory_extracts_cross_script_recurring_style() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，场景废弃走廊 | note=...".into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=17 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
                episodes_id: Some(3),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫"));
        assert!(!summary.contains("中景"));
        assert!(!summary.contains("场景废弃走廊"));
    }

    #[test]
    fn build_project_video_style_memory_requires_majority_support_when_samples_are_dense() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=1 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=2 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=3 | style=镜头稳定跟拍，光影冷调逆光 | note=...".into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=4 | style=镜头稳定跟拍，情绪悲怆，光影冷调逆光 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=5 | style=镜头近景手持，情绪悲怆，光影暖光 | note=..."
                    .into(),
                episodes_id: Some(2),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=5"));
        assert!(summary.contains("style=镜头稳定跟拍，光影冷调逆光"));
        assert!(!summary.contains("情绪冷峻压迫"));
    }

    #[test]
    fn build_project_video_style_memory_prefers_latest_prompt_seed_within_each_script_storyboard() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=newseed000002 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
                episodes_id: Some(7),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=oldseed000001 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
                episodes_id: Some(7),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=seed000000003 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
                episodes_id: Some(8),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | promptSeed=seed000000004 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
                episodes_id: Some(7),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("光影暖金逆光"));
        assert!(!summary.contains("光影冷调逆光"));
    }

    #[test]
    fn build_project_video_style_memory_caps_samples_per_script_to_reduce_single_script_bias() {
        let summary = build_project_video_style_memory(&[
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=1 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=2 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=3 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=..."
                        .into(),
                episodes_id: Some(1),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=4 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=..."
                        .into(),
                episodes_id: Some(2),
            },
            ScopedAgentMemoryRow {
                name: "selected_video_memory".into(),
                content:
                    "storyboardIds=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=..."
                        .into(),
                episodes_id: Some(2),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=4"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫"));
        assert!(!summary.contains("光影冷调逆光"));
        assert!(!summary.contains("光影暖金逆光"));
    }

    #[test]
    fn build_script_video_style_memory_summarizes_recurring_keywords_from_variant_notes() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景稳定跟拍，情绪紧张压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头低机位稳定跟拍，情绪冷峻压迫，光影阴天冷光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=3"));
        assert!(summary.contains("style=镜头稳定跟拍"));
        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影阴天冷光"));
        assert!(!summary.contains("近景"));
        assert!(!summary.contains("低机位"));
    }

    #[test]
    fn build_script_video_style_memory_drops_recurring_local_framing_without_stable_shot_language()
    {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | style=镜头近景，情绪冷峻压迫，光影阴天冷光 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=..."
                    .into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头近景，情绪紧张压迫，光影阴天冷光 | note=..."
                    .into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影阴天冷光"));
        assert!(!summary.contains("镜头近景"));
    }

    #[test]
    fn build_script_video_style_memory_deduplicates_same_storyboard_prompt_seed_samples() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=seed000000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=seed000000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=重复确认同镜头".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | promptSeed=seed000000002 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"));
        assert!(!summary.contains("中景"));
    }

    #[test]
    fn build_script_video_style_memory_prefers_latest_prompt_seed_per_storyboard() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=newseed000002 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=9 | promptSeed=oldseed000001 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=10 | promptSeed=seed000000003 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影暖金逆光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=2"));
        assert!(summary.contains("光影暖金逆光"));
        assert!(!summary.contains("光影冷调逆光"));
    }

    #[test]
    fn build_script_video_style_memory_skips_low_support_keywords_when_note_pool_is_large() {
        let summary = build_script_video_style_memory(&[
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=情绪冷峻压迫，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=13 | style=情绪悲怆，光影冷调逆光 | note=...".into(),
            },
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=14 | style=情绪悲怆，光影暖光 | note=...".into(),
            },
        ])
        .expect("summary");

        assert!(summary.contains("sampleCount=4"));
        assert!(summary.contains("style=光影冷调逆光"));
        assert!(!summary.contains("情绪冷峻压迫"));
        assert!(!summary.contains("情绪悲怆"));
    }

    #[test]
    fn select_project_video_style_memory_notes_reads_summary_note() {
        let notes = select_project_video_style_memory_notes(&[
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头稳定跟拍，情绪冷峻压迫 | note=镜头稳定跟拍，情绪冷峻压迫".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=镜头近景手持 | note=镜头近景手持".into(),
            },
        ]);

        assert_eq!(notes, vec!["镜头稳定跟拍，情绪冷峻压迫".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_drop_scene_fragments_from_prompt_style_memory() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光，场景旧宅走廊 | note=...".into(),
            }],
            12,
            None,
        );

        assert_eq!(
            notes,
            vec!["镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
        );
    }

    #[test]
    fn select_selected_video_memory_notes_drop_local_framing_when_other_style_fragments_exist() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头近景，情绪冷峻压迫，光影阴天冷光 | note=..."
                    .into(),
            }],
            12,
            None,
        );

        assert_eq!(notes, vec!["情绪冷峻压迫，光影阴天冷光".to_string()]);
    }

    #[test]
    fn select_selected_video_memory_notes_keep_local_framing_when_it_is_only_style_signal() {
        let notes = select_selected_video_memory_notes(
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头近景 | note=...".into(),
            }],
            12,
            None,
        );

        assert_eq!(notes, vec!["镜头近景".to_string()]);
    }

    #[test]
    fn compact_video_continuity_note_keeps_only_style_and_continuity_fragments() {
        let note = compact_video_continuity_note(
            "女主推门冲出；保持冷调压迫感；镜头中景稳定跟拍；后续反派从暗处逼近",
        )
        .expect("note");

        assert_eq!(note, "保持冷调压迫感，镜头中景稳定跟拍");
        assert!(!note.contains("反派"));
    }

    #[tokio::test]
    async fn clear_selected_video_memory_ignores_invalid_storyboard_id() {
        let pool =
            PgPool::connect_lazy("postgresql://user:pass@localhost/db").expect("lazy pg pool");
        let result = clear_selected_video_memory(&pool, Uuid::nil(), 1, 2, 0).await;

        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn clear_rejected_video_negative_memory_ignores_invalid_storyboard_id() {
        let pool =
            PgPool::connect_lazy("postgresql://user:pass@localhost/db").expect("lazy pg pool");
        let result = clear_rejected_video_negative_memory(&pool, Uuid::nil(), 1, 2, 0).await;

        assert!(result.is_ok());
    }
}
