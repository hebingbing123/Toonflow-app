use axum::{
    extract::{Json, State},
    http::HeaderMap,
    Json as JsonResponse,
};
use serde::Serialize;
use sqlx::PgPool;
use std::collections::{BTreeSet, HashMap};
use uuid::Uuid;

use super::WorkbenchGenerateVideoBody;
use crate::error::ApiError;
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_VIDEO_GENERATE};
use crate::production::types::GenerateVideoUploadItem;
use crate::production::workbench::video_prompt_memory::{
    select_project_video_style_memory_notes, select_rejected_video_negative_memory_notes,
    select_script_video_style_memory_notes, select_selected_video_memory_notes,
    storyboard_prompt_seed, AgentMemoryRow, StoryboardPromptSeedRow,
};
use crate::scope::http::require_owned_numeric_script_scope;
use crate::state::AppState;

const VIDEO_NEGATIVE_PROMPT_MAX_CHARS: usize = 120;

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(in crate::production) struct WorkbenchGenerateVideoResponse {
    enqueued: Vec<JobRow>,
    total: usize,
    negative_prompt: Option<String>,
    storyboard_negative_prompts: Vec<StoryboardNegativePrompt>,
}

#[derive(Debug, Clone, sqlx::FromRow)]
struct QualityReviewSeedRow {
    target_type: Option<String>,
    target_id: Option<String>,
    bad_case_category: Option<String>,
    comments: Option<String>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StoryboardNegativePrompt {
    storyboard_id: i32,
    negative_prompt: Option<String>,
}

#[utoipa::path(
    post,
    path = "/api/v1/production/workbench/generate-video",
    operation_id = "postProductionWorkbenchGenerateVideoV1",
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
pub(in crate::production) async fn post_workbench_generate_video(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkbenchGenerateVideoBody>,
) -> Result<JsonResponse<WorkbenchGenerateVideoResponse>, ApiError> {
    if body.track_id <= 0 {
        return Err(ApiError::BadRequest(
            "trackId must be a positive integer".into(),
        ));
    }
    if body.upload_data.is_empty() {
        return Err(ApiError::BadRequest("uploadData must not be empty".into()));
    }
    if body.prompt.trim().is_empty() {
        return Err(ApiError::BadRequest("prompt must not be empty".into()));
    }
    if body.model.trim().is_empty() {
        return Err(ApiError::BadRequest("model must not be empty".into()));
    }
    if body.duration <= 0 {
        return Err(ApiError::BadRequest(
            "duration must be a positive integer".into(),
        ));
    }

    let (user_id, pool, scope_row) =
        require_owned_numeric_script_scope(&state, &headers, body.project_id, body.script_id)
            .await?;
    let upload_sources = normalize_upload_sources(&body.upload_data)?;
    let storyboard_ids = upload_sources.keys().copied().collect::<Vec<_>>();
    ensure_track_in_scope(
        pool,
        scope_row.project_id,
        scope_row.script_id,
        body.track_id,
    )
    .await?;
    ensure_storyboards_in_scope(pool, scope_row.script_id, &storyboard_ids).await?;

    let aspect_ratio = load_project_aspect_ratio(pool, scope_row.project_id)
        .await?
        .unwrap_or_else(|| "16:9".to_string());
    let storyboard_negative_prompts = load_auto_negative_prompts(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        &storyboard_ids,
    )
    .await?;
    let provider = infer_video_provider(&body.model);
    let duration_label = format!("{}s", body.duration);
    let prompt = body.prompt.trim().to_string();
    let model = body.model.trim().to_string();
    let resolution = body.resolution.trim().to_string();
    let mode = body.mode.trim().to_string();

    let mut enqueued = Vec::with_capacity(upload_sources.len());
    let mut response_negative_prompts = Vec::with_capacity(storyboard_ids.len());
    for (storyboard_numeric_id, source_url) in upload_sources {
        let merged_negative_prompt = merge_negative_prompts(
            body.negative_prompt.as_deref(),
            storyboard_negative_prompts
                .get(&storyboard_numeric_id)
                .and_then(|value| value.as_deref()),
        );
        sqlx::query(
            r#"
            UPDATE app_storyboard
            SET prompt = $2,
                duration = $3,
                track_id = $4,
                state = '生成中',
                updated_at = NOW()
            WHERE script_id = $1
              AND numeric_id = $5
            "#,
        )
        .bind(scope_row.script_id)
        .bind(&prompt)
        .bind(&duration_label)
        .bind(body.track_id)
        .bind(storyboard_numeric_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let payload = serde_json::json!({
            "source": "production.workbench.generate-video",
            "project_numeric_id": body.project_id,
            "script_id": body.script_id,
            "storyboard_numeric_id": storyboard_numeric_id,
            "provider": provider,
            "model": &model,
            "mode": &mode,
            "prompt": &prompt,
            "negative_prompt": merged_negative_prompt.clone(),
            "duration": body.duration,
            "resolution": &resolution,
            "aspect_ratio": &aspect_ratio,
            "audio": body.audio,
            "track_id": body.track_id,
            "image_url": source_url,
        });
        let row = enqueue_generation_job(pool, user_id, JOB_KIND_VIDEO_GENERATE, payload).await?;
        enqueued.push(row);
        response_negative_prompts.push(StoryboardNegativePrompt {
            storyboard_id: storyboard_numeric_id,
            negative_prompt: merged_negative_prompt,
        });
    }

    let total = enqueued.len();
    Ok(JsonResponse(WorkbenchGenerateVideoResponse {
        enqueued,
        total,
        negative_prompt: body.negative_prompt.clone(),
        storyboard_negative_prompts: response_negative_prompts,
    }))
}

fn normalize_upload_sources(
    items: &[GenerateVideoUploadItem],
) -> Result<HashMap<i32, String>, ApiError> {
    let mut seen = BTreeSet::new();
    let mut normalized = HashMap::with_capacity(items.len());
    for item in items {
        if item.id <= 0 {
            return Err(ApiError::BadRequest(
                "each uploadData.id must be a positive integer".into(),
            ));
        }
        if !seen.insert(item.id) {
            return Err(ApiError::BadRequest(
                "uploadData must not contain duplicate storyboard ids".into(),
            ));
        }
        let source = item.sources.trim();
        if source.is_empty() {
            return Err(ApiError::BadRequest(
                "each uploadData.sources must not be empty".into(),
            ));
        }
        let parsed = reqwest::Url::parse(source)
            .map_err(|e| ApiError::BadRequest(format!("invalid uploadData.sources URL: {e}")))?;
        match parsed.scheme() {
            "http" | "https" => {}
            other => {
                return Err(ApiError::BadRequest(format!(
                    "unsupported uploadData.sources scheme: {other} (expected http/https)"
                )));
            }
        }
        normalized.insert(item.id, source.to_string());
    }
    Ok(normalized)
}

async fn ensure_track_in_scope(
    pool: &PgPool,
    project_id: Uuid,
    script_id: Uuid,
    track_numeric_id: i32,
) -> Result<(), ApiError> {
    let exists: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1
          FROM app_video_track
          WHERE project_id = $1
            AND (script_id = $2 OR script_id IS NULL)
            AND numeric_id = $3
        )
        "#,
    )
    .bind(project_id)
    .bind(script_id)
    .bind(track_numeric_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if exists {
        Ok(())
    } else {
        Err(ApiError::NotFound)
    }
}

async fn ensure_storyboards_in_scope(
    pool: &PgPool,
    script_id: Uuid,
    storyboard_ids: &[i32],
) -> Result<(), ApiError> {
    let owned_ids = sqlx::query_scalar::<_, i32>(
        r#"
        SELECT numeric_id
        FROM app_storyboard
        WHERE script_id = $1
          AND numeric_id = ANY($2)
        "#,
    )
    .bind(script_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if owned_ids.len() == storyboard_ids.len() {
        Ok(())
    } else {
        Err(ApiError::NotFound)
    }
}

async fn load_project_aspect_ratio(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Option<String>, ApiError> {
    let raw = sqlx::query_scalar::<_, Option<String>>(
        "SELECT video_ratio FROM app_project WHERE id = $1",
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(raw.and_then(|value| compact_video_ratio(&value)))
}

fn compact_video_ratio(value: &str) -> Option<String> {
    let normalized = value.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return None;
    }
    if normalized.contains("9:16") {
        return Some("9:16".to_string());
    }
    if normalized.contains("1:1") || normalized.contains("square") {
        return Some("1:1".to_string());
    }
    if normalized.contains("16:9") || normalized.contains("horizontal") {
        return Some("16:9".to_string());
    }
    None
}

pub(crate) async fn load_auto_negative_prompt(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<Option<String>, ApiError> {
    let prompts = load_auto_negative_prompts(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;
    Ok(storyboard_ids
        .iter()
        .find_map(|storyboard_id| prompts.get(storyboard_id).cloned().flatten()))
}

pub(crate) async fn load_auto_negative_prompts(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, Option<String>>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(HashMap::new());
    }
    let storyboard_target_ids = storyboard_ids
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    let rows = sqlx::query_as::<_, QualityReviewSeedRow>(
        r#"
        SELECT target_type, target_id, bad_case_category, comments
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND (script_id IS NULL OR script_id = $3)
          AND (
            is_bad_case = TRUE
            OR passed = FALSE
            OR COALESCE(visual_quality, 10) <= 4
            OR COALESCE(overall_score, 10) <= 4
          )
          AND (
            target_type IN ('video', 'output')
            OR (target_type = 'storyboard' AND target_id = ANY($4))
          )
        ORDER BY
          CASE
            WHEN target_type = 'storyboard' AND target_id = ANY($4) THEN 0
            WHEN script_id = $3 THEN 1
            ELSE 2
          END,
          created_at DESC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(&storyboard_target_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let rejected_rows = load_rejected_video_negative_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
    )
    .await?;
    let selected_rows =
        load_selected_video_memory_rows(pool, user_id, project_numeric_id, script_numeric_id)
            .await?;
    let prompt_seed_map = load_storyboard_prompt_seed_map(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;

    Ok(build_storyboard_negative_prompts(
        storyboard_ids,
        &rows,
        &rejected_rows,
        &selected_rows,
        &prompt_seed_map,
    ))
}

async fn load_rejected_video_negative_memory_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    sqlx::query_as::<_, AgentMemoryRow>(
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
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

async fn load_storyboard_prompt_seed_map(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, String>, ApiError> {
    let rows = sqlx::query_as::<_, (i32, Option<String>, Option<String>, Option<String>)>(
        r#"
        SELECT sb.numeric_id, sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
          AND sc.numeric_id = $3
          AND sb.numeric_id = ANY($4)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(rows
        .into_iter()
        .filter_map(|(storyboard_id, prompt, video_desc, duration)| {
            storyboard_prompt_seed(&StoryboardPromptSeedRow {
                prompt,
                video_desc,
                duration,
            })
            .map(|seed| (storyboard_id, seed))
        })
        .collect())
}

async fn load_selected_video_memory_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN ('selected_video_memory', 'script_video_style_memory'))
            OR (episodes_id IS NULL AND name = 'project_video_style_memory')
          )
        ORDER BY create_time_ms DESC
        LIMIT 8
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

fn build_storyboard_negative_prompts(
    storyboard_ids: &[i32],
    review_rows: &[QualityReviewSeedRow],
    rejected_rows: &[AgentMemoryRow],
    selected_rows: &[AgentMemoryRow],
    prompt_seed_map: &HashMap<i32, String>,
) -> HashMap<i32, Option<String>> {
    let script_style_note = select_script_video_style_memory_notes(selected_rows)
        .into_iter()
        .next();
    let project_style_note = select_project_video_style_memory_notes(selected_rows)
        .into_iter()
        .next();
    storyboard_ids
        .iter()
        .copied()
        .map(|storyboard_id| {
            let selected_style_note = select_selected_video_memory_notes(
                selected_rows,
                storyboard_id,
                prompt_seed_map.get(&storyboard_id).map(String::as_str),
            )
            .into_iter()
            .next();
            let review_fragments = filter_conflicting_review_fragments(
                collect_negative_review_fragments(
                    &review_rows
                        .iter()
                        .filter(|row| quality_review_row_matches_storyboard(row, storyboard_id))
                        .cloned()
                        .collect::<Vec<_>>(),
                    storyboard_id,
                ),
                selected_style_note
                    .as_deref()
                    .or(script_style_note.as_deref())
                    .or(project_style_note.as_deref()),
            );
            let prioritized_style_note = selected_style_note
                .as_deref()
                .or(script_style_note.as_deref())
                .or(project_style_note.as_deref());
            let rejected_fragments = filter_conflicting_review_fragments(
                split_negative_prompt_fragments(
                    select_rejected_video_negative_memory_notes(
                        rejected_rows,
                        storyboard_id,
                        prompt_seed_map.get(&storyboard_id).map(String::as_str),
                    )
                    .into_iter()
                    .next()
                    .as_deref(),
                ),
                prioritized_style_note,
            );
            let review_prompt =
                merge_negative_prompt_fragment_groups(&[rejected_fragments, review_fragments]);
            (storyboard_id, review_prompt)
        })
        .collect()
}

fn filter_conflicting_review_fragments(
    fragments: Vec<String>,
    selected_style_note: Option<&str>,
) -> Vec<String> {
    let Some(note) = selected_style_note else {
        return fragments;
    };
    fragments
        .into_iter()
        .filter(|fragment| !review_fragment_conflicts_with_selected_style(fragment, note))
        .collect()
}

fn review_fragment_conflicts_with_selected_style(
    fragment: &str,
    selected_style_note: &str,
) -> bool {
    let fragment = canonical_negative_fragment(fragment);
    let note = selected_style_note.trim();
    if fragment.is_empty() || note.is_empty() {
        return false;
    }

    if fragment == canonical_negative_fragment("avoid overly tight close-up framing") {
        return note.contains("近景") || note.contains("特写");
    }
    if fragment == canonical_negative_fragment("avoid extreme camera angle") {
        return note.contains("低机位") || note.contains("高机位");
    }
    if fragment == canonical_negative_fragment("avoid oppressive or frantic mood") {
        return note.contains("压迫") || note.contains("紧张") || note.contains("冷峻");
    }
    if fragment == canonical_negative_fragment("avoid overly cold emotional tone") {
        return note.contains("冷调") || note.contains("冷色") || note.contains("冷峻");
    }
    if fragment == canonical_negative_fragment("avoid flat cold lighting") {
        return note.contains("光影")
            && (note.contains("冷调") || note.contains("冷光") || note.contains("逆光"));
    }
    if fragment == canonical_negative_fragment("avoid harsh backlight silhouette") {
        return note.contains("光影") && note.contains("逆光");
    }

    false
}

fn quality_review_row_matches_storyboard(row: &QualityReviewSeedRow, storyboard_id: i32) -> bool {
    match row.target_type.as_deref().map(str::trim) {
        Some("storyboard") => row
            .target_id
            .as_deref()
            .and_then(|value| value.trim().parse::<i32>().ok())
            .is_some_and(|value| value == storyboard_id),
        _ => true,
    }
}

#[cfg_attr(not(test), allow(dead_code))]
fn compact_negative_review_constraints(rows: &[QualityReviewSeedRow]) -> Option<String> {
    merge_negative_prompt_fragment_groups(&[collect_negative_review_fragments(rows, 0)])
}

fn collect_negative_review_fragments(
    rows: &[QualityReviewSeedRow],
    storyboard_id: i32,
) -> Vec<String> {
    let mut fragments = Vec::new();
    for row in rows
        .iter()
        .filter(|row| review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_unique_negative_fragment(&mut fragments, map_bad_case_category(category));
        }
        if fragments.len() >= 4 {
            break;
        }
    }
    for row in rows
        .iter()
        .filter(|row| review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_unique_negative_fragment(&mut fragments, Some(fragment));
            }
        }
        if fragments.len() >= 4 {
            break;
        }
    }
    for row in rows
        .iter()
        .filter(|row| !review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_unique_negative_fragment(&mut fragments, map_bad_case_category(category));
        }
        if fragments.len() >= 6 {
            break;
        }
    }
    for row in rows
        .iter()
        .filter(|row| !review_row_targets_storyboard(row, storyboard_id))
    {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_unique_negative_fragment(&mut fragments, Some(fragment));
            }
        }
        if fragments.len() >= 6 {
            break;
        }
    }
    fragments
}

fn review_row_targets_storyboard(row: &QualityReviewSeedRow, storyboard_id: i32) -> bool {
    matches!(
        row.target_type.as_deref().map(str::trim),
        Some("storyboard")
    ) && row
        .target_id
        .as_deref()
        .and_then(|value| value.trim().parse::<i32>().ok())
        .is_some_and(|value| value == storyboard_id)
}

fn push_unique_negative_fragment(target: &mut Vec<String>, candidate: Option<&'static str>) {
    let Some(candidate) = candidate else {
        return;
    };
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    target.push(candidate.to_string());
}

fn map_bad_case_category(category: &str) -> Option<&'static str> {
    match category.trim() {
        "visual_error" => Some("avoid warped anatomy, blur, flicker"),
        "storyboard_mismatch" => Some("avoid extra shot changes or wrong framing"),
        "character_break" => Some("avoid face drift or costume inconsistency"),
        "pacing_issue" => Some("avoid rushed or jerky motion"),
        "dialogue_issue" => Some("avoid lip-sync mismatch"),
        _ => None,
    }
}

fn infer_negative_fragments_from_comments(comments: &str) -> Vec<&'static str> {
    let normalized = comments.trim().to_ascii_lowercase();
    let mut fragments = Vec::new();
    let keyword_groups = [
        (
            &[
                "手", "手指", "肢体", "四肢", "畸形", "变形", "anatom", "limb",
            ][..],
            "avoid warped hands or limbs",
        ),
        (
            &["脸", "面部", "五官", "表情崩", "face", "facial"][..],
            "avoid face distortion or identity drift",
        ),
        (
            &["闪烁", "跳帧", "抖动", "flicker", "jitter", "stutter"][..],
            "avoid flicker or motion jitter",
        ),
        (
            &["镜头", "构图", "机位", "切镜", "shot", "framing", "camera"][..],
            "avoid unnecessary shot changes",
        ),
        (
            &["背景", "场景", "空间", "setting", "background"][..],
            "avoid wrong setting details",
        ),
        (
            &["服装", "发型", "角色不一致", "costume", "hair", "character"][..],
            "avoid costume or character drift",
        ),
    ];

    for (keywords, fragment) in keyword_groups {
        if keywords.iter().any(|keyword| normalized.contains(keyword)) {
            fragments.push(fragment);
        }
    }
    fragments
}

fn merge_negative_prompts(manual: Option<&str>, automatic: Option<&str>) -> Option<String> {
    merge_negative_prompt_fragment_groups(&[
        split_negative_prompt_fragments(manual),
        split_negative_prompt_fragments(automatic),
    ])
}

fn merge_negative_prompt_fragment_groups(groups: &[Vec<String>]) -> Option<String> {
    let mut fragments = Vec::new();
    for group in groups {
        for fragment in group {
            push_negative_fragment_without_budget(&mut fragments, fragment);
        }
    }
    fragments = compact_negative_fragment_families(fragments);
    let mut budgeted = Vec::new();
    for fragment in fragments {
        push_negative_fragment_with_budget(&mut budgeted, &fragment);
    }
    if budgeted.is_empty() {
        None
    } else {
        Some(budgeted.join(", "))
    }
}

#[derive(Debug, Default, Clone, Copy)]
struct CharacterConsistencyFlags {
    face_distortion: bool,
    identity_drift: bool,
    costume_inconsistency: bool,
}

fn compact_negative_fragment_families(fragments: Vec<String>) -> Vec<String> {
    let mut compacted = Vec::with_capacity(fragments.len());
    let mut character_flags = CharacterConsistencyFlags::default();
    let mut character_idx = None;

    for (idx, fragment) in fragments.into_iter().enumerate() {
        if let Some(flags) = parse_character_consistency_fragment(&fragment) {
            character_idx.get_or_insert(idx);
            character_flags.face_distortion |= flags.face_distortion;
            character_flags.identity_drift |= flags.identity_drift;
            character_flags.costume_inconsistency |= flags.costume_inconsistency;
            continue;
        }
        compacted.push((idx, fragment));
    }

    if let Some(idx) = character_idx {
        compacted.push((idx, render_character_consistency_fragment(character_flags)));
    }
    compacted.sort_by(|a, b| a.0.cmp(&b.0));
    compacted.into_iter().map(|(_, fragment)| fragment).collect()
}

fn parse_character_consistency_fragment(fragment: &str) -> Option<CharacterConsistencyFlags> {
    let canonical = canonical_negative_fragment(fragment);
    match canonical.as_str() {
        "avoid face distortion or identity drift" => Some(CharacterConsistencyFlags {
            face_distortion: true,
            identity_drift: true,
            costume_inconsistency: false,
        }),
        "avoid costume or character drift" => Some(CharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        "avoid face drift or costume inconsistency" => Some(CharacterConsistencyFlags {
            face_distortion: false,
            identity_drift: true,
            costume_inconsistency: true,
        }),
        _ => None,
    }
}

fn render_character_consistency_fragment(flags: CharacterConsistencyFlags) -> String {
    if flags.face_distortion && flags.costume_inconsistency {
        "avoid face distortion, identity drift, costume drift".to_string()
    } else if flags.costume_inconsistency {
        "avoid face drift or costume inconsistency".to_string()
    } else {
        "avoid face distortion or identity drift".to_string()
    }
}

fn split_negative_prompt_fragments(prompt: Option<&str>) -> Vec<String> {
    let mut fragments = Vec::new();
    if let Some(prompt) = prompt {
        for fragment in prompt.split([',', ';', '，', '；', '\n']) {
            let fragment = fragment.trim();
            if fragment.is_empty() {
                continue;
            }
            if negative_fragment_is_covered(fragment, &fragments) {
                continue;
            }
            fragments.retain(|existing| !negative_fragment_covers(fragment, existing));
            fragments.push(fragment.to_string());
        }
    }
    fragments
}

fn push_negative_fragment_without_budget(target: &mut Vec<String>, candidate: &str) {
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    target.push(candidate.to_string());
}

fn push_negative_fragment_with_budget(target: &mut Vec<String>, candidate: &str) {
    if negative_fragment_is_covered(candidate, target) {
        return;
    }
    target.retain(|existing| !negative_fragment_covers(candidate, existing));
    let mut next = target.clone();
    next.push(candidate.to_string());
    let joined = next.join(", ");
    if joined.chars().count() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS {
        *target = next;
        return;
    }

    let clipped = clip_negative_prompt(candidate);
    if clipped.is_empty() || negative_fragment_is_covered(&clipped, target) {
        return;
    }
    let mut clipped_next = target.clone();
    clipped_next.push(clipped);
    let clipped_joined = clipped_next.join(", ");
    if clipped_joined.chars().count() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS {
        *target = clipped_next;
    }
}

fn negative_fragment_is_covered(candidate: &str, existing_fragments: &[String]) -> bool {
    existing_fragments
        .iter()
        .any(|existing| negative_fragment_covers(existing, candidate))
}

fn negative_fragment_covers(existing: &str, candidate: &str) -> bool {
    if negative_fragment_same_family(existing, candidate) {
        return negative_fragment_information_score(existing)
            >= negative_fragment_information_score(candidate);
    }
    negative_fragment_contains(existing, candidate)
}

fn negative_fragment_contains(existing: &str, candidate: &str) -> bool {
    let existing = canonical_negative_fragment(existing);
    let candidate = canonical_negative_fragment(candidate);
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

fn negative_fragment_same_family(existing: &str, candidate: &str) -> bool {
    let existing = negative_fragment_family(existing);
    let candidate = negative_fragment_family(candidate);
    !existing.is_empty() && existing == candidate
}

fn negative_fragment_family(value: &str) -> &'static str {
    let canonical = canonical_negative_fragment(value);
    match canonical.as_str() {
        "avoid flicker" | "avoid flicker or motion jitter" => "flicker_motion_jitter",
        "avoid unnecessary shot changes" | "avoid extra shot changes or wrong framing" => {
            "shot_change_framing"
        }
        _ => "",
    }
}

fn negative_fragment_information_score(value: &str) -> usize {
    canonical_negative_fragment(value).chars().count()
}

fn canonical_negative_fragment(value: &str) -> String {
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

fn clip_negative_prompt(prompt: &str) -> String {
    let normalized = prompt.split_whitespace().collect::<Vec<_>>().join(" ");
    let mut chars = normalized.chars();
    let clipped = chars
        .by_ref()
        .take(VIDEO_NEGATIVE_PROMPT_MAX_CHARS)
        .collect::<String>();
    if chars.next().is_some() {
        format!("{}...", clipped.trim_end())
    } else {
        clipped
    }
}

fn infer_video_provider(model: &str) -> &'static str {
    let normalized = model.trim().to_ascii_lowercase();
    if normalized.contains("kling") || normalized.contains("可灵") {
        "kling"
    } else if normalized.contains("pika") {
        "pika"
    } else {
        "runway"
    }
}

#[cfg(test)]
mod tests {
    use super::{
        build_storyboard_negative_prompts, clip_negative_prompt,
        compact_negative_review_constraints, compact_video_ratio,
        infer_negative_fragments_from_comments, infer_video_provider, load_auto_negative_prompts,
        merge_negative_prompts, normalize_upload_sources, quality_review_row_matches_storyboard,
        review_fragment_conflicts_with_selected_style, QualityReviewSeedRow,
        VIDEO_NEGATIVE_PROMPT_MAX_CHARS,
    };
    use crate::production::types::GenerateVideoUploadItem;
    use crate::production::workbench::video_prompt_memory::{
        select_rejected_video_negative_memory_notes, AgentMemoryRow,
    };
    use sqlx::PgPool;
    use std::collections::HashMap;
    use uuid::Uuid;

    #[test]
    fn normalize_upload_sources_rejects_duplicate_storyboards() {
        let err = normalize_upload_sources(&[
            GenerateVideoUploadItem {
                id: 3,
                sources: "https://example.com/a.png".into(),
            },
            GenerateVideoUploadItem {
                id: 3,
                sources: "https://example.com/b.png".into(),
            },
        ])
        .unwrap_err();
        assert!(matches!(
            err,
            crate::error::ApiError::BadRequest(message)
                if message == "uploadData must not contain duplicate storyboard ids"
        ));
    }

    #[test]
    fn compact_negative_review_constraints_prefers_short_visual_failures() {
        let prompt = compact_negative_review_constraints(&[
            QualityReviewSeedRow {
                target_type: None,
                target_id: None,
                bad_case_category: Some("visual_error".into()),
                comments: Some("手指变形且有闪烁".into()),
            },
            QualityReviewSeedRow {
                target_type: None,
                target_id: None,
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定，服装漂移".into()),
            },
        ])
        .expect("negative prompt");

        assert!(prompt.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt.contains("avoid warped hands or limbs"));
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
        assert!(!prompt.contains("avoid costume or character drift"));
    }

    #[test]
    fn infer_negative_fragments_from_comments_matches_cn_and_en_keywords() {
        let fragments =
            infer_negative_fragments_from_comments("面部崩坏并且 flicker，镜头切换也多");
        assert!(fragments.contains(&"avoid face distortion or identity drift"));
        assert!(fragments.contains(&"avoid flicker or motion jitter"));
        assert!(fragments.contains(&"avoid unnecessary shot changes"));
    }

    #[test]
    fn merge_negative_prompts_deduplicates_and_clips() {
        let merged = merge_negative_prompts(
            Some("avoid blur, avoid flicker"),
            Some("avoid flicker, avoid wrong setting details"),
        )
        .expect("merged prompt");
        assert_eq!(
            merged,
            "avoid blur, avoid flicker, avoid wrong setting details"
        );
        assert!(clip_negative_prompt(&"a".repeat(160)).ends_with("..."));
    }

    #[test]
    fn merge_negative_prompts_keeps_more_informative_fragment() {
        let merged = merge_negative_prompts(
            Some("avoid flicker"),
            Some("avoid flicker or motion jitter, avoid blur"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid flicker or motion jitter, avoid blur");
    }

    #[test]
    fn merge_negative_prompts_prefers_more_informative_shot_change_fragment() {
        let merged = merge_negative_prompts(
            Some("avoid unnecessary shot changes"),
            Some("avoid extra shot changes or wrong framing, avoid blur"),
        )
        .expect("merged prompt");

        assert_eq!(merged, "avoid extra shot changes or wrong framing, avoid blur");
    }

    #[test]
    fn merge_negative_prompts_compacts_character_consistency_family() {
        let merged = merge_negative_prompts(
            Some("avoid face drift or costume inconsistency"),
            Some("avoid face distortion or identity drift, avoid costume or character drift"),
        )
        .expect("merged prompt");

        assert_eq!(
            merged,
            "avoid face distortion, identity drift, costume drift"
        );
    }

    #[tokio::test]
    async fn load_auto_negative_prompts_returns_empty_without_storyboards() {
        let pool = PgPool::connect_lazy("postgres://postgres:postgres@localhost/postgres")
            .expect("lazy pool");
        let prompts = load_auto_negative_prompts(&pool, Uuid::nil(), 1, 2, &[])
            .await
            .expect("prompts");
        assert!(prompts.is_empty());
    }

    #[test]
    fn rejected_video_negative_memory_can_merge_with_review_constraints() {
        let rows = vec![
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | rejectionCount=2 | avoid=avoid shaky handheld motion".into(),
            },
        ];
        let merged = merge_negative_prompts(
            Some("avoid flicker"),
            select_rejected_video_negative_memory_notes(&rows, 12, None)
                .first()
                .map(String::as_str),
        )
        .expect("merged");

        assert_eq!(
            merged,
            "avoid flicker, avoid flat cold lighting, avoid oppressive or frantic mood"
        );
    }

    #[test]
    fn quality_review_row_matches_storyboard_keeps_storyboard_scope_isolated() {
        let storyboard_row = QualityReviewSeedRow {
            target_type: Some("storyboard".into()),
            target_id: Some("12".into()),
            bad_case_category: Some("storyboard_mismatch".into()),
            comments: None,
        };
        let global_row = QualityReviewSeedRow {
            target_type: Some("video".into()),
            target_id: None,
            bad_case_category: Some("visual_error".into()),
            comments: None,
        };

        assert!(quality_review_row_matches_storyboard(&storyboard_row, 12));
        assert!(!quality_review_row_matches_storyboard(&storyboard_row, 9));
        assert!(quality_review_row_matches_storyboard(&global_row, 9));
    }

    #[test]
    fn build_storyboard_negative_prompts_keeps_each_storyboard_prompt_independent() {
        let prompts = build_storyboard_negative_prompts(
            &[12, 13],
            &[
                QualityReviewSeedRow {
                    target_type: Some("storyboard".into()),
                    target_id: Some("12".into()),
                    bad_case_category: Some("storyboard_mismatch".into()),
                    comments: None,
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("有明显闪烁".into()),
                },
            ],
            &[
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=13 | rejectionCount=2 | avoid=avoid flat cold lighting"
                            .into(),
                },
                AgentMemoryRow {
                    name: "rejected_video_negative_memory".into(),
                    content:
                        "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood"
                            .into(),
                },
            ],
            &[],
            &HashMap::new(),
        );

        let prompt_12 = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        let prompt_13 = prompts
            .get(&13)
            .and_then(|value| value.as_deref())
            .expect("storyboard 13 prompt");

        assert!(prompt_12.contains("avoid extra shot changes or wrong framing"));
        assert!(prompt_12.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt_12.contains("avoid op"));
        assert!(!prompt_12.contains("avoid flat cold lighting"));

        assert!(prompt_13.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt_13.contains("avoid flat cold lighting"));
        assert!(!prompt_13.contains("avoid extra shot changes or wrong framing"));
    }

    #[test]
    fn build_storyboard_negative_prompts_prioritizes_storyboard_memory_over_global_review_tail() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("visual_error".into()),
                    comments: Some("明显闪烁，手部也会变形".into()),
                },
                QualityReviewSeedRow {
                    target_type: Some("output".into()),
                    target_id: None,
                    bad_case_category: Some("character_break".into()),
                    comments: Some("角色服装和脸都会漂移".into()),
                },
            ],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | rejectionCount=2 | avoid=avoid oppressive or frantic mood, avoid flat cold lighting".into(),
            }],
            &[],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");

        assert!(prompt.contains("avoid oppressive or frantic mood"));
        assert!(prompt.contains("avoid flat cold lighting"));
        assert!(prompt.len() <= VIDEO_NEGATIVE_PROMPT_MAX_CHARS + 3);
    }

    #[test]
    fn selected_video_style_can_suppress_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("近景太近，情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=seed000000001 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=镜头近景，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &HashMap::from([(12, "seed000000001".to_string())]),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn script_video_style_summary_can_suppress_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: None,
                comments: Some("情绪太冷太压迫，逆光太重".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn script_video_style_summary_can_suppress_conflicting_rejected_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood"
                        .into(),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts.get(&12).and_then(|value| value.as_deref());
        assert_eq!(prompt, None);
    }

    #[test]
    fn rejected_fragments_keep_non_conflicting_constraints_under_style_memory() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[],
            &[AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content:
                    "storyboardIds=12 | rejectionCount=2 | avoid=avoid flat cold lighting, avoid face drift or costume inconsistency"
                        .into(),
            }],
            &[AgentMemoryRow {
                name: "script_video_style_memory".into(),
                content:
                    "style=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光 | note=镜头稳定跟拍，情绪冷峻压迫，光影冷调逆光"
                        .into(),
            }],
            &HashMap::new(),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        assert_eq!(prompt, "avoid face drift or costume inconsistency");
    }

    #[test]
    fn selected_video_style_does_not_suppress_non_conflicting_review_fragments() {
        let prompts = build_storyboard_negative_prompts(
            &[12],
            &[QualityReviewSeedRow {
                target_type: Some("storyboard".into()),
                target_id: Some("12".into()),
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定".into()),
            }],
            &[],
            &[AgentMemoryRow {
                name: "selected_video_memory".into(),
                content: "storyboardIds=12 | promptSeed=seed000000001 | style=镜头近景，情绪冷峻压迫，光影冷调逆光 | note=镜头近景，情绪冷峻压迫，光影冷调逆光".into(),
            }],
            &HashMap::from([(12, "seed000000001".to_string())]),
        );

        let prompt = prompts
            .get(&12)
            .and_then(|value| value.as_deref())
            .expect("storyboard 12 prompt");
        assert!(prompt.contains("avoid face distortion, identity drift, costume drift"));
    }

    #[test]
    fn review_fragment_conflict_filter_is_limited_to_exact_selected_style_signals() {
        assert!(review_fragment_conflicts_with_selected_style(
            "avoid overly tight close-up framing",
            "镜头近景，情绪冷峻压迫，光影冷调逆光"
        ));
        assert!(!review_fragment_conflicts_with_selected_style(
            "avoid wrong setting details",
            "镜头近景，情绪冷峻压迫，光影冷调逆光"
        ));
    }

    #[test]
    fn infer_video_provider_defaults_to_runway() {
        assert_eq!(infer_video_provider("gen-2"), "runway");
        assert_eq!(infer_video_provider("kling-v1"), "kling");
        assert_eq!(infer_video_provider("pika-1.5"), "pika");
    }

    #[test]
    fn compact_video_ratio_recognizes_common_formats() {
        assert_eq!(compact_video_ratio("vertical 9:16"), Some("9:16".into()));
        assert_eq!(compact_video_ratio("horizontal"), Some("16:9".into()));
        assert_eq!(compact_video_ratio("square 1:1"), Some("1:1".into()));
        assert_eq!(compact_video_ratio(""), None);
    }
}
