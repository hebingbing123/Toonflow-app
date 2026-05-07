#![allow(dead_code)]

use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::types::AssetGenKind;

pub(super) const MAX_MODEL_LEN: usize = 512;
pub(super) const MAX_RESOLUTION_LEN: usize = 128;
pub(super) const MAX_NAME_LEN: usize = 512;
pub(super) const MAX_PROMPT_LEN: usize = 48_000;
pub(super) const MAX_BASE64_HINT_LEN: usize = 24_000_000;
pub(super) const MAX_ASSET_TYPE_LEN: usize = 64;
pub(super) const MAX_DESCRIBE_LEN: usize = 48_000;
/// Large batch calls can send many rows; cap payload size.
pub(super) const MAX_BATCH_ITEMS: usize = 50;
pub(super) const MAX_CONCURRENT_COUNT: i32 = 20;

pub(super) fn asset_type_str(k: &AssetGenKind) -> &'static str {
    match k {
        AssetGenKind::Role => "role",
        AssetGenKind::Scene => "scene",
        AssetGenKind::Tool => "tool",
        AssetGenKind::Storyboard => "storyboard",
    }
}

pub(super) fn trim_non_empty_str(s: &str, field: &'static str) -> Result<String, ApiError> {
    let t = s.trim();
    if t.is_empty() {
        return Err(ApiError::BadRequest(format!("{field} must be non-empty")));
    }
    Ok(t.to_owned())
}

pub(super) fn trim_non_empty(s: String, field: &'static str) -> Result<String, ApiError> {
    trim_non_empty_str(&s, field)
}

pub(super) fn normalize_optional_base64(
    input: Option<&str>,
    field: &'static str,
) -> Result<Option<String>, ApiError> {
    let Some(raw) = input else {
        return Ok(None);
    };
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return Ok(None);
    }
    if trimmed.len() > MAX_BASE64_HINT_LEN {
        return Err(ApiError::BadRequest(format!(
            "{field} must be at most {MAX_BASE64_HINT_LEN} chars"
        )));
    }
    if trimmed.starts_with("data:") {
        return Ok(Some(trimmed.to_owned()));
    }
    Ok(Some(format!("data:image/jpeg;base64,{trimmed}")))
}

pub(super) async fn resolve_owned_project_uuid(
    pool: &PgPool,
    uid: Uuid,
    project_numeric_id: i32,
) -> Result<Uuid, ApiError> {
    if project_numeric_id <= 0 {
        return Err(ApiError::BadRequest("projectId must be positive".into()));
    }
    let id: Option<Uuid> = sqlx::query_scalar(
        r#"
        SELECT p.id
        FROM app_project p
        WHERE p.numeric_id = $1
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
        "#,
    )
    .bind(project_numeric_id)
    .bind(uid)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    id.ok_or(ApiError::NotFound)
}

/// Returns **404** when any `numeric_id` is missing from this owned project (defense before enqueue).
pub(super) async fn ensure_asset_numerics_exist_in_owned_project(
    pool: &PgPool,
    uid: Uuid,
    project_uuid: Uuid,
    asset_numeric_ids: &[i32],
) -> Result<(), ApiError> {
    if asset_numeric_ids.is_empty() {
        return Ok(());
    }
    let mut uniq: Vec<i32> = asset_numeric_ids.to_vec();
    uniq.sort_unstable();
    uniq.dedup();

    let cnt: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT a.numeric_id)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.id = $1
          AND a.numeric_id = ANY($3::int4[])
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(&uniq)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if cnt != uniq.len() as i64 {
        return Err(ApiError::NotFound);
    }
    Ok(())
}

pub(super) async fn ensure_batch_asset_items_linked_to_script(
    pool: &PgPool,
    uid: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    asset_numeric_ids: &[i32],
) -> Result<(), ApiError> {
    let scope_row =
        crate::scope::owned_script_scope(pool, uid, project_numeric_id, script_numeric_id)
            .await
            .map_err(|e| e.into_api_error())?;

    let mut uniq: Vec<i32> = asset_numeric_ids.to_vec();
    uniq.sort_unstable();
    uniq.dedup();

    let linked: i64 = sqlx::query_scalar(
        r#"
        SELECT COUNT(DISTINCT a.numeric_id)::bigint
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = $3
        WHERE p.numeric_id = $2
          AND a.numeric_id = ANY($4::int4[])
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        "#,
    )
    .bind(uid)
    .bind(project_numeric_id)
    .bind(scope_row.script_id)
    .bind(&uniq)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if linked != uniq.len() as i64 {
        return Err(ApiError::NotFound);
    }
    Ok(())
}
