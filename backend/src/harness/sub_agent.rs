use serde_json::{json, Value};
use sqlx::PgPool;
use uuid::Uuid;

use crate::harness::HarnessContext;
use crate::llm::chat_completion_assistant_text;
use crate::production::{storyboard_prompt_seed, StoryboardPromptSeedRow};
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
const AUTO_MEMORY_FALLBACK_LIMIT: usize = 1;
const AUTO_MEMORY_KEEP_ROWS: i64 = 8;
const AUTO_MEMORY_MAX_CHARS: usize = 320;
const AUTO_MEMORY_FETCH_LIMIT: i64 = AUTO_MEMORY_KEEP_ROWS;

#[derive(Debug, Clone, Default, PartialEq, Eq)]
struct ScopeSignature {
    storyboard_ids: Vec<i64>,
    storyboard_prompt_seeds: Vec<(i64, String)>,
    asset_ids: Vec<i64>,
    asset_types: Vec<&'static str>,
    focus_sections: Vec<&'static str>,
    novel_ids: Vec<i64>,
    relative_script_offset: Option<i64>,
}

#[derive(Debug, sqlx::FromRow)]
struct ScopedStoryboardPromptSeedRow {
    numeric_id: i32,
    prompt: Option<String>,
    video_desc: Option<String>,
    duration: Option<String>,
}

#[derive(Debug, sqlx::FromRow)]
struct AutoMemoryRow {
    name: String,
    content: String,
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

fn parse_storyboard_prompt_seed_scope(scope: Option<&str>) -> Vec<(i64, String)> {
    let Some(scope) = scope.map(str::trim).filter(|value| !value.is_empty()) else {
        return Vec::new();
    };
    if let Some(prompt_seed) = scope.strip_prefix("promptSeed=") {
        let prompt_seed = prompt_seed.trim();
        return (!prompt_seed.is_empty())
            .then(|| vec![(0_i64, prompt_seed.to_string())])
            .unwrap_or_default();
    }

    let Some(mapped) = scope.strip_prefix("storyboardPromptSeeds=") else {
        return Vec::new();
    };
    let mut seeds = mapped
        .split(',')
        .filter_map(|entry| {
            let (storyboard_id, prompt_seed) = entry.trim().split_once(':')?;
            let storyboard_id = storyboard_id.trim().parse::<i64>().ok()?;
            let prompt_seed = prompt_seed.trim();
            (storyboard_id > 0 && !prompt_seed.is_empty())
                .then(|| (storyboard_id, prompt_seed.to_string()))
        })
        .collect::<Vec<_>>();
    seeds.sort_by(|left, right| left.0.cmp(&right.0).then(left.1.cmp(&right.1)));
    seeds.dedup();
    seeds
}

fn scope_signature_from_args(arguments: &Value, prompt_seed_scope: Option<&str>) -> ScopeSignature {
    let storyboard_ids = parse_positive_id_list(arguments, "storyboardIds");
    let mut storyboard_prompt_seeds = parse_storyboard_prompt_seed_scope(prompt_seed_scope);
    if storyboard_ids.len() == 1
        && storyboard_prompt_seeds.len() == 1
        && storyboard_prompt_seeds[0].0 == 0
    {
        storyboard_prompt_seeds[0].0 = storyboard_ids[0];
    }
    ScopeSignature {
        storyboard_ids,
        storyboard_prompt_seeds,
        asset_ids: parse_positive_id_list(arguments, "assetIds"),
        asset_types: parse_asset_type_list(arguments, "assetTypes"),
        focus_sections: parse_focus_section_list(arguments, "focusSections"),
        novel_ids: parse_positive_id_list(arguments, "novelIds"),
        relative_script_offset: parse_relative_script_offset(arguments, "relativeScriptOffset"),
    }
}

fn parse_scope_list(segment: Option<&str>) -> Vec<i64> {
    let mut values = segment
        .unwrap_or_default()
        .split(',')
        .filter_map(|value| value.trim().parse::<i64>().ok())
        .filter(|value| *value > 0)
        .collect::<Vec<_>>();
    values.sort_unstable();
    values.dedup();
    values
}

fn parse_scope_enum_list<T>(segment: Option<&str>, normalize: impl Fn(&str) -> Option<T>) -> Vec<T>
where
    T: Ord,
{
    let mut values = segment
        .unwrap_or_default()
        .split(',')
        .filter_map(|value| normalize(value.trim()))
        .collect::<Vec<_>>();
    values.sort_unstable();
    values.dedup();
    values
}

fn parse_scope_signature(content: &str) -> ScopeSignature {
    let mut signature = ScopeSignature::default();
    for segment in content.split(" | ") {
        if let Some(scope_segment) = segment.strip_prefix("scope=") {
            for entry in scope_segment.split("; ") {
                let Some((key, value)) = entry.split_once('=') else {
                    continue;
                };
                match key {
                    "storyboardIds" => signature.storyboard_ids = parse_scope_list(Some(value)),
                    "assetIds" => signature.asset_ids = parse_scope_list(Some(value)),
                    "assetTypes" => {
                        signature.asset_types = parse_scope_enum_list(Some(value), |raw| match raw
                            .to_ascii_lowercase()
                            .as_str()
                        {
                            "role" => Some("role"),
                            "scene" => Some("scene"),
                            "tool" => Some("tool"),
                            _ => None,
                        })
                    }
                    "focusSections" => {
                        signature.focus_sections =
                            parse_scope_enum_list(Some(value), |raw| match raw {
                                "storySkeleton" => Some("storySkeleton"),
                                "adaptationStrategy" => Some("adaptationStrategy"),
                                "script" => Some("script"),
                                _ => None,
                            })
                    }
                    "novelIds" => signature.novel_ids = parse_scope_list(Some(value)),
                    "relativeScriptOffset" => {
                        signature.relative_script_offset =
                            value.parse::<i64>().ok().filter(|v| *v != 0)
                    }
                    _ => {}
                }
            }
            continue;
        }
        if let Some(prompt_seed_segment) = segment.strip_prefix("promptSeed=") {
            let prompt_seed = prompt_seed_segment.trim();
            if let Some(storyboard_id) = signature.storyboard_ids.first().copied() {
                if !prompt_seed.is_empty() {
                    signature
                        .storyboard_prompt_seeds
                        .push((storyboard_id, prompt_seed.to_string()));
                }
            }
            continue;
        }
        if segment.starts_with("storyboardPromptSeeds=") {
            signature.storyboard_prompt_seeds = parse_storyboard_prompt_seed_scope(Some(segment));
        }
    }
    signature
}

fn has_scope(signature: &ScopeSignature) -> bool {
    !signature.storyboard_ids.is_empty()
        || !signature.storyboard_prompt_seeds.is_empty()
        || !signature.asset_ids.is_empty()
        || !signature.asset_types.is_empty()
        || !signature.focus_sections.is_empty()
        || !signature.novel_ids.is_empty()
        || signature.relative_script_offset.is_some()
}

fn overlap_count<T: Eq>(current: &[T], candidate: &[T]) -> usize {
    current
        .iter()
        .filter(|value| candidate.iter().any(|other| other == *value))
        .count()
}

fn prompt_seed_overlap_score(current: &ScopeSignature, candidate: &ScopeSignature) -> usize {
    current
        .storyboard_prompt_seeds
        .iter()
        .filter(|(storyboard_id, prompt_seed)| {
            candidate.storyboard_prompt_seeds.iter().any(
                |(candidate_storyboard_id, candidate_prompt_seed)| {
                    candidate_storyboard_id == storyboard_id && candidate_prompt_seed == prompt_seed
                },
            )
        })
        .count()
}

fn scope_has_matching_storyboard_prompt_seed(
    scope: &ScopeSignature,
    storyboard_id: i64,
    prompt_seed: &str,
) -> bool {
    scope
        .storyboard_prompt_seeds
        .iter()
        .any(|(candidate_storyboard_id, candidate_prompt_seed)| {
            *candidate_storyboard_id == storyboard_id && candidate_prompt_seed == prompt_seed
        })
}

fn scope_has_conflicting_storyboard_prompt_seed(
    current: &ScopeSignature,
    candidate: &ScopeSignature,
) -> bool {
    candidate
        .storyboard_prompt_seeds
        .iter()
        .any(|(storyboard_id, candidate_prompt_seed)| {
            current.storyboard_prompt_seeds.iter().any(
                |(current_storyboard_id, current_prompt_seed)| {
                    current_storyboard_id == storyboard_id
                        && current_prompt_seed != candidate_prompt_seed
                },
            )
        })
}

fn scope_overlap_score(current: &ScopeSignature, candidate: &ScopeSignature) -> usize {
    let mut score = 0;
    score += prompt_seed_overlap_score(current, candidate) * 16;
    score += overlap_count(&current.storyboard_ids, &candidate.storyboard_ids) * 8;
    score += overlap_count(&current.asset_ids, &candidate.asset_ids) * 5;
    score += overlap_count(&current.asset_types, &candidate.asset_types) * 3;
    score += overlap_count(&current.focus_sections, &candidate.focus_sections) * 3;
    score += overlap_count(&current.novel_ids, &candidate.novel_ids) * 2;
    if current.relative_script_offset.is_some()
        && current.relative_script_offset == candidate.relative_script_offset
    {
        score += 1;
    }
    score
}

fn select_auto_memory_entries(
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
    rows: Vec<String>,
) -> Vec<String> {
    if rows.is_empty() {
        return rows;
    }

    let current_scope = scope_signature_from_args(arguments, prompt_seed_scope);
    if !has_scope(&current_scope) {
        return rows
            .into_iter()
            .take(AUTO_MEMORY_FALLBACK_LIMIT)
            .collect::<Vec<_>>();
    }

    let mut scored = rows
        .into_iter()
        .enumerate()
        .map(|(index, row)| {
            let candidate_scope = parse_scope_signature(&row);
            (
                scope_overlap_score(&current_scope, &candidate_scope),
                index,
                candidate_scope,
                row,
            )
        })
        .collect::<Vec<_>>();

    let matched_count = scored.iter().filter(|(score, _, _, _)| *score > 0).count();
    if matched_count == 0 {
        return scored
            .into_iter()
            .map(|(_, _, _, row)| row)
            .take(AUTO_MEMORY_FALLBACK_LIMIT)
            .collect::<Vec<_>>();
    }

    let has_matching_prompt_seed_storyboards = current_scope
        .storyboard_prompt_seeds
        .iter()
        .filter(|(storyboard_id, prompt_seed)| {
            scored.iter().any(|(_, _, candidate_scope, _)| {
                scope_has_matching_storyboard_prompt_seed(
                    candidate_scope,
                    *storyboard_id,
                    prompt_seed,
                )
            })
        })
        .map(|(storyboard_id, _)| *storyboard_id)
        .collect::<Vec<_>>();

    scored.sort_by(|left, right| right.0.cmp(&left.0).then(left.1.cmp(&right.1)));
    scored
        .into_iter()
        .filter(|(score, _, candidate_scope, _)| {
            if *score <= 0 {
                return false;
            }
            if has_matching_prompt_seed_storyboards.is_empty() {
                return true;
            }
            if !scope_has_conflicting_storyboard_prompt_seed(&current_scope, candidate_scope) {
                return true;
            }
            !candidate_scope
                .storyboard_prompt_seeds
                .iter()
                .any(|(storyboard_id, _)| {
                    has_matching_prompt_seed_storyboards.contains(storyboard_id)
                })
        })
        .take(AUTO_MEMORY_SUMMARY_LIMIT as usize)
        .map(|(_, _, _, row)| row)
        .collect::<Vec<_>>()
}

fn compact_auto_memory_entry_for_scope(entry: &str, current_scope: &ScopeSignature) -> String {
    if !has_scope(current_scope) {
        return entry.trim().to_string();
    }

    let candidate_scope = parse_scope_signature(entry);
    let scope_matches_exactly = candidate_scope.storyboard_ids == current_scope.storyboard_ids
        && candidate_scope.storyboard_prompt_seeds == current_scope.storyboard_prompt_seeds
        && candidate_scope.asset_ids == current_scope.asset_ids
        && candidate_scope.asset_types == current_scope.asset_types
        && candidate_scope.focus_sections == current_scope.focus_sections
        && candidate_scope.novel_ids == current_scope.novel_ids
        && candidate_scope.relative_script_offset == current_scope.relative_script_offset;
    if !scope_matches_exactly {
        return entry.trim().to_string();
    }

    let compacted = entry
        .split(" | ")
        .map(str::trim)
        .filter(|segment| {
            !segment.starts_with("scope=")
                && !segment.starts_with("promptSeed=")
                && !segment.starts_with("storyboardPromptSeeds=")
        })
        .collect::<Vec<_>>()
        .join(" | ");
    compact_exact_scope_auto_memory_entry(&compacted)
}

fn dedupe_auto_memory_entries(entries: Vec<String>) -> Vec<String> {
    let mut seen = std::collections::HashSet::new();
    let mut deduped = Vec::with_capacity(entries.len());
    for entry in entries {
        let normalized = entry.trim();
        if normalized.is_empty() || !seen.insert(normalized.to_string()) {
            continue;
        }
        deduped.push(normalized.to_string());
    }
    deduped
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

fn summarize_result_excerpt(text: &str) -> Option<String> {
    let normalized = normalize_whitespace(text);
    if normalized.is_empty() {
        return None;
    }

    let compacted = normalized
        .split(['。', '！', '？', '；'])
        .map(compact_auto_memory_result_fragment)
        .filter(|fragment| !fragment.is_empty())
        .collect::<Vec<_>>()
        .join("，");
    let compacted = normalize_whitespace(compacted.trim());
    (!compacted.is_empty()).then(|| truncate_chars(&compacted, 180))
}

fn compact_auto_memory_result_fragment(fragment: &str) -> String {
    let mut compacted = normalize_whitespace(
        fragment.trim_matches(|ch: char| ch.is_whitespace() || "，,。；;：:!！?？".contains(ch)),
    );
    if compacted.is_empty() {
        return compacted;
    }

    for prefix in [
        "本轮执行完成",
        "本轮已完成",
        "执行完成",
        "生成完成",
        "读取完成",
        "写入完成",
        "同步完成",
        "更新完成",
        "检查完成",
        "核对完成",
        "已完成",
        "已生成",
        "已读取 flow",
        "已读取 Flow",
        "已读取",
        "已写入工作区",
        "已写入",
        "已同步",
        "已更新",
        "已检查",
        "已核对",
    ] {
        if let Some(stripped) = compacted.strip_prefix(prefix) {
            compacted =
                normalize_whitespace(stripped.trim_matches(|ch: char| {
                    ch.is_whitespace() || "，,。；;：:!！?？".contains(ch)
                }));
            break;
        }
    }

    compact_auto_memory_result_clause_group(&compacted)
}

fn is_low_signal_auto_memory_result_fragment(fragment: &str) -> bool {
    if fragment.is_empty() {
        return true;
    }

    let normalized = fragment
        .chars()
        .filter(|ch| !ch.is_whitespace())
        .collect::<String>()
        .to_ascii_lowercase();

    matches!(
        normalized.as_str(),
        "完成"
            | "完成了"
            | "执行完成"
            | "本轮执行完成"
            | "已完成"
            | "已生成"
            | "已读取"
            | "已读取flow"
            | "已写入"
            | "已写入工作区"
            | "已同步"
            | "已更新"
            | "已检查"
            | "已核对"
            | "结果"
            | "内容"
            | "工作区"
            | "flow"
            | "分镜"
            | "分镜图"
            | "分镜表"
            | "剧本"
            | "脚本"
            | "提示词"
            | "素材"
            | "资产"
            | "导演规划"
            | "storyboard"
            | "storyboardtable"
            | "script"
            | "scriptplan"
    )
}

fn compact_auto_memory_result_clause_group(fragment: &str) -> String {
    let clauses =
        fragment
            .split(['，', ','])
            .map(|clause| {
                normalize_whitespace(clause.trim_matches(|ch: char| {
                    ch.is_whitespace() || "，,。；;：:!！?？".contains(ch)
                }))
            })
            .filter(|clause| !clause.is_empty())
            .filter(|clause| !is_low_signal_auto_memory_result_fragment(clause))
            .collect::<Vec<_>>();
    if clauses.is_empty() {
        return String::new();
    }
    clauses.join("，")
}

fn compact_exact_scope_auto_memory_entry(entry: &str) -> String {
    let mut tool_alias = None;
    let mut summary = None;
    let mut review = None;
    let mut fallback_segments = Vec::new();

    for segment in entry
        .split(" | ")
        .map(str::trim)
        .filter(|segment| !segment.is_empty())
    {
        if let Some(value) = segment.strip_prefix("tool=") {
            tool_alias = Some(compact_auto_memory_tool_alias(value));
            continue;
        }
        if let Some(value) = segment.strip_prefix("summary=") {
            summary = compact_auto_memory_summary_text(value);
            continue;
        }
        if let Some(value) = segment.strip_prefix("result=") {
            summary = compact_auto_memory_summary_text(value);
            continue;
        }
        if let Some(value) = segment.strip_prefix("review=") {
            review = compact_auto_memory_review_text(value);
            continue;
        }
        fallback_segments.push(segment.to_string());
    }

    let headline = summary.or(review);
    match (tool_alias, headline) {
        (Some(tool_alias), Some(headline)) => format!("{tool_alias}: {headline}"),
        (None, Some(headline)) => headline,
        (Some(tool_alias), None) if fallback_segments.is_empty() => tool_alias.to_string(),
        _ => entry.trim().to_string(),
    }
}

fn compact_auto_memory_tool_alias(tool_name: &str) -> &str {
    match tool_name {
        "run_sub_agent_storyboard_panel" => "panel",
        "run_sub_agent_storyboard_gen" => "storyboard",
        "run_sub_agent_production_supervision" => "supervision",
        "run_sub_agent_director_plan" => "director",
        "run_sub_agent_storyboard_table" => "storyboard-table",
        "run_sub_agent_generate_assets" => "asset-image",
        "run_sub_agent_derive_assets" => "assets",
        "run_sub_agent_storySkeleton" => "story-skeleton",
        "run_sub_agent_adaptationStrategy" => "adaptation",
        "run_sub_agent_script" => "script",
        "run_supervision_agent" => "supervision",
        _ => tool_name,
    }
}

fn compact_auto_memory_review_text(review: &str) -> Option<String> {
    let summary = review
        .split(';')
        .map(str::trim)
        .find_map(|part| part.strip_prefix("summary="))
        .and_then(compact_auto_memory_summary_text);
    if summary.is_some() {
        return summary;
    }

    let target = review
        .split(';')
        .map(str::trim)
        .find_map(|part| part.strip_prefix("target="))
        .map(str::trim)
        .filter(|value| !value.is_empty());
    let next = review
        .split(';')
        .map(str::trim)
        .find_map(|part| part.strip_prefix("next="))
        .map(str::trim)
        .filter(|value| !value.is_empty());

    match (target, next) {
        (Some(target), Some(next)) => Some(format!("{target} {next}")),
        (Some(target), None) => Some(target.to_string()),
        (None, Some(next)) => Some(next.to_string()),
        (None, None) => None,
    }
}

fn compact_auto_memory_summary_text(text: &str) -> Option<String> {
    let compacted = text
        .split('，')
        .map(strip_auto_memory_scaffolding)
        .filter(|fragment| !fragment.is_empty())
        .filter(|fragment| !is_low_signal_auto_memory_summary_fragment(fragment))
        .collect::<Vec<_>>()
        .join("，");
    let compacted = normalize_whitespace(compacted.trim());
    (!compacted.is_empty()).then_some(truncate_chars(&compacted, AUTO_MEMORY_MAX_CHARS))
}

fn is_low_signal_auto_memory_summary_fragment(fragment: &str) -> bool {
    let normalized = fragment
        .chars()
        .filter(|ch| !ch.is_whitespace() && !"，,。；;：:!！?？".contains(*ch))
        .collect::<String>()
        .to_ascii_lowercase();
    if normalized.is_empty() {
        return true;
    }

    matches!(
        normalized.as_str(),
        "风格统一"
            | "镜头语言统一"
            | "镜头衔接统一"
            | "画面风格统一"
            | "视觉风格统一"
            | "光影一致"
            | "情绪一致"
            | "情绪延续"
            | "风格延续"
            | "保持一致"
            | "保持统一"
            | "视觉设定延续"
            | "场景设定延续"
            | "道具设定延续"
            | "角色设定延续"
    )
}

fn strip_auto_memory_scaffolding(fragment: &str) -> String {
    let mut compacted = normalize_whitespace(fragment.trim());
    if compacted.is_empty() {
        return compacted;
    }

    for pattern in [
        "当前镜头已确认的",
        "当前分镜已确认的",
        "本镜头已确认的",
        "该镜头已确认的",
        "当前镜头已确认",
        "当前分镜已确认",
        "本镜头已确认",
        "该镜头已确认",
        "当前镜头",
        "当前分镜",
        "本镜头",
        "该镜头",
    ] {
        compacted = compacted.replace(pattern, "");
    }

    let compacted = normalize_whitespace(compacted.trim());
    match compacted.as_str() {
        "" | "已确认" | "镜头已确认" | "分镜已确认" => String::new(),
        _ => compacted,
    }
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

fn format_storyboard_prompt_seed_scope(
    storyboard_prompt_seeds: &[(i32, String)],
) -> Option<String> {
    match storyboard_prompt_seeds {
        [] => None,
        [(_, prompt_seed)] => Some(format!("promptSeed={prompt_seed}")),
        seeds => Some(format!(
            "storyboardPromptSeeds={}",
            seeds
                .iter()
                .map(|(storyboard_id, prompt_seed)| format!("{storyboard_id}:{prompt_seed}"))
                .collect::<Vec<_>>()
                .join(",")
        )),
    }
}

async fn resolve_storyboard_prompt_seed_scope(
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
        WHERE p.owner_user_id = $1
          AND p.numeric_id = $2
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

async fn load_auto_memory_note(
    pool: &PgPool,
    user_id: Uuid,
    project_numeric_id: i32,
    episodes_id: Option<i32>,
    agent_type: &str,
    arguments: &Value,
    prompt_seed_scope: Option<&str>,
) -> Result<Option<String>, InvokeError> {
    let current_scope = scope_signature_from_args(arguments, prompt_seed_scope);
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

    let items = rows
        .into_iter()
        .map(|entry| format!("- {}", truncate_chars(entry.trim(), AUTO_MEMORY_MAX_CHARS)))
        .collect::<Vec<_>>()
        .join("\n");
    Ok(Some(format!(
        "同 scope 最近记忆：\n{items}\n只把它们当作延续线索；真正写入前先最小核对工具数据。"
    )))
}

fn filter_auto_scope_memory_rows(rows: Vec<AutoMemoryRow>) -> Vec<String> {
    rows.into_iter()
        .filter(|row| row.name == "auto_scope_memory")
        .map(|row| row.content.trim().to_string())
        .filter(|content| !content.is_empty())
        .collect()
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
        SELECT content
        FROM app_agent_memory
        WHERE owner_user_id = $1
          AND numeric_project_id = $2
          AND episodes_id IS NOT DISTINCT FROM $3
          AND agent_type = $4
          AND memory_type = 'summary'
          AND name = 'auto_scope_memory'
        ORDER BY create_time_ms DESC
        LIMIT 1
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

async fn persist_auto_memory_snapshot(
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
        build_auto_memory_snapshot, compact_auto_memory_entry_for_scope,
        dedupe_auto_memory_entries, filter_auto_scope_memory_rows,
        format_storyboard_prompt_seed_scope, parse_review_summary, parse_scope_signature,
        parse_storyboard_prompt_seed_scope, parse_tag_attributes, scope_signature_from_args,
        select_auto_memory_entries, sub_agent_prompt_from_args, AutoMemoryRow,
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
            None,
        )
        .expect("snapshot");

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
            None,
        )
        .expect("snapshot");

        assert!(snapshot.contains("tool=run_sub_agent_storyboard_table"));
        assert!(snapshot.contains("scope=assetIds=1,5"));
        assert!(snapshot.contains("result=第一行结果 第二行结果"));
        assert!(snapshot.chars().count() <= 320);
    }

    #[test]
    fn format_storyboard_prompt_seed_scope_uses_single_prompt_seed_for_single_storyboard() {
        assert_eq!(
            format_storyboard_prompt_seed_scope(&[(12, "seed-12-current".to_string())]),
            Some("promptSeed=seed-12-current".to_string())
        );
    }

    #[test]
    fn build_auto_memory_snapshot_includes_multi_storyboard_prompt_seed_scope() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_storyboard_gen",
            &json!({"storyboardIds": [12, 14]}),
            "补齐分镜连续性",
            None,
            Some("storyboardPromptSeeds=12:seed-12-current,14:seed-14-current"),
        )
        .expect("snapshot");

        assert!(snapshot.contains("scope=storyboardIds=12,14"));
        assert!(snapshot.contains("storyboardPromptSeeds=12:seed-12-current,14:seed-14-current"));
    }

    #[test]
    fn scope_signature_from_args_keeps_compact_sorted_scope() {
        let signature = scope_signature_from_args(
            &json!({
                "storyboardIds": [9, 1, 9],
                "assetIds": [5, 2, 5],
                "assetTypes": ["scene", "role", "scene"],
                "focusSections": ["script", "storySkeleton", "script"],
                "novelIds": [8, 3, 8],
                "relativeScriptOffset": -1
            }),
            None,
        );

        assert_eq!(signature.storyboard_ids, vec![1, 9]);
        assert!(signature.storyboard_prompt_seeds.is_empty());
        assert_eq!(signature.asset_ids, vec![2, 5]);
        assert_eq!(signature.asset_types, vec!["role", "scene"]);
        assert_eq!(signature.focus_sections, vec!["script", "storySkeleton"]);
        assert_eq!(signature.novel_ids, vec![3, 8]);
        assert_eq!(signature.relative_script_offset, Some(-1));
    }

    #[test]
    fn parse_scope_signature_reads_snapshot_scope_segment() {
        let signature = parse_scope_signature(
            "tool=run_sub_agent_storyboard_gen | scope=storyboardIds=3,9; assetIds=5,7; assetTypes=role,scene | storyboardPromptSeeds=3:seed-3,9:seed-9 | result=done",
        );

        assert_eq!(signature.storyboard_ids, vec![3, 9]);
        assert_eq!(
            signature.storyboard_prompt_seeds,
            vec![(3, "seed-3".to_string()), (9, "seed-9".to_string())]
        );
        assert_eq!(signature.asset_ids, vec![5, 7]);
        assert_eq!(signature.asset_types, vec!["role", "scene"]);
    }

    #[test]
    fn parse_storyboard_prompt_seed_scope_reads_multi_storyboard_seed_map() {
        assert_eq!(
            parse_storyboard_prompt_seed_scope(Some(
                "storyboardPromptSeeds=14:seed-14-current,12:seed-12-current"
            )),
            vec![
                (12, "seed-12-current".to_string()),
                (14, "seed-14-current".to_string())
            ]
        );
    }

    #[test]
    fn select_auto_memory_entries_prefers_overlapping_scope() {
        let rows = select_auto_memory_entries(
            &json!({
                "storyboardIds": [9],
                "assetIds": [7],
                "assetTypes": ["scene"]
            }),
            None,
            vec![
                "tool=a | scope=storyboardIds=1; assetIds=2 | result=older".to_string(),
                "tool=b | scope=storyboardIds=9; assetIds=7; assetTypes=scene | result=best"
                    .to_string(),
                "tool=c | scope=storyboardIds=9 | result=good".to_string(),
            ],
        );

        assert_eq!(rows.len(), 2);
        assert!(rows[0].contains("result=best"));
        assert!(rows[1].contains("result=good"));
    }

    #[test]
    fn select_auto_memory_entries_falls_back_to_latest_when_scope_missing() {
        let rows = select_auto_memory_entries(
            &json!({}),
            None,
            vec![
                "tool=a | scope=storyboardIds=1 | result=latest".to_string(),
                "tool=b | scope=storyboardIds=9 | result=older".to_string(),
            ],
        );

        assert_eq!(rows.len(), 1);
        assert!(rows[0].contains("result=latest"));
    }

    #[test]
    fn select_auto_memory_entries_prefers_matching_prompt_seed_over_stale_same_storyboard() {
        let rows = select_auto_memory_entries(
            &json!({
                "storyboardIds": [12]
            }),
            Some("promptSeed=seed-12-current"),
            vec![
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-stale | summary=旧版镜头走位".to_string(),
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位".to_string(),
            ],
        );

        assert_eq!(rows.len(), 1);
        assert!(rows[0].contains("promptSeed=seed-12-current"));
    }

    #[test]
    fn filter_auto_scope_memory_rows_skips_other_summary_types_and_blank_content() {
        let rows = filter_auto_scope_memory_rows(vec![
            AutoMemoryRow {
                name: "selected_video_memory".to_string(),
                content: "storyboardIds=12 | promptSeed=seed-12-current | style=镜头近景".to_string(),
            },
            AutoMemoryRow {
                name: "auto_scope_memory".to_string(),
                content: " tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位 ".to_string(),
            },
            AutoMemoryRow {
                name: "auto_scope_memory".to_string(),
                content: "   ".to_string(),
            },
        ]);

        assert_eq!(rows.len(), 1);
        assert_eq!(
            rows[0],
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位"
        );
    }

    #[test]
    fn select_auto_memory_entries_keeps_older_matching_scope_when_newer_rows_are_noise() {
        let rows = select_auto_memory_entries(
            &json!({
                "storyboardIds": [12]
            }),
            Some("promptSeed=seed-12-current"),
            vec![
                "tool=noise_a | scope=storyboardIds=31 | promptSeed=seed-31 | summary=别的镜头31".to_string(),
                "tool=noise_b | scope=storyboardIds=32 | promptSeed=seed-32 | summary=别的镜头32".to_string(),
                "tool=noise_c | scope=storyboardIds=33 | promptSeed=seed-33 | summary=别的镜头33".to_string(),
                "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位".to_string(),
            ],
        );

        assert_eq!(rows.len(), 1);
        assert!(rows[0].contains("storyboardIds=12"));
        assert!(rows[0].contains("promptSeed=seed-12-current"));
    }

    #[test]
    fn compact_auto_memory_entry_for_scope_drops_redundant_scope_and_seed_prefix() {
        let current_scope = scope_signature_from_args(
            &json!({
                "storyboardIds": [12]
            }),
            Some("promptSeed=seed-12-current"),
        );

        let compacted = compact_auto_memory_entry_for_scope(
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12 | promptSeed=seed-12-current | summary=当前镜头角色站位",
            &current_scope,
        );

        assert_eq!(compacted, "panel: 角色站位");
    }

    #[test]
    fn compact_auto_memory_entry_for_scope_keeps_scope_when_candidate_differs() {
        let current_scope = scope_signature_from_args(
            &json!({
                "storyboardIds": [12]
            }),
            Some("promptSeed=seed-12-current"),
        );

        let compacted = compact_auto_memory_entry_for_scope(
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12,14 | storyboardPromptSeeds=12:seed-12-current,14:seed-14-current | summary=保持当前镜头角色站位",
            &current_scope,
        );

        assert_eq!(
            compacted,
            "tool=run_sub_agent_storyboard_panel | scope=storyboardIds=12,14 | storyboardPromptSeeds=12:seed-12-current,14:seed-14-current | summary=保持当前镜头角色站位"
        );
    }

    #[test]
    fn compact_auto_memory_entry_for_scope_prefers_review_summary_over_metadata() {
        let current_scope = scope_signature_from_args(
            &json!({
                "storyboardIds": [12]
            }),
            Some("promptSeed=seed-12-current"),
        );

        let compacted = compact_auto_memory_entry_for_scope(
            "tool=run_sub_agent_production_supervision | scope=storyboardIds=12 | promptSeed=seed-12-current | review=target=storyboardTable; grade=B; next=refresh; summary=当前镜头角色站位不要跳轴",
            &current_scope,
        );

        assert_eq!(compacted, "supervision: 角色站位不要跳轴");
    }

    #[test]
    fn compact_auto_memory_entry_for_scope_falls_back_to_review_target_and_next() {
        let current_scope = scope_signature_from_args(
            &json!({
                "storyboardIds": [12]
            }),
            Some("promptSeed=seed-12-current"),
        );

        let compacted = compact_auto_memory_entry_for_scope(
            "tool=run_sub_agent_production_supervision | scope=storyboardIds=12 | promptSeed=seed-12-current | review=target=storyboardTable; grade=C; next=refresh",
            &current_scope,
        );

        assert_eq!(compacted, "supervision: storyboardTable refresh");
    }

    #[test]
    fn dedupe_auto_memory_entries_drops_scope_compaction_duplicates() {
        let rows = dedupe_auto_memory_entries(vec![
            "panel: 角色站位".to_string(),
            "panel: 角色站位".to_string(),
            "panel: 补充环境光位".to_string(),
        ]);

        assert_eq!(
            rows,
            vec![
                "panel: 角色站位".to_string(),
                "panel: 补充环境光位".to_string()
            ]
        );
    }

    #[test]
    fn build_auto_memory_snapshot_drops_low_signal_plain_result() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_storyboard_gen",
            &json!({"storyboardIds": [12]}),
            "本轮执行完成。已读取 flow。已写入工作区。",
            None,
            None,
        );

        assert!(snapshot.is_none());
    }

    #[test]
    fn build_auto_memory_snapshot_strips_generic_result_prefix_and_keeps_constraint() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_storyboard_gen",
            &json!({"storyboardIds": [12]}),
            "已生成主角冲向巷口，保持镜头方向连续。",
            None,
            None,
        )
        .expect("snapshot");

        assert!(snapshot.contains("result=主角冲向巷口，保持镜头方向连续"));
        assert!(!snapshot.contains("已生成"));
    }

    #[test]
    fn build_auto_memory_snapshot_drops_low_signal_result_tail_clause() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_storyboard_gen",
            &json!({"storyboardIds": [12]}),
            "主角冲向巷口，保持镜头方向连续，已写入工作区。",
            None,
            None,
        )
        .expect("snapshot");

        assert!(snapshot.contains("result=主角冲向巷口，保持镜头方向连续"));
        assert!(!snapshot.contains("已写入工作区"));
    }

    #[test]
    fn build_auto_memory_snapshot_compacts_review_summary_before_persisting() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_production_supervision",
            &json!({"storyboardIds": [12]}),
            "unused",
            Some(&json!({
                "target": "storyboardTable",
                "grade": "B",
                "nextAction": "check_storyboard",
                "summary": "当前镜头角色站位不要跳轴"
            })),
            Some("promptSeed=seed-12-current"),
        )
        .expect("snapshot");

        assert!(snapshot.contains("summary=角色站位不要跳轴"));
        assert!(!snapshot.contains("当前镜头"));
    }

    #[test]
    fn build_auto_memory_snapshot_drops_generic_review_summary_placeholder() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_production_supervision",
            &json!({"storyboardIds": [12]}),
            "unused",
            Some(&json!({
                "target": "storyboardTable",
                "grade": "B",
                "nextAction": "check_storyboard",
                "summary": "当前镜头风格统一，情绪延续"
            })),
            Some("promptSeed=seed-12-current"),
        )
        .expect("snapshot");

        assert!(!snapshot.contains("summary="));
        assert!(!snapshot.contains("风格统一"));
        assert!(!snapshot.contains("情绪延续"));
    }

    #[test]
    fn build_auto_memory_snapshot_keeps_specific_review_constraint_while_dropping_generic_prefix() {
        let snapshot = build_auto_memory_snapshot(
            "run_sub_agent_production_supervision",
            &json!({"storyboardIds": [12]}),
            "unused",
            Some(&json!({
                "target": "storyboardTable",
                "grade": "B",
                "nextAction": "check_storyboard",
                "summary": "当前镜头风格统一，人物站位不要跳轴"
            })),
            Some("promptSeed=seed-12-current"),
        )
        .expect("snapshot");

        assert!(snapshot.contains("summary=人物站位不要跳轴"));
        assert!(!snapshot.contains("风格统一"));
    }
}
