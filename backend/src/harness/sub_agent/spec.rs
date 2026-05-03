//! Sub-agent spec routing: maps tool names to skill paths, role names, and hints.

pub(super) struct SubAgentSpec {
    pub(super) role_name: &'static str,
    pub(super) skill_path: &'static str,
    pub(super) skill_section: Option<&'static str>,
    pub(super) format_hint: Option<&'static str>,
    pub(super) execution_hint: Option<&'static str>,
}

pub(super) fn agent_memory_type_for_tool(tool_name: &str) -> Option<&'static str> {
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

pub(super) fn sub_agent_spec(tool_name: &str) -> Option<SubAgentSpec> {
    match tool_name {
        "run_sub_agent_storySkeleton" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_skeleton.md",
            skill_section: None,
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<storySkeleton>故事骨架内容</storySkeleton>"),
            execution_hint: Some("先最小读取：优先只拿当前任务相关的章节事件、骨架片段和必要原文窗口；信息足够时不要补读整章。"),
        }),
        "run_sub_agent_adaptationStrategy" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_adaptation.md",
            skill_section: None,
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<adaptationStrategy>改编策略内容</adaptationStrategy>"),
            execution_hint: Some("先最小读取：先读骨架和事件表字段子集，只有在世界观或细节不足时才补读原文窗口。"),
        }),
        "run_sub_agent_script" => Some(SubAgentSpec {
            role_name: "编剧",
            skill_path: "script_execution_script.md",
            skill_section: None,
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<scriptItem name=\"剧本名称\">剧本内容</scriptItem>"),
            execution_hint: Some("先最小读取：1) 先分别读当前集的 storySkeleton 与 adaptationStrategy；2) 再读目标章节的事件表字段子集；3) 只有在台词/动作细节不足时才读当前章节正文窗口；4) 只有在承接上一集时才读上一集尾段窗口。不要默认整章、整集或整块 planData 全量搬运。"),
        }),
        "run_supervision_agent" => Some(SubAgentSpec {
            role_name: "编辑",
            skill_path: "script_agent_supervision.md",
            skill_section: None,
            format_hint: Some("输出时第一行必须是单行 XML 摘要，格式如下：\n<reviewSummary target=\"storySkeleton|adaptationStrategy|script\" grade=\"A|B|C|D\" severeCount=\"0\" mediumCount=\"0\" minorCount=\"0\" nextAction=\"revise_storySkeleton|revise_adaptationStrategy|revise_script|check_novel_events|check_novel_text|check_script\" summary=\"一句话总结\" />\n随后再输出精简 Markdown 审核报告。summary 控制在 36 个汉字以内；若信息足够，不要写冗长解释。"),
            execution_hint: Some("审核必须基于工具实读的工作区内容，优先拉取字段子集或窗口片段，不要为了审核先全量加载全部正文。"),
        }),
        "run_sub_agent_derive_assets" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("一、衍生资产分析与信息写入"),
            format_hint: None,
            execution_hint: Some("先最小读取：先读剧本窗口，再按实际涉及的 assetTypes 分批读 assets；确认到具体父资产或状态后再按需补读，不要先吞整包素材。"),
        }),
        "run_sub_agent_generate_assets" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("二、衍生资产图片生成"),
            format_hint: None,
            execution_hint: Some("先最小读取：若派发指令已给出明确资产 ids，先只核对这批状态再直接生成；否则再用最小字段拿候选列表，只对明确候选发起生成。"),
        }),
        "run_sub_agent_director_plan" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("三、导演规划"),
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<scriptPlan>内容</scriptPlan>"),
            execution_hint: Some("先最小读取：先读剧本 1-48 行、<=1400 字的窗口，再先读 role/scene 资产，只有剧本明确需要时才补 tool 或具体资产 ID；若上游先要求 check_assets，核对后只回到紧凑 scriptPlan 判断缺口是否闭合，不要默认整份 assets 或后续 storyboard 上下文一起进来。"),
        }),
        "run_sub_agent_storyboard_gen" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("六、分镜图生成"),
            format_hint: None,
            execution_hint: Some("先最小读取：优先只用最小字段读取缺帧候选；有明确 storyboard ids 时只读这批镜头，再提取 shouldGenerateImage=true 且缺画面的真实 id 列表；如需复核依据，也只复读同批 storyboardTable 行和对应剧本窗口，不要先加载整块 storyboard / storyboardTable / script，更不要重跑已有结果的镜头。"),
        }),
        "run_sub_agent_storyboard_panel" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("五、分镜面板写入"),
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<storyboardItem videoDesc='视频描述' prompt='提示词内容' track='分组' duration='视频推荐时间' associateAssetsIds='[资产ID列表]'></storyboardItem>"),
            execution_hint: Some("先最小读取：先拿 storyboardTable 必要行和资产字段子集，只有 storyboardTable 不足以写 videoDesc/台词依据时才补同批镜头的局部 script 窗口；不要默认把整表和整段剧本都拉满。"),
        }),
        "run_sub_agent_storyboard_table" => Some(SubAgentSpec {
            role_name: "执行导演",
            skill_path: "production_agent_execution.md",
            skill_section: Some("四、构建分镜表"),
            format_hint: Some("你必须使用如下XML格式写入工作区：\n<storyboardTable>内容</storyboardTable>"),
            execution_hint: Some("先最小读取：剧本优先只读 1-48 行、<=1400 字窗口，资产先读 role/scene，再按需要补 tool 或精确 ids；完成分镜拆解前避免反复加载整份原文或整包素材。"),
        }),
        "run_sub_agent_production_supervision" => Some(SubAgentSpec {
            role_name: "监督导演",
            skill_path: "production_agent_supervision.md",
            skill_section: None,
            format_hint: Some("输出时第一行必须是单行 XML 摘要，格式如下：\n<reviewSummary target=\"scriptPlan|storyboardTable\" grade=\"A|B|C|D\" severeCount=\"0\" mediumCount=\"0\" minorCount=\"0\" nextAction=\"revise_scriptPlan|check_assets|check_storyboard|revise_storyboardTable|check_script|generate_storyboard\" summary=\"一句话总结\" assetIds=\"12,18\" assetTypes=\"role,scene\" storyboardIds=\"31,32\" />\n其中 assetIds 仅在下一步需要核对具体资产时填写，填逗号分隔的真实资产 ID；若暂时无法精确到资产 ID 但已收紧到最小资产类型范围，填写 assetTypes（如 role,scene 或 tool）；storyboardIds 仅在下一步需要核对或补齐具体镜头时填写，填逗号分隔的真实 storyboard 镜头 ID；不需要时可省略。随后再输出精简 Markdown 审核报告。summary 控制在 36 个汉字以内；若信息足够，不要写冗长解释。"),
            execution_hint: Some("审核必须基于工具实读的数据，优先读取 storyboardTable/script/assets 的必要字段或窗口；审核 scriptPlan 时，assets 默认先读 role/scene，再按需要补 tool 或精确 ids；若问题只涉及部分资产，下一步给出 check_assets 时优先回填真实 assetIds，做不到精确 id 也必须回填最小 assetTypes 范围；若只涉及部分缺帧或待核对镜头，下一步给出 check_storyboard、generate_storyboard 或 check_script 时都应沿用同一批真实 storyboardIds，避免无差别全量读取 storyboard 或剧本。"),
        }),
        _ => None,
    }
}

pub(super) fn stage_summary_name_for_tool(tool_name: &str) -> Option<&'static str> {
    match tool_name {
        "run_sub_agent_storySkeleton" => Some("stage_summary:story_skeleton"),
        "run_sub_agent_adaptationStrategy" => Some("stage_summary:adaptation_strategy"),
        "run_sub_agent_script" => Some("stage_summary:script"),
        "run_supervision_agent" => Some("stage_summary:script_supervision"),
        "run_sub_agent_derive_assets" => Some("stage_summary:derive_assets"),
        "run_sub_agent_generate_assets" => Some("stage_summary:generate_assets"),
        "run_sub_agent_director_plan" => Some("stage_summary:director_plan"),
        "run_sub_agent_storyboard_gen" => Some("stage_summary:storyboard_gen"),
        "run_sub_agent_storyboard_panel" => Some("stage_summary:storyboard_panel"),
        "run_sub_agent_storyboard_table" => Some("stage_summary:storyboard_table"),
        "run_sub_agent_production_supervision" => Some("stage_summary:production_supervision"),
        _ => None,
    }
}

pub(super) fn stage_label_for_tool(tool_name: &str) -> Option<&'static str> {
    match tool_name {
        "run_sub_agent_storySkeleton" => Some("story_skeleton"),
        "run_sub_agent_adaptationStrategy" => Some("adaptation_strategy"),
        "run_sub_agent_script" => Some("script"),
        "run_supervision_agent" => Some("script_supervision"),
        "run_sub_agent_derive_assets" => Some("derive_assets"),
        "run_sub_agent_generate_assets" => Some("generate_assets"),
        "run_sub_agent_director_plan" => Some("director_plan"),
        "run_sub_agent_storyboard_gen" => Some("storyboard_gen"),
        "run_sub_agent_storyboard_panel" => Some("storyboard_panel"),
        "run_sub_agent_storyboard_table" => Some("storyboard_table"),
        "run_sub_agent_production_supervision" => Some("production_supervision"),
        _ => None,
    }
}
