use serde::Deserialize;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

const SELECTED_VIDEO_MEMORY_NAME: &str = "selected_video_memory";
const SCRIPT_VIDEO_STYLE_MEMORY_NAME: &str = "script_video_style_memory";
const SELECTED_VIDEO_MEMORY_KEEP_ROWS: i64 = 12;
const SCRIPT_VIDEO_STYLE_MEMORY_KEEP_ROWS: i64 = 1;
const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;
const STYLE_NOTE_PREFIXES: [&str; 4] = ["镜头", "情绪", "光影", "场景"];
const CONTINUITY_NOTE_KEYWORDS: [&str; 8] = [
    "保持", "延续", "衔接", "连续", "一致", "统一", "方向", "构图",
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
    if let Some(style) = style_only_note(&note) {
        parts.push(format!("style={style}"));
    }
    parts.push(format!("note={note}"));
    if let Some(duration) = resolve_duration_label(row) {
        parts.push(format!("duration={duration}"));
    }
    Some(parts.join(" | "))
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

pub(crate) fn select_script_video_style_memory_notes(rows: &[AgentMemoryRow]) -> Vec<String> {
    rows.iter()
        .filter(|row| row.name == SCRIPT_VIDEO_STYLE_MEMORY_NAME)
        .filter_map(selected_video_style_value)
        .take(1)
        .collect()
}

pub(crate) fn select_selected_video_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
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
            let note = selected_video_style_value(row)?;
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

fn selected_video_memory_note(row: &StoryboardPromptSeedRow) -> Option<String> {
    if let Some(fields) = row
        .video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    {
        let mut fragments = Vec::new();
        if !fields.subject.is_empty() {
            fragments.push(clip_prompt_fragment(&fields.subject, 20));
        }
        let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<Vec<_>>()
            .join("");
        if !camera.is_empty() {
            fragments.push(format!("镜头{}", clip_prompt_fragment(&camera, 14)));
        }
        if !fields.action.is_empty() {
            fragments.push(clip_prompt_fragment(&fields.action, 18));
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
        if !fields.setting.is_empty() {
            fragments.push(format!("场景{}", clip_prompt_fragment(&fields.setting, 12)));
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

fn build_script_video_style_memory(rows: &[AgentMemoryRow]) -> Option<String> {
    let notes = rows
        .iter()
        .filter(|row| row.name == SELECTED_VIDEO_MEMORY_NAME)
        .filter_map(selected_video_style_value)
        .collect::<Vec<_>>();
    if notes.len() < 2 {
        return None;
    }

    let recurring = recurring_style_fragments(&notes);
    if recurring.is_empty() {
        return None;
    }

    let style = clip_prompt_fragment(&recurring.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS);
    Some(format!(
        "sampleCount={} | style={} | note={}",
        notes.len(),
        style,
        style
    ))
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

    for prefix in ["镜头", "情绪", "光影", "场景"] {
        if let Some(fragment) = pick_recurring_prefixed_fragment(&parsed, prefix) {
            recurring.push(fragment);
        }
    }

    recurring
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
    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn selected_video_style_value(row: &AgentMemoryRow) -> Option<String> {
    extract_key_value(&row.content, "style")
        .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .or_else(|| extract_key_value(&row.content, "note").and_then(|note| style_only_note(&note)))
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
        .filter(|(_, count, _)| *count >= 2)
        .max_by(|a, b| a.1.cmp(&b.1).then_with(|| b.2.cmp(&a.2)))
        .map(|(value, _, _)| value)
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

#[cfg(test)]
mod tests {
    use super::{
        build_script_video_style_memory, build_selected_video_memory, clear_selected_video_memory,
        compact_video_continuity_note, parse_structured_storyboard_description,
        select_neighbor_selected_video_memory_notes, select_script_video_style_memory_notes,
        select_selected_video_memory_notes, AgentMemoryRow, StoryboardPromptSeedRow,
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
        assert!(content.contains("style=镜头中景稳定跟拍，情绪急迫，光影阴天冷光，场景旧宅走廊"));
        assert!(content.contains("note=主角冲出旧宅"));
        assert!(content.contains("镜头中景稳定跟拍"));
        assert!(content.contains("情绪急迫"));
        assert!(content.contains("duration=5s"));
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
        );

        assert_eq!(notes, vec!["镜头冷调近景，情绪压迫".to_string()]);
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
        assert!(summary.contains("镜头中景稳定跟拍"));
        assert!(summary.contains("情绪冷峻压迫"));
        assert!(summary.contains("光影冷调逆光"));
        assert!(summary.contains("场景旧宅走廊"));
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
}
