//! Wave 7 + **NLE M1–M3**: timeline read/save, reorder, templates, FFmpeg preview.

use axum::{
    extract::{Path, State},
    http::HeaderMap,
    Json,
};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, conflict_with_details_i18n, ApiError};
use crate::jobs::{enqueue_generation_job, JobRow, JOB_KIND_SHORT_VIDEO_TIMELINE_PREVIEW};
use crate::projects::routes::common::{
    require_project_workspace_member_scope, require_project_write_scope,
};
use crate::short_video::assembly_query::{
    assembly_selected_media_kind, fetch_project_assembly_flat_rows, fetch_project_assembly_header,
};
use crate::short_video::timeline::{
    apply_template as apply_timeline_template, clip_for_storyboard, default_out_ms_from_duration,
    default_tracks_from_assembly, is_known_template, list_timeline_revisions,
    load_revision_document, load_timeline_row, merge_tracks, mock_waveform_peaks_for_voiceover,
    pad_transitions_for_video, parse_timeline_document, upsert_timeline_with_revision,
    validate_schema_version, validate_tracks, ProjectTimelineDocument, TimelineBgmTrack,
    TimelineSubtitleCue, TimelineTracks, TimelineTransition, TimelineTransitionType,
    TimelineVideoClip, TimelineVoiceoverClip, TIMELINE_SCHEMA_VERSION,
};
use crate::state::AppState;

use super::super::super::types::{
    ProjectShortVideoTimelineResponse, PutProjectShortVideoTimelineBody,
    PutProjectShortVideoTimelineResponse, ShortVideoTimelineApplyTemplateBody,
    ShortVideoTimelineApplyTemplateResponse, ShortVideoTimelineBgmTrack,
    ShortVideoTimelinePreviewEnqueueResponse, ShortVideoTimelineReorderBody,
    ShortVideoTimelineReorderResponse, ShortVideoTimelineRestoreBody,
    ShortVideoTimelineRestoreResponse, ShortVideoTimelineRevisionItem,
    ShortVideoTimelineRevisionsResponse, ShortVideoTimelineScriptGroup, ShortVideoTimelineShot,
    ShortVideoTimelineSubtitleCue, ShortVideoTimelineTracks, ShortVideoTimelineTransition,
    ShortVideoTimelineVideoClip, ShortVideoTimelineVoiceoverClip,
};

fn transition_to_api(tr: &TimelineTransition) -> ShortVideoTimelineTransition {
    ShortVideoTimelineTransition {
        transition_type: tr.transition_type.as_str().to_string(),
        duration_ms: tr.duration_ms,
    }
}

fn transition_from_api(tr: &ShortVideoTimelineTransition) -> Result<TimelineTransition, ApiError> {
    let transition_type = TimelineTransitionType::parse(&tr.transition_type)
        .ok_or_else(|| bad_request_i18n("invalid transition type", "无效的转场类型"))?;
    Ok(TimelineTransition {
        transition_type,
        duration_ms: tr.duration_ms,
    })
}

fn tracks_to_api(tracks: &TimelineTracks) -> ShortVideoTimelineTracks {
    ShortVideoTimelineTracks {
        video: tracks
            .video
            .iter()
            .map(|c| ShortVideoTimelineVideoClip {
                storyboard_numeric_id: c.storyboard_numeric_id,
                source_url: c.source_url.clone(),
                in_ms: c.in_ms,
                out_ms: c.out_ms,
                effect_preset_id: c.effect_preset_id.clone(),
            })
            .collect(),
        bgm: tracks.bgm.as_ref().map(|b| ShortVideoTimelineBgmTrack {
            enabled: b.enabled,
            asset_url: b.asset_url.clone(),
            bgm_strategy: b.bgm_strategy.clone(),
            volume: b.volume,
        }),
        subtitles: tracks
            .subtitles
            .iter()
            .map(|c| ShortVideoTimelineSubtitleCue {
                storyboard_numeric_id: c.storyboard_numeric_id,
                start_ms: c.start_ms,
                end_ms: c.end_ms,
                text: c.text.clone(),
                style_id: c.style_id.clone(),
            })
            .collect(),
        transitions: tracks.transitions.iter().map(transition_to_api).collect(),
        voiceover: tracks
            .voiceover
            .iter()
            .map(|v| ShortVideoTimelineVoiceoverClip {
                storyboard_numeric_id: v.storyboard_numeric_id,
                start_ms: v.start_ms,
                source_url: v.source_url.clone(),
                volume: v.volume,
            })
            .collect(),
        template_id: tracks.template_id.clone(),
    }
}

fn tracks_from_api(tracks: &ShortVideoTimelineTracks) -> Result<TimelineTracks, ApiError> {
    let transitions: Result<Vec<_>, _> =
        tracks.transitions.iter().map(transition_from_api).collect();
    Ok(TimelineTracks {
        video: tracks
            .video
            .iter()
            .map(|c| TimelineVideoClip {
                storyboard_numeric_id: c.storyboard_numeric_id,
                source_url: c.source_url.clone(),
                in_ms: c.in_ms,
                out_ms: c.out_ms,
                effect_preset_id: c.effect_preset_id.clone(),
            })
            .collect(),
        bgm: tracks.bgm.as_ref().map(|b| TimelineBgmTrack {
            enabled: b.enabled,
            asset_url: b.asset_url.clone(),
            bgm_strategy: b.bgm_strategy.clone(),
            volume: b.volume,
        }),
        subtitles: tracks
            .subtitles
            .iter()
            .map(|c| TimelineSubtitleCue {
                storyboard_numeric_id: c.storyboard_numeric_id,
                start_ms: c.start_ms,
                end_ms: c.end_ms,
                text: c.text.clone(),
                style_id: c.style_id.clone(),
            })
            .collect(),
        transitions: transitions?,
        voiceover: tracks
            .voiceover
            .iter()
            .map(|v| TimelineVoiceoverClip {
                storyboard_numeric_id: v.storyboard_numeric_id,
                start_ms: v.start_ms,
                source_url: v.source_url.clone(),
                volume: v.volume,
            })
            .collect(),
        template_id: tracks.template_id.clone(),
    })
}

async fn build_timeline_response(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    header_bgm: Option<&str>,
    flat: &[crate::short_video::assembly_query::AssemblyFlatRow],
) -> Result<ProjectShortVideoTimelineResponse, ApiError> {
    let defaults = default_tracks_from_assembly(flat, header_bgm);
    let persisted_row = load_timeline_row(pool, project_id).await?;
    let (timeline_version, revision, tracks) = if let Some(row) = persisted_row {
        let persisted = parse_timeline_document(row.schema_version, &row.timeline_json);
        (
            Some(row.updated_at.to_rfc3339()),
            Some(row.revision),
            merge_tracks(defaults, &persisted),
        )
    } else {
        (None, None, defaults)
    };

    let peaks = if tracks.voiceover.is_empty() {
        None
    } else {
        Some(mock_waveform_peaks_for_voiceover(&tracks.voiceover))
    };

    let mut script_order: Vec<i32> = Vec::new();
    let mut script_names: std::collections::HashMap<i32, Option<String>> =
        std::collections::HashMap::new();
    let mut grouped: std::collections::HashMap<i32, Vec<ShortVideoTimelineShot>> =
        std::collections::HashMap::new();

    for r in flat {
        if !script_order.contains(&r.script_numeric_id) {
            script_order.push(r.script_numeric_id);
        }
        script_names
            .entry(r.script_numeric_id)
            .or_insert(r.script_name.clone());
        let subtitle_snippet = r
            .video_desc
            .as_deref()
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .or_else(|| r.prompt.as_deref().map(str::trim).filter(|s| !s.is_empty()))
            .unwrap_or_default()
            .chars()
            .take(120)
            .collect::<String>();
        let selected_url = r.file_path.clone();
        let thumbnail_url = match assembly_selected_media_kind(selected_url.as_deref()) {
            "video" => None,
            "image" => selected_url.clone(),
            _ => selected_url.clone(),
        };
        let clip = clip_for_storyboard(&tracks, r.storyboard_numeric_id);
        let (in_ms, out_ms) = clip
            .map(|c| (c.in_ms, c.out_ms))
            .unwrap_or_else(|| (0, default_out_ms_from_duration(r.duration.as_deref())));
        grouped
            .entry(r.script_numeric_id)
            .or_default()
            .push(ShortVideoTimelineShot {
                storyboard_id: r.storyboard_id,
                storyboard_numeric_id: r.storyboard_numeric_id,
                sb_index: r.sb_index,
                duration: r.duration.clone(),
                selected_video_url: selected_url.clone(),
                thumbnail_url,
                subtitle_snippet,
                voiceover_audio_url: r.voiceover_audio_url.clone(),
                candidate_status: r.candidate_status.clone(),
                in_ms,
                out_ms,
                source_url: selected_url,
            });
    }

    let scripts = script_order
        .into_iter()
        .map(|script_numeric_id| ShortVideoTimelineScriptGroup {
            script_numeric_id,
            script_name: script_names.get(&script_numeric_id).cloned().flatten(),
            shots: grouped.remove(&script_numeric_id).unwrap_or_default(),
        })
        .collect();

    Ok(ProjectShortVideoTimelineResponse {
        schema_version: TIMELINE_SCHEMA_VERSION,
        timeline_version,
        revision,
        tracks: tracks_to_api(&tracks),
        scripts,
        voiceover_waveform_peaks: peaks,
    })
}

async fn check_timeline_version_conflict(
    pool: &sqlx::PgPool,
    project_id: Uuid,
    expected: &str,
) -> Result<(), ApiError> {
    if let Some(row) = load_timeline_row(pool, project_id).await? {
        let current = row.updated_at.to_rfc3339();
        if current != expected {
            return Err(conflict_with_details_i18n(
                "timeline_version mismatch",
                "时间线时间戳冲突",
                serde_json::json!({
                    "expectedTimelineVersion": expected,
                    "currentTimelineVersion": current,
                }),
            ));
        }
    } else {
        return Err(conflict_with_details_i18n(
            "timeline_version mismatch: no persisted timeline yet",
            "时间线尚未保存",
            serde_json::json!({}),
        ));
    }
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/short-video-timeline",
    operation_id = "getProjectShortVideoTimelineByProjectIdV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ProjectShortVideoTimelineResponse),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
        (status = 404, description = "Not found"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_by_id(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ProjectShortVideoTimelineResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let header = fetch_project_assembly_header(pool, scope.id)
        .await?
        .ok_or(ApiError::NotFound)?;
    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;
    Ok(Json(
        build_timeline_response(pool, header.id, header.bgm_strategy.as_deref(), &flat).await?,
    ))
}

#[utoipa::path(
    put,
    path = "/api/v1/projects/{project_id}/short-video-timeline",
    operation_id = "putProjectShortVideoTimelineByProjectIdV1",
    tag = "projects",
    request_body = PutProjectShortVideoTimelineBody,
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = PutProjectShortVideoTimelineResponse),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
        (status = 409, description = "Version conflict"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_put(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<PutProjectShortVideoTimelineBody>,
) -> Result<Json<PutProjectShortVideoTimelineResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_write_scope(&state, uid, project_id).await?;

    validate_schema_version(body.schema_version)?;

    let mut tracks = tracks_from_api(&body.tracks)?;
    crate::short_video::timeline::pad_transitions_for_video(&mut tracks);
    validate_tracks(&tracks)?;

    if let Some(expected) = body
        .expected_timeline_version
        .as_deref()
        .map(str::trim)
        .filter(|s| !s.is_empty())
    {
        check_timeline_version_conflict(pool, scope.id, expected).await?;
    }

    let doc = ProjectTimelineDocument {
        schema_version: TIMELINE_SCHEMA_VERSION,
        tracks,
    };
    let (updated_at, revision) =
        upsert_timeline_with_revision(pool, scope.id, &doc, uid, body.expected_revision).await?;

    Ok(Json(PutProjectShortVideoTimelineResponse {
        schema_version: TIMELINE_SCHEMA_VERSION,
        timeline_version: updated_at.to_rfc3339(),
        revision,
        updated_clip_count: doc.tracks.video.len(),
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/short-video-timeline/apply-template",
    operation_id = "postProjectShortVideoTimelineApplyTemplateV1",
    tag = "projects",
    request_body = ShortVideoTimelineApplyTemplateBody,
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ShortVideoTimelineApplyTemplateResponse),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_apply_template(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ShortVideoTimelineApplyTemplateBody>,
) -> Result<Json<ShortVideoTimelineApplyTemplateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_write_scope(&state, uid, project_id).await?;

    let template_id = body.template_id.trim();
    if !is_known_template(template_id) {
        return Err(bad_request_i18n("unknown templateId", "未知的 templateId"));
    }

    let header = fetch_project_assembly_header(pool, scope.id)
        .await?
        .ok_or(ApiError::NotFound)?;
    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;

    let existing = if let Some(row) = load_timeline_row(pool, scope.id).await? {
        let doc = parse_timeline_document(row.schema_version, &row.timeline_json);
        Some(doc.tracks)
    } else {
        None
    };

    let tracks = apply_timeline_template(
        template_id,
        &flat,
        header.bgm_strategy.as_deref(),
        existing.as_ref(),
    );
    validate_tracks(&tracks)?;

    let doc = ProjectTimelineDocument {
        schema_version: TIMELINE_SCHEMA_VERSION,
        tracks,
    };
    let (updated_at, _revision) =
        upsert_timeline_with_revision(pool, scope.id, &doc, uid, None).await?;

    Ok(Json(ShortVideoTimelineApplyTemplateResponse {
        schema_version: TIMELINE_SCHEMA_VERSION,
        timeline_version: updated_at.to_rfc3339(),
        template_id: template_id.to_string(),
        video_clip_count: doc.tracks.video.len(),
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/projects/{project_id}/short-video-timeline/revisions",
    operation_id = "getProjectShortVideoTimelineRevisionsV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ShortVideoTimelineRevisionsResponse),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_revisions(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ShortVideoTimelineRevisionsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let items = list_timeline_revisions(pool, scope.id).await?;
    Ok(Json(ShortVideoTimelineRevisionsResponse {
        revisions: items
            .into_iter()
            .map(|r| ShortVideoTimelineRevisionItem {
                revision: r.revision,
                created_at: r.created_at.to_rfc3339(),
                created_by: r.created_by,
                summary: Some(r.summary),
            })
            .collect(),
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/short-video-timeline/restore",
    operation_id = "postProjectShortVideoTimelineRestoreV1",
    tag = "projects",
    request_body = ShortVideoTimelineRestoreBody,
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ShortVideoTimelineRestoreResponse),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_restore(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ShortVideoTimelineRestoreBody>,
) -> Result<Json<ShortVideoTimelineRestoreResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_write_scope(&state, uid, project_id).await?;

    if body.revision <= 0 {
        return Err(bad_request_i18n(
            "revision must be positive",
            "revision 必须为正整数",
        ));
    }

    let restored_from = body.revision;
    let mut doc = load_revision_document(pool, scope.id, restored_from).await?;
    doc.schema_version = TIMELINE_SCHEMA_VERSION;
    pad_transitions_for_video(&mut doc.tracks);
    validate_tracks(&doc.tracks)?;

    let (updated_at, revision) =
        upsert_timeline_with_revision(pool, scope.id, &doc, uid, None).await?;

    Ok(Json(ShortVideoTimelineRestoreResponse {
        schema_version: TIMELINE_SCHEMA_VERSION,
        timeline_version: updated_at.to_rfc3339(),
        revision,
        restored_from_revision: restored_from,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/short-video-timeline/preview",
    operation_id = "postProjectShortVideoTimelinePreviewByProjectIdV1",
    tag = "projects",
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ShortVideoTimelinePreviewEnqueueResponse),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
        (status = 404, description = "Not found"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_preview(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<ShortVideoTimelinePreviewEnqueueResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    let header = fetch_project_assembly_header(pool, scope.id)
        .await?
        .ok_or(ApiError::NotFound)?;
    let flat = fetch_project_assembly_flat_rows(pool, header.id).await?;
    let response =
        build_timeline_response(pool, header.id, header.bgm_strategy.as_deref(), &flat).await?;
    let clip_count = response
        .tracks
        .video
        .iter()
        .filter(|c| !c.source_url.trim().is_empty() && c.out_ms > c.in_ms)
        .count();
    if clip_count == 0 {
        return Err(bad_request_i18n(
            "no timeline video clips ready for preview",
            "没有可用于预览的时间线视频片段",
        ));
    }

    let project_numeric_id: i32 =
        sqlx::query_scalar(r#"SELECT numeric_id FROM app_project WHERE id = $1"#)
            .bind(header.id)
            .fetch_one(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let payload = serde_json::json!({
        "source": "short_video_space.timeline_preview",
        "project_uuid": header.id,
        "project_numeric_id": project_numeric_id,
        "clip_count": clip_count,
    });

    let job: JobRow = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_SHORT_VIDEO_TIMELINE_PREVIEW,
        payload,
        Some(&headers),
        &state.billing_config,
    )
    .await?;

    Ok(Json(ShortVideoTimelinePreviewEnqueueResponse {
        schema_version: TIMELINE_SCHEMA_VERSION,
        job_id: job.id,
        clip_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/projects/{project_id}/short-video-timeline/reorder",
    operation_id = "postProjectShortVideoTimelineReorderV1",
    tag = "projects",
    request_body = ShortVideoTimelineReorderBody,
    params(("project_id" = Uuid, Path, description = "Project UUID")),
    responses(
        (status = 200, description = "OK", body = ShortVideoTimelineReorderResponse),
        (status = 400, description = "Bad request"),
        (status = 401, description = "Unauthorized"),
        (status = 403, description = "Forbidden"),
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn project_short_video_timeline_reorder(
    State(state): State<AppState>,
    Path(project_id): Path<Uuid>,
    headers: HeaderMap,
    Json(body): Json<ShortVideoTimelineReorderBody>,
) -> Result<Json<ShortVideoTimelineReorderResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let scope = require_project_write_scope(&state, uid, project_id).await?;

    if body.ordered_storyboard_ids.is_empty() {
        return Err(bad_request_i18n(
            "orderedStoryboardIds must not be empty",
            "orderedStoryboardIds 不能为空",
        ));
    }

    let script_uuid: Uuid = sqlx::query_scalar(
        r#"
        SELECT s.id
        FROM app_script s
        INNER JOIN app_project p ON p.id = s.project_id
        WHERE p.id = $1
          AND s.numeric_id = $2
        "#,
    )
    .bind(scope.id)
    .bind(body.script_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or_else(|| {
        bad_request_i18n(
            "script_numeric_id does not belong to project",
            "script_numeric_id 不属于该项目",
        )
    })?;

    for (index, storyboard_numeric_id) in body.ordered_storyboard_ids.iter().enumerate() {
        let updated = sqlx::query(
            r#"
            UPDATE app_storyboard
            SET sb_index = $3, updated_at = NOW()
            WHERE script_id = $1
              AND numeric_id = $2
            "#,
        )
        .bind(script_uuid)
        .bind(storyboard_numeric_id)
        .bind(index as i32)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .rows_affected();
        if updated == 0 {
            return Err(ApiError::BadRequest(format!(
                "storyboard numeric id {storyboard_numeric_id} not found in script {}",
                body.script_numeric_id
            )));
        }
    }

    Ok(Json(ShortVideoTimelineReorderResponse {
        schema_version: TIMELINE_SCHEMA_VERSION,
        script_numeric_id: body.script_numeric_id,
        updated_count: body.ordered_storyboard_ids.len(),
    }))
}
