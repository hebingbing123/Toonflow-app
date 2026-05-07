//! `video_count` for project stats / summary — **must match** completed-video semantics in
//! `assets/workbench_query/material.rs` (`run_get_material_data`).

use uuid::Uuid;

/// Count **`app_video`** rows for a project whose **`state`** is treated as a finished clip in the
/// production workbench material board.
pub(crate) async fn count_completed_videos_for_project(
    pool: &sqlx::PgPool,
    project_id: Uuid,
) -> Result<i64, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_video v
        WHERE v.project_id = $1
          AND v.state IN ('生成成功', '已完成', 'succeeded', 'completed')
        "#,
    )
    .bind(project_id)
    .fetch_one(pool)
    .await
}

/// Sum completed **`app_video`** across all projects visible via **`app_workspace_member`**
/// (current workspace model).
pub(crate) async fn count_completed_videos_for_member_projects(
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<i64, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT COUNT(*)::bigint
        FROM app_video v
        INNER JOIN app_project p ON p.id = v.project_id
        WHERE v.state IN ('生成成功', '已完成', 'succeeded', 'completed')
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        "#,
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
}
