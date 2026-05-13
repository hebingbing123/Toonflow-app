//! 观察资产治理 HTTP 处理器。

use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use sqlx::{Postgres, QueryBuilder};
use uuid::Uuid;

use crate::auth::require_user_uuid;
use crate::error::{bad_request_i18n, ApiError};
use crate::state::AppState;

use super::types::{
    CreateObservationAssetBody, ListObservationAssetsQuery, ObservationAsset,
    UpdateObservationAssetBody,
};

/// POST /api/v1/benchmark/observation-assets - 创建观察资产
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/observation-assets",
    operation_id = "createObservationAssetV1",
    tag = "benchmark",
    request_body(content = CreateObservationAssetBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ObservationAsset),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn create_observation_asset(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<CreateObservationAssetBody>,
) -> Result<Json<ObservationAsset>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_create_body(&body)?;
    let pool = state.require_pool()?;

    // 去重检测（需求 6.3）
    check_duplicate_asset(
        pool,
        user_id,
        body.project_id,
        &body.scope_kind,
        &body.issue_type,
        &body.normalized_note,
    )
    .await?;

    let signal_strength = body.signal_strength.unwrap_or(1);

    let asset = sqlx::query_as::<_, ObservationAsset>(
        r#"
        INSERT INTO app_observation_asset (
            owner_user_id, project_id, scope_kind, issue_type,
            source_kind, source_ref, signal_strength, status, normalized_note
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'candidate', $8)
        RETURNING *
        "#,
    )
    .bind(user_id)
    .bind(body.project_id)
    .bind(&body.scope_kind)
    .bind(&body.issue_type)
    .bind(&body.source_kind)
    .bind(&body.source_ref)
    .bind(signal_strength)
    .bind(&body.normalized_note)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(asset))
}

/// GET /api/v1/benchmark/observation-assets - 列出观察资产
#[utoipa::path(
    get,
    path = "/api/v1/benchmark/observation-assets",
    operation_id = "listObservationAssetsV1",
    tag = "benchmark",
    params(ListObservationAssetsQuery),
    responses(
        (status = 200, description = "OK", body = Vec<ObservationAsset>),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn list_observation_assets(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<ListObservationAssetsQuery>,
) -> Result<Json<Vec<ObservationAsset>>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_list_query(&query)?;
    let pool = state.require_pool()?;

    let limit = query.limit.unwrap_or(100).clamp(1, 500);
    let offset = query.offset.unwrap_or(0).max(0);

    let mut qb =
        QueryBuilder::<Postgres>::new("SELECT * FROM app_observation_asset WHERE owner_user_id = ");
    qb.push_bind(user_id);

    if let Some(project_id) = query.project_id {
        qb.push(" AND project_id = ");
        qb.push_bind(project_id);
    }
    if let Some(scope_kind) = &query.scope_kind {
        qb.push(" AND scope_kind = ");
        qb.push_bind(scope_kind);
    }
    if let Some(issue_type) = &query.issue_type {
        qb.push(" AND issue_type = ");
        qb.push_bind(issue_type);
    }
    if let Some(source_kind) = &query.source_kind {
        qb.push(" AND source_kind = ");
        qb.push_bind(source_kind);
    }
    if let Some(status) = &query.status {
        qb.push(" AND status = ");
        qb.push_bind(status);
    }
    if let Some(min_signal) = query.min_signal_strength {
        qb.push(" AND signal_strength >= ");
        qb.push_bind(min_signal);
    }

    qb.push(" ORDER BY signal_strength DESC, hit_count DESC, created_at DESC LIMIT ");
    qb.push_bind(limit);
    qb.push(" OFFSET ");
    qb.push_bind(offset);

    let assets = qb
        .build_query_as::<ObservationAsset>()
        .fetch_all(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(assets))
}

/// PATCH /api/v1/benchmark/observation-assets/:id - 更新观察资产
#[utoipa::path(
    patch,
    path = "/api/v1/benchmark/observation-assets/{id}",
    operation_id = "updateObservationAssetV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Observation asset ID")
    ),
    request_body(content = UpdateObservationAssetBody, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = ObservationAsset),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn update_observation_asset(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
    Json(body): Json<UpdateObservationAssetBody>,
) -> Result<Json<ObservationAsset>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    validate_update_body(&body)?;
    let pool = state.require_pool()?;

    // 验证所有权
    let _existing = sqlx::query_as::<_, ObservationAsset>(
        "SELECT * FROM app_observation_asset WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let mut qb = QueryBuilder::<Postgres>::new("UPDATE app_observation_asset SET ");
    let mut has_field = false;

    if let Some(scope_kind) = &body.scope_kind {
        qb.push("scope_kind = ");
        qb.push_bind(scope_kind);
        has_field = true;
    }
    if let Some(issue_type) = &body.issue_type {
        if has_field {
            qb.push(", ");
        }
        qb.push("issue_type = ");
        qb.push_bind(issue_type);
        has_field = true;
    }
    if let Some(signal_strength) = body.signal_strength {
        if has_field {
            qb.push(", ");
        }
        qb.push("signal_strength = ");
        qb.push_bind(signal_strength);
        has_field = true;
    }
    if let Some(normalized_note) = &body.normalized_note {
        if has_field {
            qb.push(", ");
        }
        qb.push("normalized_note = ");
        qb.push_bind(normalized_note);
        has_field = true;
    }
    if let Some(status) = &body.status {
        if has_field {
            qb.push(", ");
        }
        qb.push("status = ");
        qb.push_bind(status);
        has_field = true;
    }

    if !has_field {
        return Err(bad_request_i18n(
            "At least one field must be provided",
            "至少需要提供一个字段",
        ));
    }

    qb.push(" WHERE id = ");
    qb.push_bind(id);
    qb.push(" AND owner_user_id = ");
    qb.push_bind(user_id);
    qb.push(" RETURNING *");

    let updated = qb
        .build_query_as::<ObservationAsset>()
        .fetch_one(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(updated))
}

/// POST /api/v1/benchmark/observation-assets/:id/archive - 归档观察资产
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/observation-assets/{id}/archive",
    operation_id = "archiveObservationAssetV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Observation asset ID")
    ),
    responses(
        (status = 200, description = "OK", body = ObservationAsset),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn archive_observation_asset(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ObservationAsset>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let asset = sqlx::query_as::<_, ObservationAsset>(
        r#"
        UPDATE app_observation_asset
        SET status = 'archived'
        WHERE id = $1 AND owner_user_id = $2
        RETURNING *
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(asset))
}

/// POST /api/v1/benchmark/observation-assets/:id/reject - 拒绝观察资产
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/observation-assets/{id}/reject",
    operation_id = "rejectObservationAssetV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Observation asset ID")
    ),
    responses(
        (status = 200, description = "OK", body = ObservationAsset),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn reject_observation_asset(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ObservationAsset>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let asset = sqlx::query_as::<_, ObservationAsset>(
        r#"
        UPDATE app_observation_asset
        SET status = 'rejected'
        WHERE id = $1 AND owner_user_id = $2
        RETURNING *
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(asset))
}

/// POST /api/v1/benchmark/observation-assets/:id/hit - 增加命中计数
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/observation-assets/{id}/hit",
    operation_id = "incrementHitCountV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Observation asset ID")
    ),
    responses(
        (status = 200, description = "OK", body = ObservationAsset),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn increment_hit_count(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ObservationAsset>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let asset = sqlx::query_as::<_, ObservationAsset>(
        r#"
        UPDATE app_observation_asset
        SET hit_count = hit_count + 1,
            last_hit_at = NOW()
        WHERE id = $1 AND owner_user_id = $2
        RETURNING *
        "#,
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(asset))
}

/// POST /api/v1/benchmark/observation-assets/:id/falsified - 增加证伪计数
#[utoipa::path(
    post,
    path = "/api/v1/benchmark/observation-assets/{id}/falsified",
    operation_id = "incrementFalsifiedCountV1",
    tag = "benchmark",
    params(
        ("id" = Uuid, Path, description = "Observation asset ID")
    ),
    responses(
        (status = 200, description = "OK", body = ObservationAsset),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
pub(crate) async fn increment_falsified_count(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<Uuid>,
) -> Result<Json<ObservationAsset>, ApiError> {
    let user_id = require_user_uuid(&state, &headers)?;
    let pool = state.require_pool()?;

    let existing = sqlx::query_as::<_, ObservationAsset>(
        "SELECT * FROM app_observation_asset WHERE id = $1 AND owner_user_id = $2",
    )
    .bind(id)
    .bind(user_id)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    let next_falsified_count = existing.falsified_count + 1;
    let next_status = next_observation_status_after_falsified(
        existing.signal_strength,
        existing.hit_count,
        next_falsified_count,
        &existing.status,
    );

    let asset = sqlx::query_as::<_, ObservationAsset>(
        r#"
        UPDATE app_observation_asset
        SET falsified_count = falsified_count + 1,
            status = $3
        WHERE id = $1 AND owner_user_id = $2
        RETURNING *
        "#,
    )
    .bind(id)
    .bind(user_id)
    .bind(next_status)
    .fetch_optional(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound)?;

    Ok(Json(asset))
}

// ============================================================
// 验证辅助函数
// ============================================================

fn validate_create_body(body: &CreateObservationAssetBody) -> Result<(), ApiError> {
    validate_scope_kind(&body.scope_kind)?;
    validate_source_kind(&body.source_kind)?;

    if body.issue_type.trim().is_empty() {
        return Err(bad_request_i18n(
            "issue_type cannot be empty",
            "issue_type 不能为空",
        ));
    }

    if body.normalized_note.trim().is_empty() {
        return Err(bad_request_i18n(
            "normalized_note cannot be empty",
            "normalized_note 不能为空",
        ));
    }

    if let Some(signal_strength) = body.signal_strength {
        if !(1..=10).contains(&signal_strength) {
            return Err(bad_request_i18n(
                "signal_strength must be between 1 and 10",
                "signal_strength 必须在 1 到 10 之间",
            ));
        }
    }

    Ok(())
}

fn validate_list_query(query: &ListObservationAssetsQuery) -> Result<(), ApiError> {
    if let Some(scope_kind) = &query.scope_kind {
        validate_scope_kind(scope_kind)?;
    }
    if let Some(source_kind) = &query.source_kind {
        validate_source_kind(source_kind)?;
    }
    if let Some(status) = &query.status {
        validate_status(status)?;
    }
    Ok(())
}

fn validate_update_body(body: &UpdateObservationAssetBody) -> Result<(), ApiError> {
    if let Some(scope_kind) = &body.scope_kind {
        validate_scope_kind(scope_kind)?;
    }
    if let Some(issue_type) = &body.issue_type {
        if issue_type.trim().is_empty() {
            return Err(bad_request_i18n(
                "issue_type cannot be empty",
                "issue_type 不能为空",
            ));
        }
    }
    if let Some(normalized_note) = &body.normalized_note {
        if normalized_note.trim().is_empty() {
            return Err(bad_request_i18n(
                "normalized_note cannot be empty",
                "normalized_note 不能为空",
            ));
        }
    }
    if let Some(signal_strength) = body.signal_strength {
        if !(1..=10).contains(&signal_strength) {
            return Err(bad_request_i18n(
                "signal_strength must be between 1 and 10",
                "signal_strength 必须在 1 到 10 之间",
            ));
        }
    }
    if let Some(status) = &body.status {
        validate_status(status)?;
    }
    Ok(())
}

pub(super) fn validate_scope_kind(scope_kind: &str) -> Result<(), ApiError> {
    const VALID_SCOPES: &[&str] = &["global", "project", "style_pack"];

    if !VALID_SCOPES.contains(&scope_kind) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid scope_kind '{}'. Must be one of: {}",
                scope_kind,
                VALID_SCOPES.join(", ")
            ),
            &format!(
                "无效的 scope_kind '{}'。必须是以下之一：{}",
                scope_kind,
                VALID_SCOPES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn validate_source_kind(source_kind: &str) -> Result<(), ApiError> {
    const VALID_SOURCES: &[&str] = &[
        "quality_review",
        "job_failure",
        "patch_attribution",
        "human_review",
        "experiment",
    ];

    if !VALID_SOURCES.contains(&source_kind) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid source_kind '{}'. Must be one of: {}",
                source_kind,
                VALID_SOURCES.join(", ")
            ),
            &format!(
                "无效的 source_kind '{}'。必须是以下之一：{}",
                source_kind,
                VALID_SOURCES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn validate_status(status: &str) -> Result<(), ApiError> {
    const VALID_STATUSES: &[&str] = &["candidate", "active", "archived", "rejected"];

    if !VALID_STATUSES.contains(&status) {
        return Err(bad_request_i18n(
            &format!(
                "Invalid status '{}'. Must be one of: {}",
                status,
                VALID_STATUSES.join(", ")
            ),
            &format!(
                "无效的 status '{}'。必须是以下之一：{}",
                status,
                VALID_STATUSES.join("、")
            ),
        ));
    }

    Ok(())
}

pub(super) fn observation_asset_dedup_key(
    owner_user_id: Uuid,
    project_id: Option<i32>,
    scope_kind: &str,
    issue_type: &str,
    normalized_note: &str,
) -> String {
    format!(
        "{}:{}:{}:{}:{}",
        owner_user_id,
        project_id
            .map(|value| value.to_string())
            .unwrap_or_else(|| "global".to_string()),
        scope_kind,
        issue_type,
        normalized_note
    )
}

pub(super) fn next_observation_status_after_falsified(
    signal_strength: i32,
    hit_count: i32,
    falsified_count: i32,
    current_status: &str,
) -> String {
    if current_status == "rejected" {
        return "rejected".to_string();
    }
    if falsified_count >= 3 || (signal_strength <= 2 && hit_count == 0 && falsified_count >= 2) {
        return "archived".to_string();
    }
    current_status.to_string()
}

/// 检查重复观察资产（需求 6.3）
async fn check_duplicate_asset(
    pool: &sqlx::PgPool,
    user_id: Uuid,
    project_id: Option<i32>,
    scope_kind: &str,
    issue_type: &str,
    normalized_note: &str,
) -> Result<(), ApiError> {
    let dedup_key =
        observation_asset_dedup_key(user_id, project_id, scope_kind, issue_type, normalized_note);
    let count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)
        FROM app_observation_asset
        WHERE owner_user_id = $1
          AND (project_id = $2 OR (project_id IS NULL AND $2 IS NULL))
          AND scope_kind = $3
          AND issue_type = $4
          AND normalized_note = $5
          AND status IN ('candidate', 'active')
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(scope_kind)
    .bind(issue_type)
    .bind(normalized_note)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if count > 0 {
        return Err(bad_request_i18n(
            &format!(
                "Duplicate observation asset detected for key {}. Consider updating existing asset instead.",
                dedup_key
            ),
            &format!("检测到 key {} 下存在重复 observation asset，请考虑更新已有资产。", dedup_key),
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    #[test]
    fn test_validate_scope_kind() {
        assert!(validate_scope_kind("global").is_ok());
        assert!(validate_scope_kind("project").is_ok());
        assert!(validate_scope_kind("style_pack").is_ok());
        assert!(validate_scope_kind("invalid_scope").is_err());
    }

    #[test]
    fn test_validate_source_kind() {
        assert!(validate_source_kind("quality_review").is_ok());
        assert!(validate_source_kind("experiment").is_ok());
        assert!(validate_source_kind("invalid_source").is_err());
    }

    #[test]
    fn test_validate_status() {
        assert!(validate_status("candidate").is_ok());
        assert!(validate_status("active").is_ok());
        assert!(validate_status("archived").is_ok());
        assert!(validate_status("rejected").is_ok());
        assert!(validate_status("invalid_status").is_err());
    }

    proptest! {
        #[test]
        fn prop_low_signal_observation_assets_auto_archive(
            signal_strength in 1i32..=2,
            falsified_count in 2i32..=8
        ) {
            let status = next_observation_status_after_falsified(
                signal_strength,
                0,
                falsified_count,
                "candidate",
            );
            prop_assert_eq!(status, "archived");
        }

        #[test]
        fn prop_observation_dedup_key_is_stable(
            project_id in proptest::option::of(1i32..1000),
            scope_kind in prop_oneof![
                Just("global".to_string()),
                Just("project".to_string()),
                Just("style_pack".to_string()),
            ],
            issue_type in "[a-z_]{4,20}",
            normalized_note in "[a-z0-9 _-]{6,40}",
        ) {
            let owner = Uuid::from_u128(11);
            let key_a = observation_asset_dedup_key(
                owner,
                project_id,
                &scope_kind,
                &issue_type,
                &normalized_note,
            );
            let key_b = observation_asset_dedup_key(
                owner,
                project_id,
                &scope_kind,
                &issue_type,
                &normalized_note,
            );
            prop_assert_eq!(key_a, key_b);
        }
    }
}
