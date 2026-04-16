use sqlx::PgPool;
use uuid::Uuid;

pub(super) async fn store_video_reference(
    pool: &PgPool,
    owner_user_id: Uuid,
    project_numeric_id: i32,
    storyboard_numeric_id: i32,
    video_url: &str,
) -> Result<(), sqlx::Error> {
    sqlx::query(
        r#"
        UPDATE app_storyboard
        SET file_path = $1, state = '已完成', updated_at = NOW()
        FROM app_script, app_project
        WHERE app_storyboard.script_id = app_script.id
          AND app_script.project_id = app_project.id
          AND app_project.owner_user_id = $2
          AND app_project.numeric_id = $3
          AND app_storyboard.numeric_id = $4
        "#,
    )
    .bind(video_url)
    .bind(owner_user_id)
    .bind(project_numeric_id)
    .bind(storyboard_numeric_id)
    .execute(pool)
    .await?;

    Ok(())
}
