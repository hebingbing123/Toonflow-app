part of 'support.dart';

List<ScriptWorkspaceStage> buildScriptWorkspaceStages({
  required AppLocalizations l10n,
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
        title: l10n.agentWorkspaceScriptStageTitleStorySkeleton,
        statusLabel: l10n.agentWorkspaceScriptStageStatusReady,
        detail: l10n.agentWorkspaceScriptStageDetailStorySkeletonReady,
        domainTool: 'get_planData',
        args: _planSectionArgs('storySkeleton'),
      )
    else if (review?.target == 'storySkeleton')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleStorySkeleton,
        statusLabel: review!.grade == 'A' || review.grade == 'B'
            ? l10n.agentWorkspaceScriptStageStatusReusable
            : l10n.agentWorkspaceScriptStageStatusNeedsRevision,
        detail: review.summary.isEmpty
            ? l10n.agentWorkspaceScriptStageDetailReviewStorySkeletonEmpty
            : l10n.agentWorkspaceScriptStageDetailReviewConclusion(
                review.summary,
              ),
        domainTool: 'get_planData',
        args: _planSectionArgs('storySkeleton'),
        subAgentTool: review.nextAction == 'revise_storySkeleton'
            ? 'run_sub_agent_storySkeleton'
            : null,
        prompt: review.nextAction == 'revise_storySkeleton'
            ? l10n.agentWorkspaceScriptStagePromptReviseStorySkeleton
            : null,
      )
    else if (normalizedTool == 'get_planData' ||
        normalizedTool == 'run_sub_agent_storySkeleton')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleStorySkeleton,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingGenerate,
        detail: l10n.agentWorkspaceScriptStageDetailStorySkeletonPendingGen,
        subAgentTool: 'run_sub_agent_storySkeleton',
        prompt: l10n.agentWorkspaceScriptStagePromptGenerateStorySkeleton,
      )
    else
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleStorySkeleton,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingRead,
        detail: l10n.agentWorkspaceScriptStageDetailStorySkeletonPendingRead,
        domainTool: 'get_planData',
        args: const <String, dynamic>{'key': 'storySkeleton', 'maxChars': 1600},
      ),
    if (adaptationStrategy.isNotEmpty)
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleAdaptationStrategy,
        statusLabel: l10n.agentWorkspaceScriptStageStatusReady,
        detail: l10n.agentWorkspaceScriptStageDetailAdaptationReady,
        domainTool: 'get_planData',
        args: _planSectionArgs('adaptationStrategy'),
      )
    else if (review?.target == 'adaptationStrategy')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleAdaptationStrategy,
        statusLabel: review!.grade == 'A' || review.grade == 'B'
            ? l10n.agentWorkspaceScriptStageStatusReusable
            : l10n.agentWorkspaceScriptStageStatusNeedsRevision,
        detail: review.summary.isEmpty
            ? l10n.agentWorkspaceScriptStageDetailReviewAdaptationEmpty
            : l10n.agentWorkspaceScriptStageDetailReviewConclusion(
                review.summary,
              ),
        domainTool: 'get_planData',
        args: _planSectionArgs('adaptationStrategy'),
        subAgentTool: review.nextAction == 'revise_adaptationStrategy'
            ? 'run_sub_agent_adaptationStrategy'
            : null,
        prompt: review.nextAction == 'revise_adaptationStrategy'
            ? l10n.agentWorkspaceScriptStagePromptReviseAdaptationStrategy
            : null,
      )
    else if (normalizedTool == 'get_planData' ||
        normalizedTool == 'run_sub_agent_adaptationStrategy')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleAdaptationStrategy,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingGenerate,
        detail: l10n.agentWorkspaceScriptStageDetailAdaptationPendingGen,
        subAgentTool: 'run_sub_agent_adaptationStrategy',
        prompt: l10n.agentWorkspaceScriptStagePromptGenerateAdaptationStrategy,
      )
    else
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleAdaptationStrategy,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingRead,
        detail: l10n.agentWorkspaceScriptStageDetailAdaptationPendingRead,
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
        title: l10n.agentWorkspaceScriptStageTitleChapterMaterial,
        statusLabel: l10n.agentWorkspaceScriptStageStatusReady,
        detail: l10n.agentWorkspaceScriptStageDetailChapterMaterialReady(
          items.length,
        ),
        domainTool: normalizedTool,
        args: _buildNovelStageArgs(items, toolName: normalizedTool),
      )
    else if (normalizedTool == 'get_novel_text' ||
        normalizedTool == 'get_novel_events')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleChapterMaterial,
        statusLabel: l10n.agentWorkspaceScriptStageStatusSupplementNeeded,
        detail: l10n.agentWorkspaceScriptStageDetailChapterMaterialEmptyNovel,
        domainTool: 'get_novel_text',
        args: _novelTextWindowArgs(null),
      )
    else
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleChapterMaterial,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingRead,
        detail: l10n.agentWorkspaceScriptStageDetailChapterMaterialPendingRead,
        domainTool: 'get_novel_text',
        args: _novelTextWindowArgs(null),
      ),
    if (scriptContent.isNotEmpty)
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleScriptBody,
        statusLabel: l10n.agentWorkspaceScriptStageStatusCompleted,
        detail: l10n.agentWorkspaceScriptStageDetailScriptBodyReady,
        domainTool: 'get_script_content',
        args: _scriptWindowArgs(scopeScriptId),
      )
    else if (review?.target == 'script')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleScriptBody,
        statusLabel: review!.grade == 'A' || review.grade == 'B'
            ? l10n.agentWorkspaceScriptStageStatusReusable
            : l10n.agentWorkspaceScriptStageStatusNeedsRevision,
        detail: review.summary.isEmpty
            ? l10n.agentWorkspaceScriptStageDetailReviewScriptEmpty
            : l10n.agentWorkspaceScriptStageDetailReviewConclusion(
                review.summary,
              ),
        domainTool: 'get_script_content',
        args: _scriptTailWindowArgs(scopeScriptId),
        subAgentTool: review.nextAction == 'revise_script'
            ? 'run_sub_agent_script'
            : null,
        prompt: review.nextAction == 'revise_script'
            ? l10n.agentWorkspaceScriptStagePromptReviseScript
            : null,
      )
    else if (normalizedTool == 'get_script_content' ||
        normalizedTool == 'run_sub_agent_script')
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleScriptBody,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingGenerate,
        detail: l10n.agentWorkspaceScriptStageDetailScriptPendingGen,
        subAgentTool: 'run_sub_agent_script',
        prompt: l10n.agentWorkspaceScriptStagePromptGenerateScript,
      )
    else
      ScriptWorkspaceStage(
        title: l10n.agentWorkspaceScriptStageTitleScriptBody,
        statusLabel: l10n.agentWorkspaceScriptStageStatusPendingRead,
        detail: l10n.agentWorkspaceScriptStageDetailScriptPendingRead,
        domainTool: 'get_script_content',
        args: _scriptWindowArgs(scopeScriptId),
      ),
  ];
}
