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
    parse_structured_storyboard_description,
};
use crate::production::workbench::video_prompt_memory::{
    select_selected_video_memory_notes, AgentMemoryRow, StoryboardPromptSeedRow,
};
use crate::scope::http::require_authenticated;
use crate::scope::http::require_owned_numeric_script_scope_user_pool;
use crate::state::AppState;

const VIDEO_PROMPT_MEMORY_ROW_LIMIT: i64 = 8;
const VIDEO_PROMPT_MEMORY_NOTE_LIMIT: usize = 2;
const VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS: usize = 56;

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
    let duration = resolve_video_prompt_duration(
        body.duration_hint,
        body.description.as_deref(),
        context.as_ref(),
    );

    Ok(JsonResponse(GenerateVideoPromptResponse {
        prompt,
        model: "runway-gen-2".to_string(),
        duration,
    }))
}

#[derive(Debug, Clone, Default)]
struct VideoPromptContext {
    storyboard_prompt: Option<String>,
    storyboard_video_desc: Option<String>,
    storyboard_duration: Option<String>,
    continuity_notes: Vec<String>,
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

    let continuity_notes =
        load_video_prompt_memory_notes(pool, user_id, project_id, script_id, storyboard_numeric_id)
            .await?;

    Ok(Some(VideoPromptContext {
        storyboard_prompt: row.prompt,
        storyboard_video_desc: row.video_desc,
        storyboard_duration: row.duration,
        continuity_notes,
    }))
}

async fn load_video_prompt_memory_notes(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_numeric_id: i32,
) -> Result<Vec<String>, ApiError> {
    let rows = sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id = $3
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND name IN ('selected_video_memory', 'auto_scope_memory')
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
    let selected_notes = select_selected_video_memory_notes(&rows, storyboard_numeric_id);
    if !selected_notes.is_empty() {
        return Ok(selected_notes);
    }
    Ok(select_video_prompt_memory_notes(
        &rows,
        storyboard_numeric_id,
    ))
}

fn build_video_prompt(
    description: Option<&str>,
    image_url: Option<&str>,
    context: Option<&VideoPromptContext>,
) -> String {
    let mut clauses = Vec::new();
    clauses.push("Single cinematic shot.".to_string());

    let resolved_description = resolve_video_prompt_description(description, context);
    match resolved_description
        .as_deref()
        .and_then(parse_structured_storyboard_description)
    {
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

    if let Some(note) = build_continuity_clause(context) {
        clauses.push(note);
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

fn build_continuity_clause(context: Option<&VideoPromptContext>) -> Option<String> {
    let notes = context
        .map(|ctx| {
            ctx.continuity_notes
                .iter()
                .map(|note| clip_prompt_fragment(note, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    if notes.is_empty() {
        return None;
    }
    Some(format!("Continuity notes: {}.", notes.join("; ")))
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
) -> Vec<String> {
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
                .map(|value| clip_prompt_fragment(&value, VIDEO_PROMPT_MEMORY_NOTE_MAX_CHARS))?;
            Some((score, note))
        })
        .collect::<Vec<_>>();
    scored.sort_by(|a, b| b.0.cmp(&a.0));

    let mut notes = Vec::new();
    for (_, note) in scored {
        if notes.iter().any(|existing| existing == &note) {
            continue;
        }
        notes.push(note);
        if notes.len() >= VIDEO_PROMPT_MEMORY_NOTE_LIMIT {
            break;
        }
    }
    notes
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
        select_video_prompt_memory_notes, VideoPromptContext,
    };
    use crate::production::workbench::video_prompt_memory::AgentMemoryRow;

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
            continuity_notes: vec!["保持上一镜头已确认的冷调压迫感".into()],
        };
        let prompt = build_video_prompt(None, None, Some(&context));

        assert!(prompt.contains("Subject: 主角冲出旧宅."));
        assert!(prompt.contains("Dialogue or voice-over: 别回头."));
        assert!(prompt.contains("Continuity notes: 保持上一镜头已确认的冷调压迫感."));
    }

    #[test]
    fn resolve_video_prompt_duration_falls_back_to_storyboard_context() {
        let context = VideoPromptContext {
            storyboard_prompt: None,
            storyboard_video_desc: None,
            storyboard_duration: Some("7 秒".into()),
            continuity_notes: Vec::new(),
        };
        assert_eq!(resolve_video_prompt_duration(None, None, Some(&context)), 7);
    }

    #[test]
    fn select_video_prompt_memory_notes_keeps_only_matching_storyboard_entries() {
        let rows = vec![
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | review=target=storyboardTable; summary=保持女主冷色调近景".to_string(),
            },
            AgentMemoryRow {
                name: "auto_scope_memory".into(),
                content: "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=12 | result=补图时保持镜头方向连续".to_string(),
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

        assert_eq!(
            select_video_prompt_memory_notes(&rows, 12),
            vec![
                "保持女主冷色调近景".to_string(),
                "补图时保持镜头方向连续".to_string()
            ]
        );
    }
}
