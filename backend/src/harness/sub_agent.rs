use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

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

const AUTO_MEMORY_SUMMARY_LIMIT: i64 = 3;
const AUTO_MEMORY_KEEP_ROWS: i64 = 8;
const AUTO_MEMORY_MAX_CHARS: usize = 320;

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

fn agent_memory_type_for_tool(tool_name: &str) -> Option<&'static str> {
    match tool_name {
        "run_sub_agent_storySkeleton"
        | "run_sub_agent_adaptationStrategy"
        | "run_sub_agent_script"
        | "run_supervision_agent" => Some("scriptAgent"),
        "run_sub_agent_derive_assets"
        | "run_sub_agent_generate_assets"
        | "run_sub_agent_director_plan"
        | "run_sub_agent_storyboard_gen"
        | "run_sub_agent_storyboard_panel"
        | "run_sub_agent_storyboard_table"
        | "run_sub_agent_production_supervision" => Some("productionAgent"),
        _ => None,
    }
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

fn parse_focus_section_list(arguments: &Value, key: &str) -> Vec<&'static str> {
    let mut sections = arguments
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .filter_map(|value| match value.trim() {
            "storySkeleton" => Some("storySkeleton"),
            "adaptationStrategy" => Some("adaptationStrategy"),
            "script" => Some("script"),
            _ => None,
        })
        .collect::<Vec<_>>();
    sections.sort_unstable();
    sections.dedup();
    sections
}

fn parse_relative_script_offset(arguments: &Value, key: &str) -> Option<i64> {
    match arguments.get(key).and_then(Value::as_i64) {
        Some(-1) => Some(-1),
        Some(1) => Some(1),
        _ => None,
    }
}

fn script_scope_note(arguments: &Value) -> Option<String> {
    let focus_sections = parse_focus_section_list(arguments, "focusSections");
    let novel_ids = parse_positive_id_list(arguments, "novelIds");
    let relative_script_offset = parse_relative_script_offset(arguments, "relativeScriptOffset");
    if focus_sections.is_empty() && novel_ids.is_empty() && relative_script_offset.is_none() {
        return None;
    }

    let mut attrs = Vec::new();
    if !focus_sections.is_empty() {
        attrs.push(format!("focusSections=\"{}\"", focus_sections.join(",")));
    }
    if !novel_ids.is_empty() {
        attrs.push(format!(
            "novelIds=\"{}\"",
            novel_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }
    if let Some(offset) = relative_script_offset {
        attrs.push(format!("relativeScriptOffset=\"{offset}\""));
    }
    Some(format!(
        "<scope {} />\n仅限此范围；不足再最小补读。",
        attrs.join(" ")
    ))
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

fn normalize_whitespace(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn truncate_chars(text: &str, max_chars: usize) -> String {
    let char_count = text.chars().count();
    if char_count <= max_chars {
        return text.to_string();
    }
    let truncated = text
        .chars()
        .take(max_chars.saturating_sub(1))
        .collect::<String>();
    format!("{truncated}…")
}

fn summarize_result_excerpt(text: &str) -> String {
    let normalized = normalize_whitespace(text);
    if normalized.is_empty() {
        return "本轮执行完成。".to_string();
    }
    truncate_chars(&normalized, 180)
}

fn scope_summary(arguments: &Value) -> Option<String> {
    let mut parts = Vec::new();

    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    if !storyboard_ids.is_empty() {
        parts.push(format!(
            "storyboardIds={}",
            storyboard_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }

    let asset_ids = parse_positive_id_list(arguments, "assetIds");
    if !asset_ids.is_empty() {
        parts.push(format!(
            "assetIds={}",
            asset_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }

    let asset_types = parse_asset_type_list(arguments, "assetTypes");
    if !asset_types.is_empty() {
        parts.push(format!("assetTypes={}", asset_types.join(",")));
    }

    let focus_sections = parse_focus_section_list(arguments, "focusSections");
    if !focus_sections.is_empty() {
        parts.push(format!("focusSections={}", focus_sections.join(",")));
    }

    let novel_ids = parse_positive_id_list(arguments, "novelIds");
    if !novel_ids.is_empty() {
        parts.push(format!(
            "novelIds={}",
            novel_ids
                .iter()
                .map(i64::to_string)
                .collect::<Vec<_>>()
                .join(",")
        ));
    }

    if let Some(offset) = parse_relative_script_offset(arguments, "relativeScriptOffset") {
        parts.push(format!("relativeScriptOffset={offset}"));
    }

    if parts.is_empty() {
        None
    } else {
        Some(parts.join("; "))
    }
}

fn build_auto_memory_snapshot(
    tool_name: &str,
    arguments: &Value,
    result_text: &str,
    review: Option<&Value>,
) -> String {
    let mut parts = vec![format!("tool={tool_name}")];
    if let Some(scope) = scope_summary(arguments) {
        parts.push(format!("scope={scope}"));
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
        if let Some(summary) = review.get("summary").and_then(Value::as_str) {
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
        parts.push(format!("result={}", summarize_result_excerpt(result_text)));
    }

    truncate_chars(&parts.join(" | "), AUTO_MEMORY_MAX_CHARS)
}

async fn load_auto_memory_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
) -> Result<Option<String>, InvokeError> {
    let rows: Vec<String> = sqlx::query_scalar(
        r#"
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'summary'
        ORDER BY create_time_ms DESC
        LIMIT $5
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(AUTO_MEMORY_SUMMARY_LIMIT)
    .fetch_all(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    if rows.is_empty() {
        return Ok(None);
    }

    let items = rows
        .into_iter()
        .map(|entry| format!("- {}", truncate_chars(entry.trim(), AUTO_MEMORY_MAX_CHARS)))
        .collect::<Vec<_>>()
        .join("\n");
    Ok(Some(format!(
        "Recent scoped memory from the same user/project/script:\n{items}\n仅把这些内容当作已知进展与决策线索；若本轮需要落地写入，先最小核对相关工具数据。"
    )))
}

async fn persist_auto_memory_snapshot(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    content: &str,
) -> Result<(), InvokeError> {
    sqlx::query(
        r#"
        INSERT INTO app_agent_memory (
          owner_user_id, numeric_project_id, episodes_id, agent_type,
          memory_type, role, name, content, summarized, create_time_ms
        )
        VALUES ($1, $2, $3, $4, 'summary', 'assistant', 'auto_scope_memory', $5, 1, EXTRACT(EPOCH FROM NOW()) * 1000)
        "#,
    )
    .bind(user_id)
    .bind(project_numeric_id)
    .bind(episodes_id)
    .bind(agent_type)
    .bind(content)
    .execute(pool)
    .await
    .map_err(|e| InvokeError::DatabaseError(e.to_string()))?;

    sqlx::query(
        r#"
        DELETE FROM app_agent_memory
        WHERE id IN (
          SELECT id
          FROM app_agent_memory
          WHERE owner_user_id = $1
            AND numeric_project_id = $2
            AND episodes_id IS NOT DISTINCT FROM $3
            AND agent_type = $4
            AND memory_type = 'summary'
            AND name = 'auto_scope_memory'
          ORDER BY create_time_ms DESC
          OFFSET $5
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
    let memory_note = match (
        ctx.pool.as_ref(),
        ctx.project_numeric_id,
        agent_memory_type_for_tool(tool_name),
    ) {
        (Some(pool), Some(project_numeric_id), Some(agent_type)) => {
            load_auto_memory_note(
                pool,
                ctx.user_id,
                project_numeric_id,
                ctx.script_numeric_id,
                agent_type,
            )
            .await?
        }
        _ => None,
    };
    let execution_note = spec.execution_hint.unwrap_or(
        "Use the narrowest tool call that can solve the task before requesting broader context.",
    );
    let mut messages = vec![
        json!({"role":"system","content":system}),
        json!({"role":"assistant","content":context_note}),
    ];
    if let Some(memory_note) = memory_note {
        messages.push(json!({"role":"assistant","content":memory_note}));
    }
    messages
        .push(json!({"role":"assistant","content":format!("Execution hint: {execution_note}")}));
    messages.push(json!({"role":"user","content":prompt}));
    let text = chat_completion_assistant_text(cfg, client, messages)
        .await
        .map_err(InvokeError::LlmError)?;

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
        let snapshot = build_auto_memory_snapshot(tool_name, arguments, &text, review.as_ref());
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

    Ok(json!({
        "tool": tool_name,
        "agent_role": spec.role_name,
        "result": text,
        "review": review,
    }))
}

#[cfg(test)]
mod tests {
    use super::{
        build_auto_memory_snapshot, parse_review_summary, parse_tag_attributes,
        sub_agent_prompt_from_args,
    };
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
    fn sub_agent_prompt_from_args_appends_compact_scope_for_script_tools() {
        let prompt = sub_agent_prompt_from_args(
            "run_sub_agent_script",
            &json!({
                "prompt": "继续写剧本。",
                "focusSections": ["adaptationStrategy", "storySkeleton", "storySkeleton"],
                "novelIds": [12, 7, 12],
                "relativeScriptOffset": -1
            }),
        )
        .expect("prompt");

        assert!(prompt.contains("继续写剧本。"));
        assert!(prompt.contains(
            r#"<scope focusSections="adaptationStrategy,storySkeleton" novelIds="7,12" relativeScriptOffset="-1" />"#
        ));
    }

    #[test]
    fn build_auto_memory_snapshot_prefers_review_fields() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_production_supervision",
            &json!({"assetTypes": ["scene", "role"], "storyboardIds": [9, 3]}),
            "unused",
            Some(&json!({
                "target": "scriptPlan",
                "grade": "B",
                "nextAction": "check_assets",
                "summary": "导演规划可用但资产还需对齐",
                "assetIds": "7,8"
            })),
        );

        assert!(snapshot.contains("tool=run_sub_agent_production_supervision"));
        assert!(snapshot.contains("scope=storyboardIds=3,9; assetTypes=role,scene"));
        assert!(snapshot.contains("review=target=scriptPlan; grade=B; next=check_assets"));
        assert!(snapshot.contains("summary=导演规划可用但资产还需对齐"));
    }

    #[test]
    fn build_auto_memory_snapshot_truncates_plain_result() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_storyboard_table",
            &json!({"assetIds": [5, 1, 5]}),
            "  第一行结果  \n\n第二行结果  ",
            None,
        );

        assert!(snapshot.contains("tool=run_sub_agent_storyboard_table"));
        assert!(snapshot.contains("scope=assetIds=1,5"));
        assert!(snapshot.contains("result=第一行结果 第二行结果"));
        assert!(snapshot.chars().count() <= 320);
    }
}
