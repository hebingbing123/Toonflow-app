//! 单批脚本：校验、调用提取工具、持久化结果。

use sqlx::PgPool;
use uuid::Uuid;

use crate::llm::LlmConfig;
use crate::scope;
use crate::settings::agent_memory::maybe_fill_project_style_bible_from_assets;

use super::super::persist::persist_group;
use super::super::tool::{call_extract_tool, filter_tool_existing, filter_tool_new_assets};
use super::mark_failed::mark_script_failed;

#[allow(clippy::too_many_arguments)]
pub(super) async fn process_one_group(
    pool: &PgPool,
    cfg: &LlmConfig,
    client: &reqwest::Client,
    system: &str,
    project_numeric_id: i32,
    project_uuid: Uuid,
    uid: Uuid,
    chunk: &[i32],
    script_map: &std::collections::HashMap<i32, (Option<String>, Option<String>)>,
) -> Result<(), String> {
    let mut valid: Vec<(i32, String)> = Vec::new();

    for &sid in chunk {
        let Some((name, content)) = script_map.get(&sid).cloned() else {
            mark_script_failed(pool, project_uuid, uid, sid, "script not found in project").await?;
            continue;
        };
        let oip = match scope::owned_script_in_project(pool, uid, project_uuid, sid).await {
            Ok(o) => o,
            Err(scope::ScopeError::NotFound) => {
                mark_script_failed(pool, project_uuid, uid, sid, "script not found in project")
                    .await?;
                continue;
            }
            Err(scope::ScopeError::Database(m)) => return Err(m),
        };

        let row: Option<(Option<i32>,)> =
            sqlx::query_as(r#"SELECT extract_state FROM app_script WHERE id = $1"#)
                .bind(oip.script_id)
                .fetch_optional(pool)
                .await
                .map_err(|e| e.to_string())?;

        let Some((Some(2),)) = row else {
            continue;
        };

        let body = content.unwrap_or_default();
        let title = name.unwrap_or_default();
        valid.push((sid, format!("===== 【剧本ID: {sid}】{title} =====\n{body}")));
    }

    if valid.is_empty() {
        return Ok(());
    }

    let valid_ids: Vec<i32> = valid.iter().map(|(id, _)| *id).collect();

    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = 0, updated_at = NOW()
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
    .bind(&valid_ids)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;

    let existing_rows: Vec<(String, String)> = sqlx::query_as(
        r#"SELECT name, asset_type FROM app_asset WHERE project_id = $1 ORDER BY name"#,
    )
    .bind(project_uuid)
    .fetch_all(pool)
    .await
    .map_err(|e| e.to_string())?;

    let existing_hint = if existing_rows.is_empty() {
        String::new()
    } else {
        format!(
            "\n\n【已有资产列表】：{}",
            existing_rows
                .iter()
                .map(|(n, t)| format!("{n}({t})"))
                .collect::<Vec<_>>()
                .join("、")
        )
    };

    let scripts_content = valid
        .iter()
        .map(|(_, block)| block.as_str())
        .collect::<Vec<_>>()
        .join("\n\n");

    let user_msg = format!(
        "{existing_hint}\n\n请根据以下{}集剧本提取对应的剧本资产（角色、场景、道具）:\n\n{scripts_content}",
        valid.len()
    );

    let parsed = match call_extract_tool(cfg, client, system, &user_msg).await {
        Ok(p) => p,
        Err(e) => {
            for sid in &valid_ids {
                mark_script_failed(pool, project_uuid, uid, *sid, &e).await?;
            }
            return Ok(());
        }
    };

    let valid_set: std::collections::HashSet<i32> = valid_ids.iter().copied().collect();
    let new_f = filter_tool_new_assets(parsed.new_assets, &valid_set);
    let ex_f = filter_tool_existing(parsed.existing_asset_refs, &valid_set);

    if new_f.is_empty() && ex_f.is_empty() {
        let msg = "AI returned no assets";
        for sid in &valid_ids {
            mark_script_failed(pool, project_uuid, uid, *sid, msg).await?;
        }
        return Ok(());
    }

    let mut tx = pool.begin().await.map_err(|e| e.to_string())?;
    if let Err(e) = persist_group(&mut tx, project_uuid, &valid_ids, &new_f, &ex_f).await {
        tx.rollback().await.ok();
        for sid in &valid_ids {
            mark_script_failed(pool, project_uuid, uid, *sid, &e.to_string()).await?;
        }
        return Ok(());
    }
    tx.commit().await.map_err(|e| e.to_string())?;

    sqlx::query(
        r#"
        UPDATE app_script s
        SET extract_state = 1, error_reason = NULL, updated_at = NOW()
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
    .bind(&valid_ids)
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;

    let pool_clone = pool.clone();
    tokio::spawn(async move {
        if let Err(error) =
            maybe_fill_project_style_bible_from_assets(&pool_clone, uid, project_numeric_id).await
        {
            tracing::warn!(
                project_id = project_numeric_id,
                user_id = %uid,
                error = ?error,
                "style bible asset fill failed"
            );
        }
    });

    Ok(())
}
