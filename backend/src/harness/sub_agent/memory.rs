//! Auto-memory: DB rows, reading, persisting, snapshot building, and stage summary.

use serde_json::Value;
use sqlx::PgPool;
use uuid::Uuid;

use crate::harness::invoke::InvokeError;
use crate::production::{storyboard_prompt_seed, StoryboardPromptSeedRow};
use crate::settings::agent_memory::replace_named_summary_memory_with_scope;

use super::memory_limits::{
    auto_memory_fetch_limit, auto_memory_keep_rows, auto_memory_max_chars,
    auto_memory_rework_limit, stage_summary_note_max_chars, style_bible_note_max_chars,
};
use super::scope::{
    compact_auto_memory_entry_for_scope, compact_auto_memory_summary_text,
    dedupe_auto_memory_entries, parse_positive_id_list, scope_signature_from_args,
    scope_signature_json, scope_summary, select_auto_memory_entries, summarize_result_excerpt,
    truncate_chars,
};
use super::spec::{stage_label_for_tool, stage_summary_name_for_tool};

const STYLE_BIBLE_AGENT_TYPE: &str = "productionAgent";
const STYLE_BIBLE_NAME: &str = "style_bible:project";

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

#[allow(clippy::too_many_arguments)]
pub(super) async fn load_auto_memory_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    tool_name: &str,
    agent_type: &str,
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
) -> Result<Option<String>, InvokeError> {
    let current_scope = scope_signature_from_args(arguments, prompt_seed_scope);
    let current_scope_json = scope_signature_json(episodes_id, &current_scope);
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
    .bind(auto_memory_fetch_limit())
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
    // 返工模式下注入上限收紧为 1 倍（非返工为 2 倍）
    let char_budget = if is_rework {
        auto_memory_max_chars()
    } else {
        auto_memory_max_chars() * auto_memory_rework_limit()
    };
    let mut chars = 0usize;
    let items = rows
        .into_iter()
        .map(|entry| {
            format!(
                "- {}",
                truncate_chars(entry.trim(), auto_memory_max_chars())
            )
        })
        .filter(|entry| {
            let next = chars + entry.chars().count();
            if next > char_budget {
                return false;
            }
            chars = next;
            true
        })
        .collect::<Vec<_>>()
        .join("\n")
        .trim()
        .to_string();
    let context_text = collect_memory_context_text(arguments, prompt_seed_scope);
    let style_bible_note = if agent_type == STYLE_BIBLE_AGENT_TYPE {
        load_filtered_style_bible_note(pool, user_id, project_numeric_id, &context_text).await?
    } else {
        None
    };
    let stage_summary_note = load_stage_summary_note(
        pool,
        user_id,
        project_numeric_id,
        episodes_id,
        agent_type,
        tool_name,
        current_scope_json.as_ref(),
    )
    .await?;
    let mut sections = Vec::new();
    if let Some(style_bible_note) = style_bible_note {
        sections.push(format!("角色锚点：\n{style_bible_note}"));
    }
    if let Some(stage_summary_note) = stage_summary_note {
        sections.push(format!("当前阶段最近结论：\n- {stage_summary_note}"));
    }
    let rework_hint = if is_rework {
        "（返工模式：仅注入失败原因与修复目标相关记忆）\n"
    } else {
        ""
    };
    if !items.is_empty() {
        sections.push(format!(
            "同 scope 最近记忆：\n{rework_hint}{items}\n只把它们当作延续线索；真正写入前先最小核对工具数据。"
        ));
    }
    if sections.is_empty() {
        return Ok(None);
    }
    let note = sections.join("\n\n");
    let context_chars = note.chars().count();
    tracing::debug!(
        context_chars_injected = context_chars,
        rework_mode = is_rework,
        "memory injection stats"
    );
    Ok(Some(note))
}

fn collect_memory_context_text(arguments: &Value, prompt_seed_scope: Option<&str>) -> String {
    fn push_string_leaves(value: &Value, acc: &mut Vec<String>) {
        match value {
            Value::String(text) => {
                let trimmed = text.trim();
                if !trimmed.is_empty() {
                    acc.push(trimmed.to_string());
                }
            }
            Value::Array(items) => {
                for item in items {
                    push_string_leaves(item, acc);
                }
            }
            Value::Object(map) => {
                for value in map.values() {
                    push_string_leaves(value, acc);
                }
            }
            _ => {}
        }
    }

    let mut parts = Vec::new();
    push_string_leaves(arguments, &mut parts);
    if let Some(prompt_seed_scope) = prompt_seed_scope.filter(|value| !value.trim().is_empty()) {
        parts.push(prompt_seed_scope.trim().to_string());
    }
    truncate_chars(&parts.join(" | "), 800)
}

fn is_cjk_char(ch: char) -> bool {
    matches!(
        ch as u32,
        0x3400..=0x4DBF | 0x4E00..=0x9FFF | 0xF900..=0xFAFF | 0x20000..=0x2A6DF
    )
}

fn is_common_non_name(word: &str) -> bool {
    matches!(
        word,
        "我们"
            | "你们"
            | "他们"
            | "她们"
            | "自己"
            | "一个"
            | "这个"
            | "那个"
            | "现在"
            | "这里"
            | "那里"
            | "镜头"
            | "画面"
            | "情绪"
            | "角色"
            | "表情"
            | "动作"
            | "台词"
            | "场景"
            | "光影"
            | "运镜"
            | "呼吸"
            | "眼神"
            | "嘴角"
            | "指尖"
            | "声音"
            | "身体"
            | "对方"
            | "开口"
            | "视线"
            | "站在"
            | "走向"
            | "回头"
    )
}

fn extract_character_names_from_text(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();
    for ch in text.chars() {
        if is_cjk_char(ch) {
            current.push(ch);
            continue;
        }
        if !current.is_empty() {
            tokens.push(std::mem::take(&mut current));
        }
    }
    if !current.is_empty() {
        tokens.push(current);
    }

    let mut names = tokens
        .into_iter()
        .flat_map(|token| {
            let chars = token.chars().collect::<Vec<_>>();
            let mut candidates = Vec::new();
            for width in (2..=4).rev() {
                if chars.len() < width {
                    continue;
                }
                for start in 0..=chars.len() - width {
                    let word = chars[start..start + width].iter().collect::<String>();
                    if !is_common_non_name(&word) {
                        candidates.push(word);
                    }
                }
            }
            candidates
        })
        .collect::<Vec<_>>();
    names.sort();
    names.dedup();
    names
}

fn compact_style_bible_character_note(
    character: &serde_json::Map<String, Value>,
) -> Option<String> {
    let name = character.get("name")?.as_str()?.trim();
    if name.is_empty() {
        return None;
    }
    let fixed_appearance = character
        .get("fixed_appearance")
        .and_then(Value::as_str)
        .map(|value| truncate_chars(value.trim(), 40))
        .filter(|value| !value.is_empty());
    let temperament = character
        .get("default_temperament")
        .and_then(Value::as_str)
        .map(|value| truncate_chars(value.trim(), 24))
        .filter(|value| !value.is_empty());
    let emotion = character
        .get("emotion_expression")
        .and_then(Value::as_str)
        .map(|value| truncate_chars(value.trim(), 30))
        .filter(|value| !value.is_empty());
    let relationship = character
        .get("relationship_positioning")
        .and_then(Value::as_str)
        .map(|value| truncate_chars(value.trim(), 28))
        .filter(|value| !value.is_empty());
    let mut parts = Vec::new();
    if let Some(value) = fixed_appearance {
        parts.push(format!("外形={value}"));
    }
    if let Some(value) = temperament {
        parts.push(format!("气质={value}"));
    }
    if let Some(value) = emotion {
        parts.push(format!("情绪={value}"));
    }
    if let Some(value) = relationship {
        parts.push(format!("关系={value}"));
    }
    if parts.is_empty() {
        return None;
    }
    Some(format!("- {name}：{}", parts.join("；")))
}

fn build_filtered_style_bible_note(
    style_bible_content: &str,
    context_text: &str,
) -> Option<String> {
    let value = serde_json::from_str::<Value>(style_bible_content).ok()?;
    let object = value.as_object()?;
    let mentioned_names = extract_character_names_from_text(context_text);
    let mut lines = Vec::new();
    if let Some(characters) = object.get("characters").and_then(Value::as_array) {
        let mut character_lines = characters
            .iter()
            .filter_map(Value::as_object)
            .filter(|character| {
                let Some(name) = character.get("name").and_then(Value::as_str) else {
                    return false;
                };
                if mentioned_names.is_empty() {
                    return true;
                }
                mentioned_names
                    .iter()
                    .any(|mentioned| mentioned.contains(name) || name.contains(mentioned))
            })
            .filter_map(compact_style_bible_character_note)
            .collect::<Vec<_>>();
        character_lines.truncate(3);
        lines.extend(character_lines);
    }
    if let Some(baseline) = object
        .get("emotion_baseline")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        lines.push(format!("- 全局情绪基线：{}", truncate_chars(baseline, 50)));
    }
    if let Some(relationships) = object
        .get("core_relationships")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        lines.push(format!("- 核心关系：{}", truncate_chars(relationships, 50)));
    }
    if lines.is_empty() {
        return None;
    }
    Some(truncate_chars(
        &lines.join("\n"),
        style_bible_note_max_chars(),
    ))
}

async fn load_filtered_style_bible_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    context_text: &str,
) -> Result<Option<String>, InvokeError> {
    let content: Option<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND agent_type = $3
          AND memory_type = 'style_bible'
          AND name = $4
        ORDER BY create_time_ms DESC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(STYLE_BIBLE_AGENT_TYPE)
    .bind(STYLE_BIBLE_NAME)
    .fetch_optional(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
    .flatten();
    Ok(content.and_then(|value| build_filtered_style_bible_note(&value, context_text)))
}

async fn load_stage_summary_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    tool_name: &str,
    current_scope_json: Option<&Value>,
) -> Result<Option<String>, InvokeError> {
    let Some(name) = stage_summary_name_for_tool(tool_name) else {
        return Ok(None);
    };
    let scoped: Option<String> = if let Some(scope_signature) = current_scope_json {
        sqlx::query_scalar(
            r#"
            SELECT content
            FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND episodes_id IS NOT DISTINCT FROM $3
              AND agent_type = $4
              AND memory_type = 'stage_summary'
              AND name = $5
              AND scope_signature = $6
            ORDER BY create_time_ms DESC
            LIMIT 1
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(episodes_id)
        .bind(agent_type)
        .bind(name)
        .bind(scope_signature)
        .fetch_optional(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
        .flatten()
    } else {
        None
    };
    let latest = match scoped {
        Some(content) => Some(content),
        None => sqlx::query_scalar(
            r#"
            SELECT content
            FROM app_agent_memory
            WHERE owner_user_id = $1
              AND numeric_project_id = $2
              AND episodes_id IS NOT DISTINCT FROM $3
              AND agent_type = $4
              AND memory_type = 'stage_summary'
              AND name = $5
            ORDER BY create_time_ms DESC
            LIMIT 1
            "#,
        )
        .bind(user_id)
        .bind(project_numeric_id)
        .bind(episodes_id)
        .bind(agent_type)
        .bind(name)
        .fetch_optional(pool)
        .await
        .map_err(|e| InvokeError::DatabaseError(e.to_string()))?
        .flatten(),
    };
    Ok(latest.map(|content| truncate_chars(content.trim(), stage_summary_note_max_chars())))
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
    .bind(auto_memory_keep_rows())
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
    Some(truncate_chars(&parts.join(" | "), auto_memory_max_chars()))
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
    Some(truncate_chars(&parts.join(" | "), auto_memory_max_chars()))
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

#[cfg(test)]
mod tests {
    use super::{build_filtered_style_bible_note, extract_character_names_from_text};

    #[test]
    fn extract_character_names_from_text_keeps_probable_names() {
        let names =
            extract_character_names_from_text("林晚先移开视线再看向顾承泽，镜头停在她的指尖发颤。");
        assert!(names.contains(&"林晚".to_string()));
        assert!(names.contains(&"顾承泽".to_string()));
        assert!(!names.contains(&"镜头".to_string()));
    }

    #[test]
    fn build_filtered_style_bible_note_only_keeps_mentioned_characters() {
        let content = serde_json::json!({
            "characters": [
                {
                    "name": "林晚",
                    "fixed_appearance": "短发、黑色风衣、眼尾微挑",
                    "default_temperament": "冷静克制",
                    "emotion_expression": "先抿唇再开口",
                    "relationship_positioning": "对顾承泽保持防备"
                },
                {
                    "name": "顾承泽",
                    "fixed_appearance": "西装、领口整洁",
                    "default_temperament": "沉稳压场",
                    "emotion_expression": "眼神逼视"
                }
            ],
            "emotion_baseline": "压抑里带试探",
            "core_relationships": "林晚与顾承泽互相试探"
        })
        .to_string();
        let note = build_filtered_style_bible_note(&content, "林晚盯着门口，呼吸发浅")
            .expect("style bible note");
        assert!(note.contains("林晚"));
        assert!(!note.contains("顾承泽："));
        assert!(note.contains("全局情绪基线"));
    }
}
