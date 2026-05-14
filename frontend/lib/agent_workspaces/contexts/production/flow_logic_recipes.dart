part of 'flow_logic.dart';

List<ProductionWorkspaceRecipe> buildProductionWorkspaceRecipes({
  required AppLocalizations l10n,
  required String? toolName,
  required String? suggestedFlowKey,
  required Object? result,
  Map<String, dynamic>? toolArguments,
}) {
  final normalizedTool = toolName?.trim() ?? '';
  if (normalizedTool.isEmpty || result is! Map<String, dynamic>) {
    return const <ProductionWorkspaceRecipe>[];
  }
  final review = parseProductionSupervisionReview(result);
  if (normalizedTool == 'run_sub_agent_production_supervision' &&
      review != null) {
    return _buildSupervisionRecipes(l10n, review);
  }
  final normalizedKey = suggestedFlowKey?.trim() ?? '';

  if (normalizedTool == 'get_flowData') {
    final data = result['data'];
    switch (normalizedKey) {
      case 'assets':
        return _buildAssetRecipes(l10n, data);
      case 'storyboard':
        return _buildStoryboardRecipes(l10n, data);
      case 'scriptPlan':
        return _buildScriptPlanRecipes(l10n, data);
      case 'storyboardTable':
        return _buildStoryboardTableRecipes(l10n, data);
      default:
        return const <ProductionWorkspaceRecipe>[];
    }
  }

  if (normalizedTool == 'generate_storyboard' ||
      normalizedTool == 'run_sub_agent_storyboard_gen' ||
      normalizedTool == 'run_sub_agent_storyboard_panel') {
    final affectedIds = extractProductionActionCandidateIds(
      selectedTool: 'generate_storyboard',
      toolName: toolName,
      suggestedFlowKey: suggestedFlowKey,
      result: result,
      toolArguments: toolArguments,
    );
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeSbGenRefreshTitle
            : l10n.agentWorkspaceProductionFlowRecipeSbGenRereadTitle,
        detail: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeSbGenRefreshDetail
            : l10n.agentWorkspaceProductionFlowRecipeSbGenRereadDetail(
                affectedIds.join(', '),
              ),
        flowKey: 'storyboard',
        domainTool: 'get_flowData',
        domainArgs: buildProductionStoryboardGenerationArgs(ids: affectedIds),
      ),
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeContinueDirectorTitle,
        detail: l10n
            .agentWorkspaceProductionFlowRecipeContinueDirectorAfterSbDetail,
        flowKey: 'scriptPlan',
        domainTool: 'get_flowData',
        subAgentTool: 'run_sub_agent_director_plan',
      ),
    ];
  }

  if (normalizedTool == 'run_sub_agent_storyboard_table') {
    final affectedIds = extractProductionStoryboardPromptScopeIds(
      normalizedTool,
      toolArguments,
    );
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeSbTableRefreshTitle
            : l10n.agentWorkspaceProductionFlowRecipeSbTablePartialTitle,
        detail: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeSbTableRefreshDetail
            : l10n.agentWorkspaceProductionFlowRecipeSbTablePartialDetail(
                affectedIds.join(', '),
              ),
        flowKey: 'storyboardTable',
        domainTool: 'get_flowData',
        domainArgs: buildProductionStoryboardTableReadArgs(ids: affectedIds),
      ),
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeSbTableCrosscheckTitle,
        detail: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeSbTableCrosscheckDetailAll
            : l10n.agentWorkspaceProductionFlowRecipeSbTableCrosscheckDetailFocused(
                affectedIds.join(', '),
              ),
        flowKey: 'storyboard',
        domainTool: 'get_flowData',
        domainArgs: buildProductionStoryboardReviewArgs(ids: affectedIds),
      ),
    ];
  }

  if (normalizedTool == 'generate_deriveAsset' ||
      normalizedTool == 'run_sub_agent_generate_assets' ||
      normalizedTool == 'add_deriveAsset' ||
      normalizedTool == 'del_deriveAsset') {
    final affectedIds =
        normalizedTool == 'generate_deriveAsset' ||
            normalizedTool == 'run_sub_agent_generate_assets'
        ? extractProductionActionCandidateIds(
            selectedTool: 'generate_deriveAsset',
            toolName: toolName,
            suggestedFlowKey: suggestedFlowKey,
            result: result,
            toolArguments: toolArguments,
          )
        : const <int>[];
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeAssetsRefreshTitle
            : l10n.agentWorkspaceProductionFlowRecipeAssetsRereadTitle,
        detail: affectedIds.isEmpty
            ? l10n.agentWorkspaceProductionFlowRecipeAssetsRefreshDetail
            : l10n.agentWorkspaceProductionFlowRecipeAssetsRereadDetail(
                affectedIds.join(', '),
              ),
        flowKey: 'assets',
        domainTool: 'get_flowData',
        domainArgs: buildProductionAssetReadArgs(ids: affectedIds),
      ),
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeAssetsContinueSubTitle,
        detail: l10n.agentWorkspaceProductionFlowRecipeAssetsContinueSubDetail,
        flowKey: 'assets',
        subAgentTool: 'run_sub_agent_generate_assets',
        subAgentArgs: buildProductionSubAgentArgs(assetIds: affectedIds),
        prompt: buildProductionAssetGenerationPrompt(
          l10n: l10n,
          assetIds: affectedIds,
          summary: affectedIds.isEmpty
              ? null
              : l10n.agentWorkspaceProductionFlowRecipeAssetsGenHadSummaryNote,
        ),
      ),
    ];
  }

  return const <ProductionWorkspaceRecipe>[];
}

List<ProductionWorkspaceRecipe> _buildAssetRecipes(
  AppLocalizations l10n,
  Object? data,
) {
  if (data is List && data.isEmpty) {
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeAssetsPlanFirstTitle,
        detail: l10n.agentWorkspaceProductionFlowRecipeAssetsPlanFirstDetail,
        flowKey: 'assets',
        subAgentTool: 'run_sub_agent_derive_assets',
        prompt: l10n.agentWorkspaceProductionFlowRecipeAssetsPlanFirstPrompt,
      ),
    ];
  }
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    final withoutUrl = rows.where((row) {
      return !productionFlowEntryHasMediaResult(row);
    }).length;
    final pendingDeriveIds = extractProductionPendingDeriveAssetIds(rows);
    final pendingScope = summarizeProductionAssetFocusIds(
      l10n,
      pendingDeriveIds,
    );
    if (withoutUrl > 0) {
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeAssetsContinueGenTitle,
          detail: pendingScope.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeAssetsContinueGenDetailGeneric
              : l10n.agentWorkspaceProductionFlowRecipeAssetsGenDetailScoped(
                  pendingScope,
                ),
          flowKey: 'assets',
          subAgentTool: 'run_sub_agent_generate_assets',
          subAgentArgs: buildProductionSubAgentArgs(assetIds: pendingDeriveIds),
          prompt: buildProductionAssetGenerationPrompt(
            l10n: l10n,
            assetIds: pendingDeriveIds,
          ),
        ),
        ProductionWorkspaceRecipe(
          title:
              l10n.agentWorkspaceProductionFlowRecipeRefreshStoryboardNeedTitle,
          detail: l10n
              .agentWorkspaceProductionFlowRecipeRefreshStoryboardNeedDetail,
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
          domainArgs: buildProductionStoryboardReviewArgs(),
        ),
      ];
    }
  }
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeCheckStoryboardFlowTitle,
      detail: l10n.agentWorkspaceProductionFlowRecipeCheckStoryboardFlowDetail,
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardReviewArgs(),
    ),
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeTidyDirectorPlanTitle,
      detail: l10n.agentWorkspaceProductionFlowRecipeTidyDirectorPlanDetail,
      flowKey: 'scriptPlan',
      subAgentTool: 'run_sub_agent_director_plan',
      prompt: l10n.agentWorkspaceProductionFlowRecipeTidyDirectorPlanPrompt,
    ),
  ];
}

List<ProductionWorkspaceRecipe> _buildStoryboardRecipes(
  AppLocalizations l10n,
  Object? data,
) {
  if (data is List && data.isEmpty) {
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeFirstStoryboardTitle,
        detail: l10n.agentWorkspaceProductionFlowRecipeFirstStoryboardDetail,
        flowKey: 'storyboard',
        subAgentTool: 'run_sub_agent_storyboard_gen',
        prompt: l10n.agentWorkspaceProductionFlowRecipeFirstStoryboardPrompt,
      ),
    ];
  }
  if (data is List) {
    final rows = data.whereType<Map<String, dynamic>>().toList(growable: false);
    final missingIds = extractProductionStoryboardMissingImageIds(rows);
    final assetArgs = buildProductionFlowAssetArgs(rows);
    final promptAssetIds = extractProductionReferencedAssetIdsForStoryboardIds(
      rows,
      missingIds,
    );
    if (missingIds.isNotEmpty) {
      final idsLabel = missingIds.take(6).join(', ');
      final idTail = missingIds.length > 6
          ? l10n.agentWorkspaceProductionFlowRecipeShotCountTail(
              missingIds.length,
            )
          : '';
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title:
              l10n.agentWorkspaceProductionFlowRecipeFillStoryboardFramesTitle,
          detail: l10n.agentWorkspaceProductionFlowRecipeSbFillGapDetail(
            idTail,
            idsLabel,
          ),
          flowKey: 'storyboard',
          subAgentTool: 'run_sub_agent_storyboard_gen',
          subAgentArgs: buildProductionSubAgentArgs(
            storyboardIds: missingIds,
            assetIds: promptAssetIds,
          ),
          prompt: l10n
              .agentWorkspaceProductionFlowRecipePromptStoryboardContinue(
                buildProductionStoryboardGenerationPrompt(
                  l10n: l10n,
                  storyboardIds: missingIds,
                  assetIds: promptAssetIds,
                ),
              ),
        ),
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTitle,
          detail: assetArgs.containsKey('ids')
              ? l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailFromRefs
              : l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailNoIds,
          flowKey: 'assets',
          domainTool: 'get_flowData',
          domainArgs: assetArgs,
        ),
        ProductionWorkspaceRecipe(
          title:
              l10n.agentWorkspaceProductionFlowRecipeCheckStoryboardTableTitle,
          detail:
              l10n.agentWorkspaceProductionFlowRecipeCheckStoryboardTableDetail,
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionStoryboardTableReadArgs(ids: missingIds),
        ),
      ];
    }
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTitle,
        detail: assetArgs.containsKey('ids')
            ? l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailReadyIds
            : l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailReadyNoIds,
        flowKey: 'assets',
        domainTool: 'get_flowData',
        domainArgs: assetArgs,
      ),
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeRefreshDirectorPlanTitle,
        detail:
            l10n.agentWorkspaceProductionFlowRecipeRefreshDirectorPlanDetail,
        flowKey: 'scriptPlan',
        domainTool: 'get_flowData',
        subAgentTool: 'run_sub_agent_director_plan',
      ),
    ];
  }
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeRefreshDirectorPlanTitle,
      detail: l10n.agentWorkspaceProductionFlowRecipeRefreshDirectorPlanDetail,
      flowKey: 'scriptPlan',
      domainTool: 'get_flowData',
      subAgentTool: 'run_sub_agent_director_plan',
    ),
  ];
}

List<ProductionWorkspaceRecipe> _buildScriptPlanRecipes(
  AppLocalizations l10n,
  Object? data,
) {
  if (data is String && data.trim().isEmpty) {
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title: l10n.agentWorkspaceProductionFlowRecipeCreateDirectorPlanTitle,
        detail: l10n.agentWorkspaceProductionFlowRecipeCreateDirectorPlanDetail,
        flowKey: 'scriptPlan',
        subAgentTool: 'run_sub_agent_director_plan',
        prompt: l10n.agentWorkspaceProductionFlowRecipeCreateDirectorPlanPrompt,
      ),
    ];
  }
  final assetArgs = buildProductionScriptPlanAssetArgs(data);
  final assetScope = summarizeProductionAssetScope(l10n, assetArgs);
  final scriptWindow = summarizeProductionPlanningScriptWindow(l10n);
  final directorPlanArgs = buildProductionScriptPlanSubAgentArgs(data);
  final needsStoryboardIntentRefinement =
      _productionScriptPlanAdvanceReady(data) &&
      !_productionScriptPlanStoryboardReady(data);
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeReviewDirectorPlanTitle,
      detail: l10n.agentWorkspaceProductionFlowRecipeReviewDirectorPlanDetail,
      flowKey: 'scriptPlan',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt: l10n.agentWorkspaceProductionFlowRecipeReviewDirectorPlanPrompt,
    ),
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeRereadScriptTitle,
      detail: l10n
          .agentWorkspaceProductionFlowRecipeRereadScriptScriptPlanDetail(
            scriptWindow,
          ),
      flowKey: 'script',
      domainTool: 'get_flowData',
      domainArgs: buildProductionPlanningScriptArgs(),
    ),
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeCheckKeyAssetsTitle,
      detail: assetArgs.containsKey('ids')
          ? l10n.agentWorkspaceProductionFlowRecipeCheckKeyAssetsDetailIds(
              assetScope,
            )
          : l10n.agentWorkspaceProductionFlowRecipeCheckKeyAssetsDetailNoIds(
              assetScope,
            ),
      flowKey: 'assets',
      domainTool: 'get_flowData',
      domainArgs: assetArgs,
    ),
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeContinueDirectorTitle,
      detail: assetArgs.containsKey('ids')
          ? l10n.agentWorkspaceProductionFlowRecipeContinueDirectorDetailIds(
              assetScope,
            )
          : l10n.agentWorkspaceProductionFlowRecipeContinueDirectorDetailNoIds(
              assetScope,
            ),
      flowKey: 'scriptPlan',
      subAgentTool: 'run_sub_agent_director_plan',
      subAgentArgs: directorPlanArgs,
      prompt: assetArgs.containsKey('ids')
          ? l10n.agentWorkspaceProductionFlowRecipeContinueDirectorPromptIds(
              assetScope,
            )
          : l10n.agentWorkspaceProductionFlowRecipeContinueDirectorPromptNoIds(
              assetScope,
            ),
    ),
    ProductionWorkspaceRecipe(
      title: needsStoryboardIntentRefinement
          ? l10n.agentWorkspaceProductionFlowRecipeRefineSceneIntentTitle
          : l10n.agentWorkspaceProductionFlowRecipePreviewStoryboardTableTitle,
      detail: needsStoryboardIntentRefinement
          ? l10n.agentWorkspaceProductionFlowRecipeRefineSceneIntentDetail
          : l10n.agentWorkspaceProductionFlowRecipePreviewStoryboardTableDetail,
      flowKey: 'storyboardTable',
      domainTool: needsStoryboardIntentRefinement ? null : 'get_flowData',
      domainArgs: needsStoryboardIntentRefinement
          ? null
          : buildProductionStoryboardTableReadArgs(),
      subAgentTool: needsStoryboardIntentRefinement
          ? 'run_sub_agent_director_plan'
          : null,
      subAgentArgs: needsStoryboardIntentRefinement ? directorPlanArgs : null,
      prompt: needsStoryboardIntentRefinement
          ? l10n.agentWorkspaceProductionFlowRecipeRefineSceneIntentPrompt
          : null,
      uiKind: needsStoryboardIntentRefinement
          ? ProductionWorkspaceRecipeUiKind.refineIntentBeforeTable
          : ProductionWorkspaceRecipeUiKind.previewStoryboardTableBeforeFrames,
    ),
  ];
}

List<ProductionWorkspaceRecipe> _buildStoryboardTableRecipes(
  AppLocalizations l10n,
  Object? data,
) {
  if (data is String && data.trim().isEmpty) {
    return <ProductionWorkspaceRecipe>[
      ProductionWorkspaceRecipe(
        title:
            l10n.agentWorkspaceProductionFlowRecipeCreateStoryboardTableTitle,
        detail:
            l10n.agentWorkspaceProductionFlowRecipeCreateStoryboardTableDetail,
        flowKey: 'storyboardTable',
        subAgentTool: 'run_sub_agent_storyboard_table',
        prompt:
            l10n.agentWorkspaceProductionFlowRecipeCreateStoryboardTablePrompt,
      ),
    ];
  }
  if (!_hasStoryboardTableData(data)) {
    return const <ProductionWorkspaceRecipe>[];
  }
  final assetArgs = _storyboardTableRelatedAssetsArgs(data);
  final storyboardIds = extractProductionStoryboardIds(data);
  final storyboardArgs = buildProductionStoryboardReviewArgs(
    ids: storyboardIds,
  );
  return <ProductionWorkspaceRecipe>[
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeReviewStoryboardTableTitle,
      detail:
          l10n.agentWorkspaceProductionFlowRecipeReviewStoryboardTableDetail,
      flowKey: 'storyboardTable',
      subAgentTool: 'run_sub_agent_production_supervision',
      prompt:
          l10n.agentWorkspaceProductionFlowRecipeReviewStoryboardTablePrompt,
    ),
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTitle,
      detail: assetArgs.containsKey('ids')
          ? l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTableRefs
          : l10n.agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTableNoIds,
      flowKey: 'assets',
      domainTool: 'get_flowData',
      domainArgs: assetArgs,
    ),
    ProductionWorkspaceRecipe(
      title:
          l10n.agentWorkspaceProductionFlowRecipeSwitchStoryboardResultsTitle,
      detail: storyboardIds.isEmpty
          ? l10n.agentWorkspaceProductionFlowRecipeSwitchStoryboardResultsDetailAll
          : l10n.agentWorkspaceProductionFlowRecipeSwitchStoryboardResultsDetailCount(
              storyboardIds.length,
            ),
      flowKey: 'storyboard',
      domainTool: 'get_flowData',
      domainArgs: storyboardArgs,
    ),
    ProductionWorkspaceRecipe(
      title: l10n.agentWorkspaceProductionFlowRecipeSampleStoryboardTableTitle,
      detail:
          l10n.agentWorkspaceProductionFlowRecipeSampleStoryboardTableDetail,
      flowKey: 'storyboardTable',
      domainTool: 'get_flowData',
      domainArgs: buildProductionStoryboardTableReadArgs(),
      uiKind: ProductionWorkspaceRecipeUiKind.sampleStoryboardTable,
    ),
  ];
}

Map<String, dynamic> _scriptPlanCompactArgs() => <String, dynamic>{
  'key': 'scriptPlan',
  'maxChars': 2200,
};

Map<String, dynamic> _assetsCompactArgs() => <String, dynamic>{
  'key': 'assets',
  'fields': <String>['id', 'name', 'type', 'src', 'flowId', 'derive'],
  'limit': 24,
};

Map<String, dynamic> _storyboardTableRelatedAssetsArgs(Object? data) {
  return buildProductionFlowAssetArgs(data);
}

bool _hasStoryboardTableData(Object? data) {
  if (data is String) return data.trim().isNotEmpty;
  if (data is Map<String, dynamic>) {
    final rows = data['rows'];
    return rows is List && rows.isNotEmpty;
  }
  return false;
}

List<ProductionWorkspaceRecipe> _buildSupervisionRecipes(
  AppLocalizations l10n,
  ProductionSupervisionReview review,
) {
  final summary = review.summary.isEmpty
      ? l10n.agentWorkspaceProductionSupervisionSummaryFallback
      : review.summary;
  final assetScope = summarizeProductionAssetReviewScope(l10n, review);
  final storyboardFocus = summarizeProductionStoryboardFocusIds(
    l10n,
    review.storyboardIds,
  );
  final reviewScope = summarizeProductionStoryboardReviewScope(
    l10n,
    review.storyboardIds,
  );
  switch (review.nextAction) {
    case 'revise_scriptPlan':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeReviseDirectorPlanTitle,
          detail: l10n
              .agentWorkspaceProductionFlowRecipeReviseDirectorPlanDetail(
                summary,
              ),
          flowKey: 'scriptPlan',
          subAgentTool: 'run_sub_agent_director_plan',
          prompt: l10n
              .agentWorkspaceProductionFlowRecipeReviseDirectorPlanPrompt(
                summary,
              ),
        ),
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeRereadScriptTitle,
          detail: l10n
              .agentWorkspaceProductionFlowRecipeRereadScriptRevisePlanDetail(
                summarizeProductionPlanningScriptWindow(l10n),
              ),
          flowKey: 'script',
          domainTool: 'get_flowData',
          domainArgs: buildProductionPlanningScriptArgs(),
        ),
        ProductionWorkspaceRecipe(
          title:
              l10n.agentWorkspaceProductionFlowRecipeRecheckAssetSupportTitle,
          detail:
              l10n.agentWorkspaceProductionFlowRecipeRecheckAssetSupportDetail,
          flowKey: 'assets',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewAssetArgs(review),
        ),
      ];
    case 'check_assets':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeVerifyAssetSupportTitle,
          detail: l10n
              .agentWorkspaceProductionFlowRecipeVerifyAssetSupportDetail(
                assetScope,
                summary,
              ),
          flowKey: 'assets',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewAssetArgs(review),
        ),
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeRereadDirectorPlanTitle,
          detail: l10n
              .agentWorkspaceProductionFlowRecipeRereadDirectorPlanAfterAssetsDetail,
          flowKey: 'scriptPlan',
          domainTool: 'get_flowData',
          domainArgs: _scriptPlanCompactArgs(),
        ),
      ];
    case 'check_storyboard':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: l10n
              .agentWorkspaceProductionFlowRecipeInspectStoryboardResultsTitle,
          detail: storyboardFocus.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailSummaryOnly(
                  summary,
                )
              : l10n.agentWorkspaceProductionFlowRecipeInspectSbResultsDetail(
                  '$storyboardFocus。${reviewScope.isEmpty ? '' : ' $reviewScope。'}',
                  summary,
                ),
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardArgs(review),
        ),
        ProductionWorkspaceRecipe(
          title: l10n
              .agentWorkspaceProductionFlowRecipeCompareStoryboardTableTitle,
          detail: storyboardFocus.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeCompareStoryboardTableDetailGeneric
              : l10n.agentWorkspaceProductionFlowRecipeCompareStoryboardTableDetailFocus(
                  storyboardFocus,
                ),
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardTableArgs(review),
        ),
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeRereadScriptTitle,
          detail: reviewScope.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeRereadScriptNeedWindowDetail
              : l10n.agentWorkspaceProductionFlowRecipeRereadScriptReviewDetail(
                  reviewScope,
                ),
          flowKey: 'script',
          domainTool: 'get_flowData',
          domainArgs: buildProductionScriptReviewArgs(review: review),
        ),
      ];
    case 'revise_storyboardTable':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title:
              l10n.agentWorkspaceProductionFlowRecipeReviseStoryboardTableTitle,
          detail: l10n
              .agentWorkspaceProductionFlowRecipeReviseDirectorPlanDetail(
                summary,
              ),
          flowKey: 'storyboardTable',
          subAgentTool: 'run_sub_agent_storyboard_table',
          subAgentArgs: buildProductionSubAgentArgs(
            storyboardIds: review.storyboardIds,
            assetIds: review.assetIds,
            assetTypes: review.assetTypes,
          ),
          prompt: l10n
              .agentWorkspaceProductionFlowRecipePromptReviseStoryboardTable(
                buildProductionStoryboardTableRevisionPrompt(l10n, review),
              ),
        ),
        ProductionWorkspaceRecipe(
          title: l10n
              .agentWorkspaceProductionFlowRecipeSampleRereadStoryboardTableTitle,
          detail: review.storyboardIds.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeSampleRereadStoryboardTableDetailEmpty
              : l10n.agentWorkspaceProductionFlowRecipeSampleRereadStoryboardTableDetailFocused,
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardTableArgs(review),
        ),
      ];
    case 'check_script':
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title: l10n.agentWorkspaceProductionFlowRecipeRereadScriptTitle,
          detail: reviewScope.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailSummaryOnly(
                  summary,
                )
              : l10n.agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailScript(
                  reviewScope,
                  summary,
                ),
          flowKey: 'script',
          domainTool: 'get_flowData',
          domainArgs: buildProductionScriptReviewArgs(review: review),
        ),
      ];
    case 'generate_storyboard':
      final storyboardArgs = buildProductionReviewStoryboardGenerationArgs(
        review,
      );
      final promptAssetIds = review.assetIds;
      return <ProductionWorkspaceRecipe>[
        ProductionWorkspaceRecipe(
          title:
              l10n.agentWorkspaceProductionFlowRecipeContinueStoryboardGenTitle,
          detail: reviewScope.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailSummaryOnly(
                  summary,
                )
              : l10n.agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailWithScope(
                  reviewScope,
                  summary,
                ),
          flowKey: 'storyboard',
          domainTool: 'get_flowData',
          domainArgs: storyboardArgs,
          subAgentTool: 'run_sub_agent_storyboard_gen',
          subAgentArgs: buildProductionSubAgentArgs(
            storyboardIds: review.storyboardIds,
            assetIds: promptAssetIds,
            assetTypes: review.assetTypes,
          ),
          prompt: l10n
              .agentWorkspaceProductionFlowRecipePromptStoryboardFromReview(
                buildProductionStoryboardGenerationPrompt(
                  l10n: l10n,
                  storyboardIds: review.storyboardIds,
                  assetIds: promptAssetIds,
                  summary: summary,
                ),
              ),
        ),
        ProductionWorkspaceRecipe(
          title: l10n
              .agentWorkspaceProductionFlowRecipeCompareStoryboardTableTitle,
          detail: storyboardFocus.isEmpty
              ? l10n.agentWorkspaceProductionFlowRecipeCompareStoryboardTableBeforeFillDetail
              : l10n.agentWorkspaceProductionFlowRecipeCompareStoryboardTableBeforeFillDetailFocus(
                  storyboardFocus,
                ),
          flowKey: 'storyboardTable',
          domainTool: 'get_flowData',
          domainArgs: buildProductionReviewStoryboardTableArgs(review),
        ),
      ];
    default:
      return const <ProductionWorkspaceRecipe>[];
  }
}
