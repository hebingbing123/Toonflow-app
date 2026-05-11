use std::collections::BTreeMap;
use std::io::{Cursor, Write};
use std::path::PathBuf;

use axum::{
    body::Body,
    http::{header, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
};
use chrono::Utc;
use serde::Serialize;
use serde_json::{json, Value};
use sqlx::{types::Json, FromRow, PgPool};
use uuid::Uuid;
use zip::write::FileOptions;

use crate::error::ApiError;
use crate::jobs::worker::{job_ok, JobCompletion, JobRunError};
use crate::jobs::JobRow;
use crate::settings::export_s3;
use crate::settings::notifications::workspace_audit_export_artifact_storage;
use crate::state::AppState;

use super::types::{AccountDeleteResponse, AccountExportJobRecord, AccountExportsResponse};

pub(crate) const JOB_KIND_SETTINGS_ACCOUNT_EXPORT: &str = "settings.account.export";
const ACCOUNT_EXPORT_ENV: &str = "TOONFLOW_LOCAL_ACCOUNT_EXPORT_DIR";
const ACCOUNT_EXPORT_LIMIT: i64 = 20;

fn account_export_s3_bucket() -> Option<String> {
    std::env::var("TOONFLOW_ACCOUNT_EXPORT_S3_BUCKET")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

fn account_export_s3_prefix() -> String {
    std::env::var("TOONFLOW_ACCOUNT_EXPORT_S3_PREFIX")
        .ok()
        .map(|s| s.trim().trim_matches('/').to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "account-exports".to_string())
}

pub(crate) fn use_s3_for_account_export_artifacts() -> bool {
    account_export_s3_bucket().is_some()
}

#[derive(Debug, FromRow)]
struct AccountExportJobRow {
    numeric_task_id: i64,
    id: Uuid,
    status: String,
    result: Option<Json<Value>>,
    error_message: Option<String>,
    created_at: chrono::DateTime<chrono::Utc>,
    updated_at: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, FromRow)]
struct DeleteCountRow {
    owned_workspace_count: i64,
    workspace_membership_count: i64,
    owned_project_count: i64,
    generation_job_count: i64,
    notification_count: i64,
}

#[derive(Debug, Serialize)]
struct AccountExportManifest<'a> {
    export_type: &'a str,
    schema_version: i32,
    generated_at: chrono::DateTime<chrono::Utc>,
    owner_user_id: Uuid,
    job_id: Uuid,
    datasets: Vec<AccountExportDatasetMeta>,
}

#[derive(Debug, Serialize)]
struct AccountExportDatasetMeta {
    name: String,
    row_count: usize,
}

pub(crate) fn account_export_root_dir() -> PathBuf {
    std::env::var(ACCOUNT_EXPORT_ENV)
        .ok()
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| std::env::temp_dir().join("toonflow-account-exports"))
}

fn account_export_user_dir(user_id: Uuid) -> PathBuf {
    account_export_root_dir().join(user_id.to_string())
}

fn account_export_file_path(user_id: Uuid, file_name: &str) -> PathBuf {
    account_export_user_dir(user_id).join(file_name)
}

pub(crate) fn to_account_export_job_record(row: &JobRow) -> AccountExportJobRecord {
    let result = row.result.as_ref();
    let file_name = result
        .and_then(|value| value.get("file_name"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let content_type = result
        .and_then(|value| value.get("content_type"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let byte_size = result
        .and_then(|value| value.get("byte_size"))
        .and_then(|value| value.as_i64());
    AccountExportJobRecord {
        id: row.id,
        numeric_task_id: row.numeric_task_id,
        status: row.status.clone(),
        created_at: row.created_at,
        updated_at: row.updated_at,
        error_message: row.error_message.clone(),
        file_name: file_name.clone(),
        content_type,
        byte_size,
        download_ready: row.status == "succeeded" && file_name.is_some(),
    }
}

fn map_account_export_job_row(row: AccountExportJobRow) -> AccountExportJobRecord {
    let status = row.status.clone();
    let result = row.result.as_ref().map(|value| &value.0);
    let file_name = result
        .and_then(|value| value.get("file_name"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let content_type = result
        .and_then(|value| value.get("content_type"))
        .and_then(|value| value.as_str())
        .map(str::to_string);
    let byte_size = result
        .and_then(|value| value.get("byte_size"))
        .and_then(|value| value.as_i64());
    AccountExportJobRecord {
        id: row.id,
        numeric_task_id: row.numeric_task_id,
        status,
        created_at: row.created_at,
        updated_at: row.updated_at,
        error_message: row.error_message,
        file_name: file_name.clone(),
        content_type,
        byte_size,
        download_ready: row.status == "succeeded" && file_name.is_some(),
    }
}

pub(crate) async fn list_account_exports(
    pool: &PgPool,
    user_id: Uuid,
) -> Result<AccountExportsResponse, ApiError> {
    let rows = sqlx::query_as::<_, AccountExportJobRow>(
        r#"
        SELECT numeric_task_id, id, status, result, error_message, created_at, updated_at
        FROM public.app_generation_job
        WHERE owner_user_id = $1
          AND kind = $2
        ORDER BY created_at DESC
        LIMIT $3
        "#,
    )
    .bind(user_id)
    .bind(JOB_KIND_SETTINGS_ACCOUNT_EXPORT)
    .bind(ACCOUNT_EXPORT_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let active_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::bigint
        FROM public.app_generation_job
        WHERE owner_user_id = $1
          AND kind = $2
          AND status IN ('queued', 'running')
        "#,
    )
    .bind(user_id)
    .bind(JOB_KIND_SETTINGS_ACCOUNT_EXPORT)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(AccountExportsResponse {
        items: rows.into_iter().map(map_account_export_job_row).collect(),
        active_count,
    })
}

pub(crate) async fn get_account_export_file_response(
    _state: &AppState,
    pool: &PgPool,
    user_id: Uuid,
    job_id: Uuid,
) -> Result<Response, ApiError> {
    let row = sqlx::query_as::<_, AccountExportJobRow>(
        r#"
        SELECT numeric_task_id, id, status, result, error_message, created_at, updated_at
        FROM public.app_generation_job
        WHERE id = $1
          AND owner_user_id = $2
          AND kind = $3
        "#,
    )
    .bind(job_id)
    .bind(user_id)
    .bind(JOB_KIND_SETTINGS_ACCOUNT_EXPORT)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;
    if row.status != "succeeded" {
        return Err(ApiError::NotFound);
    }
    let result = row.result.ok_or(ApiError::NotFound)?.0;
    let storage = result
        .get("storage")
        .and_then(|value| value.as_str())
        .unwrap_or("local");
    let file_name = result
        .get("file_name")
        .and_then(|value| value.as_str())
        .filter(|value| !value.trim().is_empty())
        .ok_or(ApiError::NotFound)?;
    let content_type = result
        .get("content_type")
        .and_then(|value| value.as_str())
        .filter(|value| !value.trim().is_empty())
        .unwrap_or("application/zip");
    let bytes = match storage {
        "local" => tokio::fs::read(account_export_file_path(user_id, file_name))
            .await
            .map_err(|_| ApiError::NotFound)?,
        "s3" => {
            let bucket = result
                .get("s3_bucket")
                .and_then(|value| value.as_str())
                .filter(|value| !value.trim().is_empty())
                .ok_or(ApiError::NotFound)?;
            let key = result
                .get("s3_key")
                .and_then(|value| value.as_str())
                .filter(|value| !value.trim().is_empty())
                .ok_or(ApiError::NotFound)?;
            export_s3::get_object(bucket, key)
                .await
                .map_err(|_| ApiError::NotFound)?
        }
        _ => return Err(ApiError::NotFound),
    };
    let mut disposition = HeaderValue::from_str(&format!("attachment; filename=\"{file_name}\""))
        .map_err(|_| ApiError::Internal)?;
    disposition.set_sensitive(true);
    Ok((
        StatusCode::OK,
        [
            (
                header::CONTENT_TYPE,
                HeaderValue::from_str(content_type).map_err(|_| ApiError::Internal)?,
            ),
            (
                header::CACHE_CONTROL,
                HeaderValue::from_static("private, max-age=0"),
            ),
            (header::CONTENT_DISPOSITION, disposition),
        ],
        Body::from(bytes),
    )
        .into_response())
}

pub(crate) async fn build_account_export_artifact(
    pool: &PgPool,
    owner_user_id: Uuid,
    job_id: Uuid,
    payload: &Value,
) -> Result<JobCompletion, JobRunError> {
    let include_audit_logs = payload
        .get("include_audit_logs")
        .and_then(|value| value.as_bool())
        .unwrap_or(false);
    let include_notifications = payload
        .get("include_notifications")
        .and_then(|value| value.as_bool())
        .unwrap_or(true);
    let datasets = collect_account_export_datasets(
        pool,
        owner_user_id,
        include_audit_logs,
        include_notifications,
    )
    .await?;
    let now = Utc::now();
    let file_name = format!(
        "toonflow-account-export-{}-{}.zip",
        owner_user_id,
        now.format("%Y%m%dT%H%M%SZ")
    );
    let bytes = build_account_export_zip(owner_user_id, job_id, now, &datasets)?;
    let byte_size = i64::try_from(bytes.len()).unwrap_or(i64::MAX);

    let result_json = if use_s3_for_account_export_artifacts() {
        let bucket = account_export_s3_bucket().ok_or_else(|| {
            JobRunError::Failed("TOONFLOW_ACCOUNT_EXPORT_S3_BUCKET not set".into())
        })?;
        let key = format!(
            "{}/{}/{}",
            account_export_s3_prefix(),
            owner_user_id,
            file_name
        );
        export_s3::put_object(&bucket, &key, "application/zip", &bytes)
            .await
            .map_err(JobRunError::Failed)?;
        json!({
            "storage": "s3",
            "s3_bucket": bucket,
            "s3_key": key,
            "file_name": file_name,
            "content_type": "application/zip",
            "byte_size": byte_size,
            "generated_at": now,
            "download_path": format!("/api/v1/settings/account/exports/{job_id}/file"),
        })
    } else {
        let user_dir = account_export_user_dir(owner_user_id);
        tokio::fs::create_dir_all(&user_dir)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        tokio::fs::write(user_dir.join(&file_name), &bytes)
            .await
            .map_err(|e| JobRunError::Failed(e.to_string()))?;
        json!({
            "storage": "local",
            "file_name": file_name,
            "content_type": "application/zip",
            "byte_size": byte_size,
            "generated_at": now,
            "download_path": format!("/api/v1/settings/account/exports/{job_id}/file"),
        })
    };

    Ok(job_ok(result_json))
}

pub(crate) async fn delete_account_and_cleanup(
    state: &AppState,
    pool: &PgPool,
    user_id: Uuid,
) -> Result<AccountDeleteResponse, ApiError> {
    let summary = sqlx::query_as::<_, DeleteCountRow>(
        r#"
        SELECT
          (SELECT COUNT(*)::bigint FROM public.app_workspace WHERE owner_user_id = $1) AS owned_workspace_count,
          (SELECT COUNT(*)::bigint FROM public.app_workspace_member WHERE user_id = $1) AS workspace_membership_count,
          (SELECT COUNT(*)::bigint FROM public.app_project WHERE owner_user_id = $1) AS owned_project_count,
          (SELECT COUNT(*)::bigint FROM public.app_generation_job WHERE owner_user_id = $1) AS generation_job_count,
          (SELECT COUNT(*)::bigint FROM public.app_notification WHERE user_id = $1) AS notification_count
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    for sql in [
        "DELETE FROM public.app_notification WHERE user_id = $1",
        "DELETE FROM public.app_project_audit WHERE actor_user_id = $1 OR target_user_id = $1",
        "DELETE FROM public.app_outbound_webhook WHERE owner_user_id = $1",
        "DELETE FROM public.app_help_hub_link WHERE user_id = $1",
        "DELETE FROM public.import_user_map WHERE supabase_user_id = $1",
        "DELETE FROM public.app_user_profile WHERE user_id = $1",
    ] {
        sqlx::query(sql)
            .bind(user_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }
    let deleted =
        sqlx::query_scalar::<_, Uuid>("DELETE FROM auth.users WHERE id = $1 RETURNING id")
            .bind(user_id)
            .fetch_optional(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if deleted.is_none() {
        return Err(ApiError::NotFound);
    }
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let local_cleanup_paths = cleanup_local_user_artifacts(state, user_id).await;
    Ok(AccountDeleteResponse {
        deleted_user_id: user_id,
        deleted_at: Utc::now(),
        owned_workspace_count: summary.owned_workspace_count,
        workspace_membership_count: summary.workspace_membership_count,
        owned_project_count: summary.owned_project_count,
        generation_job_count: summary.generation_job_count,
        notification_count: summary.notification_count,
        local_cleanup_paths,
    })
}

async fn cleanup_local_user_artifacts(state: &AppState, user_id: Uuid) -> Vec<String> {
    let mut candidates = Vec::<PathBuf>::new();
    if let Some(dir) = state.local_asset_image_dir.as_ref() {
        candidates.push(dir.join(user_id.to_string()));
    }
    if let Some(dir) = state.local_art_style_cover_dir.as_ref() {
        candidates.push(dir.join(user_id.to_string()));
    }
    if let Some(dir) = state.local_video_export_dir.as_ref() {
        candidates.push(dir.join(user_id.to_string()));
    }
    if let Some(dir) = state.local_voiceover_audio_dir.as_ref() {
        candidates.push(dir.join(user_id.to_string()));
    }
    candidates.push(account_export_user_dir(user_id));

    if use_s3_for_account_export_artifacts() {
        if let Some(bucket) = account_export_s3_bucket() {
            let prefix = format!("{}/{}/", account_export_s3_prefix(), user_id);
            let _ = export_s3::delete_objects_with_prefix(&bucket, &prefix).await;
        }
    }
    workspace_audit_export_artifact_storage::delete_workspace_shared_audit_export_s3_prefix_for_user(
        user_id,
    )
    .await;

    let mut removed = Vec::new();
    for path in candidates {
        let exists = tokio::fs::try_exists(&path).await.unwrap_or(false);
        if !exists {
            continue;
        }
        if tokio::fs::remove_dir_all(&path).await.is_ok() {
            removed.push(path.display().to_string());
        }
    }
    removed
}

async fn collect_account_export_datasets(
    pool: &PgPool,
    user_id: Uuid,
    include_audit_logs: bool,
    include_notifications: bool,
) -> Result<BTreeMap<String, Value>, JobRunError> {
    let mut datasets = BTreeMap::new();
    datasets.insert(
        "auth_user".into(),
        query_optional_object(
            pool,
            r#"
            SELECT to_jsonb(t)
            FROM (
              SELECT id, email, phone, created_at, updated_at, last_sign_in_at, raw_user_meta_data
              FROM auth.users
              WHERE id = $1
            ) t
            "#,
            user_id,
        )
        .await?,
    );
    datasets.insert(
        "user_profile".into(),
        query_optional_object(
            pool,
            r#"
            SELECT to_jsonb(t)
            FROM (
              SELECT *
              FROM public.app_user_profile
              WHERE user_id = $1
            ) t
            "#,
            user_id,
        )
        .await?,
    );
    for (name, sql) in [
        (
            "workspaces_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_workspace WHERE owner_user_id = $1) t"#,
        ),
        (
            "workspace_memberships",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_workspace_member WHERE user_id = $1) t"#,
        ),
        (
            "workspace_invites_created",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_workspace_invite WHERE invited_by = $1 OR accepted_by = $1) t"#,
        ),
        (
            "projects_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_project WHERE owner_user_id = $1) t"#,
        ),
        (
            "project_memberships",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_project_member WHERE user_id = $1) t"#,
        ),
        (
            "scripts_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT s.* FROM public.app_script s INNER JOIN public.app_project p ON p.id = s.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "storyboards_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT sb.* FROM public.app_storyboard sb INNER JOIN public.app_script s ON s.id = sb.script_id INNER JOIN public.app_project p ON p.id = s.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "assets_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT a.* FROM public.app_asset a INNER JOIN public.app_project p ON p.id = a.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "asset_images_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT ai.* FROM public.app_asset_image ai INNER JOIN public.app_asset a ON a.id = ai.asset_id INNER JOIN public.app_project p ON p.id = a.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "novels_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT n.* FROM public.app_novel n INNER JOIN public.app_project p ON p.id = n.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "novel_events_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT e.* FROM public.app_novel_event e INNER JOIN public.app_project p ON p.id = e.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "videos_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT v.* FROM public.app_video v INNER JOIN public.app_project p ON p.id = v.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "video_tracks_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT vt.* FROM public.app_video_track vt INNER JOIN public.app_project p ON p.id = vt.project_id WHERE p.owner_user_id = $1) t"#,
        ),
        (
            "generation_jobs_owned",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_generation_job WHERE owner_user_id = $1) t"#,
        ),
        (
            "usage_events",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_usage_event WHERE user_id = $1) t"#,
        ),
        (
            "agent_memories",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.updated_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_agent_memory WHERE owner_user_id = $1) t"#,
        ),
        (
            "script_agent_plans",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.updated_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_script_agent_plan WHERE owner_user_id = $1) t"#,
        ),
        (
            "art_styles",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.updated_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_art_style WHERE owner_user_id = $1) t"#,
        ),
        (
            "user_prompts",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.updated_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_user_prompt WHERE owner_user_id = $1) t"#,
        ),
        (
            "vendor_credentials_metadata",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.updated_at DESC), '[]'::jsonb) FROM (SELECT owner_user_id, vendor_id, key_hint, metadata, created_at, updated_at, (api_key_encrypted IS NOT NULL) AS has_api_key, (api_secret_encrypted IS NOT NULL) AS has_api_secret, (api_token_encrypted IS NOT NULL) AS has_api_token FROM public.app_vendor_credential WHERE owner_user_id = $1) t"#,
        ),
        (
            "quality_reviews",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_quality_review WHERE user_id = $1) t"#,
        ),
        (
            "outbound_webhooks",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT id, owner_user_id, url, workspace_id, event_types, enabled, created_at, updated_at FROM public.app_outbound_webhook WHERE owner_user_id = $1) t"#,
        ),
        (
            "outbound_webhook_deliveries",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (
                SELECT d.*
                FROM public.app_outbound_webhook_delivery d
                INNER JOIN public.app_outbound_webhook w ON w.id = d.webhook_id
                WHERE w.owner_user_id = $1
            ) t"#,
        ),
        (
            "help_hub_links_user_scope",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.sort_order ASC, t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_help_hub_link WHERE user_id = $1) t"#,
        ),
        (
            "search_history",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.searched_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_search_history WHERE user_id = $1) t"#,
        ),
        (
            "search_logs",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_search_log WHERE user_id = $1) t"#,
        ),
        (
            "harness_user_wasm",
            r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.updated_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_harness_user_wasm WHERE owner_user_id = $1) t"#,
        ),
    ] {
        datasets.insert(name.into(), query_array(pool, sql, user_id).await?);
    }
    if include_notifications {
        datasets.insert(
            "notifications".into(),
            query_array(pool, r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_notification WHERE user_id = $1) t"#, user_id).await?,
        );
    }
    if include_audit_logs {
        datasets.insert(
            "workspace_audit".into(),
            query_array(pool, r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_workspace_audit WHERE actor_user_id = $1 OR target_user_id = $1) t"#, user_id).await?,
        );
        datasets.insert(
            "project_audit".into(),
            query_array(pool, r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_project_audit WHERE actor_user_id = $1 OR target_user_id = $1) t"#, user_id).await?,
        );
        datasets.insert(
            "outbound_webhook_config_audit".into(),
            query_array(pool, r#"SELECT COALESCE(jsonb_agg(to_jsonb(t) ORDER BY t.created_at DESC), '[]'::jsonb) FROM (SELECT * FROM public.app_outbound_webhook_config_audit WHERE owner_user_id = $1) t"#, user_id).await?,
        );
    }
    datasets.insert(
        "local_artifact_inventory".into(),
        json!(collect_local_artifact_inventory(user_id).await),
    );
    Ok(datasets)
}

async fn collect_local_artifact_inventory(user_id: Uuid) -> Vec<Value> {
    let mut inventory = Vec::new();
    let roots = vec![
        ("account_export", Some(account_export_root_dir())),
        (
            "asset_image",
            std::env::var("TOONFLOW_LOCAL_ASSET_IMAGE_DIR")
                .ok()
                .filter(|value| !value.trim().is_empty())
                .map(PathBuf::from),
        ),
        (
            "art_style_cover",
            std::env::var("TOONFLOW_LOCAL_ART_STYLE_COVER_DIR")
                .ok()
                .filter(|value| !value.trim().is_empty())
                .map(PathBuf::from),
        ),
        (
            "video_export",
            std::env::var("TOONFLOW_LOCAL_VIDEO_EXPORT_DIR")
                .ok()
                .filter(|value| !value.trim().is_empty())
                .map(PathBuf::from),
        ),
        (
            "voiceover_audio",
            std::env::var("TOONFLOW_LOCAL_VOICEOVER_AUDIO_DIR")
                .ok()
                .filter(|value| !value.trim().is_empty())
                .map(PathBuf::from),
        ),
    ];
    for (kind, root) in roots {
        let Some(root) = root else {
            continue;
        };
        let user_dir = root.join(user_id.to_string());
        let exists = tokio::fs::try_exists(&user_dir).await.unwrap_or(false);
        if !exists {
            continue;
        }
        if let Ok(mut entries) = tokio::fs::read_dir(&user_dir).await {
            while let Ok(Some(entry)) = entries.next_entry().await {
                if let Ok(metadata) = entry.metadata().await {
                    inventory.push(json!({
                        "kind": kind,
                        "path": entry.path().display().to_string(),
                        "is_dir": metadata.is_dir(),
                        "byte_size": if metadata.is_file() { Some(metadata.len()) } else { None::<u64> },
                    }));
                }
            }
        }
    }
    inventory
}

fn build_account_export_zip(
    owner_user_id: Uuid,
    job_id: Uuid,
    generated_at: chrono::DateTime<chrono::Utc>,
    datasets: &BTreeMap<String, Value>,
) -> Result<Vec<u8>, JobRunError> {
    let mut archive = zip::ZipWriter::new(Cursor::new(Vec::new()));
    let options = FileOptions::default().compression_method(zip::CompressionMethod::Deflated);
    let manifest = AccountExportManifest {
        export_type: "account_data_export",
        schema_version: 1,
        generated_at,
        owner_user_id,
        job_id,
        datasets: datasets
            .iter()
            .map(|(name, value)| AccountExportDatasetMeta {
                name: format!("{name}.json"),
                row_count: value
                    .as_array()
                    .map(|items| items.len())
                    .unwrap_or_else(|| if value.is_null() { 0 } else { 1 }),
            })
            .collect(),
    };
    write_export_entry(
        &mut archive,
        "manifest.json",
        &serde_json::to_vec_pretty(&manifest).map_err(|e| JobRunError::Failed(e.to_string()))?,
        options,
    )?;
    write_export_entry(
        &mut archive,
        "README.txt",
        b"Toonflow account export. JSON datasets are grouped by domain; vendor credentials are metadata-only and do not include decrypted secrets.\n",
        options,
    )?;
    for (name, value) in datasets {
        write_export_entry(
            &mut archive,
            &format!("datasets/{name}.json"),
            &serde_json::to_vec_pretty(value).map_err(|e| JobRunError::Failed(e.to_string()))?,
            options,
        )?;
    }
    archive
        .finish()
        .map(|cursor| cursor.into_inner())
        .map_err(|e| JobRunError::Failed(e.to_string()))
}

fn write_export_entry(
    archive: &mut zip::ZipWriter<Cursor<Vec<u8>>>,
    name: &str,
    bytes: &[u8],
    options: FileOptions,
) -> Result<(), JobRunError> {
    archive
        .start_file(name, options)
        .map_err(|e| JobRunError::Failed(e.to_string()))?;
    archive
        .write_all(bytes)
        .map_err(|e| JobRunError::Failed(e.to_string()))
}

async fn query_optional_object(
    pool: &PgPool,
    sql: &str,
    user_id: Uuid,
) -> Result<Value, JobRunError> {
    sqlx::query_scalar::<_, Option<Value>>(sql)
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map(|value| value.unwrap_or(Value::Null))
        .map_err(|e| JobRunError::Failed(e.to_string()))
}

async fn query_array(pool: &PgPool, sql: &str, user_id: Uuid) -> Result<Value, JobRunError> {
    sqlx::query_scalar::<_, Value>(sql)
        .bind(user_id)
        .fetch_one(pool)
        .await
        .map_err(|e| JobRunError::Failed(e.to_string()))
}
