part of 'support.dart';

List<ScriptWorkspaceStage> buildScriptWorkspaceStages({
  required String? toolName,
  required Object? result,
  required int? scopeScriptId,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  final resultMap = result is Map<String, dynamic> ? result : null;
  final items = _extractResultItems(result);
  final planData = _extractPlanDataMap(resultMap);
  final storySkeleton = (planData?['storySkeleton'] as String?)?.trim() ?? '';
  final adaptationStrategy =
      (planData?['adaptationStrategy'] as String?)?.trim() ?? '';
  final scriptContent = (resultMap?['content'] as String?)?.trim() ?? '';

  return <ScriptWorkspaceStage>[
    if (storySkeleton.isNotEmpty)
      const ScriptWorkspaceStage(
        title: '故事骨架',
        statusLabel: '已就绪',
        detail: 'storySkeleton 已存在，可继续收束改编策略或对照剧本正文。',
        domainTool: 'get_planData',
      )
    else if (normalizedTool == 'get_planData' ||
        normalizedTool == 'run_sub_agent_storySkeleton')
      const ScriptWorkspaceStage(
        title: '故事骨架',
        statusLabel: '待生成',
        detail: '先补故事骨架，明确主冲突、转折与结局走向。',
        subAgentTool: 'run_sub_agent_storySkeleton',
        prompt: '请基于当前项目上下文生成一版清晰的故事骨架，并突出主冲突与反转节点。',
      )
    else
      const ScriptWorkspaceStage(
        title: '故事骨架',
        statusLabel: '待读取',
        detail: '先读取 planData，确认 storySkeleton 是否齐备。',
        domainTool: 'get_planData',
      ),
    if (adaptationStrategy.isNotEmpty)
      const ScriptWorkspaceStage(
        title: '改编策略',
        statusLabel: '已就绪',
        detail: 'adaptationStrategy 已存在，可继续读取章节材料或生成正文。',
        domainTool: 'get_planData',
      )
    else if (normalizedTool == 'get_planData' ||
        normalizedTool == 'run_sub_agent_adaptationStrategy')
      const ScriptWorkspaceStage(
        title: '改编策略',
        statusLabel: '待生成',
        detail: '当前缺少 adaptationStrategy，适合先收束人物与节奏策略。',
        subAgentTool: 'run_sub_agent_adaptationStrategy',
        prompt: '请基于现有故事骨架补齐改编策略，突出节奏、人物弧光与集数拆分原则。',
      )
    else
      const ScriptWorkspaceStage(
        title: '改编策略',
        statusLabel: '待读取',
        detail: '回看 planData，判断 adaptationStrategy 是否已具备。',
        domainTool: 'get_planData',
      ),
    if (items.isNotEmpty &&
        (normalizedTool == 'get_novel_text' ||
            normalizedTool == 'get_novel_events'))
      ScriptWorkspaceStage(
        title: '章节材料',
        statusLabel: '已就绪',
        detail: '已读取 ${items.length} 条小说上下文，可继续生成剧本正文或对照现有 script。',
        domainTool: normalizedTool,
        args: _buildNovelStageArgs(items),
      )
    else if (normalizedTool == 'get_novel_text' ||
        normalizedTool == 'get_novel_events')
      const ScriptWorkspaceStage(
        title: '章节材料',
        statusLabel: '待补充',
        detail: '小说上下文为空，建议继续读取章节正文或事件脉络。',
        domainTool: 'get_novel_text',
      )
    else
      const ScriptWorkspaceStage(
        title: '章节材料',
        statusLabel: '待读取',
        detail: '先读取章节正文或事件列表，再决定如何改写剧本。',
        domainTool: 'get_novel_text',
      ),
    if (scriptContent.isNotEmpty)
      const ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: '已完成',
        detail: '当前 script 正文已存在，可直接写回或回看计划数据继续改稿。',
        domainTool: 'get_script_content',
      )
    else if (normalizedTool == 'get_script_content' ||
        normalizedTool == 'run_sub_agent_script')
      const ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: '待生成',
        detail: '当前 script 正文为空，适合直接运行 script 子代理生成首版内容。',
        subAgentTool: 'run_sub_agent_script',
        prompt: '请基于当前剧情计划与上下文生成下一版剧本正文，输出可直接写回的完整内容。',
      )
    else
      ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: '待读取',
        detail: '读取当前剧本正文，再判断是否需要直接生成下一版。',
        domainTool: 'get_script_content',
        args: scopeScriptId == null
            ? null
            : <String, dynamic>{'scriptId': scopeScriptId},
      ),
  ];
}
