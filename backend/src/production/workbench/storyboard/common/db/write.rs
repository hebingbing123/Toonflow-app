use uuid::Uuid;

use crate::error::ApiError;

pub(in crate::production::workbench::storyboard) async fn update_storyboard_info(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
    prompt: &str,
    duration: Option<i32>,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET prompt = $2, duration = COALESCE($3::text, duration), updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(prompt)
    .bind(duration)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}

pub(in crate::production::workbench::storyboard) async fn remove_storyboard_frame(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = NULL, state = NULL, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}

pub(in crate::production::workbench::storyboard) async fn update_storyboard_image_url(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
    image_url: &str,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $2, state = '已完成', updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(image_url)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}
