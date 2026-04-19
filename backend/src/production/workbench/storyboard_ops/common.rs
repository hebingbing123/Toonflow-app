use crate::error::ApiError;

pub(super) fn validate_storyboard_ids(storyboard_ids: &[i32]) -> Result<(), ApiError> {
    if storyboard_ids.is_empty() {
        return Err(ApiError::BadRequest("ids must be a non-empty array".into()));
    }
    if storyboard_ids.iter().any(|id| *id <= 0) {
        return Err(ApiError::BadRequest("ids must be positive integers".into()));
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
