part of '../../../../home_page.dart';

class _AssetGenerationWorkbenchDialog extends StatefulWidget {
  const _AssetGenerationWorkbenchDialog({
    required this.token,
    required this.project,
    required this.scriptList,
    required this.visibleAssets,
    required this.assetsFilterScriptLegacyId,
    required this.initialSelectedIds,
    required this.initialFocusedAssetLegacyId,
    required this.initialScriptLegacyId,
    required this.onMutationStart,
    required this.onMutationEnd,
    required this.reloadAssetsAndStats,
  });

  final String token;
  final ProjectRow project;
  final List<ScriptBrief> scriptList;
  final List<AssetRow> Function() visibleAssets;
  final List<int?> assetsFilterScriptLegacyId;
  final Iterable<int> initialSelectedIds;
  final int? initialFocusedAssetLegacyId;
  final int initialScriptLegacyId;
  final VoidCallback onMutationStart;
  final VoidCallback onMutationEnd;
  final Future<void> Function() reloadAssetsAndStats;

  @override
  State<_AssetGenerationWorkbenchDialog> createState() =>
      _AssetGenerationWorkbenchDialogState();
}

class _AssetGenerationWorkbenchDialogState
    extends State<_AssetGenerationWorkbenchDialog> {
  late final TextEditingController _modelCtrl;
  late final TextEditingController _resolutionCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _batchNameCtrl;
  late final TextEditingController _batchLimitCtrl;

  late final Set<int> _selectedIds;
  int? _focusedAssetLegacyId;
  late int _selectedScriptLegacyId;
  String _selectedType = '';
  bool _loadingSummary = false;
  bool _busyMutation = false;
  AssetsDataResponseV1? _productionData;
  AssetsPollingImageResponseV1? _pollingData;
  LegacyAssetMaterialDataResponse? _materialData;
  LegacyAssetBatchGenerationDataResponse? _batchData;
  List<LegacyAssetPollingPromptAssetsItem>? _promptPollingData;
  String? _statusLine;

  @override
  void initState() {
    super.initState();
    _modelCtrl = TextEditingController();
    _resolutionCtrl = TextEditingController();
    _imageUrlCtrl = TextEditingController();
    _batchNameCtrl = TextEditingController();
    _batchLimitCtrl = TextEditingController(text: '10');
    _selectedIds = <int>{...widget.initialSelectedIds};
    _focusedAssetLegacyId = widget.initialFocusedAssetLegacyId;
    _selectedScriptLegacyId = widget.initialScriptLegacyId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _syncWorkbenchSnapshot(includeProductionSummary: true);
    });
  }

  @override
  void dispose() {
    _modelCtrl.dispose();
    _resolutionCtrl.dispose();
    _imageUrlCtrl.dispose();
    _batchNameCtrl.dispose();
    _batchLimitCtrl.dispose();
    super.dispose();
  }

  List<AssetRow> _filteredVisibleAssets() {
    final assets = widget.visibleAssets();
    if (_selectedType.isEmpty) return assets;
    return assets
        .where((a) => a.assetType.trim() == _selectedType)
        .toList(growable: false);
  }

  List<int> _sortedSelection() => sortUniqueAssetLegacyIds(_selectedIds);

  void _applySelection(Iterable<int> ids, String label) {
    final next = sortUniqueAssetLegacyIds(ids);
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetLegacyId = next.isEmpty ? _focusedAssetLegacyId : next.first;
      _statusLine = next.isEmpty
          ? '$label：没有可选资产'
          : '$label：已选择 ${next.length} 条资产';
    });
  }

  void _applyScopedSelection(Iterable<int> candidateIds, String label) {
    final next = collectScopedAssetLegacyIds(
      candidateIds,
      _filteredVisibleAssets(),
    );
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetLegacyId = next.isEmpty ? null : next.first;
      _statusLine = next.isEmpty
          ? '$label：当前可见资产中没有匹配项'
          : '$label：已选择 ${next.length} 条资产';
    });
  }

  Future<void> _syncWorkbenchSnapshot({
    required bool includeProductionSummary,
    String? lead,
  }) async {
    setState(() {
      _loadingSummary = true;
      _statusLine = lead == null ? null : '$lead，正在同步工作台摘要…';
    });
    try {
      final selected = _sortedSelection();
      AssetsDataResponseV1? nextProductionData = _productionData;
      if (includeProductionSummary) {
        nextProductionData = await postProductionAssetsGetAssetsDataV1(
          widget.token,
          projectId: widget.project.legacyId,
          assetType: _selectedType.isEmpty ? null : _selectedType,
        );
      }
      AssetsPollingImageResponseV1? nextPollingData;
      List<LegacyAssetPollingPromptAssetsItem>? nextPromptPollingData;
      if (selected.isNotEmpty) {
        nextPollingData = await postProductionAssetsPollingImageV1(
          widget.token,
          projectId: widget.project.legacyId,
          assetIds: selected,
        );
        nextPromptPollingData = await postLegacyAssetsPollingPromptAssets(
          widget.token,
          widget.project.id,
          selected,
        );
      }
      final currentVisibleAssets = _filteredVisibleAssets();
      final nextSelection = chooseVisibleAssetSelection(
        currentVisibleAssets,
        preferredIds: _selectedIds,
        preferredLegacyId: _focusedAssetLegacyId,
      );
      if (!mounted) return;
      setState(() {
        if (includeProductionSummary) _productionData = nextProductionData;
        _pollingData = nextPollingData;
        _promptPollingData = nextPromptPollingData;
        _selectedIds
          ..clear()
          ..addAll(nextSelection);
        _focusedAssetLegacyId = _selectedIds.isEmpty
            ? null
            : _selectedIds.first;
        _statusLine = summarizeAssetWorkbenchSnapshot(
          lead: lead,
          visibleAssets: currentVisibleAssets,
          selectedIds: _selectedIds,
          productionData: _productionData,
          pollingData: _pollingData,
          promptPollingData: _promptPollingData,
        );
      });
    } on RustApiException catch (e) {
      if (mounted) setState(() => _statusLine = '同步工作台摘要失败：$e');
    } catch (e) {
      if (mounted) setState(() => _statusLine = '同步工作台摘要失败：$e');
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    widget.onMutationStart();
    setState(() => _busyMutation = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (mounted) setState(() => _statusLine = '$e');
    } on FormatException catch (e) {
      if (mounted) setState(() => _statusLine = e.message);
    } catch (e) {
      if (mounted) setState(() => _statusLine = '$e');
    } finally {
      if (mounted) setState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  void _toggleAssetSelection(AssetRow asset, bool checked) {
    setState(() {
      if (checked) {
        _selectedIds.add(asset.legacyId);
        _focusedAssetLegacyId = asset.legacyId;
        if (_selectedIds.length == 1) {
          _imageUrlCtrl.clear();
        }
      } else {
        _selectedIds.remove(asset.legacyId);
        if (_focusedAssetLegacyId == asset.legacyId) {
          final remaining = sortUniqueAssetLegacyIds(_selectedIds);
          _focusedAssetLegacyId = remaining.isEmpty ? null : remaining.first;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visibleAssets();
    final scopedAssets = _filteredVisibleAssets();
    final typeSelections = collectAssetIdsByType(visible);
    final pollingSelections = _pollingData == null
        ? const <String, List<int>>{}
        : collectAssetIdsByImageState(_pollingData!.statuses);
    final promptSelections = _promptPollingData == null
        ? const <String, List<int>>{}
        : collectAssetIdsByPromptState(_promptPollingData!);
    final selected = _sortedSelection();
    final selectedSingleAssetId = selected.length == 1 ? selected.first : null;

    return AlertDialog(
      title: const Text('资产出图工作台'),
      content: SizedBox(
        width: 860,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '把 production 资产摘要、批量出图、状态轮询、衍生图清理和封面 URL 更新收口到项目资产主流程，不再只依赖 system probe。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 12),
              _AssetGenerationControlsPanel(
                busy: _busyMutation,
                scriptList: widget.scriptList,
                visibleAssets: visible,
                typeSelections: typeSelections,
                selectedScriptLegacyId: _selectedScriptLegacyId,
                selectedType: _selectedType,
                modelCtrl: _modelCtrl,
                resolutionCtrl: _resolutionCtrl,
                imageUrlCtrl: _imageUrlCtrl,
                batchNameCtrl: _batchNameCtrl,
                batchLimitCtrl: _batchLimitCtrl,
                onScriptChanged: (value) {
                  setState(() => _selectedScriptLegacyId = value);
                },
                onImageUrlChanged: (_) => setState(() {}),
                onTypeChanged: (nextType) async {
                  final nextVisibleAssets = nextType.isEmpty
                      ? visible
                      : visible
                            .where((a) => a.assetType.trim() == nextType)
                            .toList(growable: false);
                  final nextSelection = chooseVisibleAssetSelection(
                    nextVisibleAssets,
                    preferredIds: _selectedIds,
                    preferredLegacyId: _focusedAssetLegacyId,
                  );
                  setState(() {
                    _selectedType = nextType;
                    _selectedIds
                      ..clear()
                      ..addAll(nextSelection);
                    _focusedAssetLegacyId = _selectedIds.isEmpty
                        ? null
                        : _selectedIds.first;
                    _statusLine = nextType.isEmpty
                        ? '正在切换到全部类型并同步工作台摘要…'
                        : '正在切换到 $nextType 并同步工作台摘要…';
                  });
                  await _syncWorkbenchSnapshot(includeProductionSummary: true);
                },
              ),
              const SizedBox(height: 12),
              _AssetGenerationActionsPanel(
                loadingSummary: _loadingSummary,
                busyMutation: _busyMutation,
                visibleAssets: visible,
                scopedAssets: scopedAssets,
                typeSelections: typeSelections,
                selectedType: _selectedType,
                selected: selected,
                selectedSingleAssetId: selectedSingleAssetId,
                imageUrlCtrl: _imageUrlCtrl,
                onSyncWorkbenchSnapshot: () =>
                    _syncWorkbenchSnapshot(includeProductionSummary: true),
                onLoadMaterialContext: () => _runMutation(() async {
                  final response = await postLegacyAssetsGetMaterialData(
                    widget.token,
                    widget.project.id,
                  );
                  if (mounted) {
                    setState(() {
                      _materialData = response;
                      _statusLine = summarizeLegacyAssetMaterialData(response);
                    });
                  }
                }),
                onLoadBatchCandidates: () => _runMutation(() async {
                  final effectiveType = _selectedType.isEmpty
                      ? visible.first.assetType.trim()
                      : _selectedType;
                  final limit = int.tryParse(_batchLimitCtrl.text.trim()) ?? 10;
                  if (effectiveType.isEmpty) {
                    throw const FormatException('批量候选读取需要有效资产类型');
                  }
                  if (limit <= 0) {
                    throw const FormatException('候选 limit 需要大于 0');
                  }
                  final response = await postLegacyAssetsBatchGenerationData(
                    widget.token,
                    projectId: widget.project.id,
                    assetType: effectiveType,
                    name: _batchNameCtrl.text.trim(),
                    limit: limit,
                  );
                  if (mounted) {
                    setState(() {
                      _batchData = response;
                      _statusLine =
                          '${summarizeLegacyBatchGenerationData(response)} · type=$effectiveType';
                    });
                  }
                }),
                onSelectAllVisible: () => _applySelection(
                  scopedAssets.map((a) => a.legacyId),
                  '已全选当前可见资产',
                ),
                onRebuildSelectionByType: () => _applySelection(
                  _selectedType.isEmpty
                      ? scopedAssets.map((a) => a.legacyId)
                      : (typeSelections[_selectedType] ?? const <int>[]),
                  _selectedType.isEmpty
                      ? '已按全部类型重建选择'
                      : '已按 $_selectedType 重建选择',
                ),
                onClearSelection: () => _applySelection(const <int>[], '已清空选择'),
                onBatchGenerateImages: () => _runMutation(() async {
                  final response =
                      await postProductionAssetsBatchGenerateAssetsImageV1(
                        widget.token,
                        projectId: widget.project.legacyId,
                        scriptId: _selectedScriptLegacyId,
                        assetIds: selected,
                        model: _modelCtrl.text.trim().isEmpty
                            ? null
                            : _modelCtrl.text.trim(),
                        resolution: _resolutionCtrl.text.trim().isEmpty
                            ? null
                            : _resolutionCtrl.text.trim(),
                      );
                  await _syncWorkbenchSnapshot(
                    includeProductionSummary: true,
                    lead:
                        '已为 ${response.total} 条资产创建出图任务，队列 ${response.enqueued.length} 条',
                  );
                }),
                onPollImageStatuses: () => _runMutation(() async {
                  final response = await postProductionAssetsPollingImageV1(
                    widget.token,
                    projectId: widget.project.legacyId,
                    assetIds: selected,
                  );
                  if (mounted) {
                    setState(() {
                      _pollingData = response;
                      _statusLine = summarizeAssetWorkbenchSnapshot(
                        visibleAssets: scopedAssets,
                        selectedIds: _selectedIds,
                        productionData: _productionData,
                        pollingData: _pollingData,
                        promptPollingData: _promptPollingData,
                      );
                    });
                  }
                }),
                onPollPromptStatuses: () => _runMutation(() async {
                  final response = await postLegacyAssetsPollingPromptAssets(
                    widget.token,
                    widget.project.id,
                    selected,
                  );
                  if (mounted) {
                    setState(() {
                      _promptPollingData = response;
                      _statusLine = summarizeAssetWorkbenchSnapshot(
                        visibleAssets: scopedAssets,
                        selectedIds: _selectedIds,
                        productionData: _productionData,
                        pollingData: _pollingData,
                        promptPollingData: _promptPollingData,
                      );
                    });
                  }
                }),
                onDeleteDerivatives: () => _runMutation(() async {
                  final response =
                      await postProductionAssetsDeleteAssetsDerivativeV1(
                        widget.token,
                        projectId: widget.project.legacyId,
                        assetIds: selected,
                      );
                  await widget.reloadAssetsAndStats();
                  await _syncWorkbenchSnapshot(
                    includeProductionSummary: true,
                    lead:
                        '已删除 ${response.deleted} 个衍生图记录，资产 ${response.assetIds.join(", ")}',
                  );
                }),
                onUpdateImageUrl: () => _runMutation(() async {
                  final response = await postProductionAssetsUpdateAssetsUrlV1(
                    widget.token,
                    projectId: widget.project.legacyId,
                    assetId: selectedSingleAssetId!,
                    imageUrl: _imageUrlCtrl.text.trim(),
                  );
                  await widget.reloadAssetsAndStats();
                  await _syncWorkbenchSnapshot(
                    includeProductionSummary: true,
                    lead:
                        '已更新资产 #${response.assetId} 封面 URL：${response.message}',
                  );
                }),
              ),
              const SizedBox(height: 8),
              _AssetGenerationStatusPanel(
                busy: _busyMutation,
                statusLine: _statusLine,
                productionData: _productionData,
                pollingData: _pollingData,
                materialData: _materialData,
                batchData: _batchData,
                promptPollingData: _promptPollingData,
                pollingSelections: pollingSelections,
                promptSelections: promptSelections,
                onApplyPollingSelection: (label, ids) => _applyScopedSelection(
                  ids,
                  '已按图片状态 $label 重建选择',
                ),
                onApplyMaterialSelection: () => _applyScopedSelection(
                  _materialData!.data.map((item) => item.id),
                  '已按素材上下文重建选择',
                ),
                onApplyBatchSelection: () => _applyScopedSelection(
                  _batchData!.data.map((item) => item.id),
                  '已按批量候选重建选择',
                ),
                onApplyPromptSelection: (label, ids) => _applyScopedSelection(
                  ids,
                  '已按 prompt 状态 $label 重建选择',
                ),
              ),
              _AssetGenerationSelectionPanel(
                busy: _busyMutation,
                filterScriptLegacyId: widget.assetsFilterScriptLegacyId[0],
                scopedAssets: scopedAssets,
                selectedIds: _selectedIds,
                onToggleAsset: _toggleAssetSelection,
              ),
            ],
          ),
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
}
