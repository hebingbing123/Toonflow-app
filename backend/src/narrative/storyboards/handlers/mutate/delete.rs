//! 删除分镜行。

use axum::http::StatusCode;
use sqlx::PgPool;
use uuid::Uuid;

use crate::error::ApiError;

use super::super::common::resolve_owned_storyboard_id;

pub(super) async fn delete_storyboard_row(
    pool: &PgPool,
    uid: Uuid,
    numeric_id: i32,
    project_id: Uuid,
) -> Result<StatusCode, ApiError> {
    let storyboard_id = resolve_owned_storyboard_id(pool, uid, project_id, numeric_id).await?;

    let res = sqlx::query(r#"DELETE FROM app_storyboard WHERE id = $1"#)
        .bind(storyboard_id)
        .execute(pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if res.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(StatusCode::NO_CONTENT)
}
