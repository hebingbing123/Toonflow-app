use chrono::{DateTime, Utc};
use serde_json::json;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::api_keys::{
    compose_api_key_token, generate_api_key_material, generate_api_key_secret_material,
    key_hint_from_secret,
};
use crate::error::ApiError;
use crate::state::AppState;

use super::types::{
    ApiKeyAuditRecord, ApiKeyCreateBody, ApiKeyCreatedResponse, ApiKeyExpiresAtActionDto,
    ApiKeyRecord, ApiKeyRotateBody, ApiKeyScopeDto, ApiKeyStatusDto,
};

#[derive(Debug, Clone, FromRow)]
struct ApiKeyRow {
    id: Uuid,
    public_id: String,
    display_name: String,
    scope: String,
    status: String,
    key_hint: String,
    expires_at: Option<DateTime<Utc>>,
    revoked_at: Option<DateTime<Utc>>,
    rotated_at: Option<DateTime<Utc>>,
    last_used_at: Option<DateTime<Utc>>,
    last_used_path: Option<String>,
    last_used_method: Option<String>,
    last_used_ip: Option<String>,
    last_used_user_agent: Option<String>,
    use_count: i64,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, FromRow)]
struct ApiKeyAuditRow {
    id: Uuid,
    api_key_id: Uuid,
    event_type: String,
    event_summary: String,
    metadata: serde_json::Value,
    created_at: DateTime<Utc>,
}

fn map_scope(scope: &str) -> Result<ApiKeyScopeDto, ApiError> {
    match scope {
        "read_only" => Ok(ApiKeyScopeDto::ReadOnly),
        "read_write" => Ok(ApiKeyScopeDto::ReadWrite),
        _ => Err(ApiError::Internal),
    }
}

fn map_status(status: &str) -> Result<ApiKeyStatusDto, ApiError> {
    match status {
        "active" => Ok(ApiKeyStatusDto::Active),
        "revoked" => Ok(ApiKeyStatusDto::Revoked),
        _ => Err(ApiError::Internal),
    }
}

fn into_record(row: ApiKeyRow) -> Result<ApiKeyRecord, ApiError> {
    let is_expired = row.expires_at.is_some_and(|ts| ts <= Utc::now());
    let is_usable = row.status == "active" && !is_expired;
    Ok(ApiKeyRecord {
        id: row.id,
        public_id: row.public_id,
        display_name: row.display_name,
        scope: map_scope(&row.scope)?,
        status: map_status(&row.status)?,
        key_hint: row.key_hint,
        expires_at: row.expires_at,
        revoked_at: row.revoked_at,
        rotated_at: row.rotated_at,
        last_used_at: row.last_used_at,
        last_used_path: row.last_used_path,
        last_used_method: row.last_used_method,
        last_used_ip: row.last_used_ip,
        last_used_user_agent: row.last_used_user_agent,
        use_count: row.use_count,
        is_expired,
        is_usable,
        created_at: row.created_at,
        updated_at: row.updated_at,
    })
}

fn normalized_display_name(raw: &str) -> Result<String, ApiError> {
    let name = raw.trim();
    if name.is_empty() {
        return Err(ApiError::BadRequest("displayName must be non-empty".into()));
    }
    if name.chars().count() > 80 {
        return Err(ApiError::BadRequest(
            "displayName must be 80 characters or fewer".into(),
        ));
    }
    Ok(name.to_string())
}

fn scope_string(scope: &ApiKeyScopeDto) -> &'static str {
    match scope {
        ApiKeyScopeDto::ReadOnly => "read_only",
        ApiKeyScopeDto::ReadWrite => "read_write",
    }
}

fn validate_expires_at(
    expires_at: Option<DateTime<Utc>>,
) -> Result<Option<DateTime<Utc>>, ApiError> {
    if let Some(value) = expires_at {
        if value <= Utc::now() {
            return Err(ApiError::BadRequest(
                "expiresAt must be in the future".into(),
            ));
        }
        return Ok(Some(value));
    }
    Ok(None)
}

fn resolve_rotated_expires_at(
    current: Option<DateTime<Utc>>,
    body: &ApiKeyRotateBody,
) -> Result<Option<DateTime<Utc>>, ApiError> {
    match body
        .expires_at_action
        .clone()
        .unwrap_or(ApiKeyExpiresAtActionDto::Preserve)
    {
        ApiKeyExpiresAtActionDto::Preserve => Ok(current),
        ApiKeyExpiresAtActionDto::Clear => Ok(None),
        ApiKeyExpiresAtActionDto::Set => validate_expires_at(body.expires_at),
    }
}

async fn insert_audit(
    state: &AppState,
    owner_user_id: Uuid,
    actor_user_id: Uuid,
    api_key_id: Uuid,
    event_type: &str,
    event_summary: String,
    metadata: serde_json::Value,
) -> Result<(), ApiError> {
    let pool = state.require_pool()?;
    sqlx::query(
        r#"
        INSERT INTO public.app_api_key_audit (
          api_key_id, owner_user_id, actor_user_id, event_type, event_summary, metadata
        )
        VALUES ($1, $2, $3, $4, $5, $6)
        "#,
    )
    .bind(api_key_id)
    .bind(owner_user_id)
    .bind(actor_user_id)
    .bind(event_type)
    .bind(event_summary)
    .bind(metadata)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

async fn get_owned_row(
    state: &AppState,
    owner_user_id: Uuid,
    id: Uuid,
) -> Result<ApiKeyRow, ApiError> {
    let pool = state.require_pool()?;
    sqlx::query_as::<_, ApiKeyRow>(
        r#"
        SELECT
          id, public_id, display_name, scope, status, key_hint, expires_at, revoked_at,
          rotated_at, last_used_at, last_used_path, last_used_method, last_used_ip,
          last_used_user_agent, use_count, created_at, updated_at
        FROM public.app_api_key
        WHERE id = $1 AND owner_user_id = $2
        "#,
    )
    .bind(id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)
}

pub async fn list_api_keys(
    state: &AppState,
    owner_user_id: Uuid,
) -> Result<Vec<ApiKeyRecord>, ApiError> {
    let pool = state.require_pool()?;
    let rows = sqlx::query_as::<_, ApiKeyRow>(
        r#"
        SELECT
          id, public_id, display_name, scope, status, key_hint, expires_at, revoked_at,
          rotated_at, last_used_at, last_used_path, last_used_method, last_used_ip,
          last_used_user_agent, use_count, created_at, updated_at
        FROM public.app_api_key
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        "#,
    )
    .bind(owner_user_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    rows.into_iter().map(into_record).collect()
}

pub async fn list_api_key_audit(
    state: &AppState,
    owner_user_id: Uuid,
    limit: i64,
) -> Result<Vec<ApiKeyAuditRecord>, ApiError> {
    let pool = state.require_pool()?;
    let rows = sqlx::query_as::<_, ApiKeyAuditRow>(
        r#"
        SELECT id, api_key_id, event_type, event_summary, metadata, created_at
        FROM public.app_api_key_audit
        WHERE owner_user_id = $1
        ORDER BY created_at DESC
        LIMIT $2
        "#,
    )
    .bind(owner_user_id)
    .bind(limit)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(rows
        .into_iter()
        .map(|row| ApiKeyAuditRecord {
            id: row.id,
            api_key_id: row.api_key_id,
            event_type: row.event_type,
            event_summary: row.event_summary,
            metadata: row.metadata,
            created_at: row.created_at,
        })
        .collect())
}

pub async fn create_api_key(
    state: &AppState,
    owner_user_id: Uuid,
    actor_user_id: Uuid,
    body: ApiKeyCreateBody,
) -> Result<ApiKeyCreatedResponse, ApiError> {
    // Validate input before touching the pool so smoke tests without DB still get 400.
    let display_name = normalized_display_name(&body.display_name)?;
    let expires_at = validate_expires_at(body.expires_at)?;
    let pool = state.require_pool()?;
    let (public_id, token, secret_hash, key_hint) = generate_api_key_material(state)?;
    let row = sqlx::query_as::<_, ApiKeyRow>(
        r#"
        INSERT INTO public.app_api_key (
          owner_user_id, public_id, display_name, scope, secret_hash, key_hint, expires_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING
          id, public_id, display_name, scope, status, key_hint, expires_at, revoked_at,
          rotated_at, last_used_at, last_used_path, last_used_method, last_used_ip,
          last_used_user_agent, use_count, created_at, updated_at
        "#,
    )
    .bind(owner_user_id)
    .bind(&public_id)
    .bind(&display_name)
    .bind(scope_string(&body.scope))
    .bind(&secret_hash)
    .bind(&key_hint)
    .bind(expires_at)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    insert_audit(
        state,
        owner_user_id,
        actor_user_id,
        row.id,
        "created",
        format!("api key created: {}", row.display_name),
        json!({
            "scope": row.scope,
            "publicId": row.public_id,
            "expiresAt": row.expires_at,
        }),
    )
    .await?;
    Ok(ApiKeyCreatedResponse {
        record: into_record(row)?,
        plaintext_token: token,
    })
}

pub async fn rotate_api_key(
    state: &AppState,
    owner_user_id: Uuid,
    actor_user_id: Uuid,
    id: Uuid,
    body: ApiKeyRotateBody,
) -> Result<ApiKeyCreatedResponse, ApiError> {
    let current = get_owned_row(state, owner_user_id, id).await?;
    let pool = state.require_pool()?;
    let expires_at = resolve_rotated_expires_at(current.expires_at, &body)?;
    let (secret, secret_hash) = generate_api_key_secret_material(state)?;
    let token = compose_api_key_token(&current.public_id, &secret);
    let key_hint = key_hint_from_secret(&current.public_id, &secret);
    let row = sqlx::query_as::<_, ApiKeyRow>(
        r#"
        UPDATE public.app_api_key
        SET
          secret_hash = $3,
          key_hint = $4,
          status = 'active',
          revoked_at = NULL,
          rotated_at = NOW(),
          expires_at = $5,
          updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2
        RETURNING
          id, public_id, display_name, scope, status, key_hint, expires_at, revoked_at,
          rotated_at, last_used_at, last_used_path, last_used_method, last_used_ip,
          last_used_user_agent, use_count, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(owner_user_id)
    .bind(&secret_hash)
    .bind(&key_hint)
    .bind(expires_at)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    insert_audit(
        state,
        owner_user_id,
        actor_user_id,
        row.id,
        "rotated",
        format!("api key rotated: {}", row.display_name),
        json!({
            "scope": row.scope,
            "publicId": row.public_id,
            "expiresAt": row.expires_at,
            "expiresAtAction": body.expires_at_action.unwrap_or(ApiKeyExpiresAtActionDto::Preserve),
        }),
    )
    .await?;
    Ok(ApiKeyCreatedResponse {
        record: into_record(row)?,
        plaintext_token: token,
    })
}

pub async fn update_api_key_status(
    state: &AppState,
    owner_user_id: Uuid,
    actor_user_id: Uuid,
    id: Uuid,
    next_status: &str,
    reason: Option<String>,
) -> Result<ApiKeyRecord, ApiError> {
    let current = get_owned_row(state, owner_user_id, id).await?;
    if next_status == "active" {
        validate_expires_at(current.expires_at)?;
    }
    let pool = state.require_pool()?;
    let revoked_at = if next_status == "revoked" {
        Some(chrono::Utc::now())
    } else {
        None
    };
    let row = sqlx::query_as::<_, ApiKeyRow>(
        r#"
        UPDATE public.app_api_key
        SET status = $3, revoked_at = $4, updated_at = NOW()
        WHERE id = $1 AND owner_user_id = $2
        RETURNING
          id, public_id, display_name, scope, status, key_hint, expires_at, revoked_at,
          rotated_at, last_used_at, last_used_path, last_used_method, last_used_ip,
          last_used_user_agent, use_count, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(owner_user_id)
    .bind(next_status)
    .bind(revoked_at)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let event_type = if next_status == "revoked" {
        "revoked"
    } else {
        "activated"
    };
    let summary = if next_status == "revoked" {
        format!("api key revoked: {}", current.display_name)
    } else {
        format!("api key activated: {}", current.display_name)
    };
    insert_audit(
        state,
        owner_user_id,
        actor_user_id,
        id,
        event_type,
        summary,
        json!({
            "reason": reason,
            "previousStatus": current.status,
            "nextStatus": next_status,
        }),
    )
    .await?;
    into_record(row)
}

pub async fn delete_api_key(
    state: &AppState,
    owner_user_id: Uuid,
    actor_user_id: Uuid,
    id: Uuid,
) -> Result<(), ApiError> {
    let current = get_owned_row(state, owner_user_id, id).await?;
    insert_audit(
        state,
        owner_user_id,
        actor_user_id,
        id,
        "deleted",
        format!("api key deleted: {}", current.display_name),
        json!({
            "scope": current.scope,
            "publicId": current.public_id,
        }),
    )
    .await?;
    let pool = state.require_pool()?;
    let deleted = sqlx::query_scalar::<_, i64>(
        r#"DELETE FROM public.app_api_key WHERE id = $1 AND owner_user_id = $2 RETURNING 1"#,
    )
    .bind(id)
    .bind(owner_user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if deleted.is_none() {
        return Err(ApiError::NotFound);
    }
    Ok(())
}
