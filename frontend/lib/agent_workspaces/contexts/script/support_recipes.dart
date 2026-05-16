part of 'support.dart';

List<ScriptWorkspaceRecipe> buildScriptWorkspaceRecipes({
  required AppLocalizations l10n,
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
      return _buildPlanDataRecipes(l10n, result, scopeScriptId: scopeScriptId);
    case 'get_novel_text':
      return _buildNovelTextRecipes(l10n, result, scopeScriptId: scopeScriptId);
    case 'get_novel_events':
      return _buildNovelEventRecipes(
        l10n,
        result,
        scopeScriptId: scopeScriptId,
      );
    case 'get_script_content':
      return _buildScriptContentRecipes(l10n, result);
    case 'run_supervision_agent':
      return _buildScriptSupervisionRecipes(
        l10n,
        result,
        scopeScriptId: scopeScriptId,
      );
    default:
      return const <ScriptWorkspaceRecipe>[];
  }
}

List<ScriptWorkspaceRecipe> _buildPlanDataRecipes(
  AppLocalizations l10n,
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final data = _extractPlanDataMap(result);
  if (data is! Map<String, dynamic>) {
    return const <ScriptWorkspaceRecipe>[];
  }
  final storySkeleton = (data['storySkeleton'] as String?)?.trim() ?? '';
  final adaptationStrategy =
      (data['adaptationStrategy'] as String?)?.trim() ?? '';
  final scriptRows = data['script'];
  final hasPlanScriptDrafts = scriptRows is List && scriptRows.isNotEmpty;
  final recipes = <ScriptWorkspaceRecipe>[];

  if (storySkeleton.isEmpty) {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeFillStorySkeletonTitle,
        detail: l10n.agentWorkspaceScriptRecipeFillStorySkeletonDetail,
        subAgentTool: 'run_sub_agent_storySkeleton',
        prompt: l10n.agentWorkspaceScriptRecipeFillStorySkeletonPrompt,
      ),
    );
  }
  if (adaptationStrategy.isEmpty) {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeFillAdaptationTitle,
        detail: l10n.agentWorkspaceScriptRecipeFillAdaptationDetail,
        subAgentTool: 'run_sub_agent_adaptationStrategy',
        prompt: l10n.agentWorkspaceScriptRecipeFillAdaptationPrompt,
      ),
    );
  }
  if (scopeScriptId != null) {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeReadScriptBodyTitle,
        detail: l10n.agentWorkspaceScriptRecipeReadScriptBodyDetail,
        domainTool: 'get_script_content',
        args: _scriptTailWindowArgs(scopeScriptId),
      ),
    );
  }
  if (hasPlanScriptDrafts) {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeReadPlanScriptDraftTitle,
        detail: l10n.agentWorkspaceScriptRecipeReadPlanScriptDraftDetail,
        domainTool: 'get_planData',
        args: _planScriptWindowArgs(scopeScriptId),
      ),
    );
  }
  if (scriptRows is List && scriptRows.isEmpty) {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipePullChapterMaterialTitle,
        detail: l10n.agentWorkspaceScriptRecipePullChapterMaterialDetail,
        domainTool: 'get_novel_text',
        args: _novelTextWindowArgs(null),
      ),
    );
  } else {
    recipes.add(
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeGenerateNextScriptTitle,
        detail: l10n.agentWorkspaceScriptRecipeGenerateNextScriptDetail,
        subAgentTool: 'run_sub_agent_script',
        prompt: l10n.agentWorkspaceScriptRecipeGenerateNextScriptPrompt,
      ),
    );
  }
  return recipes.take(3).toList(growable: false);
}

List<ScriptWorkspaceRecipe> _buildNovelTextRecipes(
  AppLocalizations l10n,
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final ids = extractScriptWorkspaceNovelIds(result);
  if (ids.isEmpty) {
    return <ScriptWorkspaceRecipe>[
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipePreferEventsTitle,
        detail: l10n.agentWorkspaceScriptRecipePreferEventsDetail,
        domainTool: 'get_novel_events',
      ),
    ];
  }
  return <ScriptWorkspaceRecipe>[
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeReadMatchingEventsTitle,
      detail: l10n.agentWorkspaceScriptRecipeReadMatchingEventsDetail,
      domainTool: 'get_novel_events',
      args: _novelEventWindowArgs(ids.first),
    ),
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeGenerateAdaptationFromTextTitle,
      detail: l10n.agentWorkspaceScriptRecipeGenerateAdaptationFromTextDetail,
      subAgentTool: 'run_sub_agent_adaptationStrategy',
      prompt: l10n.agentWorkspaceScriptRecipeGenerateAdaptationFromTextPrompt,
    ),
    if (scopeScriptId != null)
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeReviewPreviousTailTitle,
        detail: l10n.agentWorkspaceScriptRecipeReviewPreviousTailDetail,
        domainTool: 'get_script_content',
        args: _scriptTailWindowArgs(scopeScriptId),
      ),
  ];
}

List<ScriptWorkspaceRecipe> _buildNovelEventRecipes(
  AppLocalizations l10n,
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final items = _extractResultItems(result);
  if (items.isEmpty) {
    return <ScriptWorkspaceRecipe>[
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipePullChapterTextFirstTitle,
        detail: l10n.agentWorkspaceScriptRecipePullChapterTextFirstDetail,
        domainTool: 'get_novel_text',
      ),
    ];
  }
  return <ScriptWorkspaceRecipe>[
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeDistillSkeletonFromEventsTitle,
      detail: l10n.agentWorkspaceScriptRecipeDistillSkeletonFromEventsDetail,
      subAgentTool: 'run_sub_agent_storySkeleton',
      prompt: l10n.agentWorkspaceScriptRecipeDistillSkeletonFromEventsPrompt,
    ),
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeGenerateScriptFromEventsTitle,
      detail: l10n.agentWorkspaceScriptRecipeGenerateScriptFromEventsDetail,
      subAgentTool: 'run_sub_agent_script',
      prompt: l10n.agentWorkspaceScriptRecipeGenerateScriptFromEventsPrompt,
    ),
    if (scopeScriptId != null)
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeCompareExistingScriptTitle,
        detail: l10n.agentWorkspaceScriptRecipeCompareExistingScriptDetail,
        domainTool: 'get_script_content',
        args: _scriptTailWindowArgs(scopeScriptId),
      ),
  ];
}

List<ScriptWorkspaceRecipe> _buildScriptContentRecipes(
  AppLocalizations l10n,
  Map<String, dynamic> result,
) {
  final content = (result['content'] as String?)?.trim() ?? '';
  if (content.isEmpty) {
    return <ScriptWorkspaceRecipe>[
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeGenerateScriptBodyTitle,
        detail: l10n.agentWorkspaceScriptRecipeGenerateScriptBodyDetail,
        subAgentTool: 'run_sub_agent_script',
        prompt: l10n.agentWorkspaceScriptRecipeGenerateScriptBodyPrompt,
      ),
      ScriptWorkspaceRecipe(
        title: l10n.agentWorkspaceScriptRecipeRefreshPlanDataTitle,
        detail: l10n.agentWorkspaceScriptRecipeRefreshPlanDataDetail,
        domainTool: 'get_planData',
        args: _planSectionArgs('storySkeleton'),
      ),
    ];
  }
  return <ScriptWorkspaceRecipe>[
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeRefreshPlanAfterBodyTitle,
      detail: l10n.agentWorkspaceScriptRecipeRefreshPlanAfterBodyDetail,
      domainTool: 'get_planData',
      args: <String, dynamic>{'key': 'storySkeleton', 'maxChars': 1600},
    ),
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeAddChapterMaterialTitle,
      detail: l10n.agentWorkspaceScriptRecipeAddChapterMaterialDetail,
      domainTool: 'get_novel_text',
      args: _novelTextWindowArgs(null),
    ),
  ];
}

List<ScriptWorkspaceRecipe> _buildScriptSupervisionRecipes(
  AppLocalizations l10n,
  Map<String, dynamic> result, {
  required int? scopeScriptId,
}) {
  final review = parseScriptWorkspaceReview(result);
  if (review == null) {
    return const <ScriptWorkspaceRecipe>[];
  }

  final recipes = <ScriptWorkspaceRecipe>[];
  switch (review.nextAction) {
    case 'revise_storySkeleton':
      recipes.add(
        ScriptWorkspaceRecipe(
          title: l10n.agentWorkspaceScriptRecipeReviseStorySkeletonTitle,
          detail: l10n.agentWorkspaceScriptRecipeReviseStorySkeletonDetail,
          domainTool: 'get_planData',
          args: <String, dynamic>{'key': 'storySkeleton', 'maxChars': 1600},
          subAgentTool: 'run_sub_agent_storySkeleton',
          prompt: l10n.agentWorkspaceScriptRecipeReviseStorySkeletonPrompt,
        ),
      );
      break;
    case 'revise_adaptationStrategy':
      recipes.add(
        ScriptWorkspaceRecipe(
          title: l10n.agentWorkspaceScriptRecipeReviseAdaptationTitle,
          detail: l10n.agentWorkspaceScriptRecipeReviseAdaptationDetail,
          domainTool: 'get_planData',
          args: <String, dynamic>{
            'key': 'adaptationStrategy',
            'maxChars': 1600,
          },
          subAgentTool: 'run_sub_agent_adaptationStrategy',
          prompt: l10n.agentWorkspaceScriptRecipeReviseAdaptationPrompt,
        ),
      );
      break;
    case 'revise_script':
      recipes.add(
        ScriptWorkspaceRecipe(
          title: l10n.agentWorkspaceScriptRecipeReviseScriptTitle,
          detail: l10n.agentWorkspaceScriptRecipeReviseScriptDetail,
          domainTool: 'get_script_content',
          args: _scriptTailWindowArgs(scopeScriptId),
          subAgentTool: 'run_sub_agent_script',
          prompt: l10n.agentWorkspaceScriptRecipeReviseScriptPrompt,
        ),
      );
      break;
    case 'check_novel_events':
      recipes.add(
        ScriptWorkspaceRecipe(
          title: l10n.agentWorkspaceScriptRecipeVerifyEventsTitle,
          detail: l10n.agentWorkspaceScriptRecipeVerifyEventsDetail,
          domainTool: 'get_novel_events',
          args: <String, dynamic>{
            'fields': <String>['numeric_id', 'name', 'detail'],
            'limit': 8,
            'maxChars': 1200,
          },
        ),
      );
      break;
    case 'check_novel_text':
      recipes.add(
        ScriptWorkspaceRecipe(
          title: l10n.agentWorkspaceScriptRecipeAddNovelTextWindowTitle,
          detail: l10n.agentWorkspaceScriptRecipeAddNovelTextWindowDetail,
          domainTool: 'get_novel_text',
          args: <String, dynamic>{
            'fields': <String>['numeric_id', 'chapter', 'chapter_data'],
            'lineStart': 1,
            'lineEnd': 80,
            'maxChars': 1800,
            'limit': 1,
          },
        ),
      );
      break;
    case 'check_script':
      recipes.add(
        ScriptWorkspaceRecipe(
          title: l10n.agentWorkspaceScriptRecipeRereadCurrentScriptTitle,
          detail: l10n.agentWorkspaceScriptRecipeRereadCurrentScriptDetail,
          domainTool: 'get_script_content',
          args: _scriptTailWindowArgs(scopeScriptId),
        ),
      );
      break;
  }

  recipes.add(
    ScriptWorkspaceRecipe(
      title: l10n.agentWorkspaceScriptRecipeReviewTargetPeekTitle,
      detail: l10n.agentWorkspaceScriptRecipeReviewTargetPeekDetail,
      domainTool: review.target == 'script'
          ? 'get_script_content'
          : 'get_planData',
      args: review.target == 'script'
          ? _scriptTailWindowArgs(scopeScriptId)
          : _planSectionArgs(review.target),
    ),
  );

  return recipes.take(3).toList(growable: false);
}
