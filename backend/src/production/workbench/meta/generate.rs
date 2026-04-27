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
    clip_prompt_fragment, extract_key_value, negative_constraint_conflicts_with_storyboard_style,
    normalize_prompt_text, parse_positive_int, parse_structured_storyboard_description,
    StructuredStoryboardDescription,
};
use crate::production::workbench::video::generate::load_auto_negative_prompt;
use crate::production::workbench::video_prompt_memory::{
    compact_video_continuity_note, compact_video_style_prompt_note,
    select_pending_rejected_video_observation_candidates, select_prioritized_video_style_note,
    select_project_video_style_memory_notes, select_script_video_style_memory_notes,
    select_selected_video_memory_notes, storyboard_prompt_seed, AgentMemoryRow,
    StoryboardPromptSeedRow,
};
use crate::scope::http::require_authenticated;
use crate::scope::http::require_owned_numeric_script_scope_user_pool;
use crate::state::AppState;

const VIDEO_PROMPT_MEMORY_ROW_LIMIT: i64 = 24;
const VIDEO_PROMPT_SELECTED_MEMORY_ROW_LIMIT: usize = 6;
const VIDEO_PROMPT_AUTO_SCOPE_MEMORY_ROW_LIMIT: usize = 6;
const VIDEO_PROMPT_SCRIPT_STYLE_MEMORY_ROW_LIMIT: usize = 1;
const VIDEO_PROMPT_PROJECT_STYLE_MEMORY_ROW_LIMIT: usize = 1;
const VIDEO_PROMPT_OBSERVATION_FETCH_ROW_LIMIT: i64 = 24;
const VIDEO_PROMPT_OBSERVATION_REJECTION_ROW_LIMIT: usize = 8;
const VIDEO_PROMPT_OBSERVATION_SCRIPT_STYLE_ROW_LIMIT: usize = 1;
const VIDEO_PROMPT_OBSERVATION_PROJECT_STYLE_ROW_LIMIT: usize = 1;
const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;
const VIDEO_PROMPT_CONTINUITY_NOTE_LIMIT: usize = 1;
const VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT: usize = 6;
const VIDEO_PROMPT_SCENE_ASSET_ROW_LIMIT: usize = 6;
const VIDEO_PROMPT_TOOL_ASSET_ROW_LIMIT: usize = 6;
const VIDEO_PROMPT_MULTI_ROLE_ANCHOR_LIMIT: usize = 2;
const VIDEO_PROMPT_MULTI_SCENE_ANCHOR_LIMIT: usize = 2;
const VIDEO_PROMPT_MULTI_TOOL_ANCHOR_LIMIT: usize = 2;
const ACTION_OBJECT_PREFIX_VERBS: [&str; 10] = [
    "握紧", "拿着", "提着", "举着", "攥着", "扶住", "抱着", "拖着", "背着", "扛着",
];
const ACTION_SUBJECT_PREFIXES: [&str; 10] = [
    "主角", "女主", "男主", "反派", "女孩", "男孩", "女人", "男人", "老人", "孩子",
];
const SETTING_SUBJECT_LEAD_IN_SUFFIXES: [&str; 10] = [
    "身后的",
    "身后",
    "旁边的",
    "旁的",
    "旁边",
    "面前的",
    "前的",
    "后的",
    "所在的",
    "附近的",
];
const PROMPT_LEADING_BRIDGES: [&str; 7] = ["在", "于", "向", "朝", "往", "从", "自"];

fn split_prompt_note_fragments(note: &str) -> impl Iterator<Item = String> + '_ {
    note.split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
}

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
    diagnostics: GenerateVideoPromptDiagnostics,
    model: String,
    duration: i32,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct GenerateVideoPromptDiagnostics {
    prompt_chars: usize,
    negative_prompt_chars: usize,
    observation_note_chars: usize,
    role_anchor_count: usize,
    scene_anchor_count: usize,
    tool_anchor_count: usize,
    style_anchor_count: usize,
    continuity_note_count: usize,
    uses_reference_frame: bool,
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

    let prompt_result = build_video_prompt_with_diagnostics(
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

    let diagnostics = prompt_result
        .diagnostics
        .with_runtime_notes(negative_prompt.as_deref(), observation_note.as_deref());

    Ok(JsonResponse(GenerateVideoPromptResponse {
        prompt: prompt_result.prompt,
        negative_prompt,
        observation_note,
        diagnostics,
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
    script_role_anchors: Vec<String>,
    script_scene_anchors: Vec<String>,
    script_tool_anchors: Vec<String>,
    memory_style_notes: Vec<String>,
    continuity_notes: Vec<String>,
}

#[derive(Debug)]
struct VideoPromptBuildResult {
    prompt: String,
    diagnostics: GenerateVideoPromptDiagnostics,
}

impl GenerateVideoPromptDiagnostics {
    fn with_runtime_notes(
        mut self,
        negative_prompt: Option<&str>,
        observation_note: Option<&str>,
    ) -> Self {
        self.negative_prompt_chars = negative_prompt
            .map(normalize_prompt_text)
            .map(|value| value.chars().count())
            .unwrap_or(0);
        self.observation_note_chars = observation_note
            .map(normalize_prompt_text)
            .map(|value| value.chars().count())
            .unwrap_or(0);
        self
    }
}

#[derive(Debug, sqlx::FromRow)]
struct ProjectPromptSeedRow {
    art_style: Option<String>,
    director_manual: Option<String>,
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
        SELECT art_style, director_manual
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
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(script_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let script_role_rows = select_video_prompt_asset_seed_rows(script_role_rows);

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
        script_role_anchors,
        script_scene_anchors,
        script_tool_anchors,
        memory_style_notes,
        continuity_notes,
    }))
}

fn select_video_prompt_asset_seed_rows(
    rows: Vec<ScriptRolePromptSeedRow>,
) -> Vec<ScriptRolePromptSeedRow> {
    let mut role_count = 0usize;
    let mut scene_count = 0usize;
    let mut tool_count = 0usize;
    let mut selected = Vec::new();

    for row in rows {
        let asset_type = normalize_prompt_text(&row.asset_type).to_lowercase();
        let keep = match asset_type.as_str() {
            "role" if role_count < VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT => {
                role_count += 1;
                true
            }
            "scene" if scene_count < VIDEO_PROMPT_SCENE_ASSET_ROW_LIMIT => {
                scene_count += 1;
                true
            }
            "tool" if tool_count < VIDEO_PROMPT_TOOL_ASSET_ROW_LIMIT => {
                tool_count += 1;
                true
            }
            _ => false,
        };
        if keep {
            selected.push(row);
        }
    }

    selected
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
    let rows = trim_video_prompt_memory_rows(rows, storyboard_numeric_id, current_prompt_seed);
    Ok((
        select_video_prompt_style_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            storyboard_row,
        )
        .into_iter()
        .collect(),
        select_video_prompt_memory_notes(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
            Some(storyboard_row),
        ),
    ))
}

fn select_video_prompt_style_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: &StoryboardPromptSeedRow,
) -> Vec<String> {
    let exact =
        select_selected_video_memory_notes(rows, storyboard_numeric_id, current_prompt_seed)
            .into_iter()
            .filter_map(|note| compact_neighbor_video_style_note(&note, Some(storyboard_row)))
            .collect::<Vec<_>>();
    if !exact.is_empty() {
        return exact;
    }

    let prioritized = select_prioritized_video_style_note(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        Some(storyboard_row),
    )
    .into_iter()
    .filter_map(|note| compact_contextual_video_style_note(&note, Some(storyboard_row)))
    .collect::<Vec<_>>();
    if !prioritized.is_empty() {
        return prioritized;
    }

    collect_neighbor_video_prompt_style_notes(rows, storyboard_numeric_id)
        .into_iter()
        .filter_map(|note| compact_neighbor_video_style_note(&note, Some(storyboard_row)))
        .take(1)
        .collect()
}

fn collect_neighbor_video_prompt_style_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
) -> Vec<String> {
    let mut scored = rows
        .iter()
        .enumerate()
        .filter(|(_, row)| row.name == "selected_video_memory")
        .filter_map(|(idx, row)| {
            let storyboard_ids = extract_storyboard_ids_from_memory_content(&row.content);
            if storyboard_ids.is_empty() || storyboard_ids.contains(&storyboard_numeric_id) {
                return None;
            }
            let distance = storyboard_ids
                .iter()
                .map(|id| (storyboard_numeric_id - *id).abs())
                .min()?;
            let note = extract_key_value(&row.content, "style")
                .or_else(|| extract_key_value(&row.content, "note"))?;
            Some((distance, idx, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| a.0.cmp(&b.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));

    let mut notes = Vec::new();
    for (_, _, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= 2 {
            break;
        }
    }
    notes
}

fn extract_storyboard_ids_from_memory_content(content: &str) -> Vec<i32> {
    extract_key_value(content, "storyboardIds")
        .map(|raw| {
            raw.split(',')
                .filter_map(|part| part.trim().parse::<i32>().ok())
                .filter(|id| *id > 0)
                .collect::<Vec<_>>()
        })
        .unwrap_or_default()
}

fn trim_video_prompt_memory_rows(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<AgentMemoryRow> {
    let mut selected_candidates = Vec::new();
    let mut auto_scope_candidates = Vec::new();
    let mut script_style_candidates = Vec::new();
    let mut project_style_candidates = Vec::new();

    for (idx, row) in rows.into_iter().enumerate() {
        match row.name.as_str() {
            "selected_video_memory" => selected_candidates.push((idx, row)),
            "auto_scope_memory" => auto_scope_candidates.push((idx, row)),
            "script_video_style_memory" => script_style_candidates.push((idx, row)),
            "project_video_style_memory" => project_style_candidates.push((idx, row)),
            _ => {}
        }
    }

    let mut kept = std::collections::HashSet::new();
    for idx in prioritize_storyboard_memory_indices(
        &selected_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_SELECTED_MEMORY_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    for idx in prioritize_storyboard_memory_indices(
        &auto_scope_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_AUTO_SCOPE_MEMORY_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    for (idx, _) in script_style_candidates
        .iter()
        .take(VIDEO_PROMPT_SCRIPT_STYLE_MEMORY_ROW_LIMIT)
    {
        kept.insert(*idx);
    }
    for (idx, _) in project_style_candidates
        .iter()
        .take(VIDEO_PROMPT_PROJECT_STYLE_MEMORY_ROW_LIMIT)
    {
        kept.insert(*idx);
    }

    let mut all_rows = selected_candidates;
    all_rows.extend(auto_scope_candidates);
    all_rows.extend(script_style_candidates);
    all_rows.extend(project_style_candidates);
    all_rows.sort_by_key(|(idx, _)| *idx);
    all_rows
        .into_iter()
        .filter_map(|(idx, row)| kept.contains(&idx).then_some(row))
        .collect()
}

fn prioritize_storyboard_memory_indices(
    rows: &[(usize, AgentMemoryRow)],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    limit: usize,
) -> Vec<usize> {
    let mut scored = rows
        .iter()
        .map(|(idx, row)| {
            let storyboard_ids = extract_storyboard_ids_from_memory_content(&row.content);
            let exact_storyboard_match =
                storyboard_numeric_id > 0 && storyboard_ids.contains(&storyboard_numeric_id);
            let prompt_seed_match = memory_prompt_seed_matches(
                &row.content,
                storyboard_numeric_id,
                current_prompt_seed,
            );
            let prompt_seed_present =
                memory_prompt_seed_for_storyboard(&row.content, storyboard_numeric_id).is_some();
            let storyboard_distance =
                storyboard_distance_from_memory_content(&row.content, storyboard_numeric_id)
                    .unwrap_or(i32::MAX);
            (
                *idx,
                exact_storyboard_match,
                prompt_seed_match,
                prompt_seed_present,
                storyboard_distance,
            )
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then(b.2.cmp(&a.2))
            .then(a.3.cmp(&b.3))
            .then(a.4.cmp(&b.4))
            .then(a.0.cmp(&b.0))
    });
    scored
        .into_iter()
        .take(limit)
        .map(|(idx, _, _, _, _)| idx)
        .collect()
}

fn memory_prompt_seed_matches(
    content: &str,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> bool {
    match current_prompt_seed {
        Some(seed) if !seed.is_empty() => {
            memory_prompt_seed_for_storyboard(content, storyboard_numeric_id).as_deref()
                == Some(seed)
        }
        _ => false,
    }
}

fn memory_prompt_seed_for_storyboard(content: &str, storyboard_numeric_id: i32) -> Option<String> {
    if let Some(prompt_seed) =
        extract_key_value(content, "promptSeed").filter(|seed| !seed.is_empty())
    {
        return Some(prompt_seed);
    }
    if storyboard_numeric_id <= 0 {
        return None;
    }
    extract_key_value(content, "storyboardPromptSeeds").and_then(|mapping| {
        mapping.split(',').find_map(|entry| {
            let (raw_storyboard_id, prompt_seed) = entry.split_once(':')?;
            let entry_storyboard_id = raw_storyboard_id.trim().parse::<i32>().ok()?;
            (entry_storyboard_id == storyboard_numeric_id)
                .then(|| prompt_seed.trim().to_string())
                .filter(|seed| !seed.is_empty())
        })
    })
}

fn storyboard_distance_from_memory_content(
    content: &str,
    storyboard_numeric_id: i32,
) -> Option<i32> {
    if storyboard_numeric_id <= 0 {
        return None;
    }
    extract_storyboard_ids_from_memory_content(content)
        .into_iter()
        .map(|id| (storyboard_numeric_id - id).abs())
        .min()
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
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN (
                'rejected_video_negative_memory',
                'selected_video_memory',
                'script_video_style_memory'
            ))
            OR (episodes_id IS NULL AND name = 'project_video_style_memory')
        )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(VIDEO_PROMPT_OBSERVATION_FETCH_ROW_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let storyboard_row = load_storyboard_prompt_seed_row(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_numeric_id,
    )
    .await?;
    let rows = trim_video_prompt_observation_rows(rows, storyboard_numeric_id, current_prompt_seed);
    let prioritized_style_note = resolve_observation_filter_style_note(
        &rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row.as_ref(),
    );
    let note = select_best_video_prompt_observation_note(prune_low_signal_observation_candidates(
        select_pending_rejected_video_observation_candidates(
            &rows,
            storyboard_numeric_id,
            current_prompt_seed,
        )
        .into_iter()
        .filter_map(|note| {
            compact_negative_constraint_against_storyboard_style(
                &note,
                prioritized_style_note.as_deref(),
                storyboard_row.as_ref(),
            )
        })
        .filter(|note| {
            !video_prompt_observation_is_irrelevant_to_storyboard(note, storyboard_row.as_ref())
        })
        .collect(),
    ));

    Ok(note.map(|note| format!("待观察失败倾向：{note}")))
}

fn trim_video_prompt_observation_rows(
    rows: Vec<AgentMemoryRow>,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
) -> Vec<AgentMemoryRow> {
    let mut rejection_candidates = Vec::new();
    let mut script_style_candidates = Vec::new();
    let mut project_style_candidates = Vec::new();

    for (idx, row) in rows.into_iter().enumerate() {
        match row.name.as_str() {
            "rejected_video_negative_memory" => rejection_candidates.push((idx, row)),
            "script_video_style_memory" | "selected_video_memory" => {
                script_style_candidates.push((idx, row))
            }
            "project_video_style_memory" => project_style_candidates.push((idx, row)),
            _ => {}
        }
    }

    let mut kept = std::collections::HashSet::new();
    for idx in prioritize_storyboard_memory_indices(
        &rejection_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_OBSERVATION_REJECTION_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    for idx in prioritize_storyboard_memory_indices(
        &script_style_candidates,
        storyboard_numeric_id,
        current_prompt_seed,
        VIDEO_PROMPT_OBSERVATION_SCRIPT_STYLE_ROW_LIMIT,
    ) {
        kept.insert(idx);
    }
    for (idx, _) in project_style_candidates
        .iter()
        .take(VIDEO_PROMPT_OBSERVATION_PROJECT_STYLE_ROW_LIMIT)
    {
        kept.insert(*idx);
    }

    let mut all_rows = rejection_candidates;
    all_rows.extend(script_style_candidates);
    all_rows.extend(project_style_candidates);
    all_rows.sort_by_key(|(idx, _)| *idx);
    all_rows
        .into_iter()
        .filter_map(|(idx, row)| kept.contains(&idx).then_some(row))
        .collect()
}

fn resolve_observation_filter_style_note(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    select_prioritized_video_style_note(
        rows,
        storyboard_numeric_id,
        current_prompt_seed,
        storyboard_row,
    )
    .and_then(|note| compact_contextual_video_style_note(&note, storyboard_row))
    .or_else(|| select_contextual_observation_summary_style_note(rows, storyboard_row))
}

fn select_contextual_observation_summary_style_note(
    rows: &[AgentMemoryRow],
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let context = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)?;

    select_script_video_style_memory_notes(rows)
        .into_iter()
        .chain(select_project_video_style_memory_notes(rows))
        .filter_map(|note| {
            let evidence = observation_style_note_context_evidence(&note, &context);
            let compacted = compact_contextual_video_style_note(&note, storyboard_row)?;
            (evidence >= 2).then_some((evidence, compacted))
        })
        .max_by(|(left_evidence, left_note), (right_evidence, right_note)| {
            left_evidence
                .cmp(right_evidence)
                .then_with(|| right_note.chars().count().cmp(&left_note.chars().count()))
        })
        .map(|(_, note)| note)
}

fn observation_style_note_context_evidence(
    style_note: &str,
    context: &StructuredStoryboardDescription,
) -> usize {
    let note = normalize_prompt_text(style_note);
    let mut evidence = 0usize;

    let mood = normalize_prompt_text(&context.mood);
    if !mood.is_empty() && note.contains(&mood) {
        evidence += 1;
    }

    let lighting = normalize_prompt_text(&context.lighting);
    if !lighting.is_empty() && note.contains(&lighting) {
        evidence += 1;
    }

    let shot = normalize_prompt_text(&context.shot);
    let camera_move = normalize_prompt_text(&context.camera_move);
    if (!shot.is_empty() && note.contains(&shot))
        || (!camera_move.is_empty() && note.contains(&camera_move))
    {
        evidence += 1;
    }

    evidence
}

async fn load_storyboard_prompt_seed_row(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<Option<StoryboardPromptSeedRow>, ApiError> {
    sqlx::query_as::<_, StoryboardPromptSeedRow>(
        r#"
        SELECT sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = $4
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(storyboard_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

fn video_prompt_observation_conflicts_with_style(
    observation_note: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    negative_constraint_conflicts_with_storyboard_style(
        observation_note.trim(),
        selected_style_note,
        storyboard_row,
    )
}

fn video_prompt_observation_is_irrelevant_to_storyboard(
    observation_note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> bool {
    canonical_observation_note(observation_note) == "avoid lip-sync mismatch"
        && storyboard_row.is_some_and(storyboard_dialogue_is_empty_row)
}

fn storyboard_dialogue_is_empty_row(row: &StoryboardPromptSeedRow) -> bool {
    row.video_desc
        .as_deref()
        .and_then(parse_structured_storyboard_description)
        .is_some_and(|fields| storyboard_dialogue_is_empty(&fields.dialogue))
}

fn storyboard_dialogue_is_empty(dialogue: &str) -> bool {
    let normalized = normalize_prompt_text(dialogue);
    let normalized_ascii = normalized.to_ascii_lowercase();
    normalized.is_empty()
        || [
            "无台词",
            "无对白",
            "无旁白",
            "无语音",
            "no dialogue",
            "no voice-over",
            "silent",
        ]
        .iter()
        .map(|marker| normalize_prompt_text(marker).to_ascii_lowercase())
        .any(|marker| normalized_ascii == marker)
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

fn compact_negative_constraint_against_storyboard_style(
    fragment: &str,
    selected_style_note: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let trimmed = fragment.trim();
    if trimmed.is_empty() {
        return None;
    }
    let conflicts = |value: &str| {
        negative_constraint_conflicts_with_storyboard_style(
            value.trim(),
            selected_style_note,
            storyboard_row,
        )
    };
    match canonical_observation_note(trimmed).as_str() {
        "avoid extreme camera angle or overly tight close-up framing" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid extreme camera angle",
                "avoid overly tight close-up framing",
                conflicts,
            )
        }
        "avoid overly cold, oppressive, or frantic mood" => compact_conflicting_negative_pair(
            trimmed,
            "avoid oppressive or frantic mood",
            "avoid overly cold emotional tone",
            conflicts,
        ),
        "avoid flat cold lighting or harsh backlight silhouette" => {
            compact_conflicting_negative_pair(
                trimmed,
                "avoid flat cold lighting",
                "avoid harsh backlight silhouette",
                conflicts,
            )
        }
        _ => (!conflicts(trimmed)).then_some(trimmed.to_string()),
    }
}

fn compact_conflicting_negative_pair(
    original: &str,
    lhs: &str,
    rhs: &str,
    conflicts: impl Fn(&str) -> bool,
) -> Option<String> {
    let lhs_conflicts = conflicts(lhs);
    let rhs_conflicts = conflicts(rhs);
    match (lhs_conflicts, rhs_conflicts) {
        (false, false) => Some(original.to_string()),
        (true, false) => Some(rhs.to_string()),
        (false, true) => Some(lhs.to_string()),
        (true, true) => None,
    }
}

fn select_best_video_prompt_observation_note(candidates: Vec<String>) -> Option<String> {
    candidates.into_iter().max_by(|a, b| {
        score_video_prompt_observation_specificity(a)
            .cmp(&score_video_prompt_observation_specificity(b))
            .then(
                score_video_prompt_observation_quality(a)
                    .cmp(&score_video_prompt_observation_quality(b)),
            )
            .then(b.chars().count().cmp(&a.chars().count()))
            .then(b.cmp(a))
    })
}

fn prune_low_signal_observation_candidates(candidates: Vec<String>) -> Vec<String> {
    let mut kept = candidates
        .into_iter()
        .filter(|note| !observation_candidate_is_low_signal(note))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        return Vec::new();
    }
    kept.dedup();
    kept
}

fn observation_candidate_is_low_signal(note: &str) -> bool {
    matches!(
        canonical_observation_note(note).as_str(),
        "avoid repeating stable follow camera"
            | "avoid oppressive or frantic mood"
            | "avoid overly cold emotional tone"
            | "avoid heavy tragic mood"
            | "avoid overly cold, oppressive, or frantic mood"
    )
}

fn score_video_prompt_observation_specificity(note: &str) -> i32 {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "composition",
        "direction",
        "camera angle",
        "close-up",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "机位",
        "景别",
    ] {
        if normalized.contains(keyword) {
            score += 18;
        }
    }
    for keyword in [
        "face distortion",
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "lip-sync",
        "口型",
        "脸",
        "身份",
        "服装",
        "角色一致",
    ] {
        if normalized.contains(keyword) {
            score += 16;
        }
    }
    for keyword in [
        "backlight",
        "silhouette",
        "lighting",
        "light",
        "flicker",
        "exposure",
        "reflection",
        "反光",
        "逆光",
        "光影",
        "曝光",
        "闪烁",
    ] {
        if normalized.contains(keyword) {
            score += 12;
        }
    }
    for keyword in [
        "shaky", "handheld", "motion", "stutter", "blur", "抖动", "手持", "运镜",
    ] {
        if normalized.contains(keyword) {
            score += 10;
        }
    }
    for keyword in [
        "mood",
        "emotion",
        "tragic",
        "oppressive",
        "frantic",
        "情绪",
        "压迫",
        "悲怆",
    ] {
        if normalized.contains(keyword) {
            score += 6;
        }
    }
    if normalized.contains("repeat")
        || normalized.contains("repeating")
        || normalized.contains("重复")
    {
        score -= 8;
    }
    score
}

fn score_video_prompt_observation_quality(note: &str) -> i32 {
    let normalized = canonical_observation_note(note);
    if normalized.is_empty() {
        return 0;
    }

    let mut score = 0;
    for keyword in [
        "face distortion",
        "identity drift",
        "costume drift",
        "costume inconsistency",
        "lip-sync",
        "jump axis",
        "axis",
        "eyeline",
        "framing",
        "camera angle",
        "close-up",
        "backlight",
        "silhouette",
        "flicker",
        "stutter",
        "blur",
        "跳轴",
        "视线",
        "构图",
        "方向",
        "站位",
        "走位",
        "逆光",
        "曝光",
        "闪烁",
    ] {
        if normalized.contains(keyword) {
            score += 10;
        }
    }
    score
}

fn build_video_prompt(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> String {
    build_video_prompt_with_diagnostics(description, image_url, context).prompt
}

fn build_video_prompt_with_diagnostics(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> VideoPromptBuildResult {
    let mut clauses = Vec::new();
    clauses.push("Single cinematic shot.".to_string());

    let resolved_description = resolve_video_prompt_description(description, context);
    let structured_fields = resolved_description
        .as_deref()
        .and_then(parse_structured_storyboard_description);
    let mut prompt_coverage = collect_prompt_coverage(structured_fields.as_ref());
    let role_anchors = build_script_role_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    if !role_anchors.is_empty() {
        clauses.push(format!("Character anchor: {}.", role_anchors.join("; ")));
    }
    let scene_anchors = build_script_scene_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    if !scene_anchors.is_empty() {
        clauses.push(format!("Scene anchor: {}.", scene_anchors.join("; ")));
    }
    let tool_anchors = build_script_tool_anchors(
        context,
        resolved_description.as_deref(),
        structured_fields.as_ref(),
        &prompt_coverage,
    );
    if !tool_anchors.is_empty() {
        clauses.push(format!("Prop anchor: {}.", tool_anchors.join("; ")));
    }
    let mut asset_coverage = Vec::new();
    extend_prompt_coverage(&mut asset_coverage, &role_anchors);
    extend_prompt_coverage(&mut asset_coverage, &scene_anchors);
    extend_prompt_coverage(&mut asset_coverage, &tool_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &role_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &scene_anchors);
    extend_prompt_coverage(&mut prompt_coverage, &tool_anchors);
    let style_anchors =
        build_project_visual_anchors(context, structured_fields.as_ref(), &prompt_coverage);
    let mut style_coverage = Vec::new();
    extend_prompt_coverage(&mut style_coverage, &style_anchors);
    match structured_fields.as_ref() {
        Some(fields) => {
            let compacted_dialogue = compact_dialogue_clause(&fields.dialogue);
            let mut subject = compact_subject_clause(
                &fields.subject,
                &asset_coverage,
                &prompt_coverage,
                Some(fields.action.as_str()),
            );
            let setting = compact_setting_clause(
                &fields.setting,
                &asset_coverage,
                &prompt_coverage,
                Some(fields.subject.as_str()),
                Some(fields.action.as_str()),
            );
            let action = compact_action_clause(
                &fields.action,
                &asset_coverage,
                &prompt_coverage,
                compacted_dialogue.as_deref(),
                Some(fields.setting.as_str()),
            );

            if prompt_clauses_substantially_overlap(subject.as_deref(), action.as_deref()) {
                subject = None;
            }

            if let Some(subject) = subject {
                clauses.push(format!("Subject: {}.", clip_prompt_fragment(&subject, 72)));
            }
            if let Some(setting) = setting {
                clauses.push(format!("Setting: {}.", clip_prompt_fragment(&setting, 48)));
            }
            if let Some(action) = action.as_ref() {
                clauses.push(format!("Action: {}.", clip_prompt_fragment(&action, 72)));
            }
            if let Some(camera) =
                compact_camera_clause(&fields.shot, &fields.camera_move, &style_coverage)
            {
                clauses.push(format!("Camera: {}.", clip_prompt_fragment(&camera, 40)));
            }
            if !fields.mood.is_empty() && !prompt_fragment_is_covered(&fields.mood, &style_coverage)
            {
                clauses.push(format!("Mood: {}.", clip_prompt_fragment(&fields.mood, 36)));
            }
            if !fields.lighting.is_empty()
                && !prompt_fragment_is_covered(&fields.lighting, &style_coverage)
            {
                clauses.push(format!(
                    "Lighting: {}.",
                    clip_prompt_fragment(&fields.lighting, 44)
                ));
            }
            if let Some(dialogue) = compacted_dialogue.as_deref() {
                clauses.push(format!(
                    "Dialogue or voice-over: {}.",
                    clip_prompt_fragment(dialogue, 60)
                ));
            }
            if let Some(sound) = compact_sound_clause(
                &fields.sound,
                compacted_dialogue.as_deref(),
                action.as_deref(),
            ) {
                clauses.push(format!("Sound: {}.", clip_prompt_fragment(&sound, 44)));
            }
        }
        None => {
            let fallback = resolved_description
                .filter(|text| !text.is_empty())
                .unwrap_or_else(|| "Clear subject, natural motion, stable continuity.".to_string());
            clauses.push(format!("Scene: {}.", clip_prompt_fragment(&fallback, 160)));
        }
    }

    if !style_anchors.is_empty() {
        clauses.push(format!("Style anchor: {}.", style_anchors.join("; ")));
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
    clauses.push(build_video_prompt_quality_tail(
        structured_fields.as_ref(),
        &style_anchors,
        &continuity_notes,
    ));
    let prompt = clauses.join(" ");
    VideoPromptBuildResult {
        diagnostics: GenerateVideoPromptDiagnostics {
            prompt_chars: prompt.chars().count(),
            negative_prompt_chars: 0,
            observation_note_chars: 0,
            role_anchor_count: role_anchors.len(),
            scene_anchor_count: scene_anchors.len(),
            tool_anchor_count: tool_anchors.len(),
            style_anchor_count: style_anchors.len(),
            continuity_note_count: continuity_notes.len(),
            uses_reference_frame: image_url.is_some(),
        },
        prompt,
    }
}

fn compact_neighbor_video_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    compact_contextual_video_style_note(note, storyboard_row)
}

fn compact_contextual_video_style_note(
    note: &str,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }
    let Some(fields) = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description)
    else {
        return compact_video_style_prompt_note(&normalized);
    };

    let expected_camera = [fields.shot.as_str(), fields.camera_move.as_str()]
        .into_iter()
        .filter(|part| !part.is_empty())
        .collect::<String>();
    let fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| {
            neighbor_style_fragment_matches_storyboard(fragment, &fields, &expected_camera)
        })
        .filter_map(|fragment| trim_style_fragment_against_storyboard_fields(&fragment, &fields))
        .map(|fragment| clip_prompt_fragment(&fragment, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
        .collect::<Vec<_>>();
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn neighbor_style_fragment_matches_storyboard(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
    expected_camera: &str,
) -> bool {
    if fragment.starts_with("镜头") {
        return continuity_fragment_matches_fields(fragment, fields, expected_camera)
            || prompt_style_fragment_overlaps_field(fragment, &fields.shot)
            || prompt_style_fragment_overlaps_field(fragment, &fields.camera_move);
    }
    if fragment.starts_with("情绪") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.mood);
    }
    if fragment.starts_with("光影") {
        return prompt_style_fragment_overlaps_field(fragment, &fields.lighting);
    }
    false
}

fn prompt_style_fragment_overlaps_field(fragment: &str, field: &str) -> bool {
    if field.is_empty() {
        return false;
    }
    let canonical = canonical_continuity_fragment(fragment);
    !canonical.is_empty()
        && (canonical == field || canonical.contains(field) || field.contains(&canonical))
}

fn build_video_prompt_quality_tail(
    structured_fields: Option<&StructuredStoryboardDescription>,
    style_anchors: &[String],
    continuity_notes: &[String],
) -> String {
    let camera = structured_fields
        .map(|fields| {
            [fields.shot.as_str(), fields.camera_move.as_str()]
                .into_iter()
                .filter(|part| !part.is_empty())
                .collect::<String>()
        })
        .unwrap_or_default();
    let continuity_is_explicit = !continuity_notes.is_empty()
        || continuity_tail_matches(&camera)
        || style_anchors
            .iter()
            .any(|anchor| continuity_tail_matches(anchor));

    if continuity_is_explicit {
        "Natural motion, no extra shot changes.".to_string()
    } else {
        "Natural motion, stable continuity, no extra shot changes.".to_string()
    }
}

fn continuity_tail_matches(value: &str) -> bool {
    let normalized = normalize_prompt_text(value);
    !normalized.is_empty()
        && ["稳定", "跟拍", "衔接", "连续", "一致", "统一"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

fn compact_camera_clause(
    shot: &str,
    camera_move: &str,
    style_coverage: &[String],
) -> Option<String> {
    let parts = [shot, camera_move]
        .into_iter()
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .filter(|part| !prompt_fragment_is_covered(part, style_coverage))
        .collect::<Vec<_>>();
    if parts.is_empty() {
        None
    } else {
        Some(parts.join(", "))
    }
}

fn continuity_note_adds_specific_guidance(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "走位",
            "站位",
            "跳轴",
            "方向",
            "构图",
            "视线",
            "节奏",
            "动作",
            "位置",
            "前后景",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

fn continuity_fragment_is_generic_quality_tail_overlap(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || continuity_note_adds_specific_guidance(&normalized) {
        return false;
    }
    continuity_fragment_core(&normalized)
        .as_deref()
        .is_some_and(continuity_tail_matches)
}

fn project_director_fragment_adds_visual_style_guidance(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "机位",
            "运镜",
            "景别",
            "跟拍",
            "推进",
            "慢推",
            "拉远",
            "环绕",
            "手持",
            "特写",
            "近景",
            "中景",
            "全景",
            "远景",
            "光",
            "色",
            "色调",
            "质感",
            "氛围",
            "情绪",
            "风格",
            "tone",
            "style",
            "lighting",
            "mood",
            "frame",
            "composition",
        ]
        .iter()
        .any(|keyword| normalized.contains(keyword))
}

fn project_director_fragment_is_generic_quality_tail_overlap(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty()
        || continuity_note_adds_specific_guidance(&normalized)
        || project_director_fragment_adds_visual_style_guidance(&normalized)
    {
        return false;
    }
    continuity_tail_matches(&normalized)
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
        .and_then(|value| compact_project_art_style_note(value, structured_fields, &style_coverage))
    {
        anchors.push(clip_prompt_fragment(&style, 32));
        extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
    }
    if let Some(note) = ctx
        .project_director_manual
        .as_deref()
        .and_then(|value| compact_project_director_note(value, structured_fields, &style_coverage))
    {
        anchors.push(note);
        extend_prompt_coverage(&mut style_coverage, anchors.as_slice());
    }
    let has_base_style_anchor = !anchors.is_empty();
    for note in &ctx.memory_style_notes {
        let Some(note) = compact_memory_style_anchor(
            note,
            structured_fields,
            &style_coverage,
            has_base_style_anchor,
        ) else {
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

fn compact_project_art_style_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }

    let mut fragments = normalized
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| !prompt_fragment_is_covered(fragment, prompt_coverage))
        .filter(|fragment| {
            structured_fields.is_none_or(|fields| {
                fragment != &fields.mood
                    && fragment != &fields.lighting
                    && fragment != &fields.setting
                    && !continuity_fragment_matches_fields(
                        fragment,
                        fields,
                        &[fields.shot.as_str(), fields.camera_move.as_str()]
                            .into_iter()
                            .filter(|part| !part.is_empty())
                            .collect::<String>(),
                    )
            })
        })
        .collect::<Vec<_>>();

    if fragments.is_empty() {
        if prompt_fragment_is_covered(&normalized, prompt_coverage) {
            return None;
        }
        return Some(clip_prompt_fragment(&normalized, 32));
    }

    fragments.dedup();
    Some(clip_prompt_fragment(&fragments.join(", "), 32))
}

fn compact_memory_style_anchor(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    allow_prompt_covered_style_fragments: bool,
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
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| style_fragment_prefix(fragment))
        .filter_map(|fragment| {
            if let Some(fields) = structured_fields {
                return trim_style_fragment_against_storyboard_fields(&fragment, fields);
            }
            Some(fragment)
        })
        .filter(|fragment| {
            if let (Some(fields), Some(camera)) = (structured_fields, expected_camera.as_deref()) {
                if continuity_fragment_matches_fields(fragment, fields, camera)
                    && !(allow_prompt_covered_style_fragments
                        && style_fragment_matches_prompt_style_field(fragment, fields))
                {
                    return false;
                }
            }
            !style_fragment_or_body_is_semantically_covered(fragment, prompt_coverage)
                || structured_fields.is_some_and(|fields| {
                    allow_prompt_covered_style_fragments
                        && style_fragment_matches_prompt_style_field(fragment, fields)
                })
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

fn trim_style_fragment_against_storyboard_fields(
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
        return trim_prefixed_style_fragment(fragment, "光影", &[fields.lighting.as_str()]);
    }
    Some(fragment.to_string())
}

fn trim_prefixed_style_fragment(fragment: &str, prefix: &str, fields: &[&str]) -> Option<String> {
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

fn style_fragment_matches_prompt_style_field(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> bool {
    let canonical = canonical_continuity_fragment(fragment);
    !canonical.is_empty()
        && ((!fields.mood.is_empty() && canonical == fields.mood)
            || (!fields.lighting.is_empty() && canonical == fields.lighting))
}

fn style_fragment_prefix(fragment: &str) -> bool {
    ["镜头", "情绪", "光影"]
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
}

fn style_fragment_body(fragment: &str) -> Option<String> {
    ["镜头", "情绪", "光影"]
        .iter()
        .find_map(|prefix| fragment.strip_prefix(prefix))
        .map(normalize_prompt_text)
        .filter(|body| !body.is_empty())
}

fn style_fragment_or_body_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    style_fragment_is_semantically_covered(fragment, coverage)
        || style_fragment_body(fragment)
            .as_deref()
            .is_some_and(|body| prompt_fragment_is_covered(body, coverage))
}

fn style_fragment_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    continuity_fragment_is_semantically_covered(fragment, coverage)
}

fn continuity_fragment_is_semantically_covered(fragment: &str, coverage: &[String]) -> bool {
    if prompt_fragment_is_covered(fragment, coverage) {
        return true;
    }

    let canonical_fragment = canonical_continuity_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    coverage.iter().any(|existing| {
        let canonical_existing = canonical_continuity_fragment(existing);
        !canonical_existing.is_empty()
            && (canonical_existing == canonical_fragment
                || (canonical_fragment.chars().count() >= 4
                    && canonical_existing.contains(&canonical_fragment))
                || (canonical_existing.chars().count() >= 4
                    && canonical_fragment.contains(&canonical_existing)))
    })
}

fn build_script_role_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
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
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let subject_refs = structured_fields
        .map(structured_subject_ref_names)
        .unwrap_or_default();
    let role_anchor_limit = if subject_refs.len() > 1 {
        VIDEO_PROMPT_MULTI_ROLE_ANCHOR_LIMIT.min(subject_refs.len())
    } else {
        1
    };
    let mut scored = Vec::new();
    for (idx, anchor) in ctx.script_role_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Role,
        ) else {
            continue;
        };
        let score = score_script_asset_anchor(&name, &description, &subject, &action)
            + score_subject_ref_match(&name, &subject_refs);
        if name.is_empty() || score <= 0 {
            continue;
        }
        scored.push((score, idx, anchor));
    }
    select_script_asset_anchors(scored, role_anchor_limit)
}

fn build_script_scene_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
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
    let setting_refs = structured_fields
        .map(structured_setting_ref_names)
        .unwrap_or_default();
    let action = structured_fields
        .map(|fields| normalize_prompt_text(&fields.action))
        .unwrap_or_default();
    let mut scored = Vec::new();
    let mut directly_referenced_anchor_count = 0usize;
    for (idx, anchor) in ctx.script_scene_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Scene,
        ) else {
            continue;
        };
        let ref_match_score =
            score_scene_ref_match(&name, &description, &setting, &setting_refs, &action);
        let score =
            score_script_asset_anchor(&name, &description, &setting, &action) + ref_match_score;
        if name.is_empty() || score <= 0 {
            continue;
        }
        if ref_match_score > 0 {
            directly_referenced_anchor_count += 1;
        }
        scored.push((score, idx, anchor));
    }
    let scene_anchor_limit = if directly_referenced_anchor_count > 1 {
        VIDEO_PROMPT_MULTI_SCENE_ANCHOR_LIMIT.min(directly_referenced_anchor_count)
    } else {
        1
    };
    select_script_asset_anchors(scored, scene_anchor_limit)
}

fn build_script_tool_anchors(
    context: Option<&VideoPromptContext>,
    description: Option<&str>,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
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
    let subject_refs = structured_fields
        .map(structured_subject_ref_names)
        .unwrap_or_default();
    let mut scored = Vec::new();
    let mut directly_referenced_anchor_count = 0usize;
    for (idx, anchor) in ctx.script_tool_anchors.iter().enumerate() {
        let Some((name, note)) = anchor.split_once(':') else {
            continue;
        };
        let name = normalize_prompt_text(name);
        let Some(anchor) = compact_selected_script_asset_anchor(
            &name,
            note.trim(),
            structured_fields,
            prompt_coverage,
            ScriptAssetAnchorKind::Tool,
        ) else {
            continue;
        };
        let ref_match_score = score_subject_ref_match(&name, &subject_refs);
        let score =
            score_script_asset_anchor(&name, &description, &subject, &action) + ref_match_score;
        if name.is_empty() || score <= 0 {
            continue;
        }
        if ref_match_score > 0 {
            directly_referenced_anchor_count += 1;
        }
        scored.push((score, idx, anchor));
    }
    let tool_anchor_limit = if directly_referenced_anchor_count > 1 {
        VIDEO_PROMPT_MULTI_TOOL_ANCHOR_LIMIT.min(directly_referenced_anchor_count)
    } else {
        1
    };
    select_script_asset_anchors(scored, tool_anchor_limit)
}

fn score_script_asset_anchor(name: &str, description: &str, primary: &str, secondary: &str) -> i32 {
    if name.is_empty() {
        return 0;
    }
    let mut score = 0;
    let primary_head = primary
        .split(['/', '／', '、', '，', ',', ' '])
        .map(normalize_prompt_text)
        .find(|part| !part.is_empty());
    if primary_head.as_deref() == Some(name) {
        score += 160;
    }
    if !primary.is_empty() && primary == name {
        score += 120;
    } else if !primary.is_empty() && (primary.contains(name) || name.contains(primary)) {
        score += 96;
        if primary.starts_with(name) {
            score += 96;
        }
        if let Some(idx) = primary.find(name) {
            score += 24 - idx.min(24) as i32;
        }
    }
    if !secondary.is_empty() && secondary.contains(name) {
        score += 48;
        if let Some(idx) = secondary.find(name) {
            score += 12 - idx.min(12) as i32;
        }
    }
    if !description.is_empty() && description.contains(name) {
        score += 36;
        if let Some(idx) = description.find(name) {
            score += 8 - idx.min(8) as i32;
        }
    }
    score - name.chars().count() as i32
}

fn score_subject_ref_match(name: &str, subject_refs: &[String]) -> i32 {
    if name.is_empty() {
        return 0;
    }

    subject_refs
        .iter()
        .enumerate()
        .find_map(|(idx, subject_ref)| {
            (subject_ref == name || subject_ref.contains(name) || name.contains(subject_ref))
                .then_some(220 - (idx.min(4) as i32 * 8))
        })
        .unwrap_or(0)
}

fn score_scene_ref_match(
    name: &str,
    description: &str,
    setting: &str,
    setting_refs: &[String],
    action: &str,
) -> i32 {
    if name.is_empty() {
        return 0;
    }

    let mut best = setting_refs
        .iter()
        .enumerate()
        .find_map(|(idx, setting_ref)| {
            (setting_ref == name || setting_ref.contains(name) || name.contains(setting_ref))
                .then_some(220 - (idx.min(4) as i32 * 8))
        })
        .unwrap_or(0);
    for suffix in scene_anchor_suffix_candidates(name) {
        let Some(prefix) = name.strip_suffix(&suffix).map(normalize_prompt_text) else {
            continue;
        };
        let prefix_matches_context = !prefix.is_empty()
            && [description, setting, action]
                .into_iter()
                .any(|field| field.contains(&prefix));
        if !prefix_matches_context {
            continue;
        }
        if setting.contains(&suffix) {
            best = best.max(120 - suffix.chars().count() as i32);
        }
        if action.contains(&suffix) {
            best = best.max(72 - suffix.chars().count() as i32);
        }
        if description.contains(&suffix) {
            best = best.max(48 - suffix.chars().count() as i32);
        }
    }
    best
}

fn scene_anchor_suffix_candidates(name: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(name);
    if normalized.chars().count() < 4 {
        return Vec::new();
    }

    let chars = normalized.chars().collect::<Vec<_>>();
    let mut suffixes = Vec::new();
    for len in 2..=4 {
        if chars.len() <= len {
            continue;
        }
        let suffix = chars[chars.len() - len..].iter().collect::<String>();
        if scene_anchor_suffix_looks_specific(&suffix)
            && !suffixes.iter().any(|existing| existing == &suffix)
        {
            suffixes.push(suffix);
        }
    }
    suffixes
}

fn scene_anchor_suffix_looks_specific(suffix: &str) -> bool {
    !suffix.is_empty()
        && [
            "门厅", "走廊", "街口", "巷口", "门口", "楼梯", "楼道", "雨巷", "包间", "车内", "车门",
            "客厅", "卧室", "仓库", "天台", "屋顶", "尽头",
        ]
        .iter()
        .any(|keyword| suffix.ends_with(keyword))
}

fn structured_subject_ref_names(fields: &StructuredStoryboardDescription) -> Vec<String> {
    fields
        .subject_refs
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut refs, value| {
            if !refs.iter().any(|existing| existing == &value) {
                refs.push(value);
            }
            refs
        })
}

fn structured_setting_ref_names(fields: &StructuredStoryboardDescription) -> Vec<String> {
    fields
        .setting
        .split(['/', '／', ',', '，', '、', ';', '；', '|'])
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
        .fold(Vec::new(), |mut refs, value| {
            if !refs.iter().any(|existing| existing == &value) {
                refs.push(value);
            }
            refs
        })
}

fn select_script_asset_anchors(mut scored: Vec<(i32, usize, String)>, limit: usize) -> Vec<String> {
    if limit == 0 {
        return Vec::new();
    }
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let mut selected = Vec::new();
    for (_, _, anchor) in scored {
        if selected.iter().any(|existing| existing == &anchor) {
            continue;
        }
        selected.push(anchor);
        if selected.len() >= limit {
            break;
        }
    }
    selected
}

#[derive(Debug, Clone, Copy)]
enum ScriptAssetAnchorKind {
    Role,
    Scene,
    Tool,
}

fn compact_selected_script_asset_anchor(
    name: &str,
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    kind: ScriptAssetAnchorKind,
) -> Option<String> {
    let normalized_name = normalize_prompt_text(name);
    if normalized_name.is_empty() {
        return None;
    }
    if script_asset_anchor_note_is_generic_placeholder(note) {
        return None;
    }

    let mut fragments = note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_script_asset_anchor_fragment_against_storyboard_fields(
                fragment,
                structured_fields,
                kind,
            )
        })
        .filter(|fragment| {
            !script_asset_anchor_fragment_is_covered(
                fragment,
                structured_fields,
                prompt_coverage,
                kind,
            )
        })
        .collect::<Vec<_>>();
    fragments.dedup();

    if fragments.is_empty() {
        return None;
    }

    Some(format!("{normalized_name}:{}", fragments.join("，")))
}

fn script_asset_anchor_note_is_generic_placeholder(note: &str) -> bool {
    matches!(
        normalize_prompt_text(note).as_str(),
        "视觉设定延续" | "场景设定延续" | "道具设定延续"
    )
}

fn script_asset_anchor_fragment_is_covered(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
    prompt_coverage: &[String],
    kind: ScriptAssetAnchorKind,
) -> bool {
    if prompt_fragment_is_covered(fragment, prompt_coverage) {
        return true;
    }

    let Some(fields) = structured_fields else {
        return false;
    };
    match kind {
        ScriptAssetAnchorKind::Role => fragment_mostly_repeats_prompt_mood(fragment, &fields.mood),
        ScriptAssetAnchorKind::Scene | ScriptAssetAnchorKind::Tool => false,
    }
}

fn trim_script_asset_anchor_fragment_against_storyboard_fields(
    fragment: String,
    structured_fields: Option<&StructuredStoryboardDescription>,
    kind: ScriptAssetAnchorKind,
) -> Option<String> {
    let Some(fields) = structured_fields else {
        return Some(fragment);
    };

    let mut trimmed = fragment;
    for field in script_asset_anchor_overlap_fields(fields, kind) {
        trimmed = trim_fragment_by_exact_field_overlap(&trimmed, field)?;
    }
    Some(trimmed)
}

fn script_asset_anchor_overlap_fields(
    fields: &StructuredStoryboardDescription,
    kind: ScriptAssetAnchorKind,
) -> Vec<&str> {
    let mut overlap_fields = match kind {
        ScriptAssetAnchorKind::Role => vec![fields.subject.as_str(), fields.action.as_str()],
        ScriptAssetAnchorKind::Scene => vec![fields.setting.as_str()],
        ScriptAssetAnchorKind::Tool => Vec::new(),
    };
    overlap_fields.push(fields.mood.as_str());
    overlap_fields.push(fields.lighting.as_str());
    overlap_fields
}

fn trim_fragment_by_exact_field_overlap(fragment: &str, field: &str) -> Option<String> {
    let normalized_fragment = normalize_prompt_text(fragment);
    let normalized_field = normalize_prompt_text(field);
    if normalized_fragment.is_empty() || normalized_field.is_empty() {
        return Some(normalized_fragment);
    }
    if !normalized_fragment.contains(&normalized_field) {
        return Some(normalized_fragment);
    }

    let residual = normalize_prompt_text(&normalized_fragment.replace(&normalized_field, ""));
    if residual.chars().count() <= 2 {
        None
    } else {
        Some(residual)
    }
}

fn fragment_mostly_repeats_prompt_mood(fragment: &str, mood: &str) -> bool {
    let fragment = normalize_prompt_text(fragment);
    let mood = normalize_prompt_text(mood);
    if fragment.is_empty() || mood.is_empty() || !fragment.contains(&mood) {
        return false;
    }

    let residual = fragment.replace(&mood, "");
    normalize_prompt_text(&residual).chars().count() <= 2
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
        score_continuity_specificity(b)
            .cmp(&score_continuity_specificity(a))
            .then(
                score_continuity_note(b, structured_fields)
                    .cmp(&score_continuity_note(a, structured_fields)),
            )
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
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_continuity_fragment_against_storyboard_fields(&fragment, fields)
        })
        .map(|fragment| {
            trim_continuity_fragment_against_prompt_coverage(&fragment, prompt_coverage)
        })
        .filter(|fragment| {
            let normalized_core = continuity_fragment_core(fragment);
            !continuity_fragment_matches_fields(fragment, fields, &expected_camera)
                && !continuity_fragment_is_generic_quality_tail_overlap(fragment)
                && !continuity_fragment_is_semantically_covered(fragment, prompt_coverage)
                && normalized_core.as_deref().is_none_or(|core| {
                    !continuity_fragment_is_semantically_covered(core, prompt_coverage)
                })
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

fn trim_continuity_fragment_against_prompt_coverage(
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

    continuity_fragment_still_specific_after_coverage_trim(&trimmed)
        .then_some(trimmed)
        .unwrap_or(normalized)
}

fn continuity_fragment_still_specific_after_coverage_trim(fragment: &str) -> bool {
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

fn trim_continuity_fragment_against_storyboard_fields(
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

fn trim_continuity_fragment_storyboard_lead_in(
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

fn continuity_fragment_core(fragment: &str) -> Option<String> {
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

fn continuity_fragment_prefix_and_body(fragment: &str) -> (String, String) {
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

fn compact_subject_clause(
    subject: &str,
    asset_coverage: &[String],
    _prompt_coverage: &[String],
    action: Option<&str>,
) -> Option<String> {
    let subject = trim_subject_action_overlap(subject, action).unwrap_or_else(|| subject.into());
    compact_prompt_clause(&subject, asset_coverage, None, PromptClauseKind::Subject)
}

fn compact_setting_clause(
    setting: &str,
    asset_coverage: &[String],
    prompt_coverage: &[String],
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let compacted = strip_prompt_setting_subject_prefix(setting, prompt_coverage);
    let compacted =
        strip_prompt_setting_context_prefix(&compacted, subject, action).unwrap_or(compacted);
    let compacted =
        compact_prompt_clause(&compacted, asset_coverage, None, PromptClauseKind::Setting)?;
    let compacted = normalize_prompt_clause_compaction(&compacted, PromptClauseKind::Setting);
    (!compacted.is_empty()
        && !prompt_fragment_has_direct_coverage(&compacted, asset_coverage)
        && !prompt_fragment_has_direct_coverage(&compacted, prompt_coverage))
    .then_some(compacted)
}

fn compact_action_clause(
    action: &str,
    asset_coverage: &[String],
    _prompt_coverage: &[String],
    dialogue: Option<&str>,
    setting: Option<&str>,
) -> Option<String> {
    let compacted =
        compact_prompt_clause(action, asset_coverage, setting, PromptClauseKind::Action)?;

    let trimmed = dialogue
        .and_then(|line| strip_dialogue_covered_action_suffix(&compacted, line))
        .unwrap_or(compacted);
    (!trimmed.is_empty()).then_some(trimmed)
}

#[derive(Debug, Clone, Copy)]
enum PromptClauseKind {
    Subject,
    Setting,
    Action,
}

fn compact_prompt_clause(
    raw: &str,
    asset_coverage: &[String],
    setting: Option<&str>,
    kind: PromptClauseKind,
) -> Option<String> {
    let normalized = normalize_prompt_text(raw);
    if normalized.is_empty() || prompt_fragment_has_direct_coverage(&normalized, asset_coverage) {
        return None;
    }

    let mut compacted = strip_action_setting_prefix(&normalized, setting, kind);
    compacted = strip_leading_covered_prompt_fragment(&compacted, asset_coverage);
    compacted = strip_action_object_prefix(&compacted, asset_coverage, kind);
    compacted = normalize_prompt_clause_compaction(&compacted, kind);
    if compacted.is_empty() {
        return None;
    }
    Some(compacted)
}

fn strip_action_object_prefix(
    fragment: &str,
    coverage: &[String],
    kind: PromptClauseKind,
) -> String {
    if !matches!(kind, PromptClauseKind::Action) {
        return fragment.to_string();
    }

    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 2 {
                continue;
            }
            for verb in ACTION_OBJECT_PREFIX_VERBS {
                let Some(stripped) = compacted.strip_prefix(verb) else {
                    continue;
                };
                let Some(stripped) = stripped.strip_prefix(candidate) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            ':' | '：'
                                | ';'
                                | '；'
                                | ','
                                | '，'
                                | '/'
                                | '／'
                                | '、'
                                | '的'
                                | '着'
                                | '后'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn prompt_fragment_has_direct_coverage(fragment: &str, coverage: &[String]) -> bool {
    let canonical_fragment = canonical_prompt_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }
    coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .any(|existing| !existing.is_empty() && existing == canonical_fragment)
}

fn strip_leading_covered_prompt_fragment(fragment: &str, coverage: &[String]) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 2 {
                continue;
            }
            let stripped = strip_prompt_prefix_candidate(&compacted, candidate);
            let Some(stripped) = stripped else { continue };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ':' | '：'
                            | ';'
                            | '；'
                            | ','
                            | '，'
                            | '/'
                            | '／'
                            | '、'
                            | '的'
                            | '在'
                            | '向'
                            | '朝'
                            | '往'
                            | '从'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn strip_prompt_prefix_candidate<'a>(fragment: &'a str, candidate: &str) -> Option<&'a str> {
    fragment.strip_prefix(candidate).or_else(|| {
        strip_prompt_leading_bridge(fragment).and_then(|value| value.strip_prefix(candidate))
    })
}

fn strip_prompt_leading_bridge(fragment: &str) -> Option<&str> {
    let trimmed = fragment.trim_start();
    PROMPT_LEADING_BRIDGES
        .into_iter()
        .find_map(|prefix| trimmed.strip_prefix(prefix))
}

fn strip_action_setting_prefix(
    fragment: &str,
    setting: Option<&str>,
    kind: PromptClauseKind,
) -> String {
    if !matches!(kind, PromptClauseKind::Action) {
        return fragment.to_string();
    }

    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    let mut candidates = build_prompt_setting_prefix_candidates(setting);
    candidates.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &candidates {
            if candidate.chars().count() < 4 {
                continue;
            }
            let Some(stripped) = strip_prompt_prefix_candidate(&compacted, candidate) else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn strip_prompt_setting_subject_prefix(setting: &str, prompt_coverage: &[String]) -> String {
    let mut compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return compacted;
    }

    let mut coverage = prompt_coverage
        .iter()
        .map(|entry| canonical_prompt_fragment(entry))
        .filter(|entry| !entry.is_empty())
        .collect::<Vec<_>>();
    coverage.sort_by(|a, b| b.chars().count().cmp(&a.chars().count()).then(a.cmp(b)));

    loop {
        let mut changed = false;
        for candidate in &coverage {
            if candidate.chars().count() < 2 || !compacted.starts_with(candidate) {
                continue;
            }
            let rest = compacted[candidate.len()..].trim_start();
            for suffix in SETTING_SUBJECT_LEAD_IN_SUFFIXES {
                let Some(stripped) = rest.strip_prefix(suffix) else {
                    continue;
                };
                let stripped = stripped.trim_start_matches(|ch: char| {
                    ch.is_whitespace()
                        || matches!(
                            ch,
                            '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
                        )
                });
                if stripped.chars().count() < 2 {
                    continue;
                }
                compacted = stripped.to_string();
                changed = true;
                break;
            }
            if changed {
                break;
            }
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn strip_prompt_setting_context_prefix(
    setting: &str,
    subject: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let compacted = normalize_prompt_text(setting);
    if compacted.is_empty() {
        return None;
    }

    let locative_lead_in = prompt_setting_locative_lead_in(&compacted)?;
    if locative_lead_in.chars().count() < 4 {
        return None;
    }

    let covered_by_context = subject
        .into_iter()
        .chain(action)
        .map(prompt_context_variants)
        .flatten()
        .any(|candidate| candidate.starts_with(&locative_lead_in));
    if !covered_by_context {
        return None;
    }

    let (_, suffix) = strip_prompt_setting_descriptive_lead_in(&compacted)?;
    let suffix = suffix.trim_start_matches(|ch: char| {
        ch.is_whitespace()
            || matches!(
                ch,
                '的' | '里' | '中' | ':' | '：' | ',' | '，' | '、' | ';' | '；'
            )
    });
    (suffix.chars().count() >= 2).then(|| suffix.to_string())
}

fn build_prompt_setting_prefix_candidates(setting: Option<&str>) -> Vec<String> {
    let mut candidates = Vec::new();
    let Some(setting) = setting
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty())
    else {
        return candidates;
    };

    candidates.push(setting.clone());
    if let Some(stripped) = strip_prompt_leading_bridge(&setting) {
        candidates.push(stripped.to_string());
    }
    if let Some((prefix, _)) = strip_prompt_setting_descriptive_lead_in(&setting) {
        candidates.push(prefix.to_string());
        if let Some(stripped) = strip_prompt_leading_bridge(prefix) {
            candidates.push(stripped.to_string());
        }
    }
    candidates.sort();
    candidates.dedup();
    candidates
}

fn prompt_setting_locative_lead_in(setting: &str) -> Option<String> {
    let normalized = normalize_prompt_text(setting);
    let (prefix, _) = strip_prompt_setting_descriptive_lead_in(&normalized)?;
    let prefix = strip_prompt_leading_bridge(prefix).unwrap_or(prefix);
    let prefix = normalize_prompt_text(prefix);
    (!prefix.is_empty()).then_some(prefix)
}

fn strip_prompt_setting_descriptive_lead_in(setting: &str) -> Option<(&str, &str)> {
    let normalized = setting.trim();
    let split_at = normalized.find('的')?;
    let (prefix, suffix_with_marker) = normalized.split_at(split_at);
    let suffix = suffix_with_marker.strip_prefix('的')?;
    let prefix = prefix.trim();
    let suffix = suffix.trim();
    (!prefix.is_empty() && !suffix.is_empty()).then_some((prefix, suffix))
}

fn prompt_context_variants(value: &str) -> Vec<String> {
    let normalized = normalize_prompt_text(value);
    if normalized.is_empty() {
        return Vec::new();
    }

    let mut variants = vec![normalized.clone()];
    if let Some(stripped) = strip_prompt_subject_role_prefix(&normalized) {
        variants.push(stripped.to_string());
        if let Some(bridge) = strip_prompt_leading_bridge(stripped) {
            variants.push(bridge.to_string());
        }
    }
    if let Some(stripped) = strip_prompt_leading_bridge(&normalized) {
        variants.push(stripped.to_string());
    }
    variants.sort();
    variants.dedup();
    variants
}

fn strip_prompt_subject_role_prefix(value: &str) -> Option<&str> {
    ACTION_SUBJECT_PREFIXES.iter().find_map(|prefix| {
        value.strip_prefix(prefix).map(|stripped| {
            stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(ch, '的' | '着' | '地' | ':' | '：' | ',' | '，' | '、')
            })
        })
    })
}

fn trim_subject_action_overlap(subject: &str, action: Option<&str>) -> Option<String> {
    let subject = normalize_prompt_text(subject);
    let action = action.map(normalize_prompt_text).unwrap_or_default();
    if subject.is_empty() || action.is_empty() {
        return None;
    }

    let Some(identity_tail) = strip_prompt_subject_role_prefix(&subject) else {
        return None;
    };
    if identity_tail.chars().count() < 3 {
        return None;
    }

    for overlap_len in (3..=identity_tail.chars().count().min(12)).rev() {
        let overlap = identity_tail.chars().take(overlap_len).collect::<String>();
        if overlap.chars().count() < 3 || !action.contains(&overlap) {
            continue;
        }
        let Some(trimmed) = subject.strip_suffix(&overlap) else {
            continue;
        };
        let trimmed = normalize_prompt_clause_compaction(trimmed, PromptClauseKind::Subject);
        if trimmed.chars().count() < 2
            || canonical_prompt_fragment(&trimmed) == canonical_prompt_fragment(&subject)
        {
            continue;
        }
        return Some(trimmed);
    }

    None
}

fn normalize_prompt_clause_compaction(fragment: &str, kind: PromptClauseKind) -> String {
    let compacted = normalize_prompt_text(fragment)
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、' | '和' | '与'
                )
        })
        .to_string();
    if compacted.is_empty() {
        return compacted;
    }
    match kind {
        PromptClauseKind::Setting => compacted
            .trim_start_matches(|ch: char| matches!(ch, '的'))
            .to_string(),
        PromptClauseKind::Subject | PromptClauseKind::Action => compacted,
    }
}

fn strip_dialogue_covered_action_suffix(action: &str, dialogue: &str) -> Option<String> {
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty() {
        return None;
    }

    let normalized_action = normalize_prompt_text(action);
    if normalized_action.is_empty() {
        return None;
    }

    for speech_prefix in [
        "低声说",
        "轻声说",
        "小声说",
        "喃喃道",
        "喃喃说",
        "呢喃",
        "说道",
        "说出",
        "说",
        "喊道",
        "喊出",
        "大喊",
        "呼喊",
        "叫喊",
        "质问",
        "回答",
        "回应",
        "重复",
    ] {
        let patterns = [
            format!("并{speech_prefix}{canonical_dialogue}"),
            format!("后{speech_prefix}{canonical_dialogue}"),
            format!("再{speech_prefix}{canonical_dialogue}"),
            format!("{speech_prefix}{canonical_dialogue}"),
        ];
        for pattern in patterns {
            let Some(prefix) = normalized_action.strip_suffix(&pattern) else {
                continue;
            };
            let normalized_prefix = normalize_prompt_text(prefix);
            let trimmed = normalized_prefix.trim_end_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ',' | '，' | ';' | '；' | ':' | '：' | '、' | '并' | '后' | '再'
                    )
            });
            if trimmed.chars().count() < 2 || action_fragment_is_speech_delivery_only(trimmed) {
                continue;
            }
            return Some(trimmed.to_string());
        }
    }

    None
}

fn action_fragment_is_speech_delivery_only(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && [
            "低声",
            "轻声",
            "小声",
            "喃喃",
            "呢喃",
            "压低声音",
            "提高嗓门",
        ]
        .iter()
        .any(|value| normalized == *value)
}

fn prompt_clauses_substantially_overlap(lhs: Option<&str>, rhs: Option<&str>) -> bool {
    let Some(lhs) = lhs
        .map(canonical_prompt_fragment)
        .filter(|value| !value.is_empty())
    else {
        return false;
    };
    let Some(rhs) = rhs
        .map(canonical_prompt_fragment)
        .filter(|value| !value.is_empty())
    else {
        return false;
    };
    lhs == rhs
        || (lhs.chars().count() >= 6 && rhs.contains(&lhs))
        || (rhs.chars().count() >= 6 && lhs.contains(&rhs))
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
    prompt_coverage: &[String],
) -> Option<String> {
    let expected_camera = structured_fields.map(|fields| {
        [fields.shot.as_str(), fields.camera_move.as_str()]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<String>()
    });
    let mut scored = Vec::new();
    for (idx, fragment) in note
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .enumerate()
    {
        if fragment.is_empty() || !project_director_fragment_relevant(&fragment) {
            continue;
        }
        let fragment = if let Some(fields) = structured_fields {
            trim_project_director_fragment_against_storyboard_fields(&fragment, fields)
        } else {
            Some(fragment)
        };
        let Some(fragment) = fragment else { continue };
        let fragment = compact_project_director_fragment_language(&fragment);
        if fragment.is_empty() {
            continue;
        }
        if project_director_fragment_is_generic_visual_placeholder(&fragment) {
            continue;
        }
        if scored
            .iter()
            .any(|(_, _, existing): &(i32, usize, String)| existing == &fragment)
        {
            continue;
        }
        if project_director_fragment_is_generic_quality_tail_overlap(&fragment) {
            continue;
        }
        if prompt_fragment_is_covered(&fragment, prompt_coverage) {
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
        let score = score_project_director_fragment(&fragment, structured_fields);
        scored.push((score, idx, fragment));
    }
    if scored.is_empty() {
        return None;
    }
    scored.sort_by(|a, b| b.0.cmp(&a.0).then(a.1.cmp(&b.1)).then(a.2.cmp(&b.2)));
    let mut fragments = scored.into_iter().take(2).collect::<Vec<_>>();
    fragments.sort_by(|a, b| a.1.cmp(&b.1).then(a.2.cmp(&b.2)));
    let fragments = fragments
        .into_iter()
        .map(|(_, _, fragment)| fragment)
        .collect::<Vec<_>>();
    Some(clip_prompt_fragment(&fragments.join(", "), 48))
}

fn compact_project_director_fragment_language(fragment: &str) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty()
        || continuity_note_adds_specific_guidance(&normalized)
        || !project_director_fragment_adds_visual_style_guidance(&normalized)
    {
        return normalized;
    }

    let compacted = strip_generic_director_continuity_subfragments(&normalized);
    let trimmed = ["保持", "维持", "延续"]
        .iter()
        .find_map(|prefix| compacted.strip_prefix(prefix))
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty());
    trimmed.unwrap_or(compacted)
}

fn strip_generic_director_continuity_subfragments(fragment: &str) -> String {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return normalized;
    }

    let separated = ["并且", "同时", "以及", "并", "且"]
        .into_iter()
        .fold(normalized.clone(), |acc, needle| acc.replace(needle, "，"));
    let kept = separated
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|part| !part.is_empty())
        .filter(|part| !project_director_fragment_is_generic_quality_tail_overlap(part))
        .collect::<Vec<_>>();
    if kept.is_empty() {
        normalized
    } else {
        kept.join("，")
    }
}

fn project_director_fragment_is_generic_visual_placeholder(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return false;
    }
    if !project_director_fragment_relevant(&normalized)
        || continuity_note_adds_specific_guidance(&normalized)
    {
        return false;
    }

    let stripped = [
        "镜头语言",
        "镜头",
        "画面",
        "光影",
        "情绪",
        "氛围",
        "风格",
        "色调",
        "质感",
        "节奏",
        "场景",
        "camera",
        "lighting",
        "mood",
        "style",
        "tone",
        "frame",
        "composition",
        "统一",
        "一致",
        "连续",
        "衔接",
        "保持",
        "延续",
        "稳定",
    ]
    .into_iter()
    .fold(normalized.clone(), |acc, token| acc.replace(token, ""));
    normalize_prompt_text(&stripped).is_empty()
}

fn trim_project_director_fragment_against_storyboard_fields(
    fragment: &str,
    fields: &StructuredStoryboardDescription,
) -> Option<String> {
    if ["镜头", "情绪", "光影"]
        .iter()
        .any(|prefix| fragment.starts_with(prefix))
    {
        return trim_style_fragment_against_storyboard_fields(fragment, fields);
    }
    Some(fragment.to_string())
}

fn score_project_director_fragment(
    fragment: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> i32 {
    let mut score = 0;
    if ["统一", "连续", "衔接", "延续", "保持"]
        .iter()
        .any(|keyword| fragment.contains(keyword))
    {
        score += 18;
    }
    if [
        "镜头",
        "构图",
        "机位",
        "运镜",
        "景别",
        "frame",
        "composition",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
    {
        score += 14;
    }
    if [
        "光", "色", "色调", "质感", "氛围", "情绪", "风格", "tone", "style",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
    {
        score += 8;
    }
    if let Some(fields) = structured_fields {
        if !fields.shot.is_empty() && fragment.contains(&fields.shot) {
            score -= 10;
        }
        if !fields.camera_move.is_empty() && fragment.contains(&fields.camera_move) {
            score -= 10;
        }
        if !fields.mood.is_empty() && fragment.contains(&fields.mood) {
            score -= 8;
        }
        if !fields.lighting.is_empty() && fragment.contains(&fields.lighting) {
            score -= 8;
        }
        if !fields.setting.is_empty() && fragment.contains(&fields.setting) {
            score -= 6;
        }
    }
    score - fragment.chars().count() as i32 / 2
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
        .map(|text| clip_prompt_fragment(&text, max_chars))?;
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

fn compact_dialogue_clause(dialogue: &str) -> Option<String> {
    let normalized = normalize_prompt_text(dialogue);
    if normalized.is_empty() || looks_like_silence(&normalized) {
        return None;
    }

    let compacted = canonical_dialogue_fragment(&normalized);
    if compacted.is_empty() {
        return Some(normalized);
    }

    let normalized_len = normalized.chars().count();
    let compacted_len = compacted.chars().count();
    let selected = if compacted_len >= 2 && normalized_len.saturating_sub(compacted_len) >= 2 {
        compacted
    } else {
        normalized
    };

    (!dialogue_fragment_is_non_semantic_vocalization(&selected)).then_some(selected)
}

fn dialogue_fragment_is_non_semantic_vocalization(value: &str) -> bool {
    let normalized = canonical_dialogue_fragment(value);
    if normalized.is_empty() {
        return false;
    }

    let mut residual = normalized;
    for fragment in [
        "急促",
        "短促",
        "轻微",
        "微弱",
        "低低",
        "沙哑",
        "压抑地",
        "压着",
        "颤抖着",
        "颤声",
        "轻声",
        "低声",
        "缓缓",
        "忍不住",
        "一声",
        "几声",
        "地",
        "着",
        "了",
    ] {
        residual = residual.replace(fragment, "");
    }
    for fragment in [
        "倒吸一口气",
        "呼吸声",
        "喘息",
        "喘气",
        "呼吸",
        "吸气",
        "叹息",
        "长叹",
        "闷哼",
        "呻吟",
        "哽咽",
        "抽泣",
        "啜泣",
        "惊呼",
        "尖叫",
        "低吼",
        "嘶吼",
        "呜咽",
    ] {
        residual = residual.replace(fragment, "");
    }
    for fragment in ["啊", "嗯", "呃", "哈", "哼", "唔", "呀", "哦"] {
        residual = residual.replace(fragment, "");
    }

    normalize_prompt_text(&residual).is_empty()
}

fn compact_sound_clause(
    sound: &str,
    dialogue: Option<&str>,
    action: Option<&str>,
) -> Option<String> {
    let normalized = normalize_prompt_text(sound);
    if normalized.is_empty() || looks_like_silence(&normalized) {
        return None;
    }

    let dialogue = dialogue
        .map(normalize_prompt_text)
        .filter(|value| !value.is_empty() && !looks_like_silence(value));
    let mut kept = Vec::new();
    for fragment in split_prompt_clause_fragments(&normalized) {
        if looks_like_silence(&fragment) {
            continue;
        }
        let fragment = compact_sound_fragment(&fragment);
        if fragment.is_empty() || looks_like_silence(&fragment) {
            continue;
        }
        if sound_fragment_is_low_signal_ambient(&fragment) {
            continue;
        }
        if dialogue
            .as_deref()
            .is_some_and(|line| sound_fragment_is_dialogue_covered(&fragment, line))
        {
            continue;
        }
        if action
            .as_deref()
            .is_some_and(|line| sound_fragment_is_action_covered(&fragment, line))
        {
            continue;
        }
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
    }

    if kept.is_empty() {
        None
    } else {
        Some(kept.join("，"))
    }
}

fn compact_sound_fragment(fragment: &str) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    loop {
        let mut changed = false;
        for prefix in [
            "伴随",
            "伴着",
            "伴有",
            "夹杂着",
            "夹杂",
            "传来",
            "响起",
            "回荡着",
            "回荡",
            "只剩下",
            "只剩",
            "能听见",
            "听见",
            "可闻",
            "耳边传来",
            "空气里只剩",
        ] {
            let Some(stripped) = compacted.strip_prefix(prefix) else {
                continue;
            };
            let stripped = stripped.trim_start_matches(|ch: char| {
                ch.is_whitespace()
                    || matches!(
                        ch,
                        ':' | '：' | ';' | '；' | ',' | '，' | '/' | '／' | '、' | '的'
                    )
            });
            if stripped.chars().count() < 2 {
                continue;
            }
            compacted = stripped.to_string();
            changed = true;
            break;
        }
        if !changed {
            break;
        }
    }

    compacted
}

fn split_prompt_clause_fragments(value: &str) -> Vec<String> {
    value
        .split(['，', ',', '；', ';', '。', '！', '!', '？', '?', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .collect()
}

fn sound_fragment_is_dialogue_covered(fragment: &str, dialogue: &str) -> bool {
    let canonical_dialogue = canonical_dialogue_fragment(dialogue);
    if canonical_dialogue.is_empty() {
        return false;
    }
    let canonical_fragment = canonical_dialogue_fragment(fragment);
    if canonical_fragment.is_empty() {
        return false;
    }

    speech_like_fragment(fragment)
        && (canonical_fragment == canonical_dialogue
            || canonical_fragment.contains(&canonical_dialogue)
            || canonical_dialogue.contains(&canonical_fragment))
}

fn sound_fragment_is_action_covered(fragment: &str, action: &str) -> bool {
    let fragment = normalize_prompt_text(fragment);
    let action = normalize_prompt_text(action);
    if fragment.is_empty() || action.is_empty() {
        return false;
    }
    if sound_fragment_has_high_value_acoustic_detail(&fragment) {
        return false;
    }

    if sound_fragment_matches_footstep_action(&fragment, &action) {
        return true;
    }
    if sound_fragment_matches_door_action(&fragment, &action) {
        return true;
    }
    false
}

fn sound_fragment_has_high_value_acoustic_detail(fragment: &str) -> bool {
    [
        "急促",
        "沉重",
        "细碎",
        "凌乱",
        "由远及近",
        "回响",
        "回荡",
        "吱呀",
        "砰",
        "轰",
        "巨响",
        "闷响",
        "脆响",
        "刺耳",
        "低鸣",
        "风声",
        "雨声",
        "滴答",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

fn sound_fragment_is_low_signal_ambient(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() || sound_fragment_has_high_value_acoustic_detail(&normalized) {
        return false;
    }

    let generic_ambient = [
        "背景音乐",
        "音乐渐起",
        "配乐渐起",
        "氛围音乐",
        "一片死寂",
        "四周死寂",
        "四周寂静",
        "周围寂静",
        "环境安静",
        "安静无声",
        "空气凝固",
        "气氛压抑",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword));
    if !generic_ambient {
        return false;
    }

    ![
        "风声", "雨声", "脚步", "足音", "门", "敲", "回响", "回荡", "滴答", "雷声", "水声",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
}

fn sound_fragment_matches_footstep_action(fragment: &str, action: &str) -> bool {
    (fragment.contains("脚步") || fragment.contains("足音"))
        && [
            "走近", "逼近", "靠近", "走来", "奔来", "跑来", "冲来", "踏入", "闯入", "离开", "走开",
            "退开",
        ]
        .iter()
        .any(|keyword| action.contains(keyword))
}

fn sound_fragment_matches_door_action(fragment: &str, action: &str) -> bool {
    let is_door_sound = [
        "敲门声",
        "敲门",
        "门响",
        "开门声",
        "关门声",
        "门被推开",
        "门被拉开",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword));
    is_door_sound
        && ["推门", "开门", "关门", "拉门", "夺门", "闯入"]
            .iter()
            .any(|keyword| action.contains(keyword))
}

fn canonical_dialogue_fragment(value: &str) -> String {
    let mut canonical = normalize_prompt_text(value)
        .trim_matches(|ch: char| {
            ch.is_whitespace()
                || matches!(
                    ch,
                    '"' | '\'' | '“' | '”' | '‘' | '’' | '「' | '」' | '『' | '』' | ':' | '：'
                )
        })
        .to_string();
    loop {
        let mut changed = false;
        for prefix in [
            "低声说",
            "轻声说",
            "小声说",
            "喃喃道",
            "喃喃说",
            "呢喃",
            "说道",
            "说出",
            "说",
            "喊道",
            "喊出",
            "大喊",
            "呼喊",
            "叫喊",
            "质问",
            "回答",
            "回应",
            "重复",
            "台词",
            "对白",
            "旁白",
        ] {
            if let Some(stripped) = canonical.strip_prefix(prefix) {
                canonical = stripped
                    .trim_start_matches(|ch: char| {
                        ch.is_whitespace()
                            || matches!(
                                ch,
                                '"' | '\''
                                    | '“'
                                    | '”'
                                    | '‘'
                                    | '’'
                                    | '「'
                                    | '」'
                                    | '『'
                                    | '』'
                                    | ':'
                                    | '：'
                            )
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

fn speech_like_fragment(fragment: &str) -> bool {
    [
        "说", "喊", "台词", "对白", "旁白", "低声", "轻声", "呢喃", "喃喃", "口播", "voice",
        "dialogue",
    ]
    .iter()
    .any(|keyword| fragment.contains(keyword))
}

fn select_video_prompt_memory_notes(
    rows: &[AgentMemoryRow],
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    storyboard_row: Option<&StoryboardPromptSeedRow>,
) -> Vec<String> {
    let structured_fields = storyboard_row
        .and_then(|row| row.video_desc.as_deref())
        .and_then(parse_structured_storyboard_description);
    let seeded_match_exists = rows.iter().any(|row| {
        row.name == "auto_scope_memory"
            && auto_scope_memory_tool_matches_video_prompt(row.content.as_str())
            && memory_storyboard_overlap_score(row.content.as_str(), storyboard_numeric_id) > 0
            && memory_prompt_seed_matches(
                row.content.as_str(),
                storyboard_numeric_id,
                current_prompt_seed,
            )
    });
    let mut scored = rows
        .iter()
        .filter_map(|row| {
            if row.name != "auto_scope_memory" {
                return None;
            }
            let content = row.content.as_str();
            if !auto_scope_memory_tool_matches_video_prompt(content) {
                return None;
            }
            if !auto_scope_memory_matches_current_prompt_seed(
                content,
                storyboard_numeric_id,
                current_prompt_seed,
                seeded_match_exists,
            ) {
                return None;
            }
            let score = memory_storyboard_overlap_score(content, storyboard_numeric_id);
            if score <= 0 {
                return None;
            }
            let note = extract_key_value(content, "summary")
                .or_else(|| extract_key_value(content, "result"))
                .and_then(|value| {
                    compact_storyboard_memory_continuity_note(&value, structured_fields.as_ref())
                })
                .and_then(|value| compact_auto_scope_continuity_summary(&value))
                .or_else(|| {
                    extract_key_value(content, "summary")
                        .or_else(|| extract_key_value(content, "result"))
                        .and_then(|value| {
                            compact_auto_scope_continuity_summary(&clip_prompt_fragment(
                                &value,
                                VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
                            ))
                        })
                })?;
            let continuity_score = score_continuity_note(&note, structured_fields.as_ref());
            if continuity_score <= 0 {
                return None;
            }
            let specificity_score = score_continuity_specificity(&note);
            Some((
                score + continuity_score + specificity_score,
                specificity_score,
                continuity_score,
                note,
            ))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then(b.0.cmp(&a.0))
            .then(b.2.cmp(&a.2))
            .then(a.3.len().cmp(&b.3.len()))
            .then(a.3.cmp(&b.3))
    });

    let mut notes = Vec::new();
    for (_, _, _, note) in scored {
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

fn auto_scope_memory_tool_matches_video_prompt(content: &str) -> bool {
    extract_key_value(content, "tool").is_some_and(|tool| {
        matches!(
            tool.as_str(),
            "run_sub_agent_storyboard_panel"
                | "run_sub_agent_storyboard_gen"
                | "run_sub_agent_production_supervision"
                | "run_sub_agent_director_plan"
        )
    })
}

fn auto_scope_memory_matches_current_prompt_seed(
    content: &str,
    storyboard_numeric_id: i32,
    current_prompt_seed: Option<&str>,
    seeded_match_exists: bool,
) -> bool {
    match current_prompt_seed.filter(|seed| !seed.is_empty()) {
        Some(seed) => match memory_prompt_seed_for_storyboard(content, storyboard_numeric_id) {
            Some(candidate_seed) => candidate_seed == seed,
            None => !seeded_match_exists,
        },
        None => true,
    }
}

fn compact_auto_scope_continuity_summary(note: &str) -> Option<String> {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return None;
    }

    let fragments = split_prompt_note_fragments(&normalized)
        .map(|fragment| strip_auto_scope_continuity_scaffolding(&fragment))
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>();
    let fragments = compact_auto_scope_continuity_fragments(fragments);
    if fragments.is_empty() {
        return None;
    }

    Some(clip_prompt_fragment(
        &fragments.join("，"),
        VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS,
    ))
}

fn compact_auto_scope_continuity_fragments(fragments: Vec<String>) -> Vec<String> {
    let mut kept = Vec::new();
    for fragment in fragments {
        if kept.iter().any(|existing| existing == &fragment) {
            continue;
        }
        kept.push(fragment);
    }

    let has_specific_guidance = kept
        .iter()
        .any(|fragment| continuity_note_adds_specific_guidance(fragment));
    kept.iter()
        .filter(|fragment| {
            !auto_scope_continuity_fragment_is_covered(fragment, &kept, has_specific_guidance)
        })
        .cloned()
        .collect()
}

fn auto_scope_continuity_fragment_is_covered(
    candidate: &str,
    fragments: &[String],
    has_specific_guidance: bool,
) -> bool {
    if auto_scope_continuity_fragment_is_generic(candidate) && has_specific_guidance {
        return true;
    }

    let candidate_axis = auto_scope_continuity_axis(candidate);
    let candidate_specificity = score_continuity_specificity(candidate);
    fragments.iter().any(|other| {
        if other == candidate {
            return false;
        }
        let same_axis = candidate_axis != AutoScopeContinuityAxis::None
            && candidate_axis == auto_scope_continuity_axis(other);
        same_axis
            && score_continuity_specificity(other) > candidate_specificity
            && auto_scope_continuity_fragments_share_anchor(candidate, other)
    })
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AutoScopeContinuityAxis {
    None,
    Positioning,
    Rhythm,
}

fn auto_scope_continuity_axis(fragment: &str) -> AutoScopeContinuityAxis {
    let normalized = normalize_prompt_text(fragment);
    if normalized.is_empty() {
        return AutoScopeContinuityAxis::None;
    }
    if [
        "跳轴",
        "视线",
        "方向",
        "构图",
        "站位",
        "走位",
        "位置",
        "前后景",
    ]
    .iter()
    .any(|keyword| normalized.contains(keyword))
    {
        return AutoScopeContinuityAxis::Positioning;
    }
    if ["节奏", "动作"]
        .iter()
        .any(|keyword| normalized.contains(keyword))
    {
        return AutoScopeContinuityAxis::Rhythm;
    }
    AutoScopeContinuityAxis::None
}

fn auto_scope_continuity_fragments_share_anchor(left: &str, right: &str) -> bool {
    let left = normalize_prompt_text(left);
    let right = normalize_prompt_text(right);
    if left.is_empty() || right.is_empty() {
        return false;
    }
    [
        "跳轴",
        "视线",
        "方向",
        "构图",
        "站位",
        "走位",
        "位置",
        "前后景",
        "节奏",
        "动作",
    ]
    .iter()
    .any(|keyword| left.contains(keyword) && right.contains(keyword))
}

fn auto_scope_continuity_fragment_is_generic(fragment: &str) -> bool {
    let normalized = normalize_prompt_text(fragment);
    !normalized.is_empty()
        && !continuity_note_adds_specific_guidance(&normalized)
        && ["衔接", "连续", "统一", "一致", "延续", "保持"]
            .iter()
            .any(|keyword| normalized.contains(keyword))
}

fn strip_auto_scope_continuity_scaffolding(fragment: &str) -> String {
    let mut compacted = normalize_prompt_text(fragment);
    if compacted.is_empty() {
        return compacted;
    }

    for pattern in [
        "当前镜头已确认的",
        "当前分镜已确认的",
        "本镜头已确认的",
        "该镜头已确认的",
        "当前镜头已确认",
        "当前分镜已确认",
        "本镜头已确认",
        "该镜头已确认",
    ] {
        compacted = compacted.replace(pattern, "");
    }
    for pattern in ["当前镜头", "当前分镜", "本镜头", "该镜头"] {
        compacted = compacted.replace(pattern, "");
    }
    compacted = normalize_prompt_text(&compacted);
    if compacted == "已确认" || compacted == "镜头已确认" || compacted == "分镜已确认"
    {
        return String::new();
    }
    clip_prompt_fragment(&compacted, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS)
}

fn compact_storyboard_memory_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> Option<String> {
    let compacted = compact_video_continuity_note(note)?;
    let Some(fields) = structured_fields else {
        return Some(compacted);
    };

    let fragments = compacted
        .split(['，', ',', '；', ';', '。', '\n'])
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .filter_map(|fragment| {
            trim_continuity_fragment_against_storyboard_fields(&fragment, fields)
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

fn score_continuity_note(
    note: &str,
    structured_fields: Option<&StructuredStoryboardDescription>,
) -> i32 {
    let mut score = 0;
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return score;
    }
    for fragment in split_prompt_note_fragments(&normalized) {
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
        for fragment in split_prompt_note_fragments(&normalized) {
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

fn score_continuity_specificity(note: &str) -> i32 {
    let normalized = normalize_prompt_text(note);
    if normalized.is_empty() {
        return 0;
    }

    normalized
        .split('，')
        .map(normalize_prompt_text)
        .filter(|fragment| !fragment.is_empty())
        .map(|fragment| {
            let mut score = 0;
            if fragment.contains("跳轴") {
                score += 20;
            }
            if ["视线", "构图", "方向"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 16;
            }
            if ["站位", "走位", "位置", "前后景"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 12;
            }
            if ["节奏", "动作"]
                .iter()
                .any(|keyword| fragment.contains(keyword))
            {
                score += 8;
            }
            score
        })
        .sum()
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
        build_video_prompt, compact_camera_clause,
        compact_negative_constraint_against_storyboard_style, compact_script_asset_anchor,
        parse_structured_storyboard_description, prune_low_signal_observation_candidates,
        resolve_observation_filter_style_note, resolve_video_prompt_duration,
        score_video_prompt_observation_specificity, select_best_video_prompt_observation_note,
        select_script_asset_anchors, select_video_prompt_asset_seed_rows,
        select_video_prompt_memory_notes, select_video_prompt_style_notes,
        trim_video_prompt_memory_rows, trim_video_prompt_observation_rows,
        video_prompt_observation_conflicts_with_style,
        video_prompt_observation_is_irrelevant_to_storyboard, GenerateVideoPromptResponse,
        ScriptRolePromptSeedRow, VideoPromptContext, VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT,
    };
    use crate::production::workbench::video_prompt_memory::{
        select_neighbor_selected_video_memory_notes, select_prioritized_video_style_note,
        select_project_video_style_memory_notes, select_script_video_style_memory_notes,
        AgentMemoryRow, StoryboardPromptSeedRow,
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
    fn build_video_prompt_skips_mood_and_lighting_when_style_anchor_already_covers_them() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑."), "{prompt}");
        assert!(prompt.contains("Mood: 冷峻压迫."), "{prompt}");
        assert!(prompt.contains("Lighting: 冷调逆光."), "{prompt}");
    }

    #[test]
    fn build_video_prompt_keeps_mood_and_lighting_when_style_anchor_is_generic() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片悬疑."));
        assert!(!prompt.contains("镜头衔接统一."));
        assert!(prompt.contains("Mood: 冷峻压迫."));
        assert!(prompt.contains("Lighting: 冷调逆光."));
    }

    #[test]
    fn build_video_prompt_skips_continuity_fragments_covered_after_prefix_trim() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光".into()],
            continuity_notes: vec!["保持上一镜头冷峻压迫，保留上一镜头走位连续".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 情绪冷峻压迫，光影冷调逆光."));
        assert!(prompt.contains("Continuity notes: 保留上一镜头走位连续."));
        assert!(!prompt.contains("Continuity notes: 保持上一镜头冷峻压迫"));
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
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，场景旧宅走廊，情绪冷峻压迫".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感; 情绪冷峻压迫."),
            "{prompt}"
        );
        assert!(!prompt.contains("镜头稳定跟拍"));
        assert!(!prompt.contains("场景旧宅走廊"));
    }

    #[test]
    fn build_video_prompt_trims_redundant_camera_half_but_keeps_extra_style_hint() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、稳定跟拍、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍压迫感，光影冷调逆光颗粒".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 镜头压迫感，光影颗粒."),
            "{prompt}"
        );
        assert_eq!(prompt.matches("稳定跟拍").count(), 1, "{prompt}");
        assert!(!prompt.contains("光影冷调逆光颗粒"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_exact_storyboard_style_from_selected_memory_note() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头中景稳定跟拍，情绪急迫，光影阴天冷光".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑."), "{prompt}");
        assert!(!prompt.contains("镜头中景稳定跟拍"), "{prompt}");
        assert!(prompt.contains("Mood: 急迫."), "{prompt}");
        assert!(prompt.contains("Lighting: 阴天冷光."), "{prompt}");
    }

    #[test]
    fn compact_camera_clause_drops_axes_already_covered_by_style_anchor() {
        let camera = compact_camera_clause(
            "低机位近景",
            "稳定跟拍",
            &["镜头低机位近景稳定跟拍电影感".to_string()],
        );

        assert_eq!(camera, None);
    }

    #[test]
    fn compact_camera_clause_keeps_only_uncovered_axis() {
        let camera = compact_camera_clause("中景", "稳定跟拍", &["镜头稳定跟拍压迫感".to_string()]);

        assert_eq!(camera.as_deref(), Some("中景"));
    }

    #[test]
    fn build_video_prompt_deduplicates_semantic_style_fragments_across_sources() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感，情绪冷峻压迫".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
            "{prompt}"
        );
        assert_eq!(prompt.matches("低机位压迫感").count(), 1, "{prompt}");
        assert!(!prompt.contains("镜头低机位压迫感"), "{prompt}");
        assert!(prompt.contains("Mood: 冷峻压迫."), "{prompt}");
    }

    #[test]
    fn build_video_prompt_deduplicates_prefixed_memory_style_against_director_style_phrase() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持冷峻压迫风格，冷调逆光质感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["情绪冷峻压迫，光影冷调逆光，镜头低机位压迫感".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt
                .contains("Style anchor: 胶片悬疑; 冷峻压迫风格, 冷调逆光质感; 镜头低机位压迫感."),
            "{prompt}"
        );
        assert_eq!(prompt.matches("冷峻压迫").count(), 2, "{prompt}");
        assert_eq!(prompt.matches("冷调逆光").count(), 2, "{prompt}");
        assert!(!prompt.contains("情绪冷峻压迫"), "{prompt}");
        assert!(!prompt.contains("光影冷调逆光"), "{prompt}");
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
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头稳定跟拍，场景旧宅走廊".into()],
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑."));
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
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感, 光影偏冷."),
            "{prompt}"
        );
        assert!(!prompt.contains("Format:"));
        assert!(!prompt.contains("镜头衔接统一"));
    }

    #[test]
    fn build_video_prompt_trims_project_director_style_half_already_covered_by_storyboard() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("光影冷调逆光颗粒，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 光影颗粒."),
            "{prompt}"
        );
        assert!(!prompt.contains("光影冷调逆光颗粒"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_project_art_style_fragments_already_covered_elsewhere() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片颗粒，冷调逆光，冷峻压迫".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片颗粒."), "{prompt}");
        assert!(!prompt.contains("冷调逆光;"));
        assert!(!prompt.contains("冷峻压迫;"));
    }

    #[test]
    fn build_video_prompt_drops_generic_director_visual_placeholders() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头语言统一，风格统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 质感克制粗粝."),
            "{prompt}"
        );
        assert!(!prompt.contains("镜头语言统一"), "{prompt}");
        assert!(!prompt.contains("风格统一"), "{prompt}");
        assert!(
            prompt.contains("Natural motion, stable continuity, no extra shot changes."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_keeps_concrete_director_fragment_while_dropping_generic_visual_placeholder(
    ) {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头语言统一，保持低机位压迫感，光影一致".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
            "{prompt}"
        );
        assert!(!prompt.contains("镜头语言统一"), "{prompt}");
        assert!(!prompt.contains("光影一致"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_director_manual_fragments_already_covered_by_storyboard() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("镜头稳定跟拍，情绪急迫，光影阴天冷光，镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑."));
        assert!(!prompt.contains("镜头稳定跟拍"));
        assert!(!prompt.contains("情绪急迫"));
        assert!(!prompt.contains("光影阴天冷光"));
    }

    #[test]
    fn build_video_prompt_prioritizes_high_value_director_manual_fragments() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("场景旧宅走廊，保持低机位压迫感，镜头衔接统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感, 质感克制粗粝."));
        assert!(!prompt.contains("场景旧宅走廊"));
        assert!(!prompt.contains("镜头衔接统一"));
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

        assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."),);
        assert!(!prompt.contains("路人:灰色外套"));
        assert!(!prompt.contains("Subject: 主角."));
    }

    #[test]
    fn build_video_prompt_keeps_only_strongest_matching_role_anchor() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角扶住同伴冲出旧宅、旧宅走廊、主角/同伴、5秒、中景、稳定跟拍、扶住同伴冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "同伴: 灰色毛衣，神情惊惶".into(),
                "主角: 黑色风衣，短发，克制冷峻".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
        assert!(!prompt.contains("同伴:灰色毛衣，神情惊惶"));
    }

    #[test]
    fn build_video_prompt_skips_generic_role_anchor_without_describe() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 视觉设定延续".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(!prompt.contains("Character anchor:"), "{prompt}");
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
        assert!(!prompt.contains("Setting: 旧宅走廊."));
    }

    #[test]
    fn build_video_prompt_skips_generic_scene_and_tool_anchor_without_describe() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 场景设定延续".into()],
            script_tool_anchors: vec!["青铜匕首: 道具设定延续".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(!prompt.contains("Scene anchor:"), "{prompt}");
        assert!(!prompt.contains("Prop anchor:"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_compacts_subject_and_action_leading_role_name_when_anchored() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅走廊、旧宅走廊、主角、5秒、中景、稳定跟拍、主角快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
        assert!(prompt.contains("Subject: 冲出旧宅走廊."));
        assert!(prompt.contains("Action: 快步推门冲出."));
        assert!(!prompt.contains("Action: 主角快步推门冲出."));
    }

    #[test]
    fn build_video_prompt_trims_subject_action_overlap_when_subject_identity_remains() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Subject: 主角."), "{prompt}");
        assert!(
            prompt.contains("Action: 快步推门冲出旧宅后回望."),
            "{prompt}"
        );
        assert!(!prompt.contains("Subject: 主角冲出旧宅."), "{prompt}");
    }

    #[test]
    fn build_video_prompt_drops_subject_after_overlap_trim_when_role_anchor_already_covers_identity(
    ) {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出旧宅后回望、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Character anchor: 主角:黑色风衣，短发，克制冷峻."));
        assert!(!prompt.contains("Subject:"), "{prompt}");
        assert!(
            prompt.contains("Action: 快步推门冲出旧宅后回望."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_role_anchor_fragment_that_mostly_repeats_prompt_mood() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Character anchor: 主角:短发."), "{prompt}");
        assert!(
            !prompt.contains("Character anchor: 主角:黑色风衣"),
            "{prompt}"
        );
        assert!(
            !prompt.contains("Character anchor: 主角:短发，克制冷峻"),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_role_anchor_fragment_that_repeats_prompt_lighting() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，阴天冷光侧边高光".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Character anchor: 主角:侧边高光."),
            "{prompt}"
        );
        assert!(!prompt.contains("Character anchor: 主角:黑色风衣，阴天冷光侧边高光."));
        assert_eq!(prompt.matches("阴天冷光").count(), 1, "{prompt}");
        assert_eq!(prompt.matches("黑色风衣").count(), 1, "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_role_anchor_fragment_that_repeats_prompt_subject() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（黑色风衣主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、冷峻、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣主角，短发碎发".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Character anchor: 主角:短发碎发."),
            "{prompt}"
        );
        assert!(!prompt.contains("Character anchor: 主角:黑色风衣主角，短发碎发."));
        assert_eq!(prompt.matches("黑色风衣主角").count(), 1, "{prompt}");
    }

    #[test]
    fn build_video_prompt_uses_subject_refs_to_keep_two_role_anchors_for_multi_character_shot() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（两人巷口对峙、雨夜巷口、主角/反派、5秒、中景、稳定跟拍、互相逼近、紧张压迫、冷调逆光、无台词、雨声脚步声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec![
                "主角: 黑色风衣，短发，左脸旧疤".into(),
                "反派: 湿发，深灰长外套，压低肩线".into(),
                "路人: 模糊背影".into(),
            ],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains(
                "Character anchor: 主角:黑色风衣，短发，左脸旧疤; 反派:湿发，深灰长外套，压低肩线."
            ),
            "{prompt}"
        );
        assert!(!prompt.contains("路人:模糊背影"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_drops_scene_anchor_when_it_only_repeats_existing_setting() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、潮湿斑驳的旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(!prompt.contains("Scene anchor:"), "{prompt}");
        assert!(!prompt.contains("Setting: 潮湿斑驳的旧宅走廊."), "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_scene_anchor_fragment_that_repeats_prompt_lighting() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，阴天冷光积水反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，积水反光."),
            "{prompt}"
        );
        assert!(!prompt.contains("旧宅走廊:潮湿斑驳，阴天冷光积水反光."));
        assert_eq!(prompt.matches("阴天冷光").count(), 1, "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_scene_anchor_fragment_that_repeats_prompt_setting() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊、主角、5秒、中景、稳定跟拍、驻足抬眼观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec!["旧宅走廊: 旧宅走廊尽头积水反光".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Scene anchor: 旧宅走廊:尽头积水反光."),
            "{prompt}"
        );
        assert!(!prompt.contains("Scene anchor: 旧宅走廊:旧宅走廊尽头积水反光."));
        assert_eq!(prompt.matches("旧宅走廊").count(), 1, "{prompt}");
    }

    #[test]
    fn build_video_prompt_compacts_tool_prefix_action_when_anchor_already_covers_prop() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首快步穿行、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首快步穿行并回头确认、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制."));
        assert!(prompt.contains("Action: 快步穿行并回头确认."));
        assert!(!prompt.contains("Action: 握紧青铜匕首快步穿行并回头确认."));
    }

    #[test]
    fn build_video_prompt_keeps_tool_prefix_action_when_no_followup_motion_exists() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧青铜匕首、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Action: 握紧青铜匕首."));
    }

    #[test]
    fn build_video_prompt_keeps_two_tool_anchors_for_multi_prop_shot() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊握紧青铜匕首撬开门锁、旧宅走廊、主角/青铜匕首/门锁、5秒、中景、稳定跟拍、握紧匕首撬开门锁后回头确认、急迫、阴天冷光、无台词、金属摩擦声脚步声、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec![
                "门锁: 生锈锁芯，金属划痕".into(),
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
                "雨伞: 黑伞".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Prop anchor: 门锁:生锈锁芯，金属划痕; 青铜匕首:刀身旧磨损，寒光克制."),
            "{prompt}"
        );
        assert!(!prompt.contains("雨伞:黑伞"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_compacts_setting_prefix_already_covered_by_scene_anchor() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足观察、旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、缓慢停步抬头观察、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
        assert!(prompt.contains("Setting: 尽头的门厅."));
        assert!(!prompt.contains("Setting: 旧宅走廊尽头的门厅."));
    }

    #[test]
    fn build_video_prompt_trims_subject_lead_in_from_setting_when_subject_already_exists() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角驻足、主角身后的门厅、主角、5秒、中景、稳定跟拍、抬眼观察、紧张、阴天冷光、无台词、脚步回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Setting: 门厅."), "{prompt}");
        assert!(!prompt.contains("Setting: 主角身后的门厅."), "{prompt}");
    }

    #[test]
    fn build_video_prompt_drops_subject_when_compaction_makes_it_duplicate_action() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角快步推门冲出、旧宅走廊、主角、5秒、中景、稳定跟拍、主角快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(!prompt.contains("Subject:"));
        assert!(prompt.contains("Action: 快步推门冲出."));
    }

    #[test]
    fn build_video_prompt_trims_dialogue_payload_from_action_when_motion_remains() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头并低声说你终于来了、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Action: 驻足回头."), "{prompt}");
        assert!(
            !prompt.contains("Action: 驻足回头并低声说你终于来了."),
            "{prompt}"
        );
        assert!(
            prompt.contains("Dialogue or voice-over: 你终于来了."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_keeps_action_when_only_dialogue_delivery_remains() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、低声说你终于来了、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Action: 低声说你终于来了."), "{prompt}");
        assert!(
            prompt.contains("Dialogue or voice-over: 你终于来了."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_compacts_leading_bridge_before_scene_prefix() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Setting: 门厅."), "{prompt}");
        assert!(prompt.contains("Action: 停步回头."), "{prompt}");
        assert!(!prompt.contains("Setting: 尽头的门厅."), "{prompt}");
        assert!(!prompt.contains("Action: 尽头停步回头."), "{prompt}");
        assert!(!prompt.contains("Setting: 在旧宅走廊尽头的门厅."));
        assert!(!prompt.contains("Action: 在旧宅走廊尽头停步回头."));
    }

    #[test]
    fn build_video_prompt_keeps_strongest_scene_anchor_but_two_directly_referenced_tool_anchors() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊握紧青铜匕首回头、旧宅走廊/门厅、主角/青铜匕首/门锁、5秒、中景、稳定跟拍、握紧匕首回头、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "门厅: 破损玻璃，潮湿回声".into(),
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
            ],
            script_tool_anchors: vec![
                "门锁: 生锈锁芯".into(),
                "青铜匕首: 刀身旧磨损，寒光克制".into(),
            ],
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
        assert!(
            prompt.contains("Prop anchor: 青铜匕首:刀身旧磨损，寒光克制; 门锁:生锈锁芯.")
                || prompt.contains("Prop anchor: 门锁:生锈锁芯; 青铜匕首:刀身旧磨损，寒光克制."),
            "{prompt}"
        );
        assert!(!prompt.contains("门厅:破损玻璃，潮湿回声"));
    }

    #[test]
    fn compact_script_asset_anchor_skips_empty_describe_instead_of_emitting_generic_placeholder() {
        assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
            asset_type: "role".into(),
            name: Some("主角".into()),
            describe: None,
        })
        .is_none());
        assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
            asset_type: "scene".into(),
            name: Some("旧宅走廊".into()),
            describe: Some("   ".into()),
        })
        .is_none());
        assert!(compact_script_asset_anchor(ScriptRolePromptSeedRow {
            asset_type: "tool".into(),
            name: Some("青铜匕首".into()),
            describe: None,
        })
        .is_none());
    }

    #[test]
    fn select_video_prompt_asset_seed_rows_keeps_per_type_budget_instead_of_global_recent_rows() {
        let rows = (0..8)
            .map(|idx| ScriptRolePromptSeedRow {
                asset_type: "role".into(),
                name: Some(format!("角色{idx}")),
                describe: Some("黑色风衣".into()),
            })
            .chain((0..3).map(|idx| ScriptRolePromptSeedRow {
                asset_type: "scene".into(),
                name: Some(format!("场景{idx}")),
                describe: Some("潮湿长廊".into()),
            }))
            .chain((0..3).map(|idx| ScriptRolePromptSeedRow {
                asset_type: "tool".into(),
                name: Some(format!("道具{idx}")),
                describe: Some("旧磨损".into()),
            }))
            .collect::<Vec<_>>();

        let selected = select_video_prompt_asset_seed_rows(rows);
        let role_count = selected
            .iter()
            .filter(|row| row.asset_type == "role")
            .count();
        let scene_count = selected
            .iter()
            .filter(|row| row.asset_type == "scene")
            .count();
        let tool_count = selected
            .iter()
            .filter(|row| row.asset_type == "tool")
            .count();

        assert_eq!(role_count, VIDEO_PROMPT_ROLE_ASSET_ROW_LIMIT);
        assert_eq!(scene_count, 3);
        assert_eq!(tool_count, 3);
    }

    #[test]
    fn select_video_prompt_asset_seed_rows_skips_unknown_asset_types() {
        let selected = select_video_prompt_asset_seed_rows(vec![
            ScriptRolePromptSeedRow {
                asset_type: "role".into(),
                name: Some("主角".into()),
                describe: Some("黑色风衣".into()),
            },
            ScriptRolePromptSeedRow {
                asset_type: "vehicle".into(),
                name: Some("摩托".into()),
                describe: Some("破旧".into()),
            },
        ]);

        assert_eq!(selected.len(), 1);
        assert_eq!(selected[0].asset_type, "role");
    }

    #[test]
    fn select_script_asset_anchors_keeps_multiple_ranked_results_when_requested() {
        let selected = select_script_asset_anchors(
            vec![
                (120, 0, "主角:黑色风衣".into()),
                (110, 1, "反派:深灰长外套".into()),
                (90, 2, "路人:模糊背影".into()),
            ],
            2,
        );

        assert_eq!(
            selected,
            vec!["主角:黑色风衣".to_string(), "反派:深灰长外套".to_string()]
        );
    }

    #[test]
    fn build_video_prompt_keeps_two_scene_anchors_for_transition_shot() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角在旧宅走廊尽头回头、在旧宅走廊尽头的门厅、主角、5秒、中景、稳定跟拍、在旧宅走廊尽头停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
                "医院门厅: 冷白瓷砖，回声明亮".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains(
                "Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊; 旧宅门厅:破损玻璃，潮湿回声."
            ) || prompt.contains(
                "Scene anchor: 旧宅门厅:破损玻璃，潮湿回声; 旧宅走廊:潮湿斑驳，冷色长廊."
            ),
            "{prompt}"
        );
        assert!(!prompt.contains("医院门厅:冷白瓷砖，回声明亮"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_keeps_two_scene_anchors_for_structured_multi_setting_shot() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅门厅/走廊尽头、主角、5秒、中景、稳定跟拍、停步回头确认身后动静、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
                "医院门厅: 冷白瓷砖，回声明亮".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains(
                "Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊; 旧宅门厅:破损玻璃，潮湿回声."
            ) || prompt.contains(
                "Scene anchor: 旧宅门厅:破损玻璃，潮湿回声; 旧宅走廊:潮湿斑驳，冷色长廊."
            ),
            "{prompt}"
        );
        assert!(!prompt.contains("医院门厅:冷白瓷砖，回声明亮"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_keeps_single_scene_anchor_for_regular_shot() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅走廊、主角、5秒、中景、稳定跟拍、停步回头、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: vec![
                "旧宅走廊: 潮湿斑驳，冷色长廊".into(),
                "旧宅门厅: 破损玻璃，潮湿回声".into(),
            ],
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Scene anchor: 旧宅走廊:潮湿斑驳，冷色长廊."));
        assert!(!prompt.contains("旧宅门厅:破损玻璃，潮湿回声"), "{prompt}");
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
        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
            "{prompt}"
        );
        assert!(
            prompt.contains("Continuity notes: 保留上一镜头走位连续."),
            "{prompt}"
        );
        assert!(!prompt.contains("Continuity notes: 黑色风衣"));
        assert!(!prompt.contains("Continuity notes: 冷色长廊"));
        assert!(!prompt.contains("Continuity notes: 刀身旧磨损"));
        assert!(!prompt.contains("Continuity notes: 保持低机位压迫感"));
        assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
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
        assert!(prompt.contains("Natural motion, no extra shot changes."));
    }

    #[test]
    fn build_video_prompt_prefers_axis_guidance_over_generic_continuity_under_single_note_budget() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保留上一镜头走位连续".into(), "人物站位不要跳轴".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Continuity notes: 人物站位不要跳轴."),
            "{prompt}"
        );
        assert!(
            !prompt.contains("Continuity notes: 保留上一镜头走位连续."),
            "{prompt}"
        );
        assert!(
            prompt.contains("Natural motion, no extra shot changes."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_leading_asset_coverage_from_fused_continuity_fragment() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角握紧青铜匕首穿过旧宅走廊、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、握紧匕首快步穿行、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣，短发，克制冷峻".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损，寒光克制".into()],
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["黑色风衣主角保留上一镜头走位连续".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Continuity notes: 保留上一镜头走位连续."),
            "{prompt}"
        );
        assert!(
            !prompt.contains("Continuity notes: 黑色风衣主角"),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_storyboard_subject_and_action_from_continuity_fragment() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["主角快步推门冲出保留上一镜头走位连续".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Continuity notes: 保留上一镜头走位连续."),
            "{prompt}"
        );
        assert!(!prompt.contains("主角快步推门冲出"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_drops_continuity_style_note_when_style_anchor_already_covers_it() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻压迫、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: Some("保持低机位压迫感".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头低机位压迫感，人物站位不要跳轴".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 低机位压迫感."),
            "{prompt}"
        );
        assert!(
            prompt.contains("Continuity notes: 人物站位不要跳轴."),
            "{prompt}"
        );
        assert!(
            !prompt.contains("Continuity notes: 保持上一镜头低机位压迫感"),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_drops_continuity_half_already_split_between_storyboard_and_style_anchor()
    {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["光影冷调逆光颗粒".into()],
            continuity_notes: vec!["保持上一镜头冷调逆光颗粒".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片冷调悬疑; 光影颗粒."),
            "{prompt}"
        );
        assert!(!prompt.contains("Continuity notes:"), "{prompt}");
        assert_eq!(prompt.matches("颗粒").count(), 1, "{prompt}");
    }

    #[test]
    fn build_video_prompt_shortens_quality_tail_when_camera_already_implies_stability() {
        let prompt = build_video_prompt(
            Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）"),
            None,
            Some(&VideoPromptContext {
                storyboard_prompt: None,
                storyboard_video_desc: None,
                storyboard_duration: None,
                storyboard_prompt_seed: None,
                project_art_style: None,
                project_director_manual: None,
                script_role_anchors: Vec::new(),
                script_scene_anchors: Vec::new(),
                script_tool_anchors: Vec::new(),
                memory_style_notes: Vec::new(),
                continuity_notes: Vec::new(),
            }),
        );

        assert!(prompt.contains("Natural motion, no extra shot changes."));
        assert!(!prompt.contains("Natural motion, stable continuity, no extra shot changes."));
    }

    #[test]
    fn build_video_prompt_keeps_full_quality_tail_without_continuity_signal() {
        let prompt = build_video_prompt(
            Some("主角在空旷仓库内缓慢抬头，周围静止无风。"),
            None,
            Some(&VideoPromptContext {
                storyboard_prompt: None,
                storyboard_video_desc: None,
                storyboard_duration: None,
                storyboard_prompt_seed: None,
                project_art_style: None,
                project_director_manual: None,
                script_role_anchors: Vec::new(),
                script_scene_anchors: Vec::new(),
                script_tool_anchors: Vec::new(),
                memory_style_notes: Vec::new(),
                continuity_notes: Vec::new(),
            }),
        );

        assert!(prompt.contains("Natural motion, stable continuity, no extra shot changes."));
    }

    #[test]
    fn build_video_prompt_keeps_full_quality_tail_when_generic_director_continuity_is_trimmed() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Style anchor: 胶片悬疑."), "{prompt}");
        assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
        assert!(
            prompt.contains("Natural motion, stable continuity, no extra shot changes."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_shortens_quality_tail_when_director_continuity_survives_style_anchor() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持稳定跟拍，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片悬疑; 稳定跟拍, 质感克制粗粝."),
            "{prompt}"
        );
        assert!(
            prompt.contains("Natural motion, no extra shot changes."),
            "{prompt}"
        );
        assert!(
            !prompt.contains("Natural motion, stable continuity, no extra shot changes."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_generic_continuity_clause_inside_fused_director_style_fragment() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("保持稳定跟拍且镜头衔接统一，质感克制粗粝".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片悬疑; 稳定跟拍, 质感克制粗粝."),
            "{prompt}"
        );
        assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
        assert!(
            prompt.contains("Natural motion, no extra shot changes."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_generic_continuity_clause_inside_fused_director_lighting_fragment()
    {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角逼近门厅、旧宅门厅、主角、5秒、中景、推进、停步回头、冷峻、冷调逆光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: Some("光影偏冷并保持镜头衔接统一".into()),
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: Vec::new(),
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片悬疑; 光影偏冷."),
            "{prompt}"
        );
        assert!(!prompt.contains("镜头衔接统一"), "{prompt}");
        assert!(
            prompt.contains("Natural motion, stable continuity, no extra shot changes."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_drops_generic_continuity_note_when_tail_already_covers_it() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头衔接统一".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(!prompt.contains("Continuity notes:"));
        assert!(prompt.contains("Natural motion, stable continuity, no extra shot changes."));
    }

    #[test]
    fn build_video_prompt_keeps_specific_continuity_guidance_while_dropping_generic_fragment() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、静止、快步推门冲出、急迫、阴天冷光、别回头、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: None,
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: Vec::new(),
            continuity_notes: vec!["保持上一镜头衔接统一，人物站位不要跳轴".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Continuity notes: 人物站位不要跳轴."));
        assert!(!prompt.contains("Continuity notes: 保持上一镜头衔接统一"));
        assert!(prompt.contains("Natural motion, no extra shot changes."));
    }

    #[test]
    fn build_video_prompt_supports_ascii_delimited_memory_style_and_continuity_notes() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、冷峻压迫、冷调逆光、无台词、脚步声门响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片悬疑".into()),
            project_director_manual: None,
            script_role_anchors: Vec::new(),
            script_scene_anchors: Vec::new(),
            script_tool_anchors: Vec::new(),
            memory_style_notes: vec!["镜头低机位压迫感, 情绪冷峻压迫; 光影冷调逆光颗粒".into()],
            continuity_notes: vec!["保持上一镜头冷峻压迫, 人物站位不要跳轴".into()],
        };

        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(
            prompt.contains("Style anchor: 胶片悬疑; 镜头低机位压迫感，光影颗粒."),
            "{prompt}"
        );
        assert!(
            prompt.contains("Continuity notes: 人物站位不要跳轴."),
            "{prompt}"
        );
        assert!(
            !prompt.contains("Continuity notes: 保持上一镜头冷峻压迫"),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_trims_sound_fragments_already_covered_by_dialogue() {
        let prompt = build_video_prompt(
            Some("（主角贴墙疾行、旧宅走廊、主角、5秒、中景、稳定跟拍、屏息快步贴墙前进、紧张、阴天冷光、别回头、低声说别回头，脚步声逼近、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Dialogue or voice-over: 别回头."));
        assert!(prompt.contains("Sound: 脚步声逼近."));
        assert!(!prompt.contains("Sound: 低声说别回头"));
    }

    #[test]
    fn build_video_prompt_compacts_dialogue_wrapper_prefixes() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、轻声说：你终于来了、风声回响、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Dialogue or voice-over: 你终于来了."));
        assert!(!prompt.contains("Dialogue or voice-over: 轻声说：你终于来了."));
    }

    #[test]
    fn build_video_prompt_drops_non_semantic_vocalization_dialogue() {
        let prompt = build_video_prompt(
            Some("（主角踉跄扶墙、废弃走廊、主角、5秒、中景、手持跟拍、踉跄扶墙前行、紧张压迫、冷调逆光、急促喘息、脚步声拖行、A12）"),
            None,
            None,
        );

        assert!(!prompt.contains("Dialogue or voice-over:"), "{prompt}");
        assert!(prompt.contains("Sound: 脚步声拖行."), "{prompt}");
    }

    #[test]
    fn build_video_prompt_trims_sound_against_compacted_dialogue() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、轻声说：你终于来了、轻声说你终于来了，风声回响、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Dialogue or voice-over: 你终于来了."));
        assert!(prompt.contains("Sound: 风声回响."));
        assert!(!prompt.contains("Sound: 轻声说你终于来了"));
    }

    #[test]
    fn build_video_prompt_keeps_semantic_short_dialogue() {
        let prompt = build_video_prompt(
            Some("（主角猛然回头、旧宅门厅、主角、5秒、中景、推进、猛然回头后抬手示警、紧张、冷调逆光、别出声、风声压过呼吸声、A12）"),
            None,
            None,
        );

        assert!(
            prompt.contains("Dialogue or voice-over: 别出声."),
            "{prompt}"
        );
    }

    #[test]
    fn build_video_prompt_drops_sound_clause_when_only_dialogue_wrapper_remains() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、你终于来了、轻声说你终于来了、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Dialogue or voice-over: 你终于来了."));
        assert!(!prompt.contains("Sound:"));
    }

    #[test]
    fn build_video_prompt_compacts_sound_wrapper_prefixes() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、无台词、伴随风声回响，传来木门吱呀声、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Sound: 风声回响，木门吱呀声."), "{prompt}");
        assert!(!prompt.contains("Sound: 伴随风声回响"));
        assert!(!prompt.contains("传来木门吱呀声"));
    }

    #[test]
    fn build_video_prompt_drops_sound_wrapper_when_only_dialogue_payload_remains() {
        let prompt = build_video_prompt(
            Some("（主角驻足回头、旧宅门厅、主角、5秒、中景、静止、驻足回头、压抑、冷调逆光、你终于来了、耳边传来轻声说你终于来了，空气里只剩无音效、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Dialogue or voice-over: 你终于来了."));
        assert!(!prompt.contains("Sound:"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_drops_low_signal_ambient_sound_clause() {
        let prompt = build_video_prompt(
            Some("（主角缓步推门、旧宅门厅、主角、5秒、中景、慢推、缓步推门进入、压抑、冷调逆光、无台词、背景音乐渐起，四周一片死寂、A12）"),
            None,
            None,
        );

        assert!(!prompt.contains("Sound:"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_drops_generic_footstep_sound_when_action_already_covers_it() {
        let prompt = build_video_prompt(
            Some("（黑衣人、走廊尽头、黑衣人、5秒、中景、慢推、脚步逼近门口、紧张、冷光、、脚步声逼近、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Action: 脚步逼近门口."), "{prompt}");
        assert!(!prompt.contains("Sound:"), "{prompt}");
    }

    #[test]
    fn build_video_prompt_keeps_detailed_door_sound_even_when_action_mentions_door() {
        let prompt = build_video_prompt(
            Some("（林夏、旧宅门厅、林夏、5秒、中景、推进、推门闯入、压迫、冷调逆光、无台词、门轴吱呀作响、A12）"),
            None,
            None,
        );

        assert!(prompt.contains("Action: 推门闯入."), "{prompt}");
        assert!(prompt.contains("Sound: 门轴吱呀作响."), "{prompt}");
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
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["保持镜头方向连续".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_trim_storyboard_subject_and_action_from_auto_scope_note() {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=主角快步推门冲出保留上一镜头走位连续".to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["保留上一镜头走位连续".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_prefers_specific_axis_guidance_over_generic_continuity() {
        let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=保留上一镜头走位连续".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物站位不要跳轴".to_string(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["人物站位不要跳轴".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_drops_generic_auto_scope_summary_without_continuity_guidance(
    ) {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=当前镜头已确认"
                    .to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty()
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_strips_current_shot_scaffolding_from_auto_scope_summary() {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持当前镜头角色站位不要跳轴".to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["保持角色站位不要跳轴".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_drops_generic_continuity_half_inside_same_summary() {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持当前镜头衔接统一，人物站位不要跳轴".to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["人物站位不要跳轴".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_drops_weaker_positioning_fragment_when_jump_axis_exists() {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持当前镜头角色站位连续，人物站位不要跳轴".to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["人物站位不要跳轴".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_supports_ascii_delimited_auto_scope_summary() {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=后续反派从暗处逼近, 保持当前镜头角色站位不要跳轴; 镜头中景稳定跟拍".to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)),
            vec!["保持角色站位不要跳轴".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_drops_auto_scope_summary_after_scaffolding_becomes_empty() {
        let rows = vec![AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=当前分镜已确认".to_string(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert!(
            select_video_prompt_memory_notes(&rows, 12, None, Some(&storyboard_row)).is_empty()
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_skips_stale_auto_scope_prompt_seed_when_current_seed_exists(
    ) {
        let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | storyboardPromptSeeds=12:seed-new | summary=人物站位不要跳轴".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | storyboardPromptSeeds=12:seed-old | result=保留上一镜头走位连续".to_string(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, Some("seed-new"), Some(&storyboard_row)),
            vec!["人物站位不要跳轴".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_memory_notes_skips_unseeded_auto_scope_fallback_when_current_seed_exists(
    ) {
        let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | storyboardPromptSeeds=12:seed-new | summary=人物站位不要跳轴".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=保留上一镜头走位连续".to_string(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角冲出旧宅".into()),
            video_desc: Some("（主角冲出旧宅、旧宅走廊、主角、5秒、中景、稳定跟拍、快步推门冲出、急迫、阴天冷光、无台词、脚步声门响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12, Some("seed-new"), Some(&storyboard_row)),
            vec!["人物站位不要跳轴".to_string()]
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
    fn select_video_prompt_style_notes_falls_back_to_matching_neighbor_style_fragments() {
        let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | note=女主贴墙前行，镜头稳定近景，情绪冷色压迫感".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、紧张、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_style_notes(&rows, 12, None, &storyboard_row),
            vec!["镜头稳定".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_style_notes_prefers_script_summary_over_neighbor_local_framing() {
        let rows = vec![
            AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=11 | style=镜头稳定近景，情绪克制 | note=镜头稳定近景，情绪克制".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=6 | style=情绪克制，光影潮湿路灯暖光，场景雨夜街口 | note=情绪克制，光影潮湿路灯暖光，场景雨夜街口".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、近景、稳定跟拍、停步抬头看向路灯、克制、暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_style_notes(&rows, 12, None, &storyboard_row),
            vec!["光影潮湿路灯".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_style_notes_trims_exact_storyboard_style_memory_to_residual_hint() {
        let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | style=镜头近景稳定跟拍，情绪紧张压迫，光影冷调逆光 | note=当前镜头已确认".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主转身回望".into()),
            video_desc: Some("（女主转身回望、旧宅走廊、女主、5秒、近景、稳定跟拍、回头确认身后动静、紧张、冷调逆光、无台词、脚步回响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_video_prompt_style_notes(&rows, 12, None, &storyboard_row),
            vec!["情绪压迫".to_string()]
        );
    }

    #[test]
    fn select_video_prompt_style_notes_skip_script_summary_that_only_repeats_storyboard_fields() {
        let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

        assert!(select_video_prompt_style_notes(&rows, 12, None, &storyboard_row).is_empty());
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
    fn trim_video_prompt_memory_rows_keeps_summary_memories_when_selected_rows_are_dense() {
        let mut rows = Vec::new();
        for id in (1..=8).rev() {
            rows.push(AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: format!("storyboardIds={id} | style=镜头中景稳定跟拍{id}"),
            });
        }
        rows.push(AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=4 | style=情绪冷峻压迫，光影冷调逆光".into(),
        });
        rows.push(AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=7 | style=镜头中景稳定跟拍，情绪冷峻压迫".into(),
        });
        rows.push(AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=保持走位连续"
                    .into(),
        });

        let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"));

        assert_eq!(
            trimmed
                .iter()
                .filter(|row| row.name == "selected_video_memory")
                .count(),
            6
        );
        assert_eq!(
            trimmed
                .iter()
                .filter(|row| row.name == "script_video_style_memory")
                .count(),
            1
        );
        assert_eq!(
            trimmed
                .iter()
                .filter(|row| row.name == "project_video_style_memory")
                .count(),
            1
        );
        assert_eq!(
            trimmed
                .iter()
                .filter(|row| row.name == "auto_scope_memory")
                .count(),
            1
        );
        assert!(trimmed.iter().any(|row| {
            row.name == "script_video_style_memory"
                && row.content.contains("情绪冷峻压迫，光影冷调逆光")
        }));
        assert!(trimmed.iter().any(|row| {
            row.name == "project_video_style_memory"
                && row.content.contains("镜头中景稳定跟拍，情绪冷峻压迫")
        }));
    }

    #[test]
    fn trim_video_prompt_memory_rows_prioritizes_matching_storyboard_memories_over_newer_noise() {
        let mut rows = Vec::new();
        for id in (20..=26).rev() {
            rows.push(AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: format!(
                    "storyboardIds={id} | promptSeed=seed-{id} | style=镜头中景稳定跟拍{id}"
                ),
            });
        }
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content:
                "storyboardIds=12 | promptSeed=seed-12-current | style=镜头中景稳定跟拍，情绪冷峻压迫"
                    .into(),
        });
        for id in (30..=36).rev() {
            rows.push(AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: format!(
                    "tool=run_sub_agent_storyboard_panel | scope=storyboardIds={id} | summary=别的镜头{id}"
                ),
            });
        }
        rows.push(AgentMemoryRow {
            name: "auto_scope_memory".into(),
            content:
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | summary=人物站位不要跳轴"
                    .into(),
        });

        let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"));

        assert!(trimmed.iter().any(|row| {
            row.name == "selected_video_memory"
                && row.content.contains("storyboardIds=12")
                && row.content.contains("promptSeed=seed-12-current")
        }));
        assert!(trimmed.iter().any(|row| {
            row.name == "auto_scope_memory" && row.content.contains("storyboardIds=12")
        }));
    }

    #[test]
    fn trim_video_prompt_memory_rows_keeps_current_prompt_seed_over_newer_stale_same_storyboard_rows(
    ) {
        let mut rows = Vec::new();
        for stale_seed in [
            "seed-12-stale-6",
            "seed-12-stale-5",
            "seed-12-stale-4",
            "seed-12-stale-3",
            "seed-12-stale-2",
            "seed-12-stale-1",
        ] {
            rows.push(AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={stale_seed} | style=镜头中景稳定跟拍，情绪冷峻压迫"
                ),
            });
        }
        rows.push(AgentMemoryRow {
            name: "selected_video_memory".into(),
            content:
                "storyboardIds=12 | promptSeed=seed-12-current | style=镜头近景稳定跟拍，情绪紧张压迫"
                    .into(),
        });

        let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"));

        assert!(trimmed.iter().any(|row| {
            row.name == "selected_video_memory"
                && row.content.contains("promptSeed=seed-12-current")
        }));
        assert_eq!(
            trimmed
                .iter()
                .filter(|row| row.name == "selected_video_memory")
                .count(),
            6
        );
    }

    #[test]
    fn trim_video_prompt_memory_rows_prefers_matching_auto_scope_prompt_seed_map_over_newer_stale_row(
    ) {
        let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12,14 | storyboardPromptSeeds=12:seed-12-current,14:seed-14-current | summary=保持当前镜头角色站位".into(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-stale | summary=旧版镜头走位".into(),
            },
        ];

        let trimmed = trim_video_prompt_memory_rows(rows, 12, Some("seed-12-current"));

        assert!(trimmed.iter().any(|row| {
            row.name == "auto_scope_memory"
                && row
                    .content
                    .contains("storyboardPromptSeeds=12:seed-12-current,14:seed-14-current")
        }));
    }

    #[test]
    fn trim_video_prompt_observation_rows_keeps_matching_rejection_row_over_newer_style_noise() {
        let mut rows = Vec::new();
        for _ in 0..12 {
            rows.push(AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=88 | promptSeed=noise-seed | style=别的镜头风格".into(),
            });
        }
        rows.push(AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | promptSeed=seed-12-current | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
        });

        let trimmed = trim_video_prompt_observation_rows(rows, 12, Some("seed-12-current"));

        assert!(trimmed.iter().any(|row| {
            row.name == "rejected_video_negative_memory"
                && row.content.contains("storyboardIds=12")
                && row.content.contains("promptSeed=seed-12-current")
        }));
    }

    #[test]
    fn trim_video_prompt_observation_rows_prefers_current_prompt_seed_over_newer_stale_rejection_rows(
    ) {
        let mut rows = Vec::new();
        for stale_seed in [
            "seed-12-stale-8",
            "seed-12-stale-7",
            "seed-12-stale-6",
            "seed-12-stale-5",
            "seed-12-stale-4",
            "seed-12-stale-3",
            "seed-12-stale-2",
            "seed-12-stale-1",
        ] {
            rows.push(AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: format!(
                    "storyboardIds=12 | promptSeed={stale_seed} | rejectionCount=1 | avoid=avoid flat cold lighting"
                ),
            });
        }
        rows.push(AgentMemoryRow {
            name: "rejected_video_negative_memory".into(),
            content: "storyboardIds=12 | promptSeed=seed-12-current | rejectionCount=1 | avoid=avoid shaky handheld motion".into(),
        });

        let trimmed = trim_video_prompt_observation_rows(rows, 12, Some("seed-12-current"));

        assert!(trimmed.iter().any(|row| {
            row.name == "rejected_video_negative_memory"
                && row.content.contains("promptSeed=seed-12-current")
        }));
        assert_eq!(
            trimmed
                .iter()
                .filter(|row| row.name == "rejected_video_negative_memory")
                .count(),
            8
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
            select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
            Some("情绪冷色压迫感，光影冷调逆光".to_string())
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_skips_script_and_project_style_when_context_mismatch_is_weak(
    ) {
        let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=8 | style=镜头环绕，情绪热烈，光影暖金逆光 | note=镜头环绕，情绪热烈，光影暖金逆光".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、静止镜头、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

        assert!(
            select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)).is_none()
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_allows_script_summary_when_multiple_fields_match() {
        let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=8 | style=镜头环绕，情绪热烈，光影暖金逆光 | note=镜头环绕，情绪热烈，光影暖金逆光".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
            Some("镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".to_string())
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_skips_exact_storyboard_selection_when_it_only_repeats_current_prompt(
    ) {
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
            select_prioritized_video_style_note(&rows, 12, None, None),
            Some("光影冷调逆光".to_string())
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_returns_empty_when_only_exact_storyboard_selection_exists() {
        let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=12 | style=镜头低机位压迫感，情绪克制 | note=镜头低机位压迫感，情绪克制".into(),
        }];

        assert!(select_prioritized_video_style_note(&rows, 12, None, None).is_none());
    }

    #[test]
    fn prioritized_video_prompt_memory_prefers_script_summary_over_neighbor_local_framing_when_context_is_missing(
    ) {
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
            select_prioritized_video_style_note(&rows, 12, None, None),
            Some("情绪冷色压迫感，光影冷调逆光".to_string())
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_keeps_neighbor_local_framing_when_no_summary_exists() {
        let rows = vec![AgentMemoryRow {
            name: "selected_video_memory".into(),
            content: "storyboardIds=11 | style=镜头稳定近景，情绪冷色压迫感 | note=镜头稳定近景，情绪冷色压迫感".into(),
        }];

        assert_eq!(
            select_prioritized_video_style_note(&rows, 12, None, None),
            Some("情绪冷色压迫感".to_string())
        );
    }

    #[test]
    fn prioritized_video_prompt_memory_prefers_shorter_summary_when_context_signal_is_equal() {
        let rows = vec![
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷色压迫感，光影冷调逆光 | note=镜头稳定跟拍，情绪冷色压迫感，光影冷调逆光".into(),
            },
            AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content: "sampleCount=5 | style=情绪冷色压迫感，光影冷调逆光 | note=情绪冷色压迫感，光影冷调逆光".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角在走廊里停步回头".into()),
            video_desc: Some("（主角停步回头、旧宅走廊、主角、5秒、中景、静止、停步回头、冷色压迫感、冷调逆光、无台词、风声回响、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            select_prioritized_video_style_note(&rows, 12, None, Some(&storyboard_row)),
            Some("情绪冷色压迫感，光影冷调逆光".to_string())
        );
    }

    #[test]
    fn resolve_observation_filter_style_note_skips_summary_that_only_repeats_storyboard_fields() {
        let rows = vec![AgentMemoryRow {
            name: "script_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光 | note=镜头稳定跟拍，情绪克制，光影潮湿路灯暖光".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("女主在雨夜街口停下".into()),
            video_desc: Some("（女主在雨夜街口停下、雨夜街口、女主、5秒、中景、稳定跟拍、停步抬头看向路灯、克制、潮湿路灯暖光、无台词、雨声车流、A12）".into()),
            duration: Some("5s".into()),
        };

        assert!(
            resolve_observation_filter_style_note(&rows, 12, None, Some(&storyboard_row)).is_none()
        );
    }

    #[test]
    fn generate_video_prompt_response_serializes_observation_note() {
        let value = serde_json::to_value(GenerateVideoPromptResponse {
            prompt: "Single cinematic shot.".into(),
            negative_prompt: None,
            observation_note: Some("待观察失败倾向：avoid shaky handheld motion".into()),
            diagnostics: GenerateVideoPromptDiagnostics {
                prompt_chars: 22,
                negative_prompt_chars: 0,
                observation_note_chars: 40,
                role_anchor_count: 1,
                scene_anchor_count: 1,
                tool_anchor_count: 0,
                style_anchor_count: 1,
                continuity_note_count: 0,
                uses_reference_frame: false,
            },
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
        assert_eq!(
            value
                .get("diagnostics")
                .and_then(|item| item.get("promptChars"))
                .and_then(serde_json::Value::as_u64),
            Some(22)
        );
    }

    #[test]
    fn build_video_prompt_with_diagnostics_reports_anchor_and_memory_counts() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: Some("（主角停步回头、旧宅走廊、主角/青铜匕首、5秒、中景、稳定跟拍、停步回头确认身后动静、压抑、阴天冷光、无台词、风声回响、A12）".into()),
            storyboard_duration: Some("5s".into()),
            storyboard_prompt_seed: None,
            project_art_style: Some("胶片冷调悬疑".into()),
            project_director_manual: None,
            script_role_anchors: vec!["主角: 黑色风衣".into()],
            script_scene_anchors: vec!["旧宅走廊: 潮湿斑驳，冷色长廊".into()],
            script_tool_anchors: vec!["青铜匕首: 刀身旧磨损".into()],
            memory_style_notes: vec!["镜头低机位压迫感".into()],
            continuity_notes: vec!["保留上一镜头走位连续".into()],
        };

        let result = build_video_prompt_with_diagnostics(
            None,
            Some("https://example.com/frame.png"),
            Some(&context),
        );

        assert!(result
            .prompt
            .contains("Use the supplied frame as the visual reference."));
        assert_eq!(result.diagnostics.role_anchor_count, 1);
        assert_eq!(result.diagnostics.scene_anchor_count, 1);
        assert_eq!(result.diagnostics.tool_anchor_count, 1);
        assert_eq!(result.diagnostics.style_anchor_count, 2);
        assert_eq!(result.diagnostics.continuity_note_count, 1);
        assert!(result.diagnostics.uses_reference_frame);
        assert!(result.diagnostics.prompt_chars > 0);
    }

    #[test]
    fn observation_note_conflict_filter_skips_style_conflicts() {
        assert!(video_prompt_observation_conflicts_with_style(
            "avoid flat cold lighting",
            Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
        assert!(video_prompt_observation_conflicts_with_style(
            "avoid oppressive or frantic mood",
            Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
    }

    #[test]
    fn observation_note_conflict_filter_keeps_non_conflicting_warnings() {
        assert!(!video_prompt_observation_conflicts_with_style(
            "avoid face drift or costume inconsistency",
            Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
            None,
        ));
        assert!(!video_prompt_observation_conflicts_with_style(
            "avoid flat cold lighting",
            None,
            None,
        ));
    }

    #[test]
    fn observation_note_conflict_filter_can_fall_back_to_next_candidate() {
        let note = [
            "avoid flat cold lighting".to_string(),
            "avoid shaky handheld motion".to_string(),
        ]
        .into_iter()
        .find(|note| {
            !video_prompt_observation_conflicts_with_style(
                note,
                Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"),
                None,
            )
        });

        assert_eq!(note, Some("avoid shaky handheld motion".to_string()));
    }

    #[test]
    fn select_best_video_prompt_observation_note_prefers_specific_constraint_over_generic_retry() {
        let note = select_best_video_prompt_observation_note(vec![
            "avoid repeating stable follow camera".to_string(),
            "avoid extreme camera angle".to_string(),
        ]);

        assert_eq!(note, Some("avoid extreme camera angle".to_string()));
    }

    #[test]
    fn select_best_video_prompt_observation_note_prefers_shorter_when_scores_tie() {
        let note = select_best_video_prompt_observation_note(vec![
            "avoid harsh backlight silhouette please".to_string(),
            "avoid harsh backlight silhouette".to_string(),
        ]);

        assert_eq!(note, Some("avoid harsh backlight silhouette".to_string()));
    }

    #[test]
    fn prune_low_signal_observation_candidates_drops_single_generic_mood_note() {
        assert!(prune_low_signal_observation_candidates(vec![
            "avoid overly cold emotional tone".to_string()
        ])
        .is_empty());
    }

    #[test]
    fn prune_low_signal_observation_candidates_keeps_specific_note_while_dropping_generic_retry() {
        assert_eq!(
            prune_low_signal_observation_candidates(vec![
                "avoid repeating stable follow camera".to_string(),
                "avoid extreme camera angle".to_string(),
            ]),
            vec!["avoid extreme camera angle".to_string()]
        );
    }

    #[test]
    fn score_video_prompt_observation_specificity_penalizes_repeat_style_retry() {
        assert!(
            score_video_prompt_observation_specificity("avoid extreme camera angle")
                > score_video_prompt_observation_specificity(
                    "avoid repeating stable follow camera"
                )
        );
    }

    #[test]
    fn observation_note_conflict_filter_uses_storyboard_context_without_style_memory() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some(
                "（主角对峙、旧宅门厅、主角、5秒、近景、静止、盯住来人、冷峻压迫、冷调逆光、、、A12）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };

        assert!(video_prompt_observation_conflicts_with_style(
            "avoid overly tight close-up framing",
            None,
            Some(&storyboard_row),
        ));
        assert!(video_prompt_observation_conflicts_with_style(
            "avoid flat cold lighting",
            None,
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn observation_note_conflict_filter_keeps_non_conflicting_half_of_combined_warning() {
        let close_up_storyboard = StoryboardPromptSeedRow {
            prompt: Some("门口逼视".into()),
            video_desc: Some(
                "（主角逼视来人、旧宅门口、主角、5秒、近景、静止、逼近对手、克制、侧逆光、、、A15）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };
        assert_eq!(
            compact_negative_constraint_against_storyboard_style(
                "avoid extreme camera angle or overly tight close-up framing",
                None,
                Some(&close_up_storyboard),
            ),
            Some("avoid extreme camera angle".to_string())
        );

        let cold_light_storyboard = StoryboardPromptSeedRow {
            prompt: Some("冷光对峙".into()),
            video_desc: Some(
                "（主角对峙、旧宅门厅、主角、5秒、中景、静止、盯住来人、冷峻压迫、室内冷光、、、A16）"
                    .into(),
            ),
            duration: Some("5s".into()),
        };
        assert_eq!(
            compact_negative_constraint_against_storyboard_style(
                "avoid flat cold lighting or harsh backlight silhouette",
                None,
                Some(&cold_light_storyboard),
            ),
            Some("avoid harsh backlight silhouette".to_string())
        );
    }

    #[test]
    fn observation_note_conflict_filter_understands_handheld_follow_and_neon_context() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角穿过霓虹雨巷".into()),
            video_desc: Some(
                "（主角穿过霓虹雨巷、雨夜巷口、主角、5秒、中景、手持跟拍、踩水快步穿行、悲怆、霓虹反光、无台词、雨声脚步声、A14）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

        assert!(video_prompt_observation_conflicts_with_style(
            "avoid shaky handheld motion",
            None,
            Some(&storyboard_row),
        ));
        assert!(video_prompt_observation_conflicts_with_style(
            "avoid distracting neon reflections",
            None,
            Some(&storyboard_row),
        ));
        assert!(video_prompt_observation_conflicts_with_style(
            "avoid heavy tragic mood",
            None,
            Some(&storyboard_row),
        ));
        assert!(!video_prompt_observation_conflicts_with_style(
            "avoid lip-sync mismatch",
            None,
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn observation_note_irrelevant_filter_skips_lip_sync_for_silent_storyboard() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角贴墙前行".into()),
            video_desc: Some(
                "（主角贴墙前行、旧宅走廊、主角、5秒、近景、稳定跟拍、贴墙前行、压迫、冷调逆光、无台词、风声回响、A12）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

        assert!(video_prompt_observation_is_irrelevant_to_storyboard(
            "avoid lip-sync mismatch",
            Some(&storyboard_row),
        ));
        assert!(!video_prompt_observation_is_irrelevant_to_storyboard(
            "avoid shaky handheld motion",
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn observation_note_irrelevant_filter_keeps_lip_sync_for_dialogue_storyboard() {
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("主角低声说你终于来了".into()),
            video_desc: Some(
                "（主角低声说你终于来了、旧宅门口、主角、5秒、近景、稳定跟拍、停步低声说出、压迫、冷调逆光、你终于来了、风声压过呼吸声、A13）"
                    .into(),
            ),
            duration: Some("5".into()),
        };

        assert!(!video_prompt_observation_is_irrelevant_to_storyboard(
            "avoid lip-sync mismatch",
            Some(&storyboard_row),
        ));
    }

    #[test]
    fn observation_filter_style_note_can_fall_back_to_contextual_summary() {
        let rows = vec![AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            resolve_observation_filter_style_note(&rows, 12, None, Some(&storyboard_row)),
            Some("镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".to_string())
        );
    }

    #[test]
    fn observation_filter_style_note_skips_contextual_summary_when_storyboard_mismatches() {
        let rows = vec![AgentMemoryRow {
            name: "project_video_style_memory".into(),
            content: "sampleCount=5 | style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光".into(),
        }];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("暖光会面".into()),
            video_desc: Some("（主角寒暄、茶馆包间、主角、5秒、中景、轻推、坐下寒暄、温和克制、室内暖光、、、A12）".into()),
            duration: Some("5s".into()),
        };

        assert!(
            resolve_observation_filter_style_note(&rows, 12, None, Some(&storyboard_row)).is_none()
        );
    }

    #[test]
    fn observation_filter_style_note_prefers_shorter_contextual_summary_when_signal_is_equal() {
        let rows = vec![
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍推进，情绪冷峻压迫克制，光影冷调逆光颗粒 | note=镜头稳定跟拍推进，情绪冷峻压迫克制，光影冷调逆光颗粒".into(),
            },
            AgentMemoryRow {
                name: "project_video_style_memory".into(),
                content: "sampleCount=5 | style=镜头稳定跟拍推进，情绪冷峻压迫，光影冷调逆光颗粒 | note=镜头稳定跟拍推进，情绪冷峻压迫，光影冷调逆光颗粒".into(),
            },
        ];
        let storyboard_row = StoryboardPromptSeedRow {
            prompt: Some("门厅对峙".into()),
            video_desc: Some("（主角对峙、旧宅门厅、主角、5秒、中景、稳定跟拍、逼近对手、冷峻压迫、冷调逆光、、、A12）".into()),
            duration: Some("5s".into()),
        };

        assert_eq!(
            resolve_observation_filter_style_note(&rows, 12, None, Some(&storyboard_row)),
            Some("镜头推进".to_string())
        );
    }
}
