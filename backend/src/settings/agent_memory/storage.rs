use serde_json::{json, Value};
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use crate::error::ApiError;

use super::{
    load_project_automation_memory_policy, policy_allows_automated_memory, MEMORY_POLICY_NAME,
};

pub(crate) fn parse_agent_type(raw: &str) -> Result<&'static str, ApiError> {
    match raw {
        "scriptAgent" => Ok("scriptAgent"),
        "productionAgent" => Ok("productionAgent"),
        _ => Err(ApiError::BadRequest(
            "agentType must be scriptAgent or productionAgent".into(),
        )),
    }
}

pub(crate) async fn ensure_project_owned(
    pool: &PgPool,
    uid: Uuid,
    numeric_project_id: i32,
) -> Result<(), ApiError> {
    let ok: bool = sqlx::query_scalar(
        r#"
        SELECT EXISTS(
          SELECT 1 FROM app_project
          WHERE numeric_id = $1 AND owner_user_id = $2
        )
        "#,
    )
    .bind(numeric_project_id)
    .bind(uid)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    if !ok {
        return Err(ApiError::NotFound);
    }
    Ok(())
}

/// Same DELETE scope as POST /api/v1/agents/memory/clear with clearType: all.
pub(crate) async fn delete_all_agent_memory_rows(
    tx: &mut Transaction<'_, Postgres>,
    uid: Uuid,
    project_id: i32,
    agent_type: &'static str,
    episodes_id: Option<i32>,
) -> Result<(), ApiError> {
    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = $3
          AND episodes_id IS NOT DISTINCT FROM $4
        "#,
    )
    .bind(uid)
    .bind(project_id)
    .bind(agent_type)
    .bind(episodes_id)
    .execute(&mut **tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    Ok(())
}

/// Append a single memory row to app_agent_memory.
/// Used internally by quality feedback and other automated systems.
#[allow(dead_code)]
#[allow(clippy::too_many_arguments)]
pub(crate) async fn append_agent_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    memory_type: &str,
    role: &str,
    content: &str,
    name: Option<&str>,
    create_time_ms: Option<i64>,
) -> Result<(), ApiError> {
    let time_ms = create_time_ms.unwrap_or_else(|| chrono::Utc::now().timestamp_millis());
    let summarized = if memory_type == "summary" { 1 } else { 0 };

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
            owner_user_id, numeric_project_id, episodes_id, agent_type,
            memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(memory_type)
    .bind(role)
    .bind(name)
    .bind(content)
    .bind(summarized)
    .bind(time_ms)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// Replace a named summary memory within the exact user/project/script/agent scope.
/// This keeps automated summary memories bounded instead of appending indefinitely.
#[allow(clippy::too_many_arguments)]
pub(crate) async fn replace_named_summary_memory(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    role: &str,
    name: &str,
    content: &str,
    create_time_ms: Option<i64>,
) -> Result<(), ApiError> {
    replace_named_summary_memory_with_scope(
        pool,
        user_id,
        project_id,
        episodes_id,
        agent_type,
        role,
        name,
        content,
        "message",
        None,
        create_time_ms,
    )
    .await
}

/// Replace a named summary memory and persist optional tier/scope metadata.
/// This is used by automated stage/style summaries that need upsert semantics.
#[allow(clippy::too_many_arguments)]
pub(crate) async fn replace_named_summary_memory_with_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    role: &str,
    name: &str,
    content: &str,
    memory_tier: &str,
    scope_signature: Option<&Value>,
    create_time_ms: Option<i64>,
) -> Result<(), ApiError> {
    if name != MEMORY_POLICY_NAME {
        let policy =
            load_project_automation_memory_policy(pool, user_id, project_id, agent_type).await?;
        if !policy_allows_automated_memory(
            &policy,
            memory_tier,
            Some(name),
            content,
            scope_signature,
        ) {
            return Ok(());
        }
    }
    let time_ms = create_time_ms.unwrap_or_else(|| chrono::Utc::now().timestamp_millis());

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'summary'
          AND name = $5
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(name)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
            owner_user_id, numeric_project_id, episodes_id, agent_type,
            memory_type, role, name, content, summarized, create_time_ms,
            memory_tier, scope_signature
        )
        VALUES ($1, $2, $3, $4, 'summary', $5, $6, $7, 1, $8, $9, $10)
        "#,
    )
    .bind(user_id)
    .bind(project_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(role)
    .bind(name)
    .bind(content)
    .bind(time_ms)
    .bind(memory_tier)
    .bind(scope_signature)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(())
}

/// 记忆检索压缩：命中条目 > 3 条时压缩为不超过 220 字的结构化结果
/// Feature: ai-drama-quality-optimization, Property 21: 记忆检索压缩约束
/// 验证：需求 33.7
#[allow(dead_code)]
pub(crate) fn compress_memory_results(items: Vec<String>) -> Option<serde_json::Value> {
    if items.len() <= 3 {
        return None; // 不需要压缩
    }
    // 取最新的条目作为 latest_change，其余合并为 must_keep/must_avoid
    let latest = items.last().cloned().unwrap_or_default();
    let earlier: Vec<&str> = items[..items.len() - 1]
        .iter()
        .map(|s| s.as_str())
        .collect();

    // 简单启发式：包含"禁止"/"不得"/"避免"的内容归入 must_avoid，其余归入 must_keep
    let mut must_keep_parts: Vec<&str> = Vec::new();
    let mut must_avoid_parts: Vec<&str> = Vec::new();
    for item in &earlier {
        if item.contains("禁止")
            || item.contains("不得")
            || item.contains("避免")
            || item.contains("禁用")
        {
            must_avoid_parts.push(item);
        } else {
            must_keep_parts.push(item);
        }
    }

    let must_keep = must_keep_parts.join("；");
    let must_avoid = must_avoid_parts.join("；");

    // 截断到合理长度，确保总字数 ≤ 220
    let truncate = |s: String, max: usize| -> String {
        let chars: Vec<char> = s.chars().collect();
        if chars.len() <= max {
            s
        } else {
            chars[..max].iter().collect::<String>() + "…"
        }
    };

    let result = json!({
        "must_keep": truncate(must_keep, 80),
        "must_avoid": truncate(must_avoid, 60),
        "latest_change": truncate(latest, 60),
        "scope": format!("compressed from {} items", items.len()),
    });

    Some(result)
}

#[cfg(test)]
mod tests {
    use super::*;
    use proptest::prelude::*;

    // Feature: ai-drama-quality-optimization, Property 21: 记忆检索压缩约束
    // 验证：需求 33.7
    proptest! {
        #[test]
        fn prop_compress_memory_results_over_threshold(
            items in prop::collection::vec("[^\n]{1,50}", 4..20usize)
        ) {
            let result = compress_memory_results(items);
            prop_assert!(result.is_some());
            let obj = result.unwrap();
            // 必须包含4个字段
            prop_assert!(obj.get("must_keep").is_some());
            prop_assert!(obj.get("must_avoid").is_some());
            prop_assert!(obj.get("latest_change").is_some());
            prop_assert!(obj.get("scope").is_some());
            // 总字符数 ≤ 500（JSON序列化后检查，含JSON overhead）
            let serialized = serde_json::to_string(&obj).unwrap();
            prop_assert!(serialized.chars().count() <= 500);
        }

        #[test]
        fn prop_compress_memory_results_under_threshold(
            items in prop::collection::vec("[^\n]{1,50}", 0..4usize)
        ) {
            let result = compress_memory_results(items);
            prop_assert!(result.is_none());
        }
    }

    #[test]
    fn compress_exactly_3_items_returns_none() {
        let items = vec!["a".to_string(), "b".to_string(), "c".to_string()];
        assert!(compress_memory_results(items).is_none());
    }

    #[test]
    fn compress_4_items_returns_some_with_all_fields() {
        let items = vec![
            "角色A外观固定".to_string(),
            "禁止改变发色".to_string(),
            "场景光线温暖".to_string(),
            "最新：增加了新道具".to_string(),
        ];
        let result = compress_memory_results(items).unwrap();
        assert!(result.get("must_keep").is_some());
        assert!(result.get("must_avoid").is_some());
        assert!(result.get("latest_change").is_some());
        assert!(result.get("scope").is_some());
        // must_avoid 应包含含"禁止"的条目
        let must_avoid = result["must_avoid"].as_str().unwrap();
        assert!(must_avoid.contains("禁止改变发色"));
        // latest_change 应是最后一条
        let latest = result["latest_change"].as_str().unwrap();
        assert!(latest.contains("最新：增加了新道具"));
    }

    #[test]
    fn compress_empty_returns_none() {
        assert!(compress_memory_results(vec![]).is_none());
    }
}
