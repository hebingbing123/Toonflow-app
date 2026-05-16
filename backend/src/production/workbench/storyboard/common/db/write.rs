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

pub(in crate::production::workbench::storyboard) async fn update_live_action_reference(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
    reference_shot_urls: &[String],
    performance_notes: Option<&str>,
) -> Result<(), ApiError> {
    let reference_json = serde_json::to_value(reference_shot_urls).map_err(|e| {
        crate::error::bad_request_i18n(
            &format!("invalid live-action reference urls: {e}"),
            &format!("live-action reference urls 无效：{e}"),
        )
    })?;
    let performance_json = match performance_notes {
        Some(value) if !value.trim().is_empty() => {
            serde_json::Value::String(value.trim().to_string())
        }
        _ => serde_json::Value::Null,
    };

    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET
          metadata = jsonb_set(
            jsonb_set(
              COALESCE(metadata, '{}'::jsonb),
              '{shortVideo,liveAction,referenceShotUrls}',
              $2::jsonb,
              true
            ),
            '{shortVideo,liveAction,performanceNotes}',
            $3::jsonb,
            true
          ),
          updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(reference_json)
    .bind(performance_json)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}

pub(in crate::production::workbench::storyboard) async fn update_storyboard_duration(
    pool: &sqlx::PgPool,
    storyboard_id: Uuid,
    duration: i32,
) -> Result<(), ApiError> {
    let updated = sqlx::query(
        r#"
        UPDATE app_storyboard
        SET duration = $2::text, updated_at = NOW()
        WHERE id = $1
        "#,
    )
    .bind(storyboard_id)
    .bind(duration)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if updated.rows_affected() == 0 {
        return Err(ApiError::NotFound);
    }

    Ok(())
}
