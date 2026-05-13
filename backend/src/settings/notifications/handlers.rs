use axum::{
    extract::{Json, Path, Query, State},
    http::HeaderMap,
    response::Response,
};
use serde_json::{json, Value};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::helpers::{bad_request_i18n, forbidden_i18n, validate_non_empty_string};
use crate::error::ApiError;
use crate::jobs::{
    enqueue_generation_job, JobRow, JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT,
};
use crate::state::AppState;

use super::content_compliance_sync_storage::sync_content_compliance_alert_notifications;
use super::storage::{
    apply_notification_preferences_template, delete_notifications as delete_notifications_storage,
    delete_read_notifications as delete_read_notifications_storage, get_notification_preferences,
    get_notification_preferences_envelope, list_notifications,
    mark_all_notifications_read as mark_all_notifications_read_storage,
    mark_notifications_read_state, reset_notification_preferences, unread_notification_count,
    upsert_notification_preferences,
};
use super::types::{
    ApplyContentComplianceClearedTemplateBody, ApplyContentComplianceClearedTemplateResponse,
    ApplyNotificationPreferencesTemplateBody, ContentComplianceClearedTemplateAuditItem,
    ContentComplianceClearedTemplateItem, ContentComplianceClearedTemplatePolicy,
    DeleteContentComplianceClearedTemplateBody, DeleteContentComplianceClearedTemplateResponse,
    DeleteNotificationsBody, DeleteNotificationsResponse,
    ExportContentComplianceClearedTemplatesResponse,
    ExportWorkspaceContentComplianceClearedTemplateAuditQuery,
    ExportWorkspaceContentComplianceClearedTemplateAuditResponse,
    ImportContentComplianceClearedTemplatesBody, ImportContentComplianceClearedTemplatesResponse,
    ImportNotificationPreferencesBody, ListContentComplianceClearedTemplatesResponse,
    ListNotificationsEnvelope, ListNotificationsQuery,
    ListWorkspaceContentComplianceClearedTemplateAuditExportsQuery,
    ListWorkspaceContentComplianceClearedTemplateAuditExportsResponse,
    ListWorkspaceContentComplianceClearedTemplateAuditQuery,
    ListWorkspaceContentComplianceClearedTemplateAuditResponse,
    ListWorkspaceContentComplianceClearedTemplatesResponse, MarkAllNotificationsReadResponse,
    MarkNotificationsReadBody, MarkNotificationsReadEnvelope, NotificationPreferences,
    NotificationPreferencesEnvelope, ReorderContentComplianceClearedTemplatesBody,
    ReorderContentComplianceClearedTemplatesResponse, SyncContentComplianceAlertsBody,
    SyncContentComplianceAlertsResponse, UpsertContentComplianceClearedTemplateBody,
    UpsertContentComplianceClearedTemplateResponse, WorkspaceSharedAuditExportEnqueueBody,
    WorkspaceSharedAuditExportJobRecord,
};
use super::workspace_audit_export::{
    append_export_history_record, build_filtered_audit_export_body,
    fetch_workspace_shared_audit_export_job_for_user, filter_workspace_shared_audit_items,
    get_workspace_shared_audit_export_file_response, load_workspace_shared_template_audit,
    query_workspace_shared_audit_exports_page, to_workspace_shared_audit_export_job_record,
};

const SHARED_TEMPLATES_KEY: &str = "content_compliance_cleared_templates_shared";

fn default_content_compliance_cleared_templates() -> Vec<ContentComplianceClearedTemplateItem> {
    vec![
        ContentComplianceClearedTemplateItem {
            id: "oncall".to_string(),
            label: "值班".to_string(),
            description: "平衡噪音与响应速度，适合常规值班。".to_string(),
            policy: ContentComplianceClearedTemplatePolicy {
                global_minutes: 20,
                stage_minutes: [
                    ("critical_unclaimed".to_string(), 10),
                    ("over_capacity".to_string(), 20),
                    ("stalled_claimed".to_string(), 30),
                    ("escalated_72h".to_string(), 45),
                ]
                .into_iter()
                .collect(),
            },
            kind: "default".to_string(),
            can_edit: false,
            can_delete: false,
        },
        ContentComplianceClearedTemplateItem {
            id: "incident".to_string(),
            label: "高压".to_string(),
            description: "高频观察，适合事故窗口快速收敛。".to_string(),
            policy: ContentComplianceClearedTemplatePolicy {
                global_minutes: 8,
                stage_minutes: [
                    ("critical_unclaimed".to_string(), 5),
                    ("over_capacity".to_string(), 8),
                    ("stalled_claimed".to_string(), 12),
                    ("escalated_72h".to_string(), 15),
                ]
                .into_iter()
                .collect(),
            },
            kind: "default".to_string(),
            can_edit: false,
            can_delete: false,
        },
        ContentComplianceClearedTemplateItem {
            id: "quiet".to_string(),
            label: "静默".to_string(),
            description: "尽量降噪，适合低风险维护期。".to_string(),
            policy: ContentComplianceClearedTemplatePolicy {
                global_minutes: 60,
                stage_minutes: [
                    ("critical_unclaimed".to_string(), 30),
                    ("over_capacity".to_string(), 60),
                    ("stalled_claimed".to_string(), 90),
                    ("escalated_72h".to_string(), 120),
                ]
                .into_iter()
                .collect(),
            },
            kind: "default".to_string(),
            can_edit: false,
            can_delete: false,
        },
    ]
}

fn as_user_template(
    mut template: ContentComplianceClearedTemplateItem,
) -> ContentComplianceClearedTemplateItem {
    template.kind = "custom".to_string();
    template.can_edit = true;
    template.can_delete = true;
    template
}

fn merged_templates_for_prefs(
    prefs: &NotificationPreferences,
) -> Vec<ContentComplianceClearedTemplateItem> {
    let mut by_id = default_content_compliance_cleared_templates()
        .into_iter()
        .map(|item| (item.id.clone(), item))
        .collect::<std::collections::BTreeMap<_, _>>();
    for template in prefs.content_compliance_cleared_templates.iter().cloned() {
        let user_template = as_user_template(template);
        by_id.insert(user_template.id.clone(), user_template);
    }
    let order_rank = prefs
        .content_compliance_cleared_template_order
        .iter()
        .enumerate()
        .map(|(idx, id)| (id.trim().to_ascii_lowercase(), idx))
        .collect::<std::collections::HashMap<_, _>>();
    let recent_rank = prefs
        .content_compliance_cleared_recent_template_ids
        .iter()
        .enumerate()
        .map(|(idx, id)| (id.trim().to_ascii_lowercase(), idx))
        .collect::<std::collections::HashMap<_, _>>();
    let mut items = by_id.into_values().collect::<Vec<_>>();
    items.sort_by(|a, b| {
        let aid = a.id.trim().to_ascii_lowercase();
        let bid = b.id.trim().to_ascii_lowercase();
        let a_recent = recent_rank.get(&aid).copied().unwrap_or(usize::MAX);
        let b_recent = recent_rank.get(&bid).copied().unwrap_or(usize::MAX);
        if a_recent != b_recent {
            return a_recent.cmp(&b_recent);
        }
        let a_order = order_rank.get(&aid).copied().unwrap_or(usize::MAX);
        let b_order = order_rank.get(&bid).copied().unwrap_or(usize::MAX);
        if a_order != b_order {
            return a_order.cmp(&b_order);
        }
        a.label.cmp(&b.label)
    });
    items
}

async fn resolve_current_workspace_with_permission(
    pool: &sqlx::PgPool,
    uid: Uuid,
) -> Result<(Uuid, bool), ApiError> {
    let current_workspace_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT current_workspace_id FROM public.app_user_profile WHERE user_id = $1",
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .flatten();
    if let Some(ws_id) = current_workspace_id {
        let role: Option<String> = sqlx::query_scalar(
            "SELECT role::text FROM public.app_workspace_member WHERE workspace_id = $1 AND user_id = $2 LIMIT 1",
        )
        .bind(ws_id)
        .bind(uid)
        .fetch_optional(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        if let Some(role) = role {
            return Ok((ws_id, matches!(role.as_str(), "owner" | "admin")));
        }
    }
    let personal_workspace_id: Option<Uuid> = sqlx::query_scalar(
        "SELECT id FROM public.app_workspace WHERE owner_user_id = $1 AND workspace_type = 'personal' LIMIT 1",
    )
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let workspace_id = personal_workspace_id.ok_or_else(|| {
        crate::error::bad_request_i18n(
            "cannot resolve current workspace for template operations",
            "无法解析当前 workspace，无法执行模板操作",
        )
    })?;
    Ok((workspace_id, true))
}

async fn load_workspace_shared_templates(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
) -> Result<Vec<ContentComplianceClearedTemplateItem>, ApiError> {
    let metadata: Option<serde_json::Value> =
        sqlx::query_scalar("SELECT metadata FROM public.app_workspace WHERE id = $1")
            .bind(workspace_id)
            .fetch_optional(pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let Some(metadata) = metadata else {
        return Ok(Vec::new());
    };
    let templates = metadata
        .as_object()
        .and_then(|obj| obj.get(SHARED_TEMPLATES_KEY))
        .cloned()
        .unwrap_or_else(|| json!([]));
    let parsed: Vec<ContentComplianceClearedTemplateItem> =
        serde_json::from_value(templates).unwrap_or_default();
    Ok(parsed)
}

async fn persist_workspace_shared_templates_and_audit(
    pool: &sqlx::PgPool,
    workspace_id: Uuid,
    templates: &[ContentComplianceClearedTemplateItem],
    audit: &[ContentComplianceClearedTemplateAuditItem],
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        UPDATE public.app_workspace
        SET
          metadata = jsonb_set(
            jsonb_set(
              COALESCE(metadata, '{}'::jsonb),
              '{content_compliance_cleared_templates_shared}',
              $2::jsonb,
              true
            ),
            '{content_compliance_cleared_templates_shared_audit}',
            $3::jsonb,
            true
          ),
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(workspace_id)
    .bind(serde_json::to_value(templates).map_err(|e| {
        bad_request_i18n(
            &format!("Failed to serialize templates: {}", e),
            &format!("模板序列化失败：{}", e),
        )
    })?)
    .bind(serde_json::to_value(audit).map_err(|e| {
        bad_request_i18n(
            &format!("Failed to serialize audit: {}", e),
            &format!("审计序列化失败：{}", e),
        )
    })?)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications",
    operation_id = "getNotificationsV1",
    tag = "settings",
    params(ListNotificationsQuery),
    responses(
        (status = 200, description = "OK", body = ListNotificationsEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListNotificationsQuery>,
) -> Result<Json<ListNotificationsEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(list_notifications(pool, uid, &query).await?))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/mark-read",
    operation_id = "markNotificationsReadV1",
    tag = "settings",
    request_body = MarkNotificationsReadBody,
    responses(
        (status = 200, description = "OK", body = MarkNotificationsReadEnvelope),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn mark_notifications_read(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<MarkNotificationsReadBody>,
) -> Result<Json<MarkNotificationsReadEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    if body.ids.is_empty() {
        return Err(crate::error::bad_request_i18n(
            "ids must not be empty",
            "ids 不能为空",
        ));
    }
    let read = body.read.unwrap_or(true);
    let items = mark_notifications_read_state(pool, &state.notify, uid, &body.ids, read).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(MarkNotificationsReadEnvelope {
        items,
        unread_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/mark-all-read",
    operation_id = "markAllNotificationsReadV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = MarkAllNotificationsReadResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn mark_all_notifications_read(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<MarkAllNotificationsReadResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let updated_count = mark_all_notifications_read_storage(pool, &state.notify, uid).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(MarkAllNotificationsReadResponse {
        updated_count,
        unread_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/delete",
    operation_id = "deleteNotificationsV1",
    tag = "settings",
    request_body = DeleteNotificationsBody,
    responses(
        (status = 200, description = "OK", body = DeleteNotificationsResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_notifications(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteNotificationsBody>,
) -> Result<Json<DeleteNotificationsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    if body.ids.is_empty() {
        return Err(crate::error::bad_request_i18n(
            "ids must not be empty",
            "ids 不能为空",
        ));
    }
    let deleted_count = delete_notifications_storage(pool, uid, &body.ids).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(DeleteNotificationsResponse {
        deleted_count,
        unread_count,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/delete-read",
    operation_id = "deleteReadNotificationsV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = DeleteNotificationsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_read_notifications(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<DeleteNotificationsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let deleted_count = delete_read_notifications_storage(pool, uid).await?;
    let unread_count = unread_notification_count(pool, uid).await?;
    Ok(Json(DeleteNotificationsResponse {
        deleted_count,
        unread_count,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/preferences",
    operation_id = "getNotificationPreferencesV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(get_notification_preferences(pool, uid).await?))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/preferences/export",
    operation_id = "getNotificationPreferencesExportV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = NotificationPreferencesEnvelope),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_preferences_export(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<NotificationPreferencesEnvelope>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        get_notification_preferences_envelope(pool, uid).await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences",
    operation_id = "postNotificationPreferencesV1",
    tag = "settings",
    request_body = NotificationPreferences,
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<NotificationPreferences>,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        upsert_notification_preferences(pool, uid, &body, "manual").await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences/import",
    operation_id = "postNotificationPreferencesImportV1",
    tag = "settings",
    request_body = ImportNotificationPreferencesBody,
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences_import(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ImportNotificationPreferencesBody>,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        upsert_notification_preferences(pool, uid, &body.envelope.preferences, "import").await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences/reset",
    operation_id = "postNotificationPreferencesResetV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences_reset(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(reset_notification_preferences(pool, uid).await?))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/preferences/apply-template",
    operation_id = "postNotificationPreferencesApplyTemplateV1",
    tag = "settings",
    request_body = ApplyNotificationPreferencesTemplateBody,
    responses(
        (status = 200, description = "OK", body = NotificationPreferences),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_preferences_apply_template(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ApplyNotificationPreferencesTemplateBody>,
) -> Result<Json<NotificationPreferences>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        apply_notification_preferences_template(pool, uid, &body.template).await?,
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/sync",
    operation_id = "postNotificationContentComplianceSyncV1",
    tag = "settings",
    request_body = SyncContentComplianceAlertsBody,
    responses(
        (status = 200, description = "OK", body = SyncContentComplianceAlertsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_sync(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<SyncContentComplianceAlertsBody>,
) -> Result<Json<SyncContentComplianceAlertsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let synced_count =
        sync_content_compliance_alert_notifications(pool, &state.notify, uid, &body.alerts).await?;
    Ok(Json(SyncContentComplianceAlertsResponse { synced_count }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates",
    operation_id = "getNotificationContentComplianceClearedTemplatesV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = ListContentComplianceClearedTemplatesResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ListContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let user_prefs = get_notification_preferences(pool, uid).await?;
    let templates = merged_templates_for_prefs(&user_prefs);
    Ok(Json(ListContentComplianceClearedTemplatesResponse {
        templates,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates",
    operation_id = "postNotificationContentComplianceClearedTemplateV1",
    tag = "settings",
    request_body = UpsertContentComplianceClearedTemplateBody,
    responses(
        (status = 200, description = "OK", body = UpsertContentComplianceClearedTemplateResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_cleared_template(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpsertContentComplianceClearedTemplateBody>,
) -> Result<Json<UpsertContentComplianceClearedTemplateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let mut prefs = get_notification_preferences(pool, uid).await?;
    let id = body.template.id.trim().to_ascii_lowercase();
    validate_non_empty_string(&id, "template.id")?;
    validate_non_empty_string(body.template.label.trim(), "template.label")?;
    let mut next = prefs
        .content_compliance_cleared_templates
        .into_iter()
        .filter(|tpl| tpl.id.trim().to_ascii_lowercase() != id)
        .collect::<Vec<_>>();
    let mut template = body.template;
    template.id = id;
    template.kind = "custom".to_string();
    template.can_edit = true;
    template.can_delete = true;
    next.push(template);
    prefs.content_compliance_cleared_templates = next;
    upsert_notification_preferences(pool, uid, &prefs, "compliance_template_upsert").await?;

    Ok(Json(UpsertContentComplianceClearedTemplateResponse {
        templates: merged_templates_for_prefs(&prefs),
    }))
}

#[utoipa::path(
    delete,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates",
    operation_id = "deleteNotificationContentComplianceClearedTemplateV1",
    tag = "settings",
    request_body = DeleteContentComplianceClearedTemplateBody,
    responses(
        (status = 200, description = "OK", body = DeleteContentComplianceClearedTemplateResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_notifications_content_compliance_cleared_template(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteContentComplianceClearedTemplateBody>,
) -> Result<Json<DeleteContentComplianceClearedTemplateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let target_id = body.id.trim().to_ascii_lowercase();
    validate_non_empty_string(&target_id, "id")?;
    let mut prefs = get_notification_preferences(pool, uid).await?;
    let before = prefs.content_compliance_cleared_templates.len();
    prefs
        .content_compliance_cleared_templates
        .retain(|tpl| tpl.id.trim().to_ascii_lowercase() != target_id);
    let deleted = prefs.content_compliance_cleared_templates.len() != before;
    if deleted {
        upsert_notification_preferences(pool, uid, &prefs, "compliance_template_delete").await?;
    }
    Ok(Json(DeleteContentComplianceClearedTemplateResponse {
        deleted,
        templates: merged_templates_for_prefs(&prefs),
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/apply",
    operation_id = "postNotificationContentComplianceClearedTemplateApplyV1",
    tag = "settings",
    request_body = ApplyContentComplianceClearedTemplateBody,
    responses(
        (status = 200, description = "OK", body = ApplyContentComplianceClearedTemplateResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_cleared_template_apply(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ApplyContentComplianceClearedTemplateBody>,
) -> Result<Json<ApplyContentComplianceClearedTemplateResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let mut prefs = get_notification_preferences(pool, uid).await?;
    let id = body.id.trim().to_ascii_lowercase();
    validate_non_empty_string(&id, "id")?;
    let templates = merged_templates_for_prefs(&prefs);
    let Some(template) = templates
        .iter()
        .find(|tpl| tpl.id.trim().to_ascii_lowercase() == id)
        .cloned()
    else {
        return Ok(Json(ApplyContentComplianceClearedTemplateResponse {
            applied: false,
            templates,
        }));
    };
    prefs.content_compliance_cleared_throttle_minutes = template.policy.global_minutes;
    prefs.content_compliance_cleared_stage_throttle_minutes = template.policy.stage_minutes;
    prefs
        .content_compliance_cleared_recent_template_ids
        .retain(|v| v.trim().to_ascii_lowercase() != id);
    prefs
        .content_compliance_cleared_recent_template_ids
        .insert(0, id);
    prefs
        .content_compliance_cleared_recent_template_ids
        .truncate(8);
    upsert_notification_preferences(pool, uid, &prefs, "compliance_template_apply").await?;
    Ok(Json(ApplyContentComplianceClearedTemplateResponse {
        applied: true,
        templates: merged_templates_for_prefs(&prefs),
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/reorder",
    operation_id = "postNotificationContentComplianceClearedTemplateReorderV1",
    tag = "settings",
    request_body = ReorderContentComplianceClearedTemplatesBody,
    responses(
        (status = 200, description = "OK", body = ReorderContentComplianceClearedTemplatesResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_cleared_template_reorder(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ReorderContentComplianceClearedTemplatesBody>,
) -> Result<Json<ReorderContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let mut prefs = get_notification_preferences(pool, uid).await?;
    prefs.content_compliance_cleared_template_order = body.ids;
    upsert_notification_preferences(pool, uid, &prefs, "compliance_template_reorder").await?;
    Ok(Json(ReorderContentComplianceClearedTemplatesResponse {
        templates: merged_templates_for_prefs(&prefs),
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/export",
    operation_id = "getNotificationContentComplianceClearedTemplatesExportV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = ExportContentComplianceClearedTemplatesResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_export(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ExportContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let prefs = get_notification_preferences(pool, uid).await?;
    Ok(Json(ExportContentComplianceClearedTemplatesResponse {
        templates: prefs.content_compliance_cleared_templates,
        order: prefs.content_compliance_cleared_template_order,
        recent: prefs.content_compliance_cleared_recent_template_ids,
    }))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/import",
    operation_id = "postNotificationContentComplianceClearedTemplatesImportV1",
    tag = "settings",
    request_body = ImportContentComplianceClearedTemplatesBody,
    responses(
        (status = 200, description = "OK", body = ImportContentComplianceClearedTemplatesResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_cleared_templates_import(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ImportContentComplianceClearedTemplatesBody>,
) -> Result<Json<ImportContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let mut prefs = get_notification_preferences(pool, uid).await?;
    let mode = body
        .mode
        .as_deref()
        .map(|v| v.trim().to_ascii_lowercase())
        .unwrap_or_else(|| "replace".to_string());
    if mode == "merge" {
        let mut by_id = prefs
            .content_compliance_cleared_templates
            .into_iter()
            .map(|tpl| (tpl.id.trim().to_ascii_lowercase(), tpl))
            .collect::<std::collections::BTreeMap<_, _>>();
        for mut tpl in body.templates {
            let id = tpl.id.trim().to_ascii_lowercase();
            if id.is_empty() {
                continue;
            }
            tpl.id = id.clone();
            by_id.insert(id, tpl);
        }
        prefs.content_compliance_cleared_templates = by_id.into_values().collect::<Vec<_>>();
    } else {
        prefs.content_compliance_cleared_templates = body.templates;
    }
    prefs.content_compliance_cleared_template_order = body.order;
    prefs.content_compliance_cleared_recent_template_ids = body.recent;
    upsert_notification_preferences(pool, uid, &prefs, "compliance_template_import").await?;
    Ok(Json(ImportContentComplianceClearedTemplatesResponse {
        imported_count: prefs.content_compliance_cleared_templates.len() as i64,
        templates: merged_templates_for_prefs(&prefs),
        order: prefs.content_compliance_cleared_template_order,
        recent: prefs.content_compliance_cleared_recent_template_ids,
    }))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared",
    operation_id = "getWorkspaceSharedContentComplianceClearedTemplatesV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = ListWorkspaceContentComplianceClearedTemplatesResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_shared(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<ListWorkspaceContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    let templates = load_workspace_shared_templates(pool, workspace_id).await?;
    Ok(Json(
        ListWorkspaceContentComplianceClearedTemplatesResponse {
            workspace_id,
            can_manage,
            templates,
        },
    ))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit",
    operation_id = "getWorkspaceSharedContentComplianceClearedTemplateAuditV1",
    tag = "settings",
    params(ListWorkspaceContentComplianceClearedTemplateAuditQuery),
    responses(
        (status = 200, description = "OK", body = ListWorkspaceContentComplianceClearedTemplateAuditResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_shared_audit(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListWorkspaceContentComplianceClearedTemplateAuditQuery>,
) -> Result<Json<ListWorkspaceContentComplianceClearedTemplateAuditResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    let items = filter_workspace_shared_audit_items(
        load_workspace_shared_template_audit(pool, workspace_id).await?,
        query.template_id.as_deref(),
        query.action.as_deref(),
        query.start_at.as_deref(),
        query.end_at.as_deref(),
    );
    let total = items.len() as i64;
    let offset = query.offset.unwrap_or(0).max(0) as usize;
    let limit = query.limit.unwrap_or(20).clamp(1, 100) as usize;
    let paged = items
        .into_iter()
        .skip(offset)
        .take(limit)
        .collect::<Vec<_>>();
    let next_offset = (offset + paged.len()) as i64;
    let has_more = next_offset < total;
    Ok(Json(
        ListWorkspaceContentComplianceClearedTemplateAuditResponse {
            workspace_id,
            can_manage,
            items: paged,
            has_more,
            next_offset: has_more.then_some(next_offset),
        },
    ))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export",
    operation_id = "getWorkspaceSharedContentComplianceClearedTemplateAuditExportV1",
    tag = "settings",
    params(ExportWorkspaceContentComplianceClearedTemplateAuditQuery),
    responses(
        (status = 200, description = "OK", body = ExportWorkspaceContentComplianceClearedTemplateAuditResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_shared_audit_export(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ExportWorkspaceContentComplianceClearedTemplateAuditQuery>,
) -> Result<Json<ExportWorkspaceContentComplianceClearedTemplateAuditResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, _can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    let items = filter_workspace_shared_audit_items(
        load_workspace_shared_template_audit(pool, workspace_id).await?,
        query.template_id.as_deref(),
        query.action.as_deref(),
        query.start_at.as_deref(),
        query.end_at.as_deref(),
    );
    let (format, file_name, content) = build_filtered_audit_export_body(&query, items)?;
    append_export_history_record(
        pool,
        super::workspace_audit_export::ExportHistoryParams {
            workspace_id,
            uid,
            format: format.clone(),
            file_name: file_name.clone(),
            template_id: query.template_id.clone(),
            action: query.action.clone(),
            start_at: query.start_at.clone(),
            end_at: query.end_at.clone(),
            job_id: None,
            export_delivery: "sync".to_string(),
        },
    )
    .await?;
    Ok(Json(
        ExportWorkspaceContentComplianceClearedTemplateAuditResponse {
            format,
            file_name,
            content,
        },
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async",
    operation_id = "postWorkspaceSharedContentComplianceClearedTemplateAuditExportAsyncV1",
    tag = "settings",
    request_body = WorkspaceSharedAuditExportEnqueueBody,
    responses(
        (status = 200, description = "OK", body = WorkspaceSharedAuditExportJobRecord),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 429, description = "Too many concurrent exports (`code`: concurrent_limit_exceeded)", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_cleared_templates_shared_audit_export_async(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<WorkspaceSharedAuditExportEnqueueBody>,
) -> Result<Json<WorkspaceSharedAuditExportJobRecord>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, _can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    let active =
        super::workspace_audit_export::count_active_workspace_shared_audit_export_jobs(pool, uid)
            .await?;
    if active >= super::workspace_audit_export::WORKSPACE_SHARED_AUDIT_EXPORT_MAX_ACTIVE {
        return Err(ApiError::ConcurrentLimitExceeded(format!(
            "workspace shared audit export: too many jobs in progress ({active}/{})",
            super::workspace_audit_export::WORKSPACE_SHARED_AUDIT_EXPORT_MAX_ACTIVE
        )));
    }
    let format = body
        .format
        .as_deref()
        .map(|v| v.trim().to_ascii_lowercase())
        .filter(|v| v == "csv" || v == "json")
        .unwrap_or_else(|| "json".to_string());
    let mut payload = serde_json::Map::new();
    payload.insert("workspace_id".into(), json!(workspace_id.to_string()));
    payload.insert("format".into(), json!(format));
    if let Some(ref t) = body.template_id {
        let t = t.trim();
        if !t.is_empty() {
            payload.insert("template_id".into(), json!(t));
        }
    }
    if let Some(ref a) = body.action {
        let a = a.trim();
        if !a.is_empty() {
            payload.insert("action".into(), json!(a));
        }
    }
    if let Some(ref s) = body.start_at {
        let s = s.trim();
        if !s.is_empty() {
            payload.insert("start_at".into(), json!(s));
        }
    }
    if let Some(ref e) = body.end_at {
        let e = e.trim();
        if !e.is_empty() {
            payload.insert("end_at".into(), json!(e));
        }
    }
    let row: JobRow = enqueue_generation_job(
        pool,
        uid,
        JOB_KIND_SETTINGS_WORKSPACE_SHARED_AUDIT_EXPORT,
        Value::Object(payload),
        Some(&headers),
        &state.billing_config,
    )
    .await?;
    Ok(Json(to_workspace_shared_audit_export_job_record(
        &row,
        workspace_id,
    )))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}",
    operation_id = "getWorkspaceSharedContentComplianceClearedTemplateAuditExportJobV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK", body = WorkspaceSharedAuditExportJobRecord),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_shared_audit_export_job(
    State(state): State<AppState>,
    Path(job_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Json<WorkspaceSharedAuditExportJobRecord>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    Ok(Json(
        fetch_workspace_shared_audit_export_job_for_user(pool, uid, job_id).await?,
    ))
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/{job_id}/file",
    operation_id = "getWorkspaceSharedContentComplianceClearedTemplateAuditExportJobFileV1",
    tag = "settings",
    responses(
        (status = 200, description = "OK"),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_shared_audit_export_job_file(
    State(state): State<AppState>,
    Path(job_id): Path<Uuid>,
    headers: HeaderMap,
) -> Result<Response, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    get_workspace_shared_audit_export_file_response(pool, uid, job_id).await
}

#[utoipa::path(
    get,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/exports",
    operation_id = "getWorkspaceSharedContentComplianceClearedTemplateAuditExportsV1",
    tag = "settings",
    params(ListWorkspaceContentComplianceClearedTemplateAuditExportsQuery),
    responses(
        (status = 200, description = "OK", body = ListWorkspaceContentComplianceClearedTemplateAuditExportsResponse),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn get_notifications_content_compliance_cleared_templates_shared_audit_exports(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListWorkspaceContentComplianceClearedTemplateAuditExportsQuery>,
) -> Result<Json<ListWorkspaceContentComplianceClearedTemplateAuditExportsResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    let exported_start = query.exported_start_at.as_deref().and_then(|v| {
        chrono::DateTime::parse_from_rfc3339(v.trim())
            .ok()
            .map(|dt| dt.with_timezone(&chrono::Utc))
    });
    let exported_end = query.exported_end_at.as_deref().and_then(|v| {
        chrono::DateTime::parse_from_rfc3339(v.trim())
            .ok()
            .map(|dt| dt.with_timezone(&chrono::Utc))
    });
    let offset = query.offset.unwrap_or(0).max(0);
    let limit = query.limit.unwrap_or(20).clamp(1, 100);
    let (paged, total) = query_workspace_shared_audit_exports_page(
        pool,
        workspace_id,
        query.format.as_deref(),
        exported_start,
        exported_end,
        offset,
        limit,
    )
    .await?;
    let next_offset = offset + paged.len() as i64;
    let has_more = next_offset < total;
    Ok(Json(
        ListWorkspaceContentComplianceClearedTemplateAuditExportsResponse {
            workspace_id,
            can_manage,
            items: paged,
            has_more,
            next_offset: has_more.then_some(next_offset),
        },
    ))
}

#[utoipa::path(
    post,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared",
    operation_id = "postWorkspaceSharedContentComplianceClearedTemplateV1",
    tag = "settings",
    request_body = UpsertContentComplianceClearedTemplateBody,
    responses(
        (status = 200, description = "OK", body = ListWorkspaceContentComplianceClearedTemplatesResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn post_notifications_content_compliance_cleared_templates_shared(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UpsertContentComplianceClearedTemplateBody>,
) -> Result<Json<ListWorkspaceContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    if !can_manage {
        return Err(forbidden_i18n(
            "only owner/admin can manage shared templates",
            "只有所有者/管理员可以管理共享模板",
        ));
    }
    let id = body.template.id.trim().to_ascii_lowercase();
    validate_non_empty_string(&id, "template.id")?;
    let label = body.template.label.trim().to_string();
    validate_non_empty_string(&label, "template.label")?;
    let mut templates = load_workspace_shared_templates(pool, workspace_id).await?;
    templates.retain(|item| item.id.trim().to_ascii_lowercase() != id);
    let mut template = body.template;
    template.id = id.clone();
    template.label = label;
    template.kind = "workspace_shared".to_string();
    template.can_edit = true;
    template.can_delete = true;
    templates.push(template);
    let mut audit = load_workspace_shared_template_audit(pool, workspace_id).await?;
    audit.insert(
        0,
        ContentComplianceClearedTemplateAuditItem {
            at: chrono::Utc::now(),
            actor_user_id: uid,
            action: "upsert".to_string(),
            template_id: id,
            note: Some("workspace shared template upsert".to_string()),
        },
    );
    audit.truncate(200);
    persist_workspace_shared_templates_and_audit(pool, workspace_id, &templates, &audit).await?;
    Ok(Json(
        ListWorkspaceContentComplianceClearedTemplatesResponse {
            workspace_id,
            can_manage,
            templates,
        },
    ))
}

#[utoipa::path(
    delete,
    path = "/api/v1/settings/notifications/content-compliance/cleared-templates/shared",
    operation_id = "deleteWorkspaceSharedContentComplianceClearedTemplateV1",
    tag = "settings",
    request_body = DeleteContentComplianceClearedTemplateBody,
    responses(
        (status = 200, description = "OK", body = ListWorkspaceContentComplianceClearedTemplatesResponse),
        (status = 400, description = "Bad Request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn delete_notifications_content_compliance_cleared_templates_shared(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<DeleteContentComplianceClearedTemplateBody>,
) -> Result<Json<ListWorkspaceContentComplianceClearedTemplatesResponse>, ApiError> {
    let uid = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;
    let (workspace_id, can_manage) = resolve_current_workspace_with_permission(pool, uid).await?;
    if !can_manage {
        return Err(forbidden_i18n(
            "only owner/admin can manage shared templates",
            "只有所有者/管理员可以管理共享模板",
        ));
    }
    let id = body.id.trim().to_ascii_lowercase();
    validate_non_empty_string(&id, "id")?;
    let mut templates = load_workspace_shared_templates(pool, workspace_id).await?;
    templates.retain(|item| item.id.trim().to_ascii_lowercase() != id);
    let mut audit = load_workspace_shared_template_audit(pool, workspace_id).await?;
    audit.insert(
        0,
        ContentComplianceClearedTemplateAuditItem {
            at: chrono::Utc::now(),
            actor_user_id: uid,
            action: "delete".to_string(),
            template_id: id,
            note: Some("workspace shared template delete".to_string()),
        },
    );
    audit.truncate(200);
    persist_workspace_shared_templates_and_audit(pool, workspace_id, &templates, &audit).await?;
    Ok(Json(
        ListWorkspaceContentComplianceClearedTemplatesResponse {
            workspace_id,
            can_manage,
            templates,
        },
    ))
}
