use chrono::{DateTime, Utc};
use serde_json::json;
use sqlx::FromRow;
use uuid::Uuid;

use crate::auth::api_keys::{
    compose_api_key_token, generate_api_key_material, generate_api_key_secret_material,
    key_hint_from_secret,
};
use crate::error::helpers::bad_request_i18n;
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
        return Err(bad_request_i18n(
            "displayName must be non-empty",
            "displayName 不能为空",
        ));
    }
    if name.chars().count() > 80 {
        return Err(bad_request_i18n(
            "displayName must be 80 characters or fewer",
            "displayName 长度不能超过 80 个字符",
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
            return Err(bad_request_i18n(
                "expiresAt must be in the future",
                "expiresAt 必须是未来时间",
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
    let deleted = sqlx::query_scalar::<_, bool>(
        r#"
        DELETE FROM public.app_api_key
        WHERE id = $1 AND owner_user_id = $2
        RETURNING TRUE
        "#,
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

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use sqlx::PgPool;
    use tokio::sync::RwLock;
    use uuid::Uuid;

    use crate::http_kit::metrics::MetricsRegistry;
    use crate::metering::BillingConfig;
    use crate::state::{MemoryConfig, WsNotifyHub};

    use super::*;

    fn test_database_url() -> Option<String> {
        std::env::var("TEST_DATABASE_URL").ok()
    }

    fn test_state(pool: PgPool) -> AppState {
        AppState {
            pool: Some(pool),
            jwt_secret: Some(b"contract-smoke-jwt-secret-bytes-32chars!".to_vec()),
            llm: None,
            http_client: reqwest::Client::new(),
            notify: WsNotifyHub::new(),
            memory_config: Arc::new(RwLock::new(MemoryConfig::default_seeded())),
            switch_ai_dev_tool: Arc::new(RwLock::new("0".into())),
            local_asset_image_dir: None,
            local_art_style_cover_dir: None,
            local_video_export_dir: None,
            local_voiceover_audio_dir: None,
            metrics_registry: Arc::new(MetricsRegistry::default()),
            billing_config: BillingConfig::default(),
        }
    }

    async fn insert_test_user(pool: &PgPool, user_id: Uuid) {
        let email = format!("api-key-delete-{}@example.test", user_id.simple());
        sqlx::query(
            r#"
            INSERT INTO auth.users (
              id, email, encrypted_password, email_confirmed_at, created_at, updated_at
            )
            VALUES ($1, $2, 'contract-test-password', NOW(), NOW(), NOW())
            "#,
        )
        .bind(user_id)
        .bind(email)
        .execute(pool)
        .await
        .expect("insert auth.users fixture");
    }

    async fn cleanup_test_user(pool: &PgPool, user_id: Uuid) {
        let _ = sqlx::query("DELETE FROM auth.users WHERE id = $1")
            .bind(user_id)
            .execute(pool)
            .await;
    }

    #[tokio::test]
    async fn delete_api_key_removes_row_and_preserves_deleted_audit() {
        let Some(db_url) = test_database_url() else {
            eprintln!("skipping api key delete regression test: TEST_DATABASE_URL not set");
            return;
        };

        let pool = PgPool::connect(&db_url)
            .await
            .expect("connect test database");
        let state = test_state(pool.clone());
        let user_id = Uuid::new_v4();

        insert_test_user(&pool, user_id).await;

        let created = create_api_key(
            &state,
            user_id,
            user_id,
            ApiKeyCreateBody {
                display_name: "delete regression".into(),
                scope: ApiKeyScopeDto::ReadWrite,
                expires_at: None,
            },
        )
        .await
        .expect("create api key");

        delete_api_key(&state, user_id, user_id, created.record.id)
            .await
            .expect("delete api key");

        let exists = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS(SELECT 1 FROM public.app_api_key WHERE id = $1)",
        )
        .bind(created.record.id)
        .fetch_one(&pool)
        .await
        .expect("check deleted row");
        assert!(!exists, "api key row should be deleted");

        let deleted_audit_count = sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)::bigint
            FROM public.app_api_key_audit
            WHERE api_key_id = $1 AND event_type = 'deleted'
            "#,
        )
        .bind(created.record.id)
        .fetch_one(&pool)
        .await
        .expect("count deleted audit rows");
        assert_eq!(deleted_audit_count, 1, "deleted audit row should remain");

        cleanup_test_user(&pool, user_id).await;
    }
}
