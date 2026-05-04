part of '../../../home_page.dart';

class _StoryboardBatchWorkbenchDialog extends StatefulWidget {
  const _StoryboardBatchWorkbenchDialog({
    required this.token,
    required this.projectNumericId,
    required this.scriptNumericId,
    required this.boardsList,
    required this.onMutationStart,
    required this.onMutationEnd,
  });

  final String token;
  final int projectNumericId;
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
          (row) => resolveStoryboardGenerationPrompt(
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
    StoryboardRow row,
    ProductionStoryboardItemV1? productionRow,
  ) {
    final parts = <String>[
      if (row.sbIndex != null || productionRow?.sbIndex != null)
        '序号 ${row.sbIndex ?? productionRow?.sbIndex}',
      if ((row.state ?? productionRow?.state ?? '').trim().isNotEmpty)
        '状态 ${row.state ?? productionRow?.state}',
      if ((row.duration ?? productionRow?.duration ?? '').trim().isNotEmpty)
        '时长 ${row.duration ?? productionRow?.duration}',
      if ((row.filePath ?? productionRow?.url ?? '').trim().isNotEmpty) '已有画面',
    ];
    return parts.isEmpty ? '待补充分镜信息' : parts.join(' · ');
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
      final response = await postProductionGetStoryboardDataV1(
        widget.token,
        projectId: widget.projectNumericId,
        scriptId: widget.scriptNumericId,
      );
      final ids = widget.boardsList.map((row) => row.numericId).toSet();
      final filtered = response.data
          .where((row) => ids.contains(row.id))
          .toList(growable: false);
      final nextSelectedIds = <int>{
        ..._selectedIds.where((id) => ids.contains(id)),
      };
      if (nextSelectedIds.isEmpty && widget.boardsList.isNotEmpty) {
        nextSelectedIds.add(widget.boardsList.first.numericId);
      }
      final nextSingleSelectedId = nextSelectedIds.length == 1
          ? nextSelectedIds.first
          : null;
      if (!mounted) return;
      setState(() {
        _productionRows = filtered;
        _selectedIds
          ..clear()
          ..addAll(nextSelectedIds);
        if (previousSingleSelectedId != nextSingleSelectedId) {
          _clearSelectionScopedOutputs();
        }
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          actionSummary: filtered.isEmpty
              ? '制作视图尚无分镜记录，仍可按脚本分镜提示词发起出图。'
              : '已同步 ${filtered.length} 条制作分镜。',
          diagnosis: _currentDiagnosis(),
        );
      });
    } on RustApiException catch (e) {
      if (mounted) setState(() => _statusLine = '加载制作视图失败：$e');
    } catch (e) {
      if (mounted) setState(() => _statusLine = '加载制作视图失败：$e');
    } finally {
      if (mounted) setState(() => _loadingProduction = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            ? '同步中…'
            : describeStoryboardBatchWorkbenchRecommendedAction(
                diagnosis.recommendedAction,
              );
      case StoryboardBatchWorkbenchRecommendedAction.selectReadyStoryboards:
        recommendedAction = _busyMutation ? null : _selectReadyStoryboards;
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
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
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.previewSelected:
        recommendedAction = _busyMutation || singleSelectedId == null
            ? null
            : () => _runMutation(() => _loadCurrentPreview(singleSelectedId));
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.exportSelected:
        recommendedAction = _busyMutation || _selectedIds.isEmpty
            ? null
            : () => _runMutation(() => _exportSelectedZip(selected));
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              diagnosis.recommendedAction,
            );
    }

    return AlertDialog(
      title: const Text('分镜出图工作台'),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '把批量出图、当前预览、下载链接与导出 ZIP 收口到剧本分镜区，不再只依赖 production probe。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
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
          child: const Text('关闭'),
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
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
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
