part of 'support.dart';

List<ScriptWorkspaceStage> buildScriptWorkspaceStages({
  required String? toolName,
  required Object? result,
  required int? scopeScriptId,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  final resultMap = result is Map<String, dynamic> ? result : null;
  final review = parseScriptWorkspaceReview(resultMap);
  final items = _extractResultItems(result);
  final planData = _extractPlanDataMap(resultMap);
  final storySkeleton = (planData?['storySkeleton'] as String?)?.trim() ?? '';
  final adaptationStrategy =
      (planData?['adaptationStrategy'] as String?)?.trim() ?? '';
  final scriptContent = (resultMap?['content'] as String?)?.trim() ?? '';

  return <ScriptWorkspaceStage>[
    if (storySkeleton.isNotEmpty)
      ScriptWorkspaceStage(
        title: '故事骨架',
        statusLabel: '已就绪',
        detail: 'storySkeleton 已存在，可继续收束改编策略或对照剧本正文。',
        domainTool: 'get_planData',
        args: _planSectionArgs('storySkeleton'),
      )
    else if (review?.target == 'storySkeleton')
      ScriptWorkspaceStage(
        title: '故事骨架',
        statusLabel: review!.grade == 'A' || review.grade == 'B'
            ? '可沿用'
            : '待修订',
        detail: review.summary.isEmpty
            ? '审核已覆盖 storySkeleton，可按建议继续修订。'
            : '审核结论：${review.summary}',
        domainTool: 'get_planData',
        args: _planSectionArgs('storySkeleton'),
        subAgentTool: review.nextAction == 'revise_storySkeleton'
            ? 'run_sub_agent_storySkeleton'
            : null,
        prompt: review.nextAction == 'revise_storySkeleton'
            ? '请先读取 storySkeleton 与相关事件窗口，再针对审核意见局部修订故事骨架。'
            : null,
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
      ScriptWorkspaceStage(
        title: '故事骨架',
        statusLabel: '待读取',
        detail: '先读取 planData，确认 storySkeleton 是否齐备。',
        domainTool: 'get_planData',
        args: const <String, dynamic>{'key': 'storySkeleton', 'maxChars': 1600},
      ),
    if (adaptationStrategy.isNotEmpty)
      ScriptWorkspaceStage(
        title: '改编策略',
        statusLabel: '已就绪',
        detail: 'adaptationStrategy 已存在，可继续读取章节材料或生成正文。',
        domainTool: 'get_planData',
        args: _planSectionArgs('adaptationStrategy'),
      )
    else if (review?.target == 'adaptationStrategy')
      ScriptWorkspaceStage(
        title: '改编策略',
        statusLabel: review!.grade == 'A' || review.grade == 'B'
            ? '可沿用'
            : '待修订',
        detail: review.summary.isEmpty
            ? '审核已覆盖 adaptationStrategy，可按建议继续修订。'
            : '审核结论：${review.summary}',
        domainTool: 'get_planData',
        args: _planSectionArgs('adaptationStrategy'),
        subAgentTool: review.nextAction == 'revise_adaptationStrategy'
            ? 'run_sub_agent_adaptationStrategy'
            : null,
        prompt: review.nextAction == 'revise_adaptationStrategy'
            ? '请先读取 adaptationStrategy 与 storySkeleton，再针对审核意见局部修订改编策略。'
            : null,
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
      ScriptWorkspaceStage(
        title: '改编策略',
        statusLabel: '待读取',
        detail: '回看 planData，判断 adaptationStrategy 是否已具备。',
        domainTool: 'get_planData',
        args: const <String, dynamic>{
          'key': 'adaptationStrategy',
          'maxChars': 1600,
        },
      ),
    if (items.isNotEmpty &&
        (normalizedTool == 'get_novel_text' ||
            normalizedTool == 'get_novel_events'))
      ScriptWorkspaceStage(
        title: '章节材料',
        statusLabel: '已就绪',
        detail: '已读取 ${items.length} 条小说上下文，可继续生成剧本正文或对照现有 script。',
        domainTool: normalizedTool,
        args: _buildNovelStageArgs(items, toolName: normalizedTool),
      )
    else if (normalizedTool == 'get_novel_text' ||
        normalizedTool == 'get_novel_events')
      ScriptWorkspaceStage(
        title: '章节材料',
        statusLabel: '待补充',
        detail: '小说上下文为空，建议继续读取章节正文或事件脉络。',
        domainTool: 'get_novel_text',
        args: _novelTextWindowArgs(null),
      )
    else
      ScriptWorkspaceStage(
        title: '章节材料',
        statusLabel: '待读取',
        detail: '先读取章节正文或事件列表，再决定如何改写剧本。',
        domainTool: 'get_novel_text',
        args: _novelTextWindowArgs(null),
      ),
    if (scriptContent.isNotEmpty)
      ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: '已完成',
        detail: '当前 script 正文已存在，可直接写回或回看计划数据继续改稿。',
        domainTool: 'get_script_content',
        args: _scriptWindowArgs(scopeScriptId),
      )
    else if (review?.target == 'script')
      ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: review!.grade == 'A' || review.grade == 'B'
            ? '可沿用'
            : '待修订',
        detail: review.summary.isEmpty
            ? '审核已覆盖剧本正文，可按建议继续改稿。'
            : '审核结论：${review.summary}',
        domainTool: 'get_script_content',
        args: _scriptTailWindowArgs(scopeScriptId),
        subAgentTool: review.nextAction == 'revise_script'
            ? 'run_sub_agent_script'
            : null,
        prompt: review.nextAction == 'revise_script'
            ? '请先读取当前集尾段窗口、storySkeleton、adaptationStrategy；如仍不足再补读章节正文窗口，并针对审核意见定向修订本集剧本。'
            : null,
      )
    else if (normalizedTool == 'get_script_content' ||
        normalizedTool == 'run_sub_agent_script')
      const ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: '待生成',
        detail: '当前 script 正文为空，适合直接运行 script 子代理生成首版内容。',
        subAgentTool: 'run_sub_agent_script',
        prompt:
            '请先读取当前集计划与目标章节事件；只有在承接上一集时才补读上一集尾段，其余细节再按需补正文窗口，生成下一版剧本正文并输出可直接写回的完整内容。',
      )
    else
      ScriptWorkspaceStage(
        title: '剧本正文',
        statusLabel: '待读取',
        detail: '读取当前剧本正文，再判断是否需要直接生成下一版。',
        domainTool: 'get_script_content',
        args: _scriptWindowArgs(scopeScriptId),
      ),
  ];
}
