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
    execution_hint: Option<&'static str>,
}

fn parse_tag_attributes(line: &str, tag_name: &str) -> Option<serde_json::Map<String, Value>> {
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

fn parse_review_summary(text: &str) -> Option<Value> {
    let summary_line = text
        .lines()
        .map(str::trim)
        .find(|line| line.starts_with("<reviewSummary "))?;
    let attrs = parse_tag_attributes(summary_line, "reviewSummary")?;
    Some(Value::Object(attrs))
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
            execution_hint: Some(
                "先最小读取：优先只拿当前任务相关的章节事件、骨架片段和必要原文窗口；信息足够时不要补读整章。",
            ),
        }),
        "run_sub_agent_adaptationStrategy" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_adaptation.md",
            skill_section: None,
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<adaptationStrategy>改编策略内容</adaptationStrategy>",
            ),
            execution_hint: Some(
                "先最小读取：先读骨架和事件表字段子集，只有在世界观或细节不足时才补读原文窗口。",
            ),
        }),
        "run_sub_agent_script" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_script.md",
            skill_section: None,
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<scriptItem name=\"剧本名称\">剧本内容</scriptItem>",
            ),
            execution_hint: Some(
                "先最小读取：1) 先分别读当前集的 storySkeleton 与 adaptationStrategy；2) 再读目标章节的事件表字段子集；3) 只有在台词/动作细节不足时才读当前章节正文窗口；4) 只有在承接上一集时才读上一集尾段窗口。不要默认整章、整集或整块 planData 全量搬运。",
            ),
        }),
        "run_supervision_agent" => Some(SubAgentSpec {
            role_name: "编辑",
            skill_path: "script_agent_supervision.md",
            skill_section: None,
            format_hint: Some(
                "输出时第一行必须是单行 XML 摘要，格式如下：\n<reviewSummary target=\"storySkeleton|adaptationStrategy|script\" grade=\"A|B|C|D\" severeCount=\"0\" mediumCount=\"0\" minorCount=\"0\" nextAction=\"revise_storySkeleton|revise_adaptationStrategy|revise_script|check_novel_events|check_novel_text|check_script\" summary=\"一句话总结\" />\n随后再输出精简 Markdown 审核报告。summary 控制在 36 个汉字以内；若信息足够，不要写冗长解释。",
            ),
            execution_hint: Some(
                "审核必须基于工具实读的工作区内容，优先拉取字段子集或窗口片段，不要为了审核先全量加载全部正文。",
            ),
        }),
        "run_sub_agent_derive_assets" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("一、衍生资产分析与信息写入"),
            format_hint: None,
            execution_hint: Some(
                "先最小读取：先读剧本窗口，再按实际涉及的 assetTypes 分批读 assets；确认到具体父资产或状态后再按需补读，不要先吞整包素材。",
            ),
        }),
        "run_sub_agent_generate_assets" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("二、衍生资产图片生成"),
            format_hint: None,
            execution_hint: Some(
                "先最小读取：若派发指令已给出明确资产 ids，先只核对这批状态再直接生成；否则再用最小字段拿候选列表，只对明确候选发起生成。",
            ),
        }),
        "run_sub_agent_director_plan" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("三、导演规划"),
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<scriptPlan>内容</scriptPlan>"),
            execution_hint: Some(
                "先最小读取：先读剧本 1-48 行、<=1400 字的窗口，再先读 role/scene 资产，只有剧本明确需要时才补 tool 或具体资产 ID；若上游先要求 check_assets，核对后只回到紧凑 scriptPlan 判断缺口是否闭合，不要默认整份 assets 或后续 storyboard 上下文一起进来。",
            ),
        }),
        "run_sub_agent_storyboard_gen" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("六、分镜图生成"),
            format_hint: None,
            execution_hint: Some(
                "先最小读取：优先只用最小字段读取缺帧候选；有明确 storyboard ids 时只读这批镜头，再提取 shouldGenerateImage=true 且缺画面的真实 id 列表；如需复核依据，也只复读同批 storyboardTable 行和对应剧本窗口，不要先加载整块 storyboard / storyboardTable / script，更不要重跑已有结果的镜头。",
            ),
        }),
        "run_sub_agent_storyboard_panel" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("五、分镜面板写入"),
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<storyboardItem videoDesc='视频描述' prompt='提示词内容' track='分组' duration='视频推荐时间' associateAssetsIds='[资产ID列表]'></storyboardItem>",
            ),
            execution_hint: Some(
                "先最小读取：先拿 storyboardTable 必要行和资产字段子集，只有 storyboardTable 不足以写 videoDesc/台词依据时才补同批镜头的局部 script 窗口；不要默认把整表和整段剧本都拉满。",
            ),
        }),
        "run_sub_agent_storyboard_table" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("四、构建分镜表"),
            format_hint: Some(
                "你必须使用如下XML格式写入工作区：\n<storyboardTable>内容</storyboardTable>",
            ),
            execution_hint: Some(
                "先最小读取：剧本优先只读 1-48 行、<=1400 字窗口，资产先读 role/scene，再按需要补 tool 或精确 ids；完成分镜拆解前避免反复加载整份原文或整包素材。",
            ),
        }),
        "run_sub_agent_production_supervision" => Some(SubAgentSpec {
            role_name: "监督导演",
            skill_path: "production_agent_supervision.md",
            skill_section: None,
            format_hint: Some(
                "输出时第一行必须是单行 XML 摘要，格式如下：\n<reviewSummary target=\"scriptPlan|storyboardTable\" grade=\"A|B|C|D\" severeCount=\"0\" mediumCount=\"0\" minorCount=\"0\" nextAction=\"revise_scriptPlan|check_assets|check_storyboard|revise_storyboardTable|check_script|generate_storyboard\" summary=\"一句话总结\" assetIds=\"12,18\" assetTypes=\"role,scene\" storyboardIds=\"31,32\" />\n其中 assetIds 仅在下一步需要核对具体资产时填写，填逗号分隔的真实资产 ID；若暂时无法精确到资产 ID 但已收紧到最小资产类型范围，填写 assetTypes（如 role,scene 或 tool）；storyboardIds 仅在下一步需要核对或补齐具体镜头时填写，填逗号分隔的真实 storyboard 镜头 ID；不需要时可省略。随后再输出精简 Markdown 审核报告。summary 控制在 36 个汉字以内；若信息足够，不要写冗长解释。",
            ),
            execution_hint: Some(
                "审核必须基于工具实读的数据，优先读取 storyboardTable/script/assets 的必要字段或窗口；审核 scriptPlan 时，assets 默认先读 role/scene，再按需要补 tool 或精确 ids；若问题只涉及部分资产，下一步给出 check_assets 时优先回填真实 assetIds，做不到精确 id 也必须回填最小 assetTypes 范围；若只涉及部分缺帧或待核对镜头，下一步给出 check_storyboard、generate_storyboard 或 check_script 时都应沿用同一批真实 storyboardIds，避免无差别全量读取 storyboard 或剧本。",
            ),
        }),
        _ => None,
    }
}

fn parse_positive_id_list(arguments: &Value, key: &str) -> Vec<i64> {
    let mut ids = arguments
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_i64)
        .filter(|id| *id > 0)
        .collect::<Vec<_>>();
    ids.sort_unstable();
    ids.dedup();
    ids
}

fn parse_asset_type_list(arguments: &Value, key: &str) -> Vec<&'static str> {
    let mut types = arguments
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .filter_map(|value| match value.trim().to_ascii_lowercase().as_str() {
            "role" => Some("role"),
            "scene" => Some("scene"),
            "tool" => Some("tool"),
            _ => None,
        })
        .collect::<Vec<_>>();
    types.sort_unstable();
    types.dedup();
    types
}

fn production_scope_note(arguments: &Value) -> Option<String> {
    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    let asset_ids = parse_positive_id_list(arguments, "assetIds");
    let asset_types = parse_asset_type_list(arguments, "assetTypes");
    if storyboard_ids.is_empty() && asset_ids.is_empty() && asset_types.is_empty() {
        return None;
    }

    let mut attrs = Vec::new();
    if !storyboard_ids.is_empty() {
        attrs.push(format!(
            "storyboardIds=\"{}\"",
            storyboard_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if !asset_ids.is_empty() {
        attrs.push(format!(
            "assetIds=\"{}\"",
            asset_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if !asset_types.is_empty() {
        attrs.push(format!("assetTypes=\"{}\"", asset_types.join(",")));
    }
    Some(format!(
        "<scope {} />\n仅限此范围；不足再最小补读。",
        attrs.join(" ")
    ))
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
    let execution_note = spec.execution_hint.unwrap_or(
        "Use the narrowest tool call that can solve the task before requesting broader context.",
    );
    let text = chat_completion_assistant_text(
        cfg,
        client,
        vec![
            json!({"role":"system","content":system}),
            json!({"role":"assistant","content":context_note}),
            json!({"role":"assistant","content":format!("Execution hint: {execution_note}")}),
            json!({"role":"user","content":prompt}),
        ],
    )
    .await
    .map_err(InvokeError::LlmError)?;

    let review = match tool_name {
        "run_supervision_agent" | "run_sub_agent_production_supervision" => {
            parse_review_summary(&text)
        }
        _ => None,
    };

    Ok(json!({
        "tool": tool_name,
        "agent_role": spec.role_name,
        "result": text,
        "review": review,
    }))
}

#[cfg(test)]
mod tests {
    use super::{parse_review_summary, parse_tag_attributes, sub_agent_prompt_from_args};
    use serde_json::json;

    #[test]
    fn parse_tag_attributes_reads_xml_style_summary_line() {
        let attrs = parse_tag_attributes(
            r#"<reviewSummary target="storyboardTable" grade="C" severeCount="1" summary="需要先修复表结构" />"#,
            "reviewSummary",
        )
        .expect("attrs");
        assert_eq!(
            attrs.get("target").and_then(|v| v.as_str()),
            Some("storyboardTable")
        );
        assert_eq!(attrs.get("grade").and_then(|v| v.as_str()), Some("C"));
        assert_eq!(
            attrs.get("summary").and_then(|v| v.as_str()),
            Some("需要先修复表结构")
        );
    }

    #[test]
    fn parse_review_summary_uses_first_summary_line() {
        let review = parse_review_summary(
            r#"
<reviewSummary target="scriptPlan" grade="B" severeCount="0" mediumCount="2" minorCount="1" nextAction="check_assets" summary="导演规划可用但资产还需对齐" assetIds="7,3,7" storyboardIds="9,3,9" />

# 审核报告：导演规划
"#,
        )
        .expect("review");
        assert_eq!(review["target"].as_str(), Some("scriptPlan"));
        assert_eq!(review["nextAction"].as_str(), Some("check_assets"));
        assert_eq!(review["assetIds"].as_str(), Some("7,3,7"));
        assert_eq!(review["storyboardIds"].as_str(), Some("9,3,9"));
    }

    #[test]
    fn parse_review_summary_preserves_asset_types_scope() {
        let review = parse_review_summary(
            r#"
<reviewSummary target="scriptPlan" grade="B" severeCount="0" mediumCount="1" minorCount="0" nextAction="check_assets" summary="先核对角色场景资产" assetTypes="role,scene" />
"#,
        )
        .expect("review");
        assert_eq!(review["assetTypes"].as_str(), Some("role,scene"));
    }

    #[test]
    fn parse_review_summary_supports_script_supervision_payload() {
        let review = parse_review_summary(
            r#"
<reviewSummary target="script" grade="C" severeCount="1" mediumCount="1" minorCount="0" nextAction="revise_script" summary="人物动机衔接还需要补强" />

# 审核报告：剧本正文
"#,
        )
        .expect("review");
        assert_eq!(review["target"].as_str(), Some("script"));
        assert_eq!(review["grade"].as_str(), Some("C"));
        assert_eq!(review["nextAction"].as_str(), Some("revise_script"));
    }

    #[test]
    fn sub_agent_prompt_from_args_appends_compact_scope_for_production_tools() {
        let prompt = sub_agent_prompt_from_args(
            "run_sub_agent_storyboard_gen",
            &json!({
                "prompt": "请继续推进 storyboard。",
                "storyboardIds": [9, 3, 9, 1],
                "assetIds": [7, 0, 5, 7],
                "assetTypes": ["scene", "role", "scene"]
            }),
        )
        .expect("prompt");

        assert!(prompt.contains("请继续推进 storyboard。"));
        assert!(prompt
            .contains(r#"<scope storyboardIds="1,3,9" assetIds="5,7" assetTypes="role,scene" />"#));
    }

    #[test]
    fn sub_agent_prompt_from_args_ignores_scope_for_script_tools() {
        let prompt = sub_agent_prompt_from_args(
            "run_sub_agent_script",
            &json!({
                "prompt": "继续写剧本。",
                "storyboardIds": [1, 2, 3]
            }),
        )
        .expect("prompt");

        assert_eq!(prompt, "继续写剧本。");
    }
}
