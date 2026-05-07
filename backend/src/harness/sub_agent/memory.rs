//! Auto-memory: DB rows, reading, persisting, snapshot building, and stage summary.

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::harness::invoke::InvokeError;
use crate::production::{storyboard_prompt_seed, StoryboardPromptSeedRow};
use crate::settings::agent_memory::replace_named_summary_memory_with_scope;

use super::scope::{
    compact_auto_memory_entry_for_scope, compact_auto_memory_summary_text,
    dedupe_auto_memory_entries, parse_positive_id_list, scope_signature_from_args,
    scope_signature_json, scope_summary, select_auto_memory_entries, summarize_result_excerpt,
    truncate_chars, AUTO_MEMORY_FETCH_LIMIT, AUTO_MEMORY_KEEP_ROWS, AUTO_MEMORY_MAX_CHARS,
    AUTO_MEMORY_REWORK_LIMIT,
};
use super::spec::{stage_label_for_tool, stage_summary_name_for_tool};

#[derive(Debug, sqlx::FromRow)]
pub(super) struct AutoMemoryRow {
    pub(super) name: String,
    pub(super) content: String,
}

#[derive(Debug, sqlx::FromRow)]
pub(super) struct ScopedStoryboardPromptSeedRow {
    pub(super) numeric_id: i32,
    pub(super) prompt: Option<String>,
    pub(super) video_desc: Option<String>,
    pub(super) duration: Option<String>,
}

pub(super) fn filter_auto_scope_memory_rows(rows: Vec<AutoMemoryRow>) -> Vec<String> {
    rows.into_iter()
        .filter(|row| row.name == "auto_scope_memory")
        .map(|row| row.content.trim().to_string())
        .filter(|content| !content.is_empty())
        .collect()
}

pub(super) fn format_storyboard_prompt_seed_scope(
    storyboard_prompt_seeds: &[(i32, String)],
) -> Option<String> {
    match storyboard_prompt_seeds {
        [] => None,
        [(_, prompt_seed)] => Some(format!("promptSeed={prompt_seed}")),
        seeds => Some(format!(
            "storyboardPromptSeeds={}",
            seeds
                .iter()
                .map(|(id, seed)| format!("{id}:{seed}"))
                .collect::<Vec<_>>()
                .join(",")
        )),
    }
}

pub(super) async fn resolve_storyboard_prompt_seed_scope(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    arguments: &Value,
) -> Result<Option<String>, InvokeError> {
    let Some(script_numeric_id) = episodes_id.filter(|id| *id > 0) else {
        return Ok(None);
    };
    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    if storyboard_ids.is_empty() {
        return Ok(None);
    }
    let storyboard_ids = storyboard_ids
        .into_iter()
        .filter_map(|id| i32::try_from(id).ok())
        .collect::<Vec<_>>();
    if storyboard_ids.is_empty() {
        return Ok(None);
    }
    let rows = sqlx::query_as::<_, ScopedStoryboardPromptSeedRow>(
        r#"
        SELECT sb.numeric_id, sb.prompt, sb.video_desc, sb.duration
        FROM app_storyboard sb
        INNER JOIN app_script sc ON sc.id = sb.script_id
        INNER JOIN app_project p ON p.id = sc.project_id
        WHERE p.numeric_id = $2
          AND EXISTS (
            SELECT 1
            FROM app_workspace_member wm
            WHERE wm.workspace_id = p.workspace_id
              AND wm.user_id = $1
          )
          AND sc.numeric_id = $3
          AND sb.numeric_id = ANY($4)
        ORDER BY sb.numeric_id ASC
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(script_numeric_id)
    .bind(&storyboard_ids)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let seeds = rows
        .into_iter()
        .filter_map(|row| {
            let prompt_seed = storyboard_prompt_seed(&StoryboardPromptSeedRow {
                prompt: row.prompt,
                video_desc: row.video_desc,
                duration: row.duration,
            })?;
            Some((row.numeric_id, prompt_seed))
        })
        .collect::<Vec<_>>();
    Ok(format_storyboard_prompt_seed_scope(&seeds))
}

pub(super) async fn load_auto_memory_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
) -> Result<Option<String>, InvokeError> {
    let current_scope = scope_signature_from_args(arguments, prompt_seed_scope);
    // 返工模式：arguments 中有 reworkReason 时收紧注入上限
    let is_rework = arguments
        .get("reworkReason")
        .or_else(|| arguments.get("reason"))
        .and_then(Value::as_str)
        .is_some_and(|v| !v.is_empty());
    let rows = sqlx::query_as::<_, AutoMemoryRow>(
        r#"
        SELECT name, content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'summary'
          AND name = 'auto_scope_memory'
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(AUTO_MEMORY_FETCH_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    let rows = select_auto_memory_entries(
        arguments,
        prompt_seed_scope,
        filter_auto_scope_memory_rows(rows),
    )
    .into_iter()
    .map(|entry| compact_auto_memory_entry_for_scope(&entry, &current_scope))
    .collect::<Vec<_>>();
    let rows = dedupe_auto_memory_entries(rows);
    if rows.is_empty() {
        return Ok(None);
    }
    // 返工模式下注入上限收紧为 1 倍（非返工为 2 倍）
    let char_budget = if is_rework {
        AUTO_MEMORY_MAX_CHARS
    } else {
        AUTO_MEMORY_MAX_CHARS * AUTO_MEMORY_REWORK_LIMIT
    };
    let mut chars = 0usize;
    let items = rows
        .into_iter()
        .map(|entry| format!("- {}", truncate_chars(entry.trim(), AUTO_MEMORY_MAX_CHARS)))
        .filter(|entry| {
            let next = chars + entry.chars().count();
            if next > char_budget {
                return false;
            }
            chars = next;
            true
        })
        .collect::<Vec<_>>()
        .join("\n");
    let context_chars = items.chars().count();
    let rework_hint = if is_rework {
        "（返工模式：仅注入失败原因与修复目标相关记忆）\n"
    } else {
        ""
    };
    tracing::debug!(
        context_chars_injected = context_chars,
        rework_mode = is_rework,
        "memory injection stats"
    );
    Ok(Some(format!(
        "同 scope 最近记忆：\n{rework_hint}{items}\n只把它们当作延续线索；真正写入前先最小核对工具数据。"
    )))
}

async fn should_persist_auto_memory_snapshot(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    content: &str,
) -> Result<bool, InvokeError> {
    let latest: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content FROM app_agent_memory
        WHERE owner_user_id = $1 AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3 AND agent_type = $4
          AND memory_type = 'summary' AND name = 'auto_scope_memory'
        ORDER BY create_time_ms DESC LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(episodes_id)
    .bind(agent_type)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;
    Ok(latest.as_deref() != Some(content))
}

pub(super) async fn persist_auto_memory_snapshot(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    content: &str,
) -> Result<(), InvokeError> {
    if !should_persist_auto_memory_snapshot(
        pool,
        user_id,
        project_numeric_id,
        episodes_id,
        agent_type,
        content,
    )
    .await?
    {
        return Ok(());
    }
    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, 'summary', 'assistant', 'auto_scope_memory', $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id).bind(project_numeric_id).bind(episodes_id).bind(agent_type).bind(content)
    .execute(pool).await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory WHERE id IN (
          SELECT id FROM app_agent_memory
          WHERE owner_user_id = $1 AND numeric_project_id = $2
            AND episodes_id IS NOT DISTINCT FROM $3 AND agent_type = $4
            AND memory_type = 'summary' AND name = 'auto_scope_memory'
          ORDER BY create_time_ms DESC OFFSET $5
        )
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(AUTO_MEMORY_KEEP_ROWS)
    .execute(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;
    Ok(())
}

pub(super) fn build_auto_memory_snapshot(
    tool_name: &str,
    arguments: &Value,
    result_text: &str,
    review: Option<&Value>,
    prompt_seed_scope: Option<&str>,
) -> Option<String> {
    let mut parts = vec![format!("tool={tool_name}")];
    if let Some(scope) = scope_summary(arguments) {
        parts.push(format!("scope={scope}"));
    }
    if let Some(prompt_seed_scope) = prompt_seed_scope.filter(|value| !value.is_empty()) {
        parts.push(prompt_seed_scope.to_string());
    }
    if let Some(review) = review {
        let mut review_parts = Vec::new();
        if let Some(target) = review.get("target").and_then(Value::as_str) {
            review_parts.push(format!("target={target}"));
        }
        if let Some(grade) = review.get("grade").and_then(Value::as_str) {
            review_parts.push(format!("grade={grade}"));
        }
        if let Some(next_action) = review.get("nextAction").and_then(Value::as_str) {
            review_parts.push(format!("next={next_action}"));
        }
        if let Some(summary) = review
            .get("summary")
            .and_then(Value::as_str)
            .and_then(compact_auto_memory_summary_text)
        {
            review_parts.push(format!("summary={summary}"));
        }
        if let Some(asset_types) = review.get("assetTypes").and_then(Value::as_str) {
            review_parts.push(format!("assetTypes={asset_types}"));
        }
        if let Some(asset_ids) = review.get("assetIds").and_then(Value::as_str) {
            review_parts.push(format!("assetIds={asset_ids}"));
        }
        if let Some(storyboard_ids) = review.get("storyboardIds").and_then(Value::as_str) {
            review_parts.push(format!("storyboardIds={storyboard_ids}"));
        }
        if !review_parts.is_empty() {
            parts.push(format!("review={}", review_parts.join("; ")));
        }
    } else {
        let summary = summarize_result_excerpt(result_text)?;
        parts.push(format!("result={summary}"));
    }
    Some(truncate_chars(&parts.join(" | "), AUTO_MEMORY_MAX_CHARS))
}

fn summarize_stage_failure(error: &InvokeError) -> String {
    truncate_chars(&super::scope::normalize_whitespace(&error.message()), 120)
}

fn summarize_stage_key_decision(review: Option<&Value>, text: Option<&str>) -> Option<String> {
    if let Some(review) = review {
        let mut parts = Vec::new();
        if let Some(target) = review.get("target").and_then(Value::as_str) {
            parts.push(format!("target={target}"));
        }
        if let Some(grade) = review.get("grade").and_then(Value::as_str) {
            parts.push(format!("grade={grade}"));
        }
        if let Some(next_action) = review
            .get("nextAction")
            .or_else(|| review.get("next_action"))
            .and_then(Value::as_str)
        {
            parts.push(format!("next={next_action}"));
        }
        if let Some(summary) = review.get("summary").and_then(Value::as_str) {
            let compact = super::scope::compact_auto_memory_result_fragment(summary);
            if !compact.is_empty() {
                parts.push(compact);
            }
        }
        let merged = super::scope::normalize_whitespace(&parts.join("; "));
        if !merged.is_empty() {
            return Some(truncate_chars(&merged, 180));
        }
    }
    text.and_then(summarize_result_excerpt)
}

pub(super) fn build_stage_summary_content(
    tool_name: &str,
    review: Option<&Value>,
    result_text: Option<&str>,
    error: Option<&InvokeError>,
) -> Option<String> {
    let stage = stage_label_for_tool(tool_name)?;
    let status = if error.is_some() {
        "failed"
    } else {
        "completed"
    };
    let mut parts = vec![format!("stage={stage}"), format!("status={status}")];
    if let Some(key) = summarize_stage_key_decision(review, result_text) {
        parts.push(format!("key={key}"));
    }
    if let Some(error) = error {
        parts.push(format!("reason={}", summarize_stage_failure(error)));
    }
    Some(truncate_chars(&parts.join(" | "), 320))
}

#[allow(clippy::too_many_arguments)]
pub(super) fn persist_stage_summary_async(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &'static str,
    tool_name: &str,
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
    review: Option<&Value>,
    result_text: Option<&str>,
    error: Option<&InvokeError>,
) {
    let Some(name) = stage_summary_name_for_tool(tool_name) else {
        return;
    };
    let Some(content) = build_stage_summary_content(tool_name, review, result_text, error) else {
        return;
    };
    let scope = scope_signature_json(
        episodes_id,
        &scope_signature_from_args(arguments, prompt_seed_scope),
    );
    let Some(scope_signature) = scope else {
        return;
    };
    let pool = pool.clone();
    let tool_name = tool_name.to_string();
    let scope_signature = scope_signature.clone();
    tokio::spawn(async move {
        if let Err(error) = replace_named_summary_memory_with_scope(
            &pool,
            user_id,
            project_numeric_id,
            episodes_id,
            agent_type,
            "assistant",
            name,
            &content,
            "stage_summary",
            Some(&scope_signature),
            None,
        )
        .await
        {
            tracing::warn!(
                tool = tool_name.as_str(),
                project_id = project_numeric_id,
                agent_type,
                error = ?error,
                "stage summary auto-write failed"
            );
        }
    });
}

pub(super) fn parse_tag_attributes(
    line: &str,
    tag_name: &str,
) -> Option<serde_json::Map<String, Value>> {
    let trimmed = line.trim();
    if !trimmed.starts_with('<') || !trimmed.ends_with("/>") {
        return None;
    }
    let mut inner = trimmed
        .strip_prefix('<')?
        .strip_suffix("/>")?
        .trim()
        .to_string();
    if !inner.starts_with(tag_name) {
        return None;
    }
    inner = inner[tag_name.len()..].trim().to_string();
    if inner.is_empty() {
        return Some(serde_json::Map::new());
    }
    let mut attrs = serde_json::Map::new();
    let bytes = inner.as_bytes();
    let mut idx = 0;
    while idx < bytes.len() {
        while idx < bytes.len() && bytes[idx].is_ascii_whitespace() {
            idx += 1;
        }
        if idx >= bytes.len() {
            break;
        }
        let key_start = idx;
        while idx < bytes.len() && !bytes[idx].is_ascii_whitespace() && bytes[idx] != b'=' {
            idx += 1;
        }
        if key_start == idx {
            return None;
        }
        let key = inner[key_start..idx].trim();
        while idx < bytes.len() && bytes[idx].is_ascii_whitespace() {
            idx += 1;
        }
        if idx >= bytes.len() || bytes[idx] != b'=' {
            return None;
        }
        idx += 1;
        while idx < bytes.len() && bytes[idx].is_ascii_whitespace() {
            idx += 1;
        }
        if idx >= bytes.len() || bytes[idx] != b'"' {
            return None;
        }
        idx += 1;
        let value_start = idx;
        while idx < bytes.len() && bytes[idx] != b'"' {
            idx += 1;
        }
        if idx >= bytes.len() {
            return None;
        }
        let value = &inner[value_start..idx];
        idx += 1;
        attrs.insert(key.to_string(), Value::String(value.to_string()));
    }
    Some(attrs)
}

pub(super) fn parse_review_summary(text: &str) -> Option<Value> {
    let summary_line = text
        .lines()
        .map(str::trim)
        .find(|line| line.starts_with("<reviewSummary "))?;
    let attrs = parse_tag_attributes(summary_line, "reviewSummary")?;
    Some(Value::Object(attrs))
}
