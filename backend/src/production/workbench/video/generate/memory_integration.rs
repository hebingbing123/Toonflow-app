use sqlx::PgPool;
use std::collections::{BTreeSet, HashMap};
use uuid::Uuid;

use super::negative_prompt_builder::{
    build_storyboard_negative_prompt_contexts, build_storyboard_negative_prompt_selection,
    build_storyboard_negative_prompts_with_recent_quality,
};
use super::*;
use crate::error::ApiError;
use crate::production::types::GenerateVideoUploadItem;
use crate::production::workbench::video_prompt_memory::{
    extract_key_value, normalize_prompt_text, AgentMemoryRow, StoryboardPromptSeedRow,
};

pub(super) fn normalize_upload_sources(
    items: &[GenerateVideoUploadItem],
) -> Result<Vec<NormalizedGenerateVideoUploadItem>, ApiError> {
    let mut seen = BTreeSet::new();
    let mut normalized = Vec::with_capacity(items.len());
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
        normalized.push(NormalizedGenerateVideoUploadItem {
            storyboard_id: item.id,
            source_url: source.to_string(),
            prompt: item
                .prompt
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_string),
            negative_prompt: item
                .negative_prompt
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_string),
        });
    }
    Ok(normalized)
}

pub(super) fn resolve_storyboard_prompt(
    item: &NormalizedGenerateVideoUploadItem,
    default_prompt: &str,
) -> Result<String, ApiError> {
    item.prompt
        .as_deref()
        .or_else(|| (!default_prompt.is_empty()).then_some(default_prompt))
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| {
            ApiError::BadRequest(format!(
                "prompt must not be empty for storyboard {}",
                item.storyboard_id
            ))
        })
}

pub(super) async fn ensure_track_in_scope(
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

pub(super) async fn ensure_storyboards_in_scope(
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

pub(super) async fn load_project_aspect_ratio(
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

pub(super) async fn load_project_mode(
    pool: &PgPool,
    project_id: Uuid,
) -> Result<Option<String>, ApiError> {
    let raw = sqlx::query_scalar::<_, Option<String>>("SELECT mode FROM app_project WHERE id = $1")
        .bind(project_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(raw.and_then(|value| compact_project_mode(&value)))
}

pub(super) fn compact_video_ratio(value: &str) -> Option<String> {
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

pub(super) fn compact_project_mode(value: &str) -> Option<String> {
    let normalized = value.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return None;
    }
    if normalized.contains("live_action") || normalized.contains("live-action") {
        return Some("live_action.short_drama".to_string());
    }
    if normalized.contains("animated") {
        return Some("animated.short_drama".to_string());
    }
    None
}

pub(super) fn apply_project_mode_prompt_preset(prompt: &str, project_mode: Option<&str>) -> String {
    let trimmed = prompt.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let Some(mode) = project_mode else {
        return trimmed.to_string();
    };
    let normalized_prompt = trimmed.to_ascii_lowercase();
    match mode {
        "live_action.short_drama" => {
            if normalized_prompt.contains("live action")
                || trimmed.contains("真人")
                || trimmed.contains("真实演员")
            {
                trimmed.to_string()
            } else {
                format!(
                    "{trimmed}；真人短剧写实，演员微表情和情绪递进，口型同步，身份一致，真实光线镜头，避免AI感卡通感"
                )
            }
        }
        "animated.short_drama" => {
            if normalized_prompt.contains("anime")
                || trimmed.contains("动漫")
                || trimmed.contains("二次元")
            {
                trimmed.to_string()
            } else {
                format!(
                    "{trimmed}；动漫短剧风格，角色表演有情绪层次，动作镜头利落清晰，适度风格化，避免过强真人纪实感"
                )
            }
        }
        _ => trimmed.to_string(),
    }
}

#[allow(dead_code)]
pub(crate) async fn load_auto_negative_prompt(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<Option<String>, ApiError> {
    let prompts = load_auto_negative_prompt_details(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;
    Ok(storyboard_ids.iter().find_map(|storyboard_id| {
        prompts
            .get(storyboard_id)
            .and_then(|item| item.prompt.clone())
    }))
}

#[allow(dead_code)]
pub(crate) async fn load_auto_negative_prompts(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, Option<String>>, ApiError> {
    Ok(load_auto_negative_prompt_details(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?
    .into_iter()
    .map(|(storyboard_id, selection)| (storyboard_id, selection.prompt))
    .collect())
}

pub(crate) async fn load_auto_negative_prompt_details(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, AutoNegativePromptSelection>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(HashMap::new());
    }
    let review_row_limit = negative_review_fetch_limit(storyboard_ids.len());
    let rows = load_negative_review_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
        review_row_limit,
    )
    .await?;
    let recent_quality_rows = load_recent_quality_signal_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;
    let rejected_rows = load_rejected_video_negative_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids.len(),
    )
    .await?;
    let selected_rows = load_selected_video_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids.len(),
    )
    .await?;
    let storyboard_seed_rows = load_storyboard_prompt_seed_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;

    Ok(build_storyboard_negative_prompts_with_recent_quality(
        storyboard_ids,
        &rows,
        &rejected_rows,
        &selected_rows,
        &storyboard_seed_rows,
        &recent_quality_rows,
    ))
}

pub(crate) async fn load_storyboard_negative_prompt_runtime(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_id: i32,
) -> Result<StoryboardNegativePromptRuntime, ApiError> {
    let review_rows = load_negative_review_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &[storyboard_id],
        negative_review_fetch_limit(1),
    )
    .await?;
    let recent_quality_rows = load_recent_quality_signal_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &[storyboard_id],
    )
    .await?;
    let rejected_rows = load_rejected_video_negative_memory_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        1,
    )
    .await?;
    let selected_rows =
        load_selected_video_memory_rows(pool, user_id, project_numeric_id, script_numeric_id, 1)
            .await?;
    let storyboard_seed_rows = load_storyboard_prompt_seed_rows(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        &[storyboard_id],
    )
    .await?;
    let mut contexts = build_storyboard_negative_prompt_contexts(
        &[storyboard_id],
        &review_rows,
        &recent_quality_rows,
        &selected_rows,
        storyboard_seed_rows,
    );
    let context =
        contexts
            .remove(&storyboard_id)
            .unwrap_or_else(|| StoryboardNegativePromptContext {
                storyboard_id,
                storyboard_review_rows: Vec::new(),
                recent_quality_pressure: None,
                selected_rows: selected_rows.clone(),
                storyboard_row: None,
                current_prompt_seed: None,
                subject_candidates: Vec::new(),
            });
    let (selection, pending_observation_candidates) =
        build_storyboard_negative_prompt_selection(&context, &rejected_rows);
    let prompt_support_rows =
        load_storyboard_prompt_support_rows(pool, user_id, project_numeric_id, script_numeric_id)
            .await?;

    Ok(StoryboardNegativePromptRuntime {
        storyboard_id,
        selection,
        pending_observation_candidates,
        rejected_rows,
        selected_rows,
        prompt_support_rows,
        storyboard_row: context.storyboard_row,
        current_prompt_seed: context.current_prompt_seed,
        subject_candidates: context.subject_candidates,
    })
}

pub(super) async fn load_negative_review_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
    review_row_limit: i64,
) -> Result<Vec<QualityReviewSeedRow>, ApiError> {
    let storyboard_target_ids = storyboard_ids
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    sqlx::query_as::<_, QualityReviewSeedRow>(
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
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(&storyboard_target_ids)
    .bind(review_row_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn load_recent_quality_signal_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<Vec<RecentQualitySignalSeedRow>, ApiError> {
    let storyboard_target_ids = storyboard_ids
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    sqlx::query_as::<_, RecentQualitySignalSeedRow>(
        r#"
        SELECT
          target_type,
          target_id,
          passed,
          overall_score,
          dialogue_naturalness,
          character_consistency,
          visual_quality,
          memory_delivery_priority_applied,
          is_bad_case,
          bad_case_category,
          comments,
          model_params->'diagnostics'->'feedbackMemory'->'focusTags' as feedback_memory_focus_tags
        FROM app_quality_review
        WHERE user_id = $1
          AND project_id = $2
          AND script_id = $3
          AND target_type IN ('storyboard', 'output', 'video')
          AND (
            target_id IS NULL
            OR target_id = ANY($4)
          )
        ORDER BY
          CASE
            WHEN target_type = 'storyboard' AND target_id = ANY($4) THEN 0
            ELSE 1
          END,
          created_at DESC
        LIMIT 24
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(&storyboard_target_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn load_storyboard_prompt_support_rows(
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
            (episodes_id = $3 AND name IN (
                'rejected_video_negative_memory',
                'selected_video_memory',
                'script_video_style_memory',
                'script_video_generation_brief_memory',
                'script_role_video_style_memory',
                'script_video_observation_memory',
                'script_role_video_observation_memory',
                'auto_scope_memory'
            ))
            OR (episodes_id = $3 AND name LIKE 'patch_attribution:%')
            OR (episodes_id IS NULL AND name IN (
                'project_video_style_memory',
                'project_video_generation_brief_memory',
                'project_role_video_style_memory',
                'project_video_observation_memory',
                'project_role_video_observation_memory'
            ))
          )
        ORDER BY create_time_ms DESC
        LIMIT 24
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) fn negative_review_fetch_limit(storyboard_count: usize) -> i64 {
    if storyboard_count == 0 {
        return VIDEO_NEGATIVE_REVIEW_BASE_LIMIT;
    }

    let storyboard_count = i64::try_from(storyboard_count).unwrap_or(i64::MAX);
    (VIDEO_NEGATIVE_REVIEW_BASE_LIMIT
        + storyboard_count.saturating_mul(VIDEO_NEGATIVE_REVIEW_PER_STORYBOARD_ROWS))
    .min(VIDEO_NEGATIVE_REVIEW_MAX_LIMIT)
}

pub(super) async fn load_rejected_video_negative_memory_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_count: usize,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    let rejected_memory_row_limit = rejected_negative_memory_fetch_limit(storyboard_count);
    sqlx::query_as::<_, AgentMemoryRow>(
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
                'script_video_observation_memory',
                'script_role_video_observation_memory'
            ))
            OR (episodes_id IS NULL AND name IN (
                'project_video_observation_memory',
                'project_role_video_observation_memory'
            ))
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(rejected_memory_row_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) async fn load_storyboard_prompt_seed_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<HashMap<i32, StoryboardPromptSeedRow>, ApiError> {
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
        .map(|(storyboard_id, prompt, video_desc, duration)| {
            (
                storyboard_id,
                StoryboardPromptSeedRow {
                    prompt,
                    video_desc,
                    duration,
                },
            )
        })
        .collect())
}

pub(super) async fn load_selected_video_memory_rows(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_count: usize,
) -> Result<Vec<AgentMemoryRow>, ApiError> {
    let selected_memory_row_limit = selected_memory_fetch_limit(storyboard_count);
    sqlx::query_as::<_, AgentMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = 'productionAgent'
          AND memory_type = 'summary'
          AND (
            (episodes_id = $3 AND name IN (
                'selected_video_memory',
                'script_video_style_memory',
                'script_video_generation_brief_memory',
                'script_role_video_style_memory'
            ))
            OR (episodes_id IS NULL AND name IN (
                'project_video_style_memory',
                'project_video_generation_brief_memory',
                'project_role_video_style_memory'
            ))
          )
        ORDER BY create_time_ms DESC
        LIMIT $4
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(selected_memory_row_limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))
}

pub(super) fn rejected_negative_memory_fetch_limit(storyboard_count: usize) -> i64 {
    if storyboard_count == 0 {
        return VIDEO_NEGATIVE_REJECTED_MEMORY_BASE_LIMIT;
    }

    let storyboard_count = i64::try_from(storyboard_count).unwrap_or(i64::MAX);
    (VIDEO_NEGATIVE_REJECTED_MEMORY_BASE_LIMIT
        .max(storyboard_count.saturating_mul(VIDEO_NEGATIVE_REJECTED_MEMORY_PER_STORYBOARD_ROWS)))
    .min(VIDEO_NEGATIVE_REJECTED_MEMORY_MAX_LIMIT)
}

pub(super) fn selected_memory_fetch_limit(storyboard_count: usize) -> i64 {
    if storyboard_count == 0 {
        return VIDEO_NEGATIVE_SELECTED_MEMORY_BASE_LIMIT;
    }

    let storyboard_count = i64::try_from(storyboard_count).unwrap_or(i64::MAX);
    (VIDEO_NEGATIVE_SELECTED_MEMORY_BASE_LIMIT.max(
        storyboard_count
            .saturating_mul(VIDEO_NEGATIVE_SELECTED_MEMORY_PER_STORYBOARD_ROWS)
            .saturating_add(VIDEO_NEGATIVE_SELECTED_MEMORY_SUMMARY_ROWS),
    ))
    .min(VIDEO_NEGATIVE_SELECTED_MEMORY_MAX_LIMIT)
}

pub(super) fn filter_selected_rows_for_subject(
    selected_rows: &[AgentMemoryRow],
    subject_candidates: &[String],
) -> Vec<AgentMemoryRow> {
    if subject_candidates.is_empty() {
        return selected_rows
            .iter()
            .map(|row| AgentMemoryRow {
                name: row.name.clone(),
                content: row.content.clone(),
            })
            .collect();
    }

    let normalized_candidates = subject_candidates
        .iter()
        .map(|candidate| normalize_prompt_text(candidate))
        .filter(|candidate| !candidate.is_empty())
        .collect::<Vec<_>>();
    selected_rows
        .iter()
        .filter(|row| {
            if row.name != "selected_video_memory" {
                return true;
            }
            let Some(subject) = extract_key_value(&row.content, "subject")
                .or_else(|| extract_key_value(&row.content, "subjectAliases"))
            else {
                return true;
            };
            let memory_subjects = subject
                .split('/')
                .map(normalize_prompt_text)
                .filter(|subject| !subject.is_empty())
                .collect::<Vec<_>>();
            memory_subjects.is_empty()
                || memory_subjects.iter().any(|memory_subject| {
                    normalized_candidates.iter().any(|candidate| {
                        candidate == memory_subject
                            || candidate.contains(memory_subject)
                            || memory_subject.contains(candidate)
                    })
                })
        })
        .map(|row| AgentMemoryRow {
            name: row.name.clone(),
            content: row.content.clone(),
        })
        .collect()
}
