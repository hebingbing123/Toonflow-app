//! Sub-agent orchestration: routes tool calls to LLM with skill docs, memory, and quality gates.

mod memory;
mod scope;
mod spec;

#[cfg(test)]
mod tests;

use serde_json::{json, Value};
use sqlx::PgPool;

use crate::error::ApiError;
use crate::harness::HarnessContext;
use crate::llm::chat_completion_with_usage;
use crate::metering::llm_usage::record_llm_usage;
use crate::production::{enforce_quality_gate, run_quality_gate, QualityGateStage};
use crate::prompting::skills::{read_skill_markdown, read_skill_markdown_section};

use super::invoke::InvokeError;

use memory::{
    build_auto_memory_snapshot, load_auto_memory_note, parse_review_summary,
    persist_auto_memory_snapshot, persist_stage_summary_async,
    resolve_storyboard_prompt_seed_scope,
};
use scope::{
    build_rework_context_note, parse_positive_id_list, production_scope_note, script_scope_note,
};
use spec::{agent_memory_type_for_tool, sub_agent_spec};

pub async fn invoke_sub_agent_tool(
    ctx: &HarnessContext,
    tool_name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let spec =
        sub_agent_spec(tool_name).ok_or_else(|| InvokeError::UnknownTool(tool_name.into()))?;
    let prompt = sub_agent_prompt_from_args(tool_name, arguments)?;
    let cfg = ctx.llm.as_ref().ok_or(InvokeError::LlmNotConfigured)?;
    let client = ctx
        .http_client
        .as_ref()
        .ok_or_else(|| InvokeError::LlmError("llm http client is unavailable".into()))?;
    let skill_doc = match spec.skill_section {
        Some(section) => read_skill_markdown_section(spec.skill_path, section)?,
        None => read_skill_markdown(spec.skill_path)?,
    };
    let system = match spec.format_hint {
        Some(hint) => format!("{}\n\n{}", skill_doc.content, hint),
        None => skill_doc.content,
    };
    let project_hint = ctx
        .project_numeric_id
        .map(|id| format!("project_numeric_id={id}"))
        .unwrap_or_else(|| "project_numeric_id=unset".into());
    let script_hint = ctx
        .script_numeric_id
        .map(|id| format!("script_numeric_id={id}"))
        .unwrap_or_else(|| "script_numeric_id=unset".into());
    let context_note = format!(
        "Harness context: {project_hint}, {script_hint}. Keep answer concise and actionable."
    );
    let project_mode_note = match (ctx.pool.as_ref(), ctx.project_numeric_id) {
        (Some(pool), Some(project_numeric_id)) => {
            load_script_project_mode_note(pool, project_numeric_id, tool_name).await?
        }
        _ => None,
    };
    let mut prompt_seed_scope = None;
    let memory_note = match (
        ctx.pool.as_ref(),
        ctx.project_numeric_id,
        agent_memory_type_for_tool(tool_name),
    ) {
        (Some(pool), Some(project_numeric_id), Some(agent_type)) => {
            prompt_seed_scope = resolve_storyboard_prompt_seed_scope(
                pool,
                ctx.user_id,
                project_numeric_id,
                ctx.script_numeric_id,
                arguments,
            )
            .await?;
            load_auto_memory_note(
                pool,
                ctx.user_id,
                project_numeric_id,
                ctx.script_numeric_id,
                tool_name,
                agent_type,
                arguments,
                prompt_seed_scope.as_deref(),
            )
            .await?
        }
        _ => None,
    };
    let execution_note = spec.execution_hint.unwrap_or(
        "Use the narrowest tool call that can solve the task before requesting broader context.",
    );
    let rework_context_note = build_rework_context_note(arguments);
    let rework_mode = rework_context_note.is_some();
    if tool_name == "run_sub_agent_storyboard_panel" {
        if let (Some(pool), Some(project_numeric_id), Some(script_numeric_id)) = (
            ctx.pool.as_ref(),
            ctx.project_numeric_id,
            ctx.script_numeric_id,
        ) {
            let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds")
                .into_iter()
                .filter_map(|value| i32::try_from(value).ok())
                .collect::<Vec<_>>();
            let (gate, strategy) = run_quality_gate(
                pool,
                ctx.user_id,
                project_numeric_id,
                script_numeric_id,
                QualityGateStage::StoryboardPanel,
                &storyboard_ids,
                std::slice::from_ref(&prompt),
            )
            .await
            .map_err(api_error_to_invoke_error)?;
            enforce_quality_gate(QualityGateStage::StoryboardPanel, &gate, strategy)
                .map_err(api_error_to_invoke_error)?;
        }
    }
    let mut messages = vec![
        json!({"role":"system","content":system}),
        json!({"role":"assistant","content":context_note}),
    ];
    let context_chars_injected = memory_note
        .as_deref()
        .map(|text| text.chars().count())
        .unwrap_or(0);
    if let Some(memory_note) = memory_note {
        messages.push(json!({"role":"assistant","content":memory_note}));
    }
    if let Some(project_mode_note) = project_mode_note {
        messages.push(json!({"role":"assistant","content":project_mode_note}));
    }
    if let Some(rework_context_note) = rework_context_note {
        messages.push(json!({"role":"assistant","content":rework_context_note}));
    }
    messages
        .push(json!({"role":"assistant","content":format!("Execution hint: {execution_note}")}));
    messages.push(json!({"role":"user","content":prompt}));
    let prompt_chars = messages
        .iter()
        .filter_map(|message| message.get("content"))
        .filter_map(Value::as_str)
        .map(|text| text.chars().count() as i64)
        .sum::<i64>();
    let usage_meta = json!({
        "toolName": tool_name,
        "agentType": agent_memory_type_for_tool(tool_name),
        "projectNumericId": ctx.project_numeric_id,
        "scriptNumericId": ctx.script_numeric_id,
        "contextCharsInjected": context_chars_injected,
        "reworkMode": rework_mode,
    });
    let result = match chat_completion_with_usage(cfg, client, messages).await {
        Ok(result) => result,
        Err(error) => {
            if let (Some(pool), Some(project_numeric_id)) =
                (ctx.pool.as_ref(), ctx.project_numeric_id)
            {
                record_llm_usage(
                    pool,
                    ctx.user_id,
                    Some(project_numeric_id),
                    ctx.script_numeric_id,
                    None,
                    "harness.sub_agent",
                    &cfg.model,
                    Some(resolve_llm_provider(cfg.base_url.as_str())),
                    None,
                    Some(prompt_chars),
                    false,
                    Some(&error),
                    None,
                    usage_meta.clone(),
                )
                .await;
            }
            if let (Some(pool), Some(project_numeric_id), Some(agent_type)) = (
                ctx.pool.as_ref(),
                ctx.project_numeric_id,
                agent_memory_type_for_tool(tool_name),
            ) {
                let invoke_error = InvokeError::LlmError(error.clone());
                persist_stage_summary_async(
                    pool,
                    ctx.user_id,
                    project_numeric_id,
                    ctx.script_numeric_id,
                    agent_type,
                    tool_name,
                    arguments,
                    prompt_seed_scope.as_deref(),
                    None,
                    None,
                    Some(&invoke_error),
                );
            }
            return Err(InvokeError::LlmError(error));
        }
    };
    if let (Some(pool), Some(project_numeric_id)) = (ctx.pool.as_ref(), ctx.project_numeric_id) {
        record_llm_usage(
            pool,
            ctx.user_id,
            Some(project_numeric_id),
            ctx.script_numeric_id,
            None,
            "harness.sub_agent",
            result.model.as_deref().unwrap_or(cfg.model.as_str()),
            Some(resolve_llm_provider(cfg.base_url.as_str())),
            result.usage.as_ref(),
            Some(prompt_chars),
            true,
            None,
            None,
            usage_meta,
        )
        .await;
    }
    let text = result.content;
    let review = match tool_name {
        "run_supervision_agent" | "run_sub_agent_production_supervision" => {
            parse_review_summary(&text)
        }
        _ => None,
    };
    if let (Some(pool), Some(project_numeric_id), Some(agent_type)) = (
        ctx.pool.as_ref(),
        ctx.project_numeric_id,
        agent_memory_type_for_tool(tool_name),
    ) {
        if let Some(snapshot) = build_auto_memory_snapshot(
            tool_name,
            arguments,
            &text,
            review.as_ref(),
            prompt_seed_scope.as_deref(),
        ) {
            persist_auto_memory_snapshot(
                pool,
                ctx.user_id,
                project_numeric_id,
                ctx.script_numeric_id,
                agent_type,
                &snapshot,
            )
            .await?;
        }
        persist_stage_summary_async(
            pool,
            ctx.user_id,
            project_numeric_id,
            ctx.script_numeric_id,
            agent_type,
            tool_name,
            arguments,
            prompt_seed_scope.as_deref(),
            review.as_ref(),
            Some(&text),
            None,
        );
    }
    Ok(json!({
        "tool": tool_name,
        "agent_role": spec.role_name,
        "result": text,
        "review": review,
    }))
}

fn resolve_llm_provider(base_url: &str) -> &'static str {
    if base_url.contains("anthropic") {
        "anthropic"
    } else if base_url.contains("openai") {
        "openai"
    } else {
        "custom"
    }
}

fn sub_agent_prompt_from_args(tool_name: &str, arguments: &Value) -> Result<String, InvokeError> {
    let prompt = arguments
        .get("prompt")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|v| !v.is_empty())
        .ok_or_else(|| InvokeError::InvalidArgs("prompt must be a non-empty string".into()))?;
    if prompt.chars().count() > 2_000 {
        return Err(InvokeError::InvalidArgs(
            "prompt must be <= 2000 characters".into(),
        ));
    }
    let scoped_prompt = match tool_name {
        "run_sub_agent_storySkeleton"
        | "run_sub_agent_adaptationStrategy"
        | "run_sub_agent_script"
        | "run_supervision_agent" => script_scope_note(arguments)
            .map(|note| format!("{prompt}\n\n{note}"))
            .unwrap_or_else(|| prompt.to_string()),
        "run_sub_agent_derive_assets"
        | "run_sub_agent_generate_assets"
        | "run_sub_agent_director_plan"
        | "run_sub_agent_storyboard_gen"
        | "run_sub_agent_storyboard_panel"
        | "run_sub_agent_storyboard_table"
        | "run_sub_agent_production_supervision" => production_scope_note(arguments)
            .map(|note| format!("{prompt}\n\n{note}"))
            .unwrap_or_else(|| prompt.to_string()),
        _ => prompt.to_string(),
    };
    Ok(scoped_prompt)
}

async fn load_script_project_mode_note(
    pool: &PgPool,
    project_numeric_id: i32,
    tool_name: &str,
) -> Result<Option<String>, InvokeError> {
    if !is_script_generation_tool(tool_name) {
        return Ok(None);
    }
    let raw = sqlx::query_scalar::<_, Option<String>>(
        "SELECT mode FROM app_project WHERE numeric_id = $1",
    )
    .bind(project_numeric_id)
    .fetch_optional(pool)
    .await
    .map_err(|error| InvokeError::DatabaseError(error.to_string()))?
    .flatten();
    Ok(project_mode_note_from_value(raw.as_deref()))
}

fn is_script_generation_tool(tool_name: &str) -> bool {
    matches!(
        tool_name,
        "run_sub_agent_storySkeleton"
            | "run_sub_agent_adaptationStrategy"
            | "run_sub_agent_script"
            | "run_supervision_agent"
    )
}

fn project_mode_note_from_value(raw_mode: Option<&str>) -> Option<String> {
    match raw_mode.and_then(compact_short_drama_project_mode) {
        Some(mode) if mode == "live_action.short_drama" => Some(
            "Project mode: live_action.short_drama. Favor natural spoken dialogue, grounded actor performance, realistic blocking, and plausible live-action scene detail. Avoid anime-styled exaggeration unless the prompt explicitly asks for it.".to_string(),
        ),
        Some(mode) if mode == "animated.short_drama" => Some(
            "Project mode: animated.short_drama. Favor stylized dramatic beats, animation-friendly visual action, expressive emotion, and stronger visual exaggeration. Avoid overly documentary live-action realism unless the prompt explicitly asks for it.".to_string(),
        ),
        _ => None,
    }
}

fn compact_short_drama_project_mode(value: &str) -> Option<String> {
    let normalized = value.trim().to_ascii_lowercase();
    if normalized.is_empty() {
        return None;
    }
    if normalized.contains("live_action") || normalized.contains("live-action") {
        return Some("live_action.short_drama".to_string());
    }
    if normalized.contains("animated") {
        return Some("animated.short_drama".to_string());
    }
    None
}

fn error_message(error: ApiError) -> String {
    match error {
        ApiError::Conflict(message)
        | ApiError::BadRequest(message)
        | ApiError::DatabaseError(message)
        | ApiError::NotImplemented(message)
        | ApiError::QuotaExceeded(message)
        | ApiError::Forbidden(message) => message,
        other => format!("{other:?}"),
    }
}

fn api_error_to_invoke_error(error: ApiError) -> InvokeError {
    match error {
        ApiError::DatabaseError(message) => InvokeError::DatabaseError(message),
        other => InvokeError::InvalidArgs(error_message(other)),
    }
}
