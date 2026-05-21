part of '../../../home_page.dart';

class _StoryboardBatchWorkbenchDialog extends StatefulWidget {
  const _StoryboardBatchWorkbenchDialog({
    required this.token,
    required this.projectId,
    required this.scriptNumericId,
    required this.boardsList,
    required this.onMutationStart,
    required this.onMutationEnd,
  });

  final String token;
  final String projectId;
  final int scriptNumericId;
  final List<StoryboardRow> boardsList;
  final VoidCallback onMutationStart;
  final VoidCallback onMutationEnd;

  @override
  State<_StoryboardBatchWorkbenchDialog> createState() =>
      _StoryboardBatchWorkbenchDialogState();
}

class _StoryboardBatchWorkbenchDialogState
    extends State<_StoryboardBatchWorkbenchDialog> {
  late final _StoryboardBatchWorkbenchControllers _ctrls;

  final Set<int> _selectedIds = {};
  List<ProductionStoryboardItemV1> _productionRows = const [];
  String? _cachedProductionDataVersion;
  bool _loadingProduction = false;
  bool _busyMutation = false;
  String? _statusLine;
  String? _previewUrl;
  String? _downloadUrl;
  StoryboardExportBundleSummary? _exportSummary;

  void _applyBatchWorkbenchState(VoidCallback action) {
    setState(action);
  }

  @override
  void initState() {
    super.initState();
    _ctrls = _StoryboardBatchWorkbenchControllers.create();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshProduction();
    });
  }

  @override
  void dispose() {
    _ctrls.dispose();
    super.dispose();
  }

  Map<int, ProductionStoryboardItemV1> _productionById() => {
    for (final row in _productionRows) row.id: row,
  };

  List<int> _sortedSelection() {
    final values = _selectedIds.toList()..sort();
    return values;
  }

  List<int> _readyStoryboardIds() {
    final productionMap = _productionById();
    return widget.boardsList
        .where(
          (row) =>
              resolveStoryboardGenerationPrompt(
                scriptStoryboard: row,
                productionStoryboard: productionMap[row.numericId],
              ) !=
              null,
        )
        .map((row) => row.numericId)
        .toList(growable: false);
  }

  StoryboardRow? _findScriptRow(int numericId) {
    for (final row in widget.boardsList) {
      if (row.numericId == numericId) return row;
    }
    return null;
  }

  void _clearSelectionScopedOutputs() {
    _previewUrl = null;
    _downloadUrl = null;
    _exportSummary = null;
  }

  StoryboardBatchWorkbenchDiagnosis _currentDiagnosis() =>
      diagnoseStoryboardBatchWorkbench(
        resolveAppLocalizationsForErrors(context),
        selectedIds: _selectedIds,
        boards: widget.boardsList,
        productionRows: _productionRows,
      );

  StoryboardExportBundleSummary? _currentExportEstimate() {
    if (_selectedIds.isEmpty) {
      return null;
    }
    return buildStoryboardExportBundleSummary(
      selectedIds: _selectedIds,
      boards: widget.boardsList,
      productionRows: _productionRows,
    );
  }

  String _storyboardMetaLine(
    AppLocalizations l10n,
    StoryboardRow row,
    ProductionStoryboardItemV1? productionRow,
  ) {
    final idx = row.sbIndex ?? productionRow?.sbIndex;
    final parts = <String>[
      if (idx != null) l10n.scriptEditorStoryboardsRowOrder(idx),
      if ((row.state ?? productionRow?.state ?? '').trim().isNotEmpty)
        l10n.scriptEditorStoryboardsRowState(
          (row.state ?? productionRow?.state)!.trim(),
        ),
      if ((row.duration ?? productionRow?.duration ?? '').trim().isNotEmpty)
        l10n.scriptEditorStoryboardsRowDuration(
          (row.duration ?? productionRow?.duration)!.trim(),
        ),
      if ((row.filePath ?? productionRow?.url ?? '').trim().isNotEmpty)
        l10n.scriptEditorStoryboardBatchHasImage,
    ];
    return parts.isEmpty
        ? l10n.scriptEditorStoryboardBatchMetaIncomplete
        : parts.join(' · ');
  }

  Future<void> _refreshProduction() async {
    final previousSingleSelectedId = _sortedSelection().length == 1
        ? _sortedSelection().first
        : null;
    setState(() {
      _loadingProduction = true;
      _statusLine = null;
    });
    try {
      final storyboardIds = widget.boardsList
          .map((row) => row.numericId)
          .toList(growable: false);
      final response = await postProductionGetProductionDataV1(
        widget.token,
        projectUuid: widget.projectId,
        scriptId: widget.scriptNumericId,
        storyboardIds: storyboardIds,
        clientDataVersion: _cachedProductionDataVersion,
      );
      final ids = storyboardIds.toSet();
      final filtered = response.unchanged
          ? _productionRows
          : response.data
                .where((row) => ids.contains(row.id))
                .toList(growable: false);
      if (response.dataVersion != null && response.dataVersion!.isNotEmpty) {
        _cachedProductionDataVersion = response.dataVersion;
      }
      final nextSelectedIds = <int>{
        ..._selectedIds.where((id) => ids.contains(id)),
      };
      final nextSingleSelectedId = nextSelectedIds.length == 1
          ? nextSelectedIds.first
          : null;
      if (!mounted) return;
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _productionRows = filtered;
        _selectedIds
          ..clear()
          ..addAll(nextSelectedIds);
        if (previousSingleSelectedId != nextSingleSelectedId) {
          _clearSelectionScopedOutputs();
        }
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          l10n,
          actionSummary: filtered.isEmpty
              ? l10n.scriptEditorStoryboardBatchSyncProductionEmpty
              : l10n.scriptEditorStoryboardBatchSyncProductionCount(
                  filtered.length,
                ),
          diagnosis: _currentDiagnosis(),
        );
      });
    } catch (e) {
      if (mounted) {
        final loc = resolveAppLocalizationsForErrors(context);
        setState(
          () => _statusLine = loc.scriptEditorStoryboardBatchLoadProductionFailed(
            describeUserVisibleApiErrorResolved(context, e),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingProduction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final productionMap = _productionById();
    final selected = _sortedSelection();
    final singleSelectedId = selected.length == 1 ? selected.first : null;
    final diagnosis = _currentDiagnosis();

    VoidCallback? recommendedAction;
    String recommendedActionLabel;
    switch (diagnosis.recommendedAction) {
      case StoryboardBatchWorkbenchRecommendedAction.syncProductionSummary:
        recommendedAction = _loadingProduction || _busyMutation
            ? null
            : _refreshProduction;
        recommendedActionLabel = _loadingProduction
            ? l10n.scriptEditorStoryboardsRefreshing
            : describeStoryboardBatchWorkbenchRecommendedAction(
                l10n,
                diagnosis.recommendedAction,
              );
      case StoryboardBatchWorkbenchRecommendedAction.selectReadyStoryboards:
        recommendedAction = _busyMutation ? null : _selectReadyStoryboards;
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              l10n,
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.generateSelected:
        recommendedAction =
            _busyMutation ||
                (_selectedIds.isEmpty && _readyStoryboardIds().isEmpty)
            ? null
            : () => _runMutation(_batchGenerate);
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              l10n,
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.previewSelected:
        recommendedAction = _busyMutation || singleSelectedId == null
            ? null
            : () => _runMutation(() => _loadCurrentPreview(singleSelectedId));
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              l10n,
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.exportSelected:
        recommendedAction = _busyMutation || _selectedIds.isEmpty
            ? null
            : () => _runMutation(() => _exportSelectedZip(selected));
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              l10n,
              diagnosis.recommendedAction,
            );
    }

    return StudioAlertDialog(
      title: Text(l10n.scriptEditorStoryboardBatchDialogTitle),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.scriptEditorStoryboardBatchDialogIntro,
              style: studioHintStyle(context),
            ),
            const SizedBox(height: 12),
            _buildDiagnosisCard(
              context,
              diagnosis,
              recommendedAction,
              recommendedActionLabel,
            ),
            const SizedBox(height: 12),
            _buildBatchWorkbenchTopActions(),
            const SizedBox(height: 8),
            _buildBatchWorkbenchPromptSection(),
            const SizedBox(height: 8),
            _buildBatchWorkbenchModelSection(),
            const SizedBox(height: 12),
            _buildBatchWorkbenchMutationActions(
              selected: selected,
              singleSelectedId: singleSelectedId,
            ),
            if (_statusLine != null) ...[
              const SizedBox(height: 8),
              Text(_statusLine!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: Row(
                children: [
                  Expanded(
                    child: _buildBatchWorkbenchBoardsList(
                      productionMap: productionMap,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBatchWorkbenchPreviewPanel(
                      context: context,
                      singleSelectedId: singleSelectedId,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busyMutation ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.projectEditorScriptsWorkbenchDialogClose),
        ),
      ],
    );
  }

  Widget _buildDiagnosisCard(
    BuildContext context,
    StoryboardBatchWorkbenchDiagnosis diagnosis,
    VoidCallback? recommendedAction,
    String recommendedActionLabel,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: studioRecessedPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diagnosis.summary,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(diagnosis.detail, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: recommendedAction,
            child: Text(recommendedActionLabel),
          ),
        ],
      ),
    );
  }
}
