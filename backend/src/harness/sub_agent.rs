use serde_json::{json, Value};

use crate::harness::HarnessContext;
use crate::llm::chat_completion_assistant_text;
use crate::prompting::skills::{read_skill_markdown, read_skill_markdown_section};

use super::invoke::InvokeError;

struct SubAgentSpec {
    role_name: &'static str,
    skill_path: &'static str,
    skill_section: Option<&'static str>,
    format_hint: Option<&'static str>,
}

fn sub_agent_spec(tool_name: &str) -> Option<SubAgentSpec> {
    match tool_name {
        "run_sub_agent_storySkeleton" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_skeleton.md",
            skill_section: None,
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<storySkeleton>故事骨架内容</storySkeleton>",
            ),
        }),
        "run_sub_agent_adaptationStrategy" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_adaptation.md",
            skill_section: None,
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<adaptationStrategy>改编策略内容</adaptationStrategy>",
            ),
        }),
        "run_sub_agent_script" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_script.md",
            skill_section: None,
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<scriptItem name=\"剧本名称\">剧本内容</scriptItem>",
            ),
        }),
        "run_supervision_agent" => Some(SubAgentSpec {
            role_name: "编辑",
            skill_path: "script_agent_supervision.md",
            skill_section: None,
            format_hint: None,
        }),
        "run_sub_agent_derive_assets" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("一、衍生资产分析与信息写入"),
            format_hint: None,
        }),
        "run_sub_agent_generate_assets" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("二、衍生资产图片生成"),
            format_hint: None,
        }),
        "run_sub_agent_director_plan" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("三、导演规划"),
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<scriptPlan>内容</scriptPlan>"),
        }),
        "run_sub_agent_storyboard_gen" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("六、分镜图生成"),
            format_hint: None,
        }),
        "run_sub_agent_storyboard_panel" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("五、分镜面板写入"),
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<storyboardItem videoDesc='视频描述' prompt='提示词内容' track='分组' duration='视频推荐时间' associateAssetsIds='[资产ID列表]'></storyboardItem>",
            ),
        }),
        "run_sub_agent_storyboard_table" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("四、构建分镜表"),
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<storyboardTable>内容</storyboardTable>",
            ),
        }),
        _ => None,
    }
}

fn sub_agent_prompt_from_args(arguments: &Value) -> Result<String, InvokeError> {
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
    Ok(prompt.to_string())
}

pub async fn invoke_sub_agent_tool(
    ctx: &HarnessContext,
    tool_name: &str,
    arguments: &Value,
) -> Result<Value, InvokeError> {
    let spec =
        sub_agent_spec(tool_name).ok_or_else(|| InvokeError::UnknownTool(tool_name.into()))?;
    let prompt = sub_agent_prompt_from_args(arguments)?;
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
    let text = chat_completion_assistant_text(
        cfg,
        client,
        vec![
            json!({"role":"system","content":system}),
            json!({"role":"assistant","content":context_note}),
            json!({"role":"user","content":prompt}),
        ],
    )
    .await
    .map_err(InvokeError::LlmError)?;

    Ok(json!({
        "tool": tool_name,
        "agent_role": spec.role_name,
        "result": text,
    }))
}
