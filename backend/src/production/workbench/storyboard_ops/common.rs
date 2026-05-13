use axum::http::HeaderMap;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::{bad_request_i18n, ApiError};
use crate::scope::http::{
    require_script_read_scope, require_script_read_scope_ref, require_script_write_scope,
};
use crate::state::AppState;

pub(super) fn validate_storyboard_ids(storyboard_ids: &[i32]) -> Result<(), ApiError> {
    if storyboard_ids.is_empty() {
        return Err(bad_request_i18n(
            "ids must be a non-empty array",
            "ids 必须是非空数组",
        ));
    }
    if storyboard_ids.iter().any(|id| *id <= 0) {
        return Err(bad_request_i18n(
            "ids must be positive integers",
            "ids 必须是正整数",
        ));
    }
    Ok(())
}

pub(super) fn normalize_storyboard_ids(storyboard_ids: &[i32]) -> Result<Vec<i32>, ApiError> {
    validate_storyboard_ids(storyboard_ids)?;
    let mut uniq = storyboard_ids.to_vec();
    uniq.sort_unstable();
    uniq.dedup();
    Ok(uniq)
}

pub(super) async fn ensure_owned_storyboards(
    pool: &sqlx::PgPool,
    script_id: uuid::Uuid,
    storyboard_ids: &[i32],
) -> Result<(), ApiError> {
    let owned_count = sqlx::query_scalar::<_, i64>(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_storyboard sb
        WHERE sb.script_id = $1
          AND sb.numeric_id = ANY($2::int4[])
        "#,
    )
    .bind(script_id)
    .bind(storyboard_ids)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if owned_count != storyboard_ids.len() as i64 {
        return Err(ApiError::NotFound);
    }
    Ok(())
}

pub(crate) async fn require_owned_normalized_storyboards_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, Uuid, Vec<i32>), ApiError> {
    let normalized_ids = normalize_storyboard_ids(storyboard_ids)?;
    let (uid, pool, scope_row) =
        require_script_read_scope(state, headers, project_id, script_id).await?;
    ensure_owned_storyboards(pool, scope_row.script_id, &normalized_ids).await?;
    Ok((uid, pool, scope_row.script_id, normalized_ids))
}

pub(crate) async fn require_owned_normalized_storyboards_scope_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, i32, Uuid, Vec<i32>), ApiError> {
    let normalized_ids = normalize_storyboard_ids(storyboard_ids)?;
    let (uid, pool, scope_row) =
        require_script_read_scope_ref(state, headers, project_id, project_uuid, script_id).await?;
    ensure_owned_storyboards(pool, scope_row.script_id, &normalized_ids).await?;
    Ok((
        uid,
        pool,
        scope_row.project_numeric_id,
        scope_row.script_id,
        normalized_ids,
    ))
}

#[allow(dead_code)]
pub(crate) async fn require_owned_normalized_storyboards_write_scope<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, Uuid, Vec<i32>), ApiError> {
    let normalized_ids = normalize_storyboard_ids(storyboard_ids)?;
    let (uid, pool, scope_row) =
        require_script_write_scope(state, headers, project_id, script_id).await?;
    ensure_owned_storyboards(pool, scope_row.script_id, &normalized_ids).await?;
    Ok((uid, pool, scope_row.script_id, normalized_ids))
}

#[allow(dead_code)]
pub(super) async fn require_owned_normalized_storyboards_access(
    state: &AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(), ApiError> {
    let (_uid, _pool, _script_uuid, _normalized_ids) = require_owned_normalized_storyboards_scope(
        state,
        headers,
        project_id,
        script_id,
        storyboard_ids,
    )
    .await?;
    Ok(())
}

pub(super) async fn require_owned_normalized_storyboards_access_ref(
    state: &AppState,
    headers: &HeaderMap,
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(), ApiError> {
    let (_uid, _pool, _project_numeric_id, _script_uuid, _normalized_ids) =
        require_owned_normalized_storyboards_scope_ref(
            state,
            headers,
            project_id,
            project_uuid,
            script_id,
            storyboard_ids,
        )
        .await?;
    Ok(())
}

#[allow(dead_code)]
pub(super) async fn require_owned_normalized_storyboards_user_pool<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: i32,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(Uuid, &'a PgPool), ApiError> {
    let (uid, pool, _script_uuid, _normalized_ids) = require_owned_normalized_storyboards_scope(
        state,
        headers,
        project_id,
        script_id,
        storyboard_ids,
    )
    .await?;
    Ok((uid, pool))
}

pub(super) async fn require_owned_normalized_storyboards_user_pool_ref<'a>(
    state: &'a AppState,
    headers: &HeaderMap,
    project_id: Option<i32>,
    project_uuid: Option<Uuid>,
    script_id: i32,
    storyboard_ids: &[i32],
) -> Result<(Uuid, &'a PgPool, i32), ApiError> {
    let (uid, pool, project_numeric_id, _script_uuid, _normalized_ids) =
        require_owned_normalized_storyboards_scope_ref(
            state,
            headers,
            project_id,
            project_uuid,
            script_id,
            storyboard_ids,
        )
        .await?;
    Ok((uid, pool, project_numeric_id))
}

#[cfg(test)]
mod tests {
    use super::{normalize_storyboard_ids, validate_storyboard_ids};
    use crate::error::ApiError;

    #[test]
    fn validate_storyboard_ids_rejects_empty_input() {
        let err = validate_storyboard_ids(&[]).unwrap_err();
        assert!(
            matches!(err, ApiError::BadRequest(message) if message == "ids must be a non-empty array")
        );
    }

    #[test]
    fn validate_storyboard_ids_rejects_non_positive_values() {
        let err = validate_storyboard_ids(&[1, 0, 3]).unwrap_err();
        assert!(
            matches!(err, ApiError::BadRequest(message) if message == "ids must be positive integers")
        );
    }

    #[test]
    fn normalize_storyboard_ids_sorts_and_deduplicates() {
        let ids = normalize_storyboard_ids(&[4, 2, 4, 1, 2]).unwrap();
        assert_eq!(ids, vec![1, 2, 4]);
    }
}
