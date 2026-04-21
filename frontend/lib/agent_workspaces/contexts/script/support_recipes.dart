part of 'support.dart';

List<ScriptWorkspaceRecipe> buildScriptWorkspaceRecipes({
  required String? toolName,
  required Object? result,
  required int? scopeScriptId,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  if (normalizedTool.isEmpty || result is! Map<String, dynamic>) {
    return const <ScriptWorkspaceRecipe>[];
  }

  switch (normalizedTool) {
    case 'get_planData':
      return _buildPlanDataRecipes(result, scopeScriptId: scopeScriptId);
    case 'get_novel_text':
      return _buildNovelTextRecipes(result, scopeScriptId: scopeScriptId);
    case 'get_novel_events':
      return _buildNovelEventRecipes(result, scopeScriptId: scopeScriptId);
    case 'get_script_content':
      return _buildScriptContentRecipes(result);
    default:
      return const <ScriptWorkspaceRecipe>[];
  }
}

List<ScriptWorkspaceRecipe> _buildPlanDataRecipes(
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final data = result['data'];
  if (data is! Map<String, dynamic>) {
    return const <ScriptWorkspaceRecipe>[];
  }
  final storySkeleton = (data['storySkeleton'] as String?)?.trim() ?? '';
  final adaptationStrategy =
      (data['adaptationStrategy'] as String?)?.trim() ?? '';
  final scriptRows = data['script'];
  final recipes = <ScriptWorkspaceRecipe>[];

  if (storySkeleton.isEmpty) {
    recipes.add(
      const ScriptWorkspaceRecipe(
        title: '补故事骨架',
        detail: 'planData 还没有 storySkeleton，先让骨架子代理补结构。',
        subAgentTool: 'run_sub_agent_storySkeleton',
        prompt: '请基于当前项目上下文生成一版清晰的故事骨架，并突出主冲突与反转节点。',
      ),
    );
  }
  if (adaptationStrategy.isEmpty) {
    recipes.add(
      const ScriptWorkspaceRecipe(
        title: '补改编策略',
        detail: '骨架之外还缺 adaptationStrategy，适合先收束改编路径。',
        subAgentTool: 'run_sub_agent_adaptationStrategy',
        prompt: '请基于现有故事骨架补齐改编策略，突出节奏、人物弧光与集数拆分原则。',
      ),
    );
  }
  if (scopeScriptId != null) {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: '读取当前剧本正文',
        detail: 'planData 已准备好后，下一步通常要对比当前 script 正文是否偏离。',
        domainTool: 'get_script_content',
        args: <String, dynamic>{'scriptId': scopeScriptId},
      ),
    );
  }
  if (scriptRows is List && scriptRows.isEmpty) {
    recipes.add(
      const ScriptWorkspaceRecipe(
        title: '拉取章节材料',
        detail: '计划里还没有剧本草稿，先读取小说章节文本补上下文。',
        domainTool: 'get_novel_text',
      ),
    );
  } else {
    recipes.add(
      const ScriptWorkspaceRecipe(
        title: '生成下一版剧本',
        detail: '计划信息已具备，可直接让 script 子代理输出下一版可写回正文。',
        subAgentTool: 'run_sub_agent_script',
        prompt: '请结合当前 planData 与已有剧本状态，输出可直接写回的完整剧本正文。',
      ),
    );
  }
  return recipes.take(3).toList(growable: false);
}

List<ScriptWorkspaceRecipe> _buildNovelTextRecipes(
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final ids = extractScriptWorkspaceNovelIds(result);
  if (ids.isEmpty) {
    return const <ScriptWorkspaceRecipe>[
      ScriptWorkspaceRecipe(
        title: '改看事件脉络',
        detail: '章节文本为空时，先读事件列表更容易定位剧情骨架缺口。',
        domainTool: 'get_novel_events',
      ),
    ];
  }
  return <ScriptWorkspaceRecipe>[
    ScriptWorkspaceRecipe(
      title: '读取对应事件',
      detail: '章节文本已到位，继续按同一章节拉取事件脉络更利于总结冲突。',
      domainTool: 'get_novel_events',
      args: <String, dynamic>{'novelId': ids.first},
    ),
    const ScriptWorkspaceRecipe(
      title: '生成改编策略',
      detail: '章节材料已经可读，适合直接让改编策略子代理给出收束方案。',
      subAgentTool: 'run_sub_agent_adaptationStrategy',
      prompt: '请基于当前章节文本总结改编策略，输出 3 到 5 条可直接执行的改写原则。',
    ),
    if (scopeScriptId != null)
      ScriptWorkspaceRecipe(
        title: '回看当前剧本',
        detail: '在章节材料明确后，再对照当前剧本正文更容易定位缺口。',
        domainTool: 'get_script_content',
        args: <String, dynamic>{'scriptId': scopeScriptId},
      ),
  ];
}

List<ScriptWorkspaceRecipe> _buildNovelEventRecipes(
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final items = _extractResultItems(result);
  if (items.isEmpty) {
    return const <ScriptWorkspaceRecipe>[
      ScriptWorkspaceRecipe(
        title: '先拉章节正文',
        detail: '事件列表为空时，先读章节文本更容易判断是数据空还是事件未抽取。',
        domainTool: 'get_novel_text',
      ),
    ];
  }
  return <ScriptWorkspaceRecipe>[
    const ScriptWorkspaceRecipe(
      title: '整理故事骨架',
      detail: '事件脉络已清晰，适合先收束成 storySkeleton。',
      subAgentTool: 'run_sub_agent_storySkeleton',
      prompt: '请基于当前事件列表提炼故事骨架，保留关键冲突、转折与结局走向。',
    ),
    const ScriptWorkspaceRecipe(
      title: '生成剧本初稿',
      detail: '如果事件链路基本齐全，可直接让 script 子代理生成可写回正文。',
      subAgentTool: 'run_sub_agent_script',
      prompt: '请结合当前事件脉络生成一版可直接写回的剧本正文，保持节奏紧凑。',
    ),
    if (scopeScriptId != null)
      ScriptWorkspaceRecipe(
        title: '对比现有剧本',
        detail: '用当前事件链路反查现有正文，能更快定位缺场或冲突偏移。',
        domainTool: 'get_script_content',
        args: <String, dynamic>{'scriptId': scopeScriptId},
      ),
  ];
}

List<ScriptWorkspaceRecipe> _buildScriptContentRecipes(
  Map<String, dynamic> result,
) {
  final content = (result['content'] as String?)?.trim() ?? '';
  if (content.isEmpty) {
    return const <ScriptWorkspaceRecipe>[
      ScriptWorkspaceRecipe(
        title: '生成剧本正文',
        detail: '当前正文为空，直接让 script 子代理产出首版内容更合适。',
        subAgentTool: 'run_sub_agent_script',
        prompt: '请基于当前计划与章节上下文生成一版完整剧本正文。',
      ),
      ScriptWorkspaceRecipe(
        title: '刷新计划数据',
        detail: '若正文为空且上下文不完整，也可先回到 planData 校验骨架与策略。',
        domainTool: 'get_planData',
      ),
    ];
  }
  return const <ScriptWorkspaceRecipe>[
    ScriptWorkspaceRecipe(
      title: '刷新计划数据',
      detail: '已有正文后，通常要回看 planData 判断是否需要同步骨架或策略。',
      domainTool: 'get_planData',
    ),
    ScriptWorkspaceRecipe(
      title: '补章节材料',
      detail: '如果要继续改稿，可先拉小说正文与事件，避免只盯着当前 script。',
      domainTool: 'get_novel_text',
    ),
  ];
}
