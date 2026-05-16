use sqlx::{FromRow, PgPool};
use uuid::Uuid;

/// Background worker: resolve **`app_asset.id`** by numeric ids inside workspace member scope.
pub async fn resolve_asset_id_for_job(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_numeric_id: i32,
    asset_numeric_id: i32,
) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar(
        r#"
        SELECT a.id
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        WHERE p.numeric_id = $1
          AND a.numeric_id = $2
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $3
          )
        "#,
    )
    .bind(project_numeric_id)
    .bind(asset_numeric_id)
    .bind(actor_user_id)
    .fetch_optional(pool)
    .await
}

/// Worker-only row: owned asset linked to a script via **`app_script_asset`**
/// (**`project_numeric_id`**, **`script_numeric_id`**, **`asset_numeric_id`**).
#[derive(Debug, Clone, FromRow)]
pub struct OwnedScriptLinkedAssetJobRow {
    pub id: Uuid,
    pub name: String,
    pub describe: Option<String>,
}

/// Resolve **`app_asset.id`** (and display fields) for jobs that must stay inside **`app_script_asset`** scope.
pub async fn resolve_owned_script_linked_asset_row_for_job(
    pool: &PgPool,
    actor_user_id: Uuid,
    project_numeric_id: i32,
    script_numeric_id: i32,
    asset_numeric_id: i32,
) -> Result<Option<OwnedScriptLinkedAssetJobRow>, sqlx::Error> {
    sqlx::query_as::<_, OwnedScriptLinkedAssetJobRow>(
        r#"
        SELECT a.id, a.name, a.describe
        FROM app_asset a
        INNER JOIN app_project p ON p.id = a.project_id
        INNER JOIN app_script s ON s.project_id = p.id AND s.numeric_id = $3
        INNER JOIN app_script_asset sa ON sa.asset_id = a.id AND sa.script_id = s.id
        WHERE p.numeric_id = $2
          AND a.numeric_id = $4
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
        "#,
    )
    .bind(actor_user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(asset_numeric_id)
    .fetch_optional(pool)
    .await
}

/// Next **`sort_index`** for a new **`app_asset_image`** row (append to history).
pub async fn next_asset_image_sort_index(
    pool: &PgPool,
    asset_id: Uuid,
) -> Result<i32, sqlx::Error> {
    let max: Option<i32> =
        sqlx::query_scalar(r#"SELECT MAX(sort_index) FROM app_asset_image WHERE asset_id = $1"#)
            .bind(asset_id)
            .fetch_one(pool)
            .await?;
    Ok(max.map_or(0, |m| m.saturating_add(1)))
}
