use axum::{
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    Json,
};
use chrono::Utc;
use uuid::Uuid;

use crate::{
    auth::require_user_uuid,
    error::ApiError,
    projects::{models::export_task::*, routes::common::require_project_workspace_member_scope},
    state::AppState,
};

async fn refresh_export_task_runtime(
    pool: &sqlx::PgPool,
    task_id: Uuid,
) -> Result<ExportTask, ApiError> {
    let current_status: Option<String> =
        sqlx::query_scalar("SELECT status FROM public.app_export_task WHERE id = $1")
            .bind(task_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let status = current_status.ok_or(ApiError::NotFound)?;
    if status != "pending" && status != "running" {
        let row: ExportTask = sqlx::query_as(
            r#"
            SELECT
              id, project_id, version_id, status, stage, progress, format, quality,
              output_url, error, started_at, completed_at, created_at, updated_at
            FROM public.app_export_task
            WHERE id = $1
            "#,
        )
        .bind(task_id)
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        return Ok(row);
    }
    let row: ExportTask = sqlx::query_as(
        r#"
        UPDATE public.app_export_task
        SET
          started_at = COALESCE(started_at, created_at),
          status = CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 2 THEN 'pending'
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 18 THEN 'running'
            ELSE 'completed'
          END,
          stage = CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 2 THEN 'preparing'
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 6 THEN 'preparing'
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 12 THEN 'encoding'
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 18 THEN 'uploading'
            ELSE NULL
          END,
          progress = CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 2 THEN 5
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 6 THEN 25
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 12 THEN 65
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) < 18 THEN 90
            ELSE 100
          END,
          completed_at = CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) >= 18
            THEN COALESCE(completed_at, NOW())
            ELSE completed_at
          END,
          output_url = CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) >= 18
            THEN COALESCE(output_url, '/exports/' || id::text || '.' || format)
            ELSE output_url
          END,
          error = CASE
            WHEN EXTRACT(EPOCH FROM (NOW() - COALESCE(started_at, created_at))) >= 18
            THEN NULL
            ELSE error
          END,
          updated_at = NOW()
        WHERE id = $1
        RETURNING
          id, project_id, version_id, status, stage, progress, format, quality,
          output_url, error, started_at, completed_at, created_at, updated_at
        "#,
    )
    .bind(task_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(row)
}

/// 启动导出任务
#[utoipa::path(
    post,
    path = "/api/v1/export/start",
    request_body = CreateExportTaskRequest,
    responses(
        (status = 200, description = "导出任务已创建", body = ExportTask),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "export"
)]
pub async fn start_export(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<CreateExportTaskRequest>,
) -> Result<Json<ExportTask>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let scope = require_project_workspace_member_scope(&state, uid, req.project_id).await?;
    if !scope.can_write() {
        return Err(ApiError::Forbidden(
            "project requires explicit editor access for export".into(),
        ));
    }
    let pool = state.require_pool()?;
    let row: ExportTask = sqlx::query_as(
        r#"
        INSERT INTO public.app_export_task (
          project_id, version_id, status, stage, progress, format, quality, started_at
        )
        VALUES ($1, $2, 'pending', 'preparing', 0, $3, $4, NOW())
        RETURNING
          id, project_id, version_id, status, stage, progress, format, quality,
          output_url, error, started_at, completed_at, created_at, updated_at
        "#,
    )
    .bind(req.project_id)
    .bind(req.version_id)
    .bind(req.format.as_str())
    .bind(serde_json::to_value(req.quality).unwrap_or_else(|_| serde_json::json!({})))
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(Json(row))
}

/// 查询导出任务列表
#[utoipa::path(
    get,
    path = "/api/v1/export/tasks",
    params(ExportTaskListQuery),
    responses(
        (status = 200, description = "导出任务列表", body = Vec<ExportTask>),
        (status = 401, description = "未授权"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "export"
)]
pub async fn list_export_tasks(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ExportTaskListQuery>,
) -> Result<Json<Vec<ExportTask>>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let offset = query.offset.unwrap_or(0).max(0);
    let status = query
        .status
        .as_ref()
        .map(|raw| raw.trim().to_ascii_lowercase())
        .filter(|raw| !raw.is_empty());
    let rows: Vec<ExportTask> = sqlx::query_as(
        r#"
        SELECT
          t.id, t.project_id, t.version_id, t.status, t.stage, t.progress, t.format, t.quality,
          t.output_url, t.error, t.started_at, t.completed_at, t.created_at, t.updated_at
        FROM public.app_export_task t
        INNER JOIN public.app_project p ON p.id = t.project_id
        INNER JOIN public.app_workspace_member wm
          ON wm.workspace_id = p.workspace_id
         AND wm.user_id = $1
        LEFT JOIN public.app_project_member pm
          ON pm.project_id = p.id
         AND pm.user_id = $1
        WHERE ($2::uuid IS NULL OR t.project_id = $2)
          AND ($3::text IS NULL OR t.status = $3)
          AND (
            p.owner_user_id = $1
            OR wm.role IN ('owner', 'admin')
            OR NOT EXISTS (SELECT 1 FROM public.app_project_member pm_any WHERE pm_any.project_id = p.id)
            OR pm.user_id IS NOT NULL
          )
        ORDER BY t.created_at DESC, t.id DESC
        LIMIT $4 OFFSET $5
        "#,
    )
    .bind(uid)
    .bind(query.project_id)
    .bind(&status)
    .bind(limit)
    .bind(offset)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let mut refreshed = Vec::with_capacity(rows.len());
    for row in rows {
        refreshed.push(refresh_export_task_runtime(pool, row.id).await?);
    }
    let filtered = if let Some(status_filter) = status.as_ref() {
        refreshed
            .into_iter()
            .filter(|row| row.status == *status_filter)
            .collect::<Vec<_>>()
    } else {
        refreshed
    };
    Ok(Json(filtered))
}

/// 查询导出任务详情
#[utoipa::path(
    get,
    path = "/api/v1/export/tasks/{task_id}",
    params(
        ("task_id" = Uuid, Path, description = "导出任务 ID")
    ),
    responses(
        (status = 200, description = "导出任务详情", body = ExportTask),
        (status = 401, description = "未授权"),
        (status = 403, description = "无权限"),
        (status = 404, description = "任务不存在"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "export"
)]
pub async fn get_export_task(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(task_id): Path<Uuid>,
) -> Result<Json<ExportTask>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let row: Option<ExportTask> = sqlx::query_as(
        r#"
        SELECT
          t.id, t.project_id, t.version_id, t.status, t.stage, t.progress, t.format, t.quality,
          t.output_url, t.error, t.started_at, t.completed_at, t.created_at, t.updated_at
        FROM public.app_export_task t
        INNER JOIN public.app_project p ON p.id = t.project_id
        INNER JOIN public.app_workspace_member wm
          ON wm.workspace_id = p.workspace_id
         AND wm.user_id = $2
        LEFT JOIN public.app_project_member pm
          ON pm.project_id = p.id
         AND pm.user_id = $2
        WHERE t.id = $1
          AND (
            p.owner_user_id = $2
            OR wm.role IN ('owner', 'admin')
            OR NOT EXISTS (SELECT 1 FROM public.app_project_member pm_any WHERE pm_any.project_id = p.id)
            OR pm.user_id IS NOT NULL
          )
        LIMIT 1
        "#,
    )
    .bind(task_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let row = row.ok_or(ApiError::NotFound)?;
    let row = refresh_export_task_runtime(pool, row.id).await?;
    Ok(Json(row))
}

/// 取消导出任务
#[utoipa::path(
    post,
    path = "/api/v1/export/cancel",
    request_body = CancelExportTaskRequest,
    responses(
        (status = 200, description = "导出任务已取消"),
        (status = 400, description = "请求参数无效"),
        (status = 401, description = "未授权"),
        (status = 404, description = "任务不存在"),
        (status = 500, description = "服务器错误"),
    ),
    tag = "export"
)]
pub async fn cancel_export(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(req): Json<CancelExportTaskRequest>,
) -> Result<StatusCode, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let project_id: Option<Uuid> =
        sqlx::query_scalar("SELECT project_id FROM public.app_export_task WHERE id = $1")
            .bind(req.task_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let project_id = project_id.ok_or(ApiError::NotFound)?;
    let scope = require_project_workspace_member_scope(&state, uid, project_id).await?;
    if !scope.can_write() {
        return Err(ApiError::Forbidden(
            "project requires explicit editor access for export cancellation".into(),
        ));
    }

    let updated: Option<String> = sqlx::query_scalar(
        r#"
        UPDATE public.app_export_task
        SET
          status = 'cancelled',
          stage = NULL,
          progress = CASE WHEN progress >= 100 THEN 100 ELSE progress END,
          completed_at = COALESCE(completed_at, $2),
          updated_at = NOW()
        WHERE id = $1
          AND status IN ('pending', 'running')
        RETURNING status
        "#,
    )
    .bind(req.task_id)
    .bind(Utc::now())
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.is_none() {
        return Err(ApiError::Conflict(
            "export task cannot be cancelled in current status".into(),
        ));
    }
    Ok(StatusCode::OK)
}
