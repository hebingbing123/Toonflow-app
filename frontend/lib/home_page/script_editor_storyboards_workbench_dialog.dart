part of '../home_page.dart';

class _StoryboardBatchWorkbenchDialog extends StatefulWidget {
  const _StoryboardBatchWorkbenchDialog({
    required this.token,
    required this.projectLegacyId,
    required this.scriptLegacyId,
    required this.boardsList,
    required this.onMutationStart,
    required this.onMutationEnd,
  });

  final String token;
  final int projectLegacyId;
  final int scriptLegacyId;
  final List<StoryboardRow> boardsList;
  final VoidCallback onMutationStart;
  final VoidCallback onMutationEnd;

  @override
  State<_StoryboardBatchWorkbenchDialog> createState() =>
      _StoryboardBatchWorkbenchDialogState();
}

class _StoryboardBatchWorkbenchDialogState
    extends State<_StoryboardBatchWorkbenchDialog> {
  late final TextEditingController _promptSuffixCtrl;
  late final TextEditingController _negativePromptCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _resolutionCtrl;

  final Set<int> _selectedIds = {};
  List<ProductionStoryboardItemV1> _productionRows = const [];
  bool _loadingProduction = false;
  bool _busyMutation = false;
  String? _statusLine;
  String? _previewUrl;
  String? _downloadUrl;
  String? _exportLine;

  @override
  void initState() {
    super.initState();
    _promptSuffixCtrl = TextEditingController();
    _negativePromptCtrl = TextEditingController();
    _modelCtrl = TextEditingController();
    _resolutionCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _refreshProduction();
    });
  }

  @override
  void dispose() {
    _promptSuffixCtrl.dispose();
    _negativePromptCtrl.dispose();
    _modelCtrl.dispose();
    _resolutionCtrl.dispose();
    super.dispose();
  }

  Map<int, ProductionStoryboardItemV1> _productionById() => {
    for (final row in _productionRows) row.id: row,
  };

  List<int> _sortedSelection() {
    final values = _selectedIds.toList()..sort();
    return values;
  }

  StoryboardRow? _findScriptRow(int legacyId) {
    for (final row in widget.boardsList) {
      if (row.legacyId == legacyId) return row;
    }
    return null;
  }

  void _clearSelectionScopedOutputs() {
    _previewUrl = null;
    _downloadUrl = null;
  }

  StoryboardBatchWorkbenchDiagnosis _currentDiagnosis() =>
      diagnoseStoryboardBatchWorkbench(
        selectedIds: _selectedIds,
        boards: widget.boardsList,
        productionRows: _productionRows,
      );

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
      if ((row.filePath ?? productionRow?.url ?? '').trim().isNotEmpty)
        '已有画面',
    ];
    return parts.isEmpty ? '待补充分镜信息' : parts.join(' · ');
  }

  Future<void> _refreshProduction() async {
    final previousSingleSelectedId =
        _sortedSelection().length == 1 ? _sortedSelection().first : null;
    setState(() {
      _loadingProduction = true;
      _statusLine = null;
    });
    try {
      final response = await postProductionGetStoryboardDataV1(
        widget.token,
        projectId: widget.projectLegacyId,
        scriptId: widget.scriptLegacyId,
      );
      final ids = widget.boardsList.map((row) => row.legacyId).toSet();
      final filtered = response.data
          .where((row) => ids.contains(row.id))
          .toList(growable: false);
      final nextSelectedIds = <int>{
        ..._selectedIds.where((id) => ids.contains(id)),
      };
      if (nextSelectedIds.isEmpty && widget.boardsList.isNotEmpty) {
        nextSelectedIds.add(widget.boardsList.first.legacyId);
      }
      final nextSingleSelectedId =
          nextSelectedIds.length == 1 ? nextSelectedIds.first : null;
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

  Future<void> _runMutation(Future<void> Function() action) async {
    widget.onMutationStart();
    setState(() => _busyMutation = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (mounted) setState(() => _statusLine = '$e');
    } catch (e) {
      if (mounted) setState(() => _statusLine = '$e');
    } finally {
      if (mounted) setState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  Future<void> _batchGenerate() async {
    final productionMap = _productionById();
    final selected = _sortedSelection();
    final suffix = _promptSuffixCtrl.text.trim();
    final negativePrompt = _negativePromptCtrl.text.trim();
    final items = <BatchGenerateImageItem>[];
    for (final legacyId in selected) {
      final scriptRow = _findScriptRow(legacyId);
      final prompt = resolveStoryboardGenerationPrompt(
        scriptStoryboard: scriptRow,
        productionStoryboard: productionMap[legacyId],
      );
      if (prompt == null) continue;
      final combinedPrompt = suffix.isEmpty ? prompt : '$prompt\n$suffix';
      items.add(
        BatchGenerateImageItem(
          storyboardId: legacyId,
          prompt: combinedPrompt,
          negativePrompt: negativePrompt.isEmpty ? null : negativePrompt,
          model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
          resolution: _resolutionCtrl.text.trim().isEmpty
              ? null
              : _resolutionCtrl.text.trim(),
        ),
      );
    }
    if (items.isEmpty) {
      throw const FormatException('所选分镜没有可用提示词，无法发起批量出图');
    }
    final response = await postStoryboardBatchGenerateImageV1(
      widget.token,
      projectId: widget.projectLegacyId,
      scriptId: widget.scriptLegacyId,
      items: items,
      model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      resolution: _resolutionCtrl.text.trim().isEmpty
          ? null
          : _resolutionCtrl.text.trim(),
    );
    await _refreshProduction();
    if (mounted) {
      setState(() {
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          actionSummary:
              '已为 ${response.total} 条分镜创建出图任务，队列 ${response.enqueued.length} 条。',
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  void _selectReadyStoryboards() {
    final productionMap = _productionById();
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(
          widget.boardsList
              .where(
                (row) =>
                    resolveStoryboardGenerationPrompt(
                      scriptStoryboard: row,
                      productionStoryboard: productionMap[row.legacyId],
                    ) !=
                    null,
              )
              .map((row) => row.legacyId),
        );
      _clearSelectionScopedOutputs();
      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
        actionSummary: '已选择全部可直接出图的分镜。',
        diagnosis: _currentDiagnosis(),
      );
    });
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
        recommendedAction =
            _busyMutation ? null : _selectReadyStoryboards;
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.generateSelected:
        recommendedAction = _busyMutation || _selectedIds.isEmpty
            ? null
            : () => _runMutation(_batchGenerate);
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.previewSelected:
        recommendedAction = _busyMutation || singleSelectedId == null
            ? null
            : () => _runMutation(() async {
                final preview = await postStoryboardPreviewImageV1(
                  widget.token,
                  storyboardId: singleSelectedId,
                );
                if (mounted) {
                  setState(() {
                    _previewUrl = preview.imageUrl;
                    _statusLine = buildStoryboardBatchWorkbenchFollowUp(
                      actionSummary: preview.imageUrl == null
                          ? '当前分镜还没有预览图。'
                          : '已读取分镜 #$singleSelectedId 的当前预览。',
                      diagnosis: _currentDiagnosis(),
                    );
                  });
                }
              });
        recommendedActionLabel =
            describeStoryboardBatchWorkbenchRecommendedAction(
              diagnosis.recommendedAction,
            );
      case StoryboardBatchWorkbenchRecommendedAction.exportSelected:
        recommendedAction = _busyMutation || _selectedIds.isEmpty
            ? null
            : () => _runMutation(() async {
                final zip = await fetchProductionExportImageZipV1(
                  widget.token,
                  shotId: selected
                      .map((id) => <String, dynamic>{'id': '$id'})
                      .toList(growable: false),
                );
                if (mounted) {
                  setState(() {
                    _exportLine =
                        '已导出 ${selected.length} 张分镜图片，文件 ${zip.filename ?? "storyboards.zip"}，大小 ${zip.bytes.length} bytes';
                    _statusLine = buildStoryboardBatchWorkbenchFollowUp(
                      actionSummary: _exportLine!,
                      diagnosis: _currentDiagnosis(),
                    );
                  });
                }
              });
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
            _buildDiagnosisCard(context, diagnosis, recommendedAction, recommendedActionLabel),
            const SizedBox(height: 12),
            _buildTopActions(context, productionMap),
            const SizedBox(height: 8),
            _buildPromptRow(),
            const SizedBox(height: 8),
            _buildModelRow(),
            const SizedBox(height: 12),
            _buildMutationActions(context, selected, singleSelectedId),
            if (_statusLine != null) ...[
              const SizedBox(height: 8),
              Text(_statusLine!, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_exportLine != null) ...[
              const SizedBox(height: 4),
              Text(
                _exportLine!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: Row(
                children: [
                  Expanded(
                    child: _buildBoardsList(context, productionMap),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPreviewPanel(context, singleSelectedId),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _busyMutation ? null : () => Navigator.of(context).pop(),
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
        color: Theme.of(context)
            .colorScheme
            .secondaryContainer
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(diagnosis.summary, style: Theme.of(context).textTheme.titleSmall),
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

  Widget _buildTopActions(
    BuildContext context,
    Map<int, ProductionStoryboardItemV1> productionMap,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: _loadingProduction || _busyMutation
              ? null
              : _refreshProduction,
          child: Text(_loadingProduction ? '同步中…' : '同步制作视图'),
        ),
        TextButton(
          onPressed: _busyMutation ? null : _selectReadyStoryboards,
          child: const Text('全选可出图分镜'),
        ),
        TextButton(
          onPressed: _busyMutation
              ? null
              : () {
                  setState(() {
                    _selectedIds.clear();
                    _clearSelectionScopedOutputs();
                    _exportLine = null;
                    _statusLine = buildStoryboardBatchWorkbenchFollowUp(
                      actionSummary: '已清空选择。',
                      diagnosis: _currentDiagnosis(),
                    );
                  });
                },
          child: const Text('清空选择'),
        ),
      ],
    );
  }

  Widget _buildPromptRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _promptSuffixCtrl,
            decoration: const InputDecoration(
              labelText: '追加提示词（可选）',
              helperText: '会拼接到每条分镜原提示词末尾。',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _negativePromptCtrl,
            decoration: const InputDecoration(labelText: '负面提示词（可选）'),
          ),
        ),
      ],
    );
  }

  Widget _buildModelRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(labelText: '模型（可选）'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _resolutionCtrl,
            decoration: const InputDecoration(labelText: '分辨率（可选）'),
          ),
        ),
      ],
    );
  }

  Widget _buildMutationActions(
    BuildContext context,
    List<int> selected,
    int? singleSelectedId,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: _busyMutation || _selectedIds.isEmpty
              ? null
              : () => _runMutation(_batchGenerate),
          child: Text(_busyMutation ? '处理中…' : '批量发起出图'),
        ),
        TextButton(
          onPressed: _busyMutation || singleSelectedId == null
              ? null
              : () => _runMutation(() async {
                  final preview = await postStoryboardPreviewImageV1(
                    widget.token,
                    storyboardId: singleSelectedId,
                  );
                  if (mounted) {
                    setState(() {
                      _previewUrl = preview.imageUrl;
                      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
                        actionSummary: preview.imageUrl == null
                            ? '当前分镜还没有预览图。'
                            : '已读取分镜 #$singleSelectedId 的当前预览。',
                        diagnosis: _currentDiagnosis(),
                      );
                    });
                  }
                }),
          child: const Text('读取当前预览'),
        ),
        TextButton(
          onPressed: _busyMutation || singleSelectedId == null
              ? null
              : () => _runMutation(() async {
                  final preview = await postStoryboardDownPreviewImageV1(
                    widget.token,
                    storyboardId: singleSelectedId,
                  );
                  if (mounted) {
                    setState(() {
                      _downloadUrl = preview.previewUrl;
                      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
                        actionSummary: preview.previewUrl == null
                            ? preview.message
                            : '已生成分镜 #$singleSelectedId 的下载链接。',
                        diagnosis: _currentDiagnosis(),
                      );
                    });
                  }
                }),
          child: const Text('读取下载链接'),
        ),
        TextButton(
          onPressed: _busyMutation || _selectedIds.isEmpty
              ? null
              : () => _runMutation(() async {
                  final zip = await fetchProductionExportImageZipV1(
                    widget.token,
                    shotId: selected
                        .map((id) => <String, dynamic>{'id': '$id'})
                        .toList(growable: false),
                  );
                  if (mounted) {
                    setState(() {
                      _exportLine =
                          '已导出 ${selected.length} 张分镜图片，文件 ${zip.filename ?? "storyboards.zip"}，大小 ${zip.bytes.length} bytes';
                      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
                        actionSummary: _exportLine!,
                        diagnosis: _currentDiagnosis(),
                      );
                    });
                  }
                }),
          child: const Text('导出所选 ZIP'),
        ),
      ],
    );
  }

  Widget _buildBoardsList(
    BuildContext context,
    Map<int, ProductionStoryboardItemV1> productionMap,
  ) {
    return ListView.builder(
      itemCount: widget.boardsList.length,
      itemBuilder: (context, index) {
        final row = widget.boardsList[index];
        final productionRow = productionMap[row.legacyId];
        final prompt = resolveStoryboardGenerationPrompt(
          scriptStoryboard: row,
          productionStoryboard: productionRow,
        );
        final checked = _selectedIds.contains(row.legacyId);
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: checked,
          onChanged: _busyMutation
              ? null
              : (value) {
                  setState(() {
                    final previousSingleSelectedId =
                        _selectedIds.length == 1 ? _selectedIds.first : null;
                    if (value == true) {
                      _selectedIds.add(row.legacyId);
                    } else {
                      _selectedIds.remove(row.legacyId);
                    }
                    final nextSingleSelectedId =
                        _selectedIds.length == 1 ? _selectedIds.first : null;
                    if (previousSingleSelectedId != nextSingleSelectedId) {
                      _clearSelectionScopedOutputs();
                    }
                  });
                },
          title: Text('#${row.legacyId}'),
          subtitle: Text(
            [
              _storyboardMetaLine(row, productionRow),
              prompt ?? '无可用提示词',
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }

  Widget _buildPreviewPanel(BuildContext context, int? singleSelectedId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('预览与导出信息', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            singleSelectedId == null
                ? '选中 1 条分镜后可读取当前预览与下载链接。'
                : '当前查看分镜 #$singleSelectedId',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_downloadUrl != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              '下载链接：$_downloadUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _previewUrl == null
                ? Center(
                    child: Text(
                      '这里会显示当前分镜预览图。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _previewUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Center(
                        child: SelectableText(
                          _previewUrl!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
