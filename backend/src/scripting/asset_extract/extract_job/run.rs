//! 提取任务入口：解析项目、置状态、按组分派处理。

use sqlx::PgPool;
use uuid::Uuid;

use crate::llm::LlmConfig;

use super::super::util::load_system_prompt;
use super::process_group::process_one_group;
use crate::scope;

pub(crate) async fn run_extract_job(
    pool: PgPool,
    cfg: LlmConfig,
    client: reqwest::Client,
    uid: Uuid,
    project_numeric_id: i32,
    script_numeric_ids: Vec<i32>,
    group_size: usize,
) -> Result<(), String> {
    let system = load_system_prompt();

    let project_uuid: Uuid = scope::owned_project_id_by_numeric(&pool, uid, project_numeric_id)
        .await
        .map_err(|e| match e {
            scope::ScopeError::NotFound => "project not found or not accessible".to_string(),
            scope::ScopeError::Database(m) => m,
        })?;

    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = 2, error_reason = NULL, updated_at = NOW()
        FROM app_project p
        WHERE s.project_id = p.id
          AND p.id = $1
          AND s.numeric_id = ANY($3)
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $2
          )
        "#,
    )
    .bind(project_uuid)
    .bind(uid)
    .bind(&script_numeric_ids)
    .execute(&pool)
    .await
    .map_err(|e| e.to_string())?;

    let script_map: Vec<(i32, Option<String>, Option<String>)> = sqlx::query_as(
        r#"
        SELECT s.numeric_id, s.name, s.content
        FROM app_script s
        WHERE s.project_id = $1 AND s.numeric_id = ANY($2)
        ORDER BY s.numeric_id
        "#,
    )
    .bind(project_uuid)
    .bind(&script_numeric_ids)
    .fetch_all(&pool)
    .await
    .map_err(|e| e.to_string())?;

    let mut rows_by_numeric_id: std::collections::HashMap<i32, (Option<String>, Option<String>)> =
        std::collections::HashMap::new();
    for (lid, name, content) in script_map {
        rows_by_numeric_id.insert(lid, (name, content));
    }

    for chunk in script_numeric_ids.chunks(group_size) {
        process_one_group(
            &pool,
            &cfg,
            &client,
            &system,
            project_numeric_id,
            project_uuid,
            uid,
            chunk,
            &rows_by_numeric_id,
        )
        .await?;
    }

    Ok(())
}
