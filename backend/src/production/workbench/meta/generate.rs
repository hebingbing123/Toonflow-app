use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;
use crate::production::workbench::meta::common::{
    clip_prompt_fragment, extract_key_value, normalize_prompt_text, parse_positive_int,
    parse_structured_storyboard_description, StructuredStoryboardDescription,
};
use crate::production::workbench::video::generate::load_auto_negative_prompt;
use crate::production::workbench::video_prompt_memory::{
    compact_video_continuity_note, select_pending_rejected_video_observation_note,
    select_selected_video_memory_notes, storyboard_prompt_seed, AgentMemoryRow,
    StoryboardPromptSeedRow,
};
use crate::scope::http::require_authenticated;
use crate::scope::http::require_owned_numeric_script_scope_user_pool;
use crate::state::AppState;

const VIDEO_PROMPT_MEMORY_ROW_LIMIT: i64 = 8;
const VIDEO_PROMPT_MEMORY_NOTE_LIMIT: usize = 2;
const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;
const VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT: usize = 1;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(in crate::production) struct GenerateVideoPromptBody {
    project_id: i32,
    script_id: i32,
    #[serde(default)]
    storyboard_id: Option<i32>,
    #[serde(default)]
    image_url: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    duration_hint: Option<i32>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateVideoPromptResponse {
    prompt: String,
    negative_prompt: Option<String>,
    observation_note: Option<String>,
    model: String,
    duration: i32,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-video-prompt",
    operation_id = "postProductionWorkbenchGenerateVideoPromptV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_generate_video_prompt(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<GenerateVideoPromptBody>,
) -> Result<JsonResponse<GenerateVideoPromptResponse>, ApiError> {
    let (user_id, pool) = require_owned_numeric_script_scope_user_pool(
        &state,
        &headers,
        body.project_id,
        body.script_id,
    )
    .await?;
    let context = load_video_prompt_context(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        body.storyboard_id,
    )
    .await?;

    let prompt = build_video_prompt(
        body.description.as_deref(),
        body.image_url.as_deref(),
        context.as_ref(),
    );
    let negative_prompt = if let Some(storyboard_id) = body.storyboard_id.filter(|id| *id > 0) {
        load_auto_negative_prompt(
            pool,
            user_id,
            body.project_id,
            body.script_id,
            &[storyboard_id],
        )
        .await?
    } else {
        None
    };
    let current_prompt_seed = context
        .as_ref()
        .and_then(|value| value.storyboard_prompt_seed.as_deref());
    let observation_note = if negative_prompt.is_none() {
        if let Some(storyboard_id) = body.storyboard_id.filter(|id| *id > 0) {
            load_pending_video_observation_note(
                pool,
                user_id,
                body.project_id,
                body.script_id,
                storyboard_id,
                current_prompt_seed,
            )
            .await?
        } else {
            None
        }
    } else {
        None
    };
    let duration = resolve_video_prompt_duration(
        body.duration_hint,
        body.description.as_deref(),
        context.as_ref(),
    );

    Ok(JsonResponse(GenerateVideoPromptResponse {
        prompt,
        negative_prompt,
        observation_note,
        model: "runway-gen-2".to_string(),
        duration,
    }))
}

#[derive(Debug, Clone, Default)]
struct VideoPromptContext {
    storyboard_prompt: Option<String>,
    storyboard_video_desc: Option<String>,
    storyboard_duration: Option<String>,
    storyboard_prompt_seed: Option<String>,
    project_art_style: Option<String>,
    project_director_manual: Option<String>,
    project_video_ratio: Option<String>,
    script_role_anchors: Vec<String>,
    script_scene_anchors: Vec<String>,
    script_tool_anchors: Vec<String>,
    memory_style_notes: Vec<String>,
    continuity_notes: Vec<String>,
}

#[derive(Debug, sqlx::FromRow)]
struct ProjectPromptSeedRow {
    art_style: Option<String>,
    director_manual: Option<String>,
    video_ratio: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
struct ScriptRolePromptSeedRow {
    asset_type: String,
    name: Option<String>,
    describe: Option<String>,
}

async fn load_video_prompt_context(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    script_id: i32,
    storyboard_id: Option<i32>,
) -> Result<Option<VideoPromptContext>, ApiError> {
    let Some(storyboard_numeric_id) = storyboard_id.filter(|id| *id > 0) else {
        return Ok(None);
    };
    let storyboard_uuid = crate::scope::owned_storyboard_in_script_scope(
        pool,
        user_id,
        project_id,
        script_id,
        storyboard_numeric_id,
    )
    .await
    .map_err(|e| e.into_api_error())?
    .storyboard_id;
    let row = sqlx::query_as::<_, StoryboardPromptSeedRow>(
        r#"
        SELECT prompt, video_desc, duration
        FROM app_storyboard
        WHERE id = $1
        "#,
    )
    .bind(storyboard_uuid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let current_prompt_seed = storyboard_prompt_seed(&row);
    let (memory_style_notes, continuity_notes) = load_video_prompt_memory_notes(
        pool,
        user_id,
        project_id,
        script_id,
        storyboard_numeric_id,
        current_prompt_seed.as_deref(),
        &row,
    )
    .await?;
    let project_row = sqlx::query_as::<_, ProjectPromptSeedRow>(
        r#"
        SELECT art_style, director_manual, video_ratio
        FROM app_project
        WHERE owner_user_id = $1
          AND numeric_id = $2
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let script_role_rows = sqlx::query_as::<_, ScriptRolePromptSeedRow>(
        r#"
        SELECT a.asset_type, a.name, a.describe
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id
        INNER JOIN app_script sc ON sc.id = sa.script_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND a.asset_type IN ('role', 'scene', 'tool')
        ORDER BY a.created_at DESC
        LIMIT 16
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut script_role_anchors = Vec::new();
    let mut script_scene_anchors = Vec::new();
    let mut script_tool_anchors = Vec::new();
    for row in script_role_rows {
        let Some(anchor) = compact_script_asset_anchor(row) else {
            continue;
        };
        match anchor.asset_type.as_str() {
            "role" => script_role_anchors.push(anchor.value),
            "scene" => script_scene_anchors.push(anchor.value),
            "tool" => script_tool_anchors.push(anchor.value),
            _ => {}
        }
    }

    Ok(Some(VideoPromptContext {
        storyboard_prompt: row.prompt,
        storyboard_video_desc: row.video_desc,
        storyboard_duration: row.duration,
        storyboard_prompt_seed: current_prompt_seed,
        project_art_style: project_row.as_ref().and_then(|row| row.art_style.clone()),
        project_director_manual: project_row
            .as_ref()
            .and_then(|row| row.director_manual.clone()),
        project_video_ratio: project_row.and_then(|row| row.video_ratio),
        script_role_anchors,
        script_scene_anchors,
        script_tool_anchors,
        memory_style_notes,
        continuity_notes,
    }))
}

async fn load_video_prompt_memory_notes(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
) -> Result<(Vec<String>, Vec<String>), ApiError> {
    let rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN ('selected_video_memory', 'script_video_style_memory', 'auto_scope_memory'))
            OR (episodes_id IS NULL AND name = 'project_video_style_memory')
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(VIDEO_PROMPT_MEMORY_ROW_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok((
        select_prioritized_video_style_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            Some(storyboard_row),
        ),
        select_video_prompt_memory_notes(&rows, storyboard_numeric_id, Some(storyboard_row)),
    ))
}

async fn load_pending_video_observation_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Result<Option<String>, ApiError> {
    let rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name = 'rejected_video_negative_memory'
        ORDER BY create_time_ms DESC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(select_pending_rejected_video_observation_note(
        &rows,
        storyboard_numeric_id,
        current_prompt_seed,
    )
    .map(|note| format!("待观察失败倾向：{note}")))
}

fn select_prioritized_video_style_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let selected_notes =
        select_selected_video_memory_notes(rows, storyboard_numeric_id, current_prompt_seed);
    if !selected_notes.is_empty() {
        return selected_notes;
    }

    let context = build_style_note_selection_context(storyboard_row);
    let mut candidates = collect_ranked_video_style_note_candidates(rows, storyboard_numeric_id);
    candidates.sort_by(|a, b| {
        score_ranked_style_note(b, &context)
            .cmp(&score_ranked_style_note(a, &context))
            .then(b.score.cmp(&a.score))
            .then(a.recency_idx.cmp(&b.recency_idx))
            .then(a.note.cmp(&b.note))
    });
    candidates
        .into_iter()
        .map(|candidate| compact_unique_memory_notes(vec![candidate.note]))
        .find(|notes| !notes.is_empty())
        .unwrap_or_default()
}

#[derive(Debug, Clone)]
struct StyleNoteSelectionContext {
    description: String,
    subject: String,
    setting: String,
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
        setting: fields
            .as_ref()
            .map(|value| normalize_prompt_text(&value.setting))
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
) -> Vec<RankedStyleNote> {
    let mut candidates = Vec::new();
    for (idx, row) in rows.iter().enumerate() {
        let (base_score, note) = match row.name.as_str() {
            "selected_video_memory" => {
                if !memory_row_is_neighbor_selected_style(row, storyboard_numeric_id) {
                    continue;
                }
                (120, extract_style_note_value(row))
            }
            "script_video_style_memory" => (90, extract_style_note_value(row)),
            "project_video_style_memory" => (70, extract_style_note_value(row)),
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
        });
    }
    candidates
}

fn memory_row_is_neighbor_selected_style(row: &AgentMemoryRow, storyboard_numeric_id: i32) -> bool {
    let storyboard_ids = row
        .content
        .split("storyboardIds=")
        .skip(1)
        .filter_map(|part| {
            let raw = part
                .chars()
                .take_while(|ch| ch.is_ascii_digit() || *ch == ',' || ch.is_ascii_whitespace())
                .collect::<String>();
            let ids = raw
                .split(',')
                .filter_map(|part| part.trim().parse::<i32>().ok())
                .filter(|value| *value > 0)
                .collect::<Vec<_>>();
            (!ids.is_empty()).then_some(ids)
        })
        .flatten()
        .collect::<Vec<_>>();
    !storyboard_ids.is_empty() && !storyboard_ids.contains(&storyboard_numeric_id)
}

fn extract_style_note_value(row: &AgentMemoryRow) -> Option<String> {
    extract_key_value(&row.content, "style")
        .or_else(|| extract_key_value(&row.content, "note"))
        .map(|value| {
            let fragments = value
                .split('，')
                .map(normalize_prompt_text)
                .filter(|fragment| !fragment.is_empty())
                .filter(|fragment| style_fragment_prefix(fragment))
                .collect::<Vec<_>>();
            if fragments.is_empty() {
                clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
            } else {
                clip_prompt_fragment(&fragments.join("，"), VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
            }
        })
        .filter(|value| !value.is_empty())
}

fn score_ranked_style_note(note: &RankedStyleNote, context: &StyleNoteSelectionContext) -> i32 {
    let mut score = note.score - note.recency_idx as i32;
    for fragment in note.note.split('，').map(normalize_prompt_text) {
        if fragment.is_empty() {
            continue;
        }
        if !context.setting.is_empty()
            && fragment.starts_with("场景")
            && fragment.contains(&context.setting)
        {
            score += 28;
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

fn compact_unique_memory_notes(notes: Vec<String>) -> Vec<String> {
    let mut fragments = Vec::new();
    for note in notes {
        for fragment in note.split('，').map(normalize_prompt_text) {
            if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
                continue;
            }
            fragments.push(fragment);
        }
    }
    pack_memory_fragments(
        fragments,
        VIDEO_PROMPT_MEMORY_NOTE_LIMIT,
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    )
}

fn pack_memory_fragments(fragments: Vec<String>, limit: usize, max_chars: usize) -> Vec<String> {
    if limit == 0 || max_chars == 0 {
        return Vec::new();
    }

    let mut packed = Vec::new();
    let mut current = Vec::new();
    let mut current_len = 0usize;

    for fragment in fragments {
        let fragment = clip_prompt_fragment(&fragment, max_chars);
        if fragment.is_empty() {
            continue;
        }
        let fragment_len = fragment.chars().count();
        let candidate_len = if current.is_empty() {
            fragment_len
        } else {
            current_len + 1 + fragment_len
        };

        if !current.is_empty() && candidate_len > max_chars {
            packed.push(current.join("，"));
            if packed.len() >= limit {
                return packed;
            }
            current = vec![fragment];
            current_len = fragment_len;
            continue;
        }

        current.push(fragment);
        current_len = candidate_len;
    }

    if !current.is_empty() && packed.len() < limit {
        packed.push(current.join("，"));
    }

    packed
}

fn build_video_prompt(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> String {
    let mut clauses = Vec::new();
    clauses.push("Single cinematic shot.".to_string());

    let resolved_description = resolve_video_prompt_description(description, context);
    let structured_fields = resolved_description
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    let role_anchors = build_script_role_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
    );
    if !role_anchors.is_empty() {
        clauses.push(format!("Character anchor: {}.", role_anchors.join("; ")));
    }
    let scene_anchors = build_script_scene_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
    );
    if !scene_anchors.is_empty() {
        clauses.push(format!("Scene anchor: {}.", scene_anchors.join("; ")));
    }
    let tool_anchors = build_script_tool_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
    );
    if !tool_anchors.is_empty() {
        clauses.push(format!("Prop anchor: {}.", tool_anchors.join("; ")));
    }
    let mut prompt_coverage = collect_prompt_coverage(structured_fields.as_ref());
    extend_prompt_coverage(&mut prompt_coverage, &role_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &scene_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &tool_anchors);
    match structured_fields.as_ref() {
        Some(fields) => {
            if !fields.subject.is_empty() {
                clauses.push(format!(
                    "Subject: {}.",
                    clip_prompt_fragment(&fields.subject, 72)
                ));
            }
            if !fields.setting.is_empty() {
                clauses.push(format!(
                    "Setting: {}.",
                    clip_prompt_fragment(&fields.setting, 48)
                ));
            }
            if !fields.action.is_empty() {
                clauses.push(format!(
                    "Action: {}.",
                    clip_prompt_fragment(&fields.action, 72)
                ));
            }
            let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
                .into_iter()
                .filter(|part| !part.is_empty())
                .collect::<Vec<_>>()
                .join(", ");
            if !camera.is_empty() {
                clauses.push(format!("Camera: {}.", clip_prompt_fragment(&camera, 40)));
            }
            if !fields.mood.is_empty() {
                clauses.push(format!("Mood: {}.", clip_prompt_fragment(&fields.mood, 36)));
            }
            if !fields.lighting.is_empty() {
                clauses.push(format!(
                    "Lighting: {}.",
                    clip_prompt_fragment(&fields.lighting, 44)
                ));
            }
            if !fields.dialogue.is_empty() && !looks_like_silence(&fields.dialogue) {
                clauses.push(format!(
                    "Dialogue or voice-over: {}.",
                    clip_prompt_fragment(&fields.dialogue, 60)
                ));
            }
            if !fields.sound.is_empty() && !looks_like_silence(&fields.sound) {
                clauses.push(format!(
                    "Sound: {}.",
                    clip_prompt_fragment(&fields.sound, 44)
                ));
            }
        }
        None => {
            let fallback = resolved_description
                .filter(|text| !text.is_empty())
                .unwrap_or_else(|| "Clear subject, natural motion, stable continuity.".to_string());
            clauses.push(format!("Scene: {}.", clip_prompt_fragment(&fallback, 160)));
        }
    }

    let style_anchors =
        build_project_visual_anchors(context, structured_fields.as_ref(), &prompt_coverage);
    if !style_anchors.is_empty() {
        let mut style_clause = vec![format!("Style anchor: {}.", style_anchors.join("; "))];
        if let Some(ratio) = context
            .and_then(|ctx| ctx.project_video_ratio.as_deref())
            .and_then(format_video_ratio_hint)
        {
            style_clause.push(format!("Format: {ratio}."));
        }
        clauses.push(style_clause.join(" "));
    }
    extend_prompt_coverage(&mut prompt_coverage, &style_anchors);
    let continuity_notes =
        build_continuity_notes(context, structured_fields.as_ref(), &prompt_coverage);
    if !continuity_notes.is_empty() {
        clauses.push(format!(
            "Continuity notes: {}.",
            continuity_notes.join("; ")
        ));
    }
    if image_url.is_some() {
        clauses.push("Use the supplied frame as the visual reference.".to_string());
    }
    clauses.push("Natural motion, stable continuity, no extra shot changes.".to_string());
    clauses.join(" ")
}

fn resolve_video_prompt_description(
    description: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> Option<String> {
    let description = description
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty());
    if description.is_some() {
        return description;
    }
    context.and_then(|ctx| {
        ctx.storyboard_video_desc
            .as_deref()
            .map(normalize_prompt_text)
            .filter(|text| !text.is_empty())
            .or_else(|| {
                ctx.storyboard_prompt
                    .as_deref()
                    .map(normalize_prompt_text)
                    .filter(|text| !text.is_empty())
            })
    })
}

fn build_project_visual_anchors(
    context: Option<&VideoPromptContext>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };

    let mut anchors = Vec::new();
    let mut style_coverage = prompt_coverage.to_vec();
    if let Some(style) = ctx
        .project_art_style
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty())
    {
        anchors.push(clip_prompt_fragment(&style, 32));
        extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
    }
    if let Some(note) = ctx
        .project_director_manual
        .as_deref()
        .and_then(|value| compact_project_director_note(value, structured_fields))
    {
        anchors.push(note);
        extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
    }
    for note in &ctx.memory_style_notes {
        let Some(note) = compact_memory_style_anchor(note, structured_fields, &style_coverage)
        else {
            continue;
        };
        if anchors.iter().any(|existing| existing == &note) {
            continue;
        }
        extend_prompt_coverage(&mut style_coverage, std::slice::from_ref(&note));
        anchors.push(note);
        break;
    }
    anchors
}

fn compact_memory_style_anchor(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let expected_camera = structured_fields.map(|fields| {
        [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>()
    });
    let fragments = normalized
        .split('，')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| style_fragment_prefix(fragment))
        .filter(|fragment| {
            if let (Some(fields), Some(camera)) = (structured_fields, expected_camera.as_deref()) {
                if continuity_fragment_matches_fields(fragment, fields, camera) {
                    return false;
                }
            }
            !prompt_fragment_is_covered(fragment, prompt_coverage)
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

fn style_fragment_prefix(fragment: &str) -> bool {
    ["镜头", "情绪", "光影", "场景"]
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
}

fn build_script_role_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_role_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let subject = structured_fields
        .map(|fields| normalize_prompt_text(&fields.subject))
        .unwrap_or_default();
    let mut anchors = Vec::new();
    for anchor in &ctx.script_role_anchors {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let subject_matches =
            !subject.is_empty() && (subject.contains(&name) || name.contains(&subject));
        if name.is_empty() || (!description.contains(&name) && !subject_matches) {
            continue;
        }
        let candidate = format!("{name}:{}", note.trim());
        if anchors.iter().any(|existing| existing == &candidate) {
            continue;
        }
        anchors.push(candidate);
        if anchors.len() >= 2 {
            break;
        }
    }
    anchors
}

fn build_script_scene_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_scene_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let setting = structured_fields
        .map(|fields| normalize_prompt_text(&fields.setting))
        .unwrap_or_default();
    let mut anchors = Vec::new();
    for anchor in &ctx.script_scene_anchors {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let setting_matches =
            !setting.is_empty() && (setting.contains(&name) || name.contains(&setting));
        if name.is_empty() || (!description.contains(&name) && !setting_matches) {
            continue;
        }
        let candidate = format!("{name}:{}", note.trim());
        if anchors.iter().any(|existing| existing == &candidate) {
            continue;
        }
        anchors.push(candidate);
        if !anchors.is_empty() {
            break;
        }
    }
    anchors
}

fn build_script_tool_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Vec<String> {
    let Some(ctx) = context else {
        return Vec::new();
    };
    if ctx.script_tool_anchors.is_empty() {
        return Vec::new();
    }

    let description = description.map(normalize_prompt_text).unwrap_or_default();
    let subject = structured_fields
        .map(|fields| normalize_prompt_text(&fields.subject))
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let mut anchors = Vec::new();
    for anchor in &ctx.script_tool_anchors {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let structured_match = (!subject.is_empty()
            && (subject.contains(&name) || name.contains(&subject)))
            || (!action.is_empty() && action.contains(&name));
        if name.is_empty() || (!description.contains(&name) && !structured_match) {
            continue;
        }
        let candidate = format!("{name}:{}", note.trim());
        if anchors.iter().any(|existing| existing == &candidate) {
            continue;
        }
        anchors.push(candidate);
        if !anchors.is_empty() {
            break;
        }
    }
    anchors
}

fn build_continuity_notes(
    context: Option<&VideoPromptContext>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Vec<String> {
    let mut notes = context
        .map(|ctx| {
            ctx.continuity_notes
                .iter()
                .filter_map(|note| {
                    compact_continuity_note(note, structured_fields, prompt_coverage)
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    notes.sort_by(|a, b| {
        score_continuity_note(b, structured_fields)
            .cmp(&score_continuity_note(a, structured_fields))
            .then(a.len().cmp(&b.len()))
            .then(a.cmp(b))
    });
    notes.truncate(VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT);
    notes
}

fn compact_continuity_note(
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

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let fragments = normalized
        .split('，')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            !continuity_fragment_matches_fields(fragment, fields, &expected_camera)
                && !prompt_fragment_is_covered(fragment, prompt_coverage)
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

fn collect_prompt_coverage(
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Vec<String> {
    let Some(fields) = structured_fields else {
        return Vec::new();
    };
    let camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>()
        .join(", ");
    [
        fields.subject.as_str(),
        fields.action.as_str(),
        fields.setting.as_str(),
        fields.mood.as_str(),
        fields.lighting.as_str(),
        camera.as_str(),
    ]
    .into_iter()
    .map(normalize_prompt_text)
    .filter(|fragment| !fragment.is_empty())
    .collect()
}

fn extend_prompt_coverage(target: &mut Vec<String>, anchors: &[String]) {
    for anchor in anchors {
        for fragment in expand_prompt_coverage_fragments(anchor) {
            if target.iter().any(|existing| existing == &fragment) {
                continue;
            }
            target.push(fragment);
        }
    }
}

fn expand_prompt_coverage_fragments(anchor: &str) -> Vec<String> {
    let mut fragments = Vec::new();
    for fragment in anchor
        .split([':', '：', ';', '；', ',', '，'])
        .map(normalize_prompt_text)
    {
        if fragment.is_empty() || fragments.iter().any(|existing| existing == &fragment) {
            continue;
        }
        fragments.push(fragment);
    }
    fragments
}

fn prompt_fragment_is_covered(fragment: &str, coverage: &[String]) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }
    coverage.iter().any(|existing| {
        let canonical_existing = canonical_prompt_fragment(existing);
        if canonical_existing.is_empty() {
            return false;
        }
        canonical_existing == canonical_fragment
            || (canonical_fragment.chars().count() >= 4
                && canonical_existing.contains(&canonical_fragment))
            || (canonical_existing.chars().count() >= 4
                && canonical_fragment.contains(&canonical_existing))
    })
}

fn canonical_prompt_fragment(fragment: &str) -> String {
    normalize_prompt_text(fragment)
        .trim_matches(|ch: char| {
            ch.is_whitespace() || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，' | '.' | '。')
        })
        .to_string()
}

fn compact_project_director_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Option<String> {
    let expected_camera = structured_fields.map(|fields| {
        [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>()
    });
    let mut fragments = Vec::new();
    for fragment in note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
    {
        if fragment.is_empty()
            || fragments.iter().any(|existing| existing == &fragment)
            || !project_director_fragment_relevant(&fragment)
        {
            continue;
        }
        if let (Some(fields), Some(camera)) = (structured_fields, expected_camera.as_deref()) {
            if continuity_fragment_matches_fields(&fragment, fields, camera)
                || fragment == fields.mood
                || fragment == fields.lighting
                || fragment == fields.setting
            {
                continue;
            }
        }
        fragments.push(fragment);
        if fragments.len() >= 2 {
            break;
        }
    }
    if fragments.is_empty() {
        return None;
    }
    Some(clip_prompt_fragment(&fragments.join(", "), 48))
}

struct ScriptAssetPromptAnchor {
    asset_type: String,
    value: String,
}

fn compact_script_asset_anchor(row: ScriptRolePromptSeedRow) -> Option<ScriptAssetPromptAnchor> {
    let asset_type = normalize_prompt_text(&row.asset_type).to_lowercase();
    let max_chars = match asset_type.as_str() {
        "role" => 24,
        "scene" => 22,
        "tool" => 20,
        _ => return None,
    };
    let name = row
        .name
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty())?;
    let describe = row
        .describe
        .as_deref()
        .map(normalize_prompt_text)
        .filter(|text| !text.is_empty())
        .map(|text| clip_prompt_fragment(&text, max_chars))
        .unwrap_or_else(|| match asset_type.as_str() {
            "role" => "视觉设定延续".to_string(),
            "scene" => "场景设定延续".to_string(),
            "tool" => "道具设定延续".to_string(),
            _ => String::new(),
        });
    Some(ScriptAssetPromptAnchor {
        asset_type,
        value: format!("{name}: {describe}"),
    })
}

fn project_director_fragment_relevant(fragment: &str) -> bool {
    [
        "镜头",
        "构图",
        "机位",
        "运镜",
        "景别",
        "光",
        "色",
        "色调",
        "质感",
        "氛围",
        "节奏",
        "场景",
        "情绪",
        "风格",
        "统一",
        "连续",
        "延续",
        "保持",
        "camera",
        "lighting",
        "mood",
        "style",
        "tone",
        "frame",
        "composition",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

fn format_video_ratio_hint(value: &str) -> Option<String> {
    let normalized = normalize_prompt_text(value).replace(' ', "");
    match normalized.as_str() {
        "" => None,
        "9:16" => Some("vertical 9:16".to_string()),
        "16:9" => Some("horizontal 16:9".to_string()),
        "1:1" => Some("square 1:1".to_string()),
        _ => Some(clip_prompt_fragment(&normalized, 16)),
    }
}

fn continuity_fragment_matches_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    let canonical = canonical_continuity_fragment(fragment);
    if canonical.is_empty() {
        return false;
    }
    canonical == fields.subject
        || canonical == fields.action
        || (!expected_camera.is_empty()
            && (canonical == expected_camera
                || canonical == fields.shot
                || canonical == fields.camera_move
                || (!fields.shot.is_empty() && canonical.contains(&fields.shot))
                || (!fields.camera_move.is_empty() && canonical.contains(&fields.camera_move))))
        || (!fields.mood.is_empty() && canonical == fields.mood)
        || (!fields.lighting.is_empty() && canonical == fields.lighting)
        || (!fields.setting.is_empty() && canonical == fields.setting)
}

fn canonical_continuity_fragment(fragment: &str) -> String {
    let mut canonical = normalize_prompt_text(fragment);
    loop {
        let mut changed = false;
        for prefix in [
            "保持上一镜头",
            "延续上一镜头",
            "保留上一镜头",
            "保持",
            "延续",
            "保留",
            "镜头",
            "情绪",
            "光影",
            "场景",
        ] {
            if let Some(stripped) = canonical.strip_prefix(prefix) {
                canonical = stripped
                    .trim_start_matches(|ch: char| {
                        ch.is_whitespace() || matches!(ch, ':' | '：' | ';' | '；' | ',' | '，')
                    })
                    .to_string();
                changed = true;
                break;
            }
        }
        if !changed {
            break;
        }
    }
    canonical
}

fn resolve_video_prompt_duration(
    duration_hint: Option<i32>,
    description: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> i32 {
    if let Some(value) = duration_hint.filter(|value| *value > 0) {
        return value.clamp(2, 16);
    }
    if let Some(parsed) = resolve_video_prompt_description(description, context)
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .and_then(|fields| fields.duration_seconds)
    {
        return parsed.clamp(2, 16);
    }
    if let Some(parsed) = context
        .and_then(|ctx| ctx.storyboard_duration.as_deref())
        .and_then(parse_positive_int)
    {
        return parsed.clamp(2, 16);
    }
    5
}

fn looks_like_silence(text: &str) -> bool {
    let normalized = text.trim().to_lowercase();
    normalized.is_empty()
        || normalized == "无"
        || normalized == "无台词"
        || normalized == "无音效"
        || normalized == "none"
        || normalized == "no dialogue"
        || normalized == "no sound"
}

fn select_video_prompt_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let structured_fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    let mut scored = rows
        .iter()
        .filter_map(|row| {
            if row.name != "auto_scope_memory" {
                return None;
            }
            let content = row.content.as_str();
            let tool = extract_key_value(content, "tool")?;
            if !matches!(
                tool.as_str(),
                "run_sub_agent_storyboard_panel"
                    | "run_sub_agent_storyboard_gen"
                    | "run_sub_agent_production_supervision"
                    | "run_sub_agent_director_plan"
            ) {
                return None;
            }
            let score = memory_storyboard_overlap_score(content, storyboard_numeric_id);
            if score <= 0 {
                return None;
            }
            let note = extract_key_value(content, "summary")
                .or_else(|| extract_key_value(content, "result"))
                .and_then(|value| compact_video_continuity_note(&value))
                .or_else(|| {
                    extract_key_value(content, "summary")
                        .or_else(|| extract_key_value(content, "result"))
                        .map(|value| {
                            clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
                        })
                })?;
            let continuity_score = score_continuity_note(&note, structured_fields.as_ref());
            Some((score + continuity_score, continuity_score, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.0.cmp(&a.0)
            .then(b.1.cmp(&a.1))
            .then(a.2.len().cmp(&b.2.len()))
            .then(a.2.cmp(&b.2))
    });

    let mut notes = Vec::new();
    for (_, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT {
            break;
        }
    }
    notes
}

fn score_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> i32 {
    let mut score = 0;
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return score;
    }
    for fragment in normalized.split('，').map(normalize_prompt_text) {
        if fragment.is_empty() {
            continue;
        }
        if fragment.contains("上一镜头") {
            score += 24;
        }
        if [
            "走位", "站位", "方向", "构图", "衔接", "连续", "延续", "保持", "统一",
        ]
        .iter()
        .any(|keyword| fragment.contains(keyword))
        {
            score += 12;
        }
        if ["镜头", "情绪", "光影", "场景"]
            .iter()
            .any(|prefix| fragment.starts_with(prefix))
        {
            score += 2;
        }
    }

    if let Some(fields) = structured_fields {
        let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>();
        for fragment in normalized.split('，').map(normalize_prompt_text) {
            if fragment.is_empty() {
                continue;
            }
            if continuity_fragment_matches_fields(&fragment, fields, &expected_camera) {
                score -= 8;
            }
        }
    }

    score
}

fn memory_storyboard_overlap_score(row: &str, storyboard_numeric_id: i32) -> i32 {
    if storyboard_numeric_id <= 0 {
        return 0;
    }
    let key = "storyboardIds";
    let mut remainder = row;
    let mut score = 0;
    while let Some(found) = remainder.find(key) {
        let next = &remainder[found + key.len()..];
        let Some(after_equal) = next.strip_prefix('=') else {
            remainder = next;
            continue;
        };
        let ids = parse_csv_positive_ints(after_equal);
        if ids.contains(&storyboard_numeric_id) {
            score += 10;
        }
        remainder = after_equal;
    }
    score
}

fn parse_csv_positive_ints(text: &str) -> Vec<i32> {
    let raw = text
        .chars()
        .take_while(|ch| ch.is_ascii_digit() || *ch == ',' || ch.is_ascii_whitespace())
        .collect::<String>();
    raw.split(',')
        .filter_map(|part| part.trim().parse::<i32>().ok())
        .filter(|value| *value > 0)
        .collect()
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct VideoModelDetailResponse {
    model_id: String,
    model_name: String,
    provider: String,
    max_duration: i32,
    resolutions: Vec<String>,
    features: Vec<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/get-video-model-detail",
    operation_id = "postProductionWorkbenchGetVideoModelDetailV1",
    tag = "production",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(in crate::production) async fn post_workbench_get_video_model_detail(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<JsonResponse<VideoModelDetailResponse>, ApiError> {
    require_authenticated(&state, &headers)?;

    Ok(JsonResponse(VideoModelDetailResponse {
        model_id: "gen-2".to_string(),
        model_name: "Gen-2".to_string(),
        provider: "runway".to_string(),
        max_duration: 16,
        resolutions: vec!["720p".to_string(), "1080p".to_string()],
        features: vec![
            "text-to-video".to_string(),
            "image-to-video".to_string(),
            "motion-brush".to_string(),
        ],
    }))
}

#[cfg(test)]
mod tests {
    use super::{
        build_video_prompt, parse_structured_storyboard_description, resolve_video_prompt_duration,
        select_prioritized_video_style_notes, select_video_prompt_memory_notes,
        GenerateVideoPromptResponse, VideoPromptContext,
    };
    use crate::production::workbench::video_prompt_memory::{
        select_neighbor_selected_video_memory_notes, select_project_video_style_memory_notes,
        select_script_video_style_memory_notes, AgentMemoryRow, StoryboardPromptSeedRow,
    };

    #[test]
    fn build_video_prompt_compacts_structured_storyboard_description() {
        let prompt = build_video_prompt(
            Some("（主角独立城楼远眺苍茫大地、城楼、主角/城楼、4s、全景、缓慢推进、负手而立衣袂翻飞、坚定压抑、黄昏冷调侧逆光、无台词、风声衣袂声、A001/A003）"),
            Some("https://example.com/frame.png"),
            None,
        );

        assert!(prompt.contains("Single cinematic shot."));
        assert!(prompt.contains("Subject: 主角独立城楼远眺苍茫大地."));
        assert!(prompt.contains("Camera: 全景, 缓慢推进."));
        assert!(prompt.contains("Use the supplied frame as the visual reference."));
        assert!(!prompt.contains("A001/A003"));
    }

    #[test]
    fn parse_structured_storyboard_description_extracts_duration() {
        let fields = parse_structured_storyboard_description(
            "（雨夜街角对峙、旧街、主角/反派、6秒、中景、手持跟拍、彼此逼近、紧张、霓虹潮湿反光、你终于来了、雨声脚步声、A1/A2）",
        )
        .expect("structured description");

        assert_eq!(fields.duration_seconds, Some(6));
        assert_eq!(fields.setting, "旧街");
        assert_eq!(fields.dialogue, "你终于来了");
    }

    #[test]
    fn resolve_video_prompt_duration_prefers_hint_then_description_then_default() {
        assert_eq!(
            resolve_video_prompt_duration(
                Some(8),
                Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
                None,
            ),
            8
        );
        assert_eq!(
            resolve_video_prompt_duration(
                None,
                Some("（主角、城楼、主角、4s、全景、静止、站立、冷峻、冷光、无台词、风声、A1）"),
                None,
            ),
            4
        );
        assert_eq!(
            resolve_video_prompt_duration(None, Some("普通描述"), None),
            5
        );
    }

    #[test]
    fn build_video_prompt_uses_storyboard_context_and_memory_notes() {
        let context = VideoPromptContext {
            storyboard_prompt: Some("主角转身冲向门外".into()),
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头已确认的冷调压迫感".into()],
        };
        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Subject: 主角冲出旧宅."));
        assert!(prompt.contains("Dialogue or voice-over: 别回头."));
        assert!(prompt.contains("Continuity notes: 保持上一镜头已确认的冷调压迫感."));
    }

    #[test]
    fn build_video_prompt_deduplicates_structured_memory_fragments() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角冲出旧宅，镜头中景稳定跟拍，情绪急迫，光影阴天冷光，场景旧宅走廊".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(!prompt.contains("Continuity notes:"));
        assert_eq!(prompt.matches("Subject: 主角冲出旧宅.").count(), 1);
    }

    #[test]
    fn build_video_prompt_keeps_only_non_duplicate_continuity_fragments() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角冲出旧宅，镜头中景稳定跟拍，情绪急迫，保持上一镜头压迫感".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Continuity notes: 保持上一镜头压迫感."));
        assert!(!prompt.contains("镜头中景稳定跟拍，情绪急迫"));
    }

    #[test]
    fn build_video_prompt_promotes_memory_style_notes_into_style_anchor() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感，情绪冷色压迫感".into()],
            continuity_notes: vec!["保持上一镜头走位连续".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 镜头低机位压迫感，情绪冷色压迫感."));
        assert!(prompt.contains("Continuity notes: 保持上一镜头走位连续."));
        assert!(!prompt.contains("Continuity notes: 镜头低机位压迫感"));
    }

    #[test]
    fn build_video_prompt_trims_memory_style_fragments_already_covered_by_prompt() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，场景旧宅走廊，情绪冷峻压迫".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt
            .contains("Style anchor: 胶片冷调悬疑; 保持低机位压迫感, 镜头衔接统一; 情绪冷峻压迫."));
        assert!(!prompt.contains("镜头稳定跟拍"));
        assert!(!prompt.contains("场景旧宅走廊"));
    }

    #[test]
    fn build_video_prompt_skips_memory_style_anchor_when_fully_covered() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持稳定跟拍，镜头衔接统一".into()),
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，场景旧宅走廊".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 镜头衔接统一."));
        assert!(!prompt.contains("场景旧宅走廊"));
    }

    #[test]
    fn resolve_video_prompt_duration_falls_back_to_storyboard_context() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: None,
            storyboard_duration: Some("7 秒".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };
        assert_eq!(resolve_video_prompt_duration(None, None, Some(&context)), 7);
    }

    #[test]
    fn build_video_prompt_adds_compact_project_visual_anchor() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一，光影偏冷".into()),
            project_video_ratio: Some("9:16".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 保持低机位压迫感, 镜头衔接统一."));
        assert!(prompt.contains("Format: vertical 9:16."));
        assert!(!prompt.contains("光影偏冷"));
    }

    #[test]
    fn build_video_prompt_adds_matching_script_role_anchor() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: vec![
                "主角: 黑色风衣，短发，克制冷峻".into(),
                "路人: 灰色外套".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
        assert!(!prompt.contains("路人:灰色外套"));
    }

    #[test]
    fn build_video_prompt_adds_matching_scene_and_tool_anchors() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            project_video_ratio: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "街角: 雨夜霓虹".into(),
            ],
            script_tool_anchors: vec![
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
                "雨伞: 黑伞".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
        assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
        assert!(!prompt.contains("街角:雨夜霓虹"));
        assert!(!prompt.contains("雨伞:黑伞"));
    }

    #[test]
    fn build_video_prompt_skips_continuity_fragments_already_covered_by_anchors() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            project_video_ratio: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "黑色风衣，冷色长廊，刀身旧磨损，保持低机位压迫感，保留上一镜头走位连续"
                    .into(),
            ],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
        assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
        assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
        assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 保持低机位压迫感, 镜头衔接统一."));
        assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续."));
        assert!(!prompt.contains("Continuity notes: 黑色风衣"));
        assert!(!prompt.contains("Continuity notes: 冷色长廊"));
        assert!(!prompt.contains("Continuity notes: 刀身旧磨损"));
        assert!(!prompt.contains("Continuity notes: 保持低机位压迫感"));
    }

    #[test]
    fn build_video_prompt_keeps_single_strongest_continuity_note() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感，镜头衔接统一".into()),
            project_video_ratio: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec![
                "黑色风衣，冷色长廊，刀身旧磨损，保持低机位压迫感".into(),
                "保留上一镜头走位连续，人物站位不要跳轴".into(),
            ],
        };

        let prompt = build_video_prompt(None, None, Some(&context));
        let continuity_clause = prompt
            .split("Continuity notes: ")
            .nth(1)
            .and_then(|value| value.split('.').next())
            .unwrap_or("");

        assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续，人物站位不要跳轴."));
        assert_eq!(prompt.matches("Continuity notes:").count(), 1);
        assert!(!continuity_clause.contains("保持低机位压迫感"));
    }

    #[test]
    fn select_video_prompt_memory_notes_keeps_only_matching_storyboard_entries() {
        let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=女主转身回望，保持女主冷色调近景".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=补图时主角冲向巷口，保持镜头方向连续".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=7 | review=target=storyboardTable; summary=别的镜头".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_derive_assets | scope=storyboardIds=12 | result=无关素材".to_string(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、紧张、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, Some(&storyboard_row)),
            vec!["保持镜头方向连续".to_string()]
        );
    }

    #[test]
    fn neighbor_selected_video_memory_notes_use_only_style_fragments_before_auto_scope_fallback() {
        let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | note=女主贴墙前行，镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=次级摘要".to_string(),
            },
        ];

        assert_eq!(
            select_neighbor_selected_video_memory_notes(&rows, 12, 2),
            vec!["镜头稳定近景，情绪冷色压迫感".to_string()]
        );
    }

    #[test]
    fn script_video_style_memory_is_available_before_auto_scope_fallback() {
        let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | note=镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=次级摘要".to_string(),
            },
        ];

        assert_eq!(
            select_script_video_style_memory_notes(&rows),
            vec!["镜头中景稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string()]
        );
    }

    #[test]
    fn project_video_style_memory_is_available_before_auto_scope_fallback() {
        let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=6 | style=镜头中景稳定跟拍，情绪冷峻压迫 | note=镜头中景稳定跟拍，情绪冷峻压迫".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=次级摘要".to_string(),
            },
        ];

        assert_eq!(
            select_project_video_style_memory_notes(&rows),
            vec!["镜头中景稳定跟拍，情绪冷峻压迫".to_string()]
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_prefers_single_best_matching_style_note() {
        let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=女主贴墙前行，镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊 | note=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=保持角色站位".to_string(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷色压迫感、冷调逆光、别回头、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_prioritized_video_style_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["情绪冷色压迫感，光影冷调逆光，场景旧宅走廊".to_string()]
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_keeps_exact_storyboard_selection_exclusive() {
        let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | style=镜头低机位压迫感，情绪克制 | note=镜头低机位压迫感，情绪克制".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=3 | style=光影冷调逆光，场景旧宅走廊 | note=光影冷调逆光，场景旧宅走廊".into(),
            },
        ];

        assert_eq!(
            select_prioritized_video_style_notes(&rows, 12, None, None),
            vec!["镜头低机位压迫感，情绪克制".to_string()]
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_prefers_more_recent_neighbor_when_context_is_missing() {
        let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=镜头稳定近景，情绪冷色压迫感".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=6 | style=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊 | note=情绪冷色压迫感，光影冷调逆光，场景旧宅走廊".into(),
            },
        ];

        assert_eq!(
            select_prioritized_video_style_notes(&rows, 12, None, None),
            vec!["镜头稳定近景，情绪冷色压迫感".to_string()]
        );
    }

    #[test]
    fn generate_video_prompt_response_serializes_observation_note() {
        let value = serde_json::to_value(GenerateVideoPromptResponse {
            prompt: "Single cinematic shot.".into(),
            negative_prompt: None,
            observation_note: Some("待观察失败倾向：avoid shaky handheld motion".into()),
            model: "runway-gen-2".into(),
            duration: 5,
        })
        .expect("serialize response");

        assert_eq!(
            value
                .get("observationNote")
                .and_then(serde_json::Value::as_str),
            Some("待观察失败倾向：avoid shaky handheld motion")
        );
    }
}
