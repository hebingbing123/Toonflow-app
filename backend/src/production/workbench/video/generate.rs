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
    select_rejected_video_negative_memory_notes, AgentMemoryRow,
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
}

#[derive(Debug, sqlx::FromRow)]
struct QualityReviewSeedRow {
    bad_case_category: Option<String>,
    comments: Option<String>,
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
    let auto_negative_prompt = load_auto_negative_prompt(
        pool,
        user_id,
        body.project_id,
        body.script_id,
        &storyboard_ids,
    )
    .await?;
    let merged_negative_prompt = merge_negative_prompts(
        body.negative_prompt.as_deref(),
        auto_negative_prompt.as_deref(),
    );
    let provider = infer_video_provider(&body.model);
    let duration_label = format!("{}s", body.duration);
    let prompt = body.prompt.trim().to_string();
    let model = body.model.trim().to_string();
    let resolution = body.resolution.trim().to_string();
    let mode = body.mode.trim().to_string();

    let mut enqueued = Vec::with_capacity(upload_sources.len());
    for (storyboard_numeric_id, source_url) in upload_sources {
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
    }

    let total = enqueued.len();
    Ok(JsonResponse(WorkbenchGenerateVideoResponse {
        enqueued,
        total,
        negative_prompt: merged_negative_prompt,
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
    if storyboard_ids.is_empty() {
        return Ok(None);
    }
    let storyboard_target_ids = storyboard_ids
        .iter()
        .map(ToString::to_string)
        .collect::<Vec<_>>();
    let rows = sqlx::query_as::<_, QualityReviewSeedRow>(
        r#"
        SELECT bad_case_category, comments
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
    let review_prompt = compact_negative_review_constraints(&rows);
    let rejected_prompt = load_rejected_video_negative_prompt(
        pool,
        user_id,
        project_numeric_id,
        script_numeric_id,
        storyboard_ids,
    )
    .await?;
    Ok(merge_negative_prompts(
        review_prompt.as_deref(),
        rejected_prompt.as_deref(),
    ))
}

async fn load_rejected_video_negative_prompt(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    storyboard_ids: &[i32],
) -> Result<Option<String>, ApiError> {
    if storyboard_ids.is_empty() {
        return Ok(None);
    }

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

    let mut merged = None;
    for storyboard_id in storyboard_ids {
        let prompt = select_rejected_video_negative_memory_notes(&rows, *storyboard_id)
            .into_iter()
            .next();
        merged = merge_negative_prompts(merged.as_deref(), prompt.as_deref());
    }
    Ok(merged)
}

fn compact_negative_review_constraints(rows: &[QualityReviewSeedRow]) -> Option<String> {
    let mut fragments = Vec::new();
    for row in rows {
        if let Some(category) = row.bad_case_category.as_deref() {
            push_unique_negative_fragment(&mut fragments, map_bad_case_category(category));
        }
        if fragments.len() >= 4 {
            break;
        }
    }
    for row in rows {
        if let Some(comments) = row.comments.as_deref() {
            for fragment in infer_negative_fragments_from_comments(comments) {
                push_unique_negative_fragment(&mut fragments, Some(fragment));
            }
        }
        if fragments.len() >= 4 {
            break;
        }
    }
    if fragments.is_empty() {
        return None;
    }
    let joined = fragments.join(", ");
    Some(clip_negative_prompt(&joined))
}

fn push_unique_negative_fragment(target: &mut Vec<String>, candidate: Option<&'static str>) {
    let Some(candidate) = candidate else {
        return;
    };
    if target.iter().any(|existing| existing == candidate) {
        return;
    }
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
    let mut fragments = Vec::new();
    for prompt in [manual, automatic].into_iter().flatten() {
        for fragment in prompt.split([',', ';', '，', '；', '\n']) {
            let fragment = fragment.trim();
            if fragment.is_empty() {
                continue;
            }
            if fragments
                .iter()
                .any(|existing: &String| existing == fragment)
            {
                continue;
            }
            fragments.push(fragment.to_string());
        }
    }
    if fragments.is_empty() {
        None
    } else {
        Some(clip_negative_prompt(&fragments.join(", ")))
    }
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
        clip_negative_prompt, compact_negative_review_constraints, compact_video_ratio,
        infer_negative_fragments_from_comments, infer_video_provider,
        load_rejected_video_negative_prompt, merge_negative_prompts, normalize_upload_sources,
        QualityReviewSeedRow,
    };
    use crate::production::types::GenerateVideoUploadItem;
    use crate::production::workbench::video_prompt_memory::{
        select_rejected_video_negative_memory_notes, AgentMemoryRow,
    };
    use sqlx::PgPool;
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
                bad_case_category: Some("visual_error".into()),
                comments: Some("手指变形且有闪烁".into()),
            },
            QualityReviewSeedRow {
                bad_case_category: Some("character_break".into()),
                comments: Some("角色脸不稳定，服装漂移".into()),
            },
        ])
        .expect("negative prompt");

        assert!(prompt.contains("avoid warped anatomy, blur, flicker"));
        assert!(prompt.contains("avoid warped hands or limbs"));
        assert!(prompt.contains("avoid face drift or costume inconsistency"));
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

    #[tokio::test]
    async fn load_rejected_video_negative_prompt_returns_none_without_storyboards() {
        let pool = PgPool::connect_lazy("postgres://postgres:postgres@localhost/postgres")
            .expect("lazy pool");
        let prompt = load_rejected_video_negative_prompt(&pool, Uuid::nil(), 1, 2, &[])
            .await
            .expect("prompt");
        assert_eq!(prompt, None);
    }

    #[test]
    fn rejected_video_negative_memory_can_merge_with_review_constraints() {
        let rows = vec![
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=12 | avoid=avoid flat cold lighting, avoid oppressive or frantic mood".into(),
            },
            AgentMemoryRow {
                name: "rejected_video_negative_memory".into(),
                content: "storyboardIds=9 | avoid=avoid shaky handheld motion".into(),
            },
        ];
        let merged = merge_negative_prompts(
            Some("avoid flicker"),
            select_rejected_video_negative_memory_notes(&rows, 12)
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
