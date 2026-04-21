part of 'dialog.dart';

class _AssetGenerationWorkbenchDialogState
    extends State<AssetGenerationWorkbenchDialog> {
  late final TextEditingController _modelCtrl;
  late final TextEditingController _resolutionCtrl;
  late final TextEditingController _imageUrlCtrl;
  late final TextEditingController _batchNameCtrl;
  late final TextEditingController _batchLimitCtrl;

  late final Set<int> _selectedIds;
  int? _focusedAssetNumericId;
  late int _selectedScriptNumericId;
  String _selectedType = '';
  bool _loadingSummary = false;
  bool _busyMutation = false;
  AssetsDataResponseV1? _productionData;
  AssetsPollingImageResponseV1? _pollingData;
  WorkbenchAssetMaterialDataResponse? _materialData;
  WorkbenchAssetBatchGenerationResponse? _batchData;
  List<WorkbenchAssetPollingPromptItem>? _promptPollingData;
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
    _focusedAssetNumericId = widget.initialFocusedAssetNumericId;
    _selectedScriptNumericId = widget.initialScriptNumericId;
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

  void _updateWorkbenchState(VoidCallback action) {
    setState(action);
  }

  List<int> _sortedSelection() => sortUniqueAssetNumericIds(_selectedIds);

  void _applySelection(Iterable<int> ids, String label) {
    final next = sortUniqueAssetNumericIds(ids);
    _updateWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetNumericId = next.isEmpty ? _focusedAssetNumericId : next.first;
      _statusLine =
          next.isEmpty ? '$label：没有可选资产' : '$label：已选择 ${next.length} 条资产';
    });
  }

  void _applyScopedSelection(Iterable<int> candidateIds, String label) {
    final next = collectScopedAssetNumericIds(
      candidateIds,
      _filterAssetsByType(widget.visibleAssets(), _selectedType),
    );
    _updateWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetNumericId = next.isEmpty ? null : next.first;
      _statusLine = next.isEmpty
          ? '$label：当前可见资产中没有匹配项'
          : '$label：已选择 ${next.length} 条资产';
    });
  }

  Future<void> _changeSelectedType(
    String nextType,
    List<AssetRow> visible,
  ) async {
    final nextVisibleAssets = nextType.isEmpty
        ? visible
        : visible
            .where((a) => a.assetType.trim() == nextType)
            .toList(growable: false);
    final nextSelection = chooseVisibleAssetSelection(
      nextVisibleAssets,
      preferredIds: _selectedIds,
      preferredNumericId: _focusedAssetNumericId,
    );
    _updateWorkbenchState(() {
      _selectedType = nextType;
      _selectedIds
        ..clear()
        ..addAll(nextSelection);
      _focusedAssetNumericId = _selectedIds.isEmpty ? null : _selectedIds.first;
      _statusLine = nextType.isEmpty
          ? '正在切换到全部类型并同步工作台摘要…'
          : '正在切换到 $nextType 并同步工作台摘要…';
    });
    await _syncWorkbenchSnapshot(includeProductionSummary: true);
  }

  void _toggleAssetSelection(AssetRow asset, bool checked) {
    _updateWorkbenchState(() {
      if (checked) {
        _selectedIds.add(asset.numericId);
        _focusedAssetNumericId = asset.numericId;
        if (_selectedIds.length == 1) {
          _imageUrlCtrl.clear();
        }
      } else {
        _selectedIds.remove(asset.numericId);
        if (_focusedAssetNumericId == asset.numericId) {
          final remaining = sortUniqueAssetNumericIds(_selectedIds);
          _focusedAssetNumericId = remaining.isEmpty ? null : remaining.first;
        }
      }
    });
  }

  Future<void> _syncWorkbenchSnapshot({
    required bool includeProductionSummary,
    String? lead,
  }) async {
    _updateWorkbenchState(() {
      _loadingSummary = true;
      _statusLine = lead == null ? null : '$lead，正在同步工作台摘要…';
    });
    try {
      final selected = _sortedSelection();
      AssetsDataResponseV1? nextProductionData = _productionData;
      if (includeProductionSummary) {
        nextProductionData = await postProductionAssetsGetAssetsDataV1(
          widget.token,
          projectId: widget.project.numericId,
          scriptId: _selectedScriptNumericId,
          assetType: _selectedType.isEmpty ? null : _selectedType,
        );
      }
      AssetsPollingImageResponseV1? nextPollingData;
      List<WorkbenchAssetPollingPromptItem>? nextPromptPollingData;
      if (selected.isNotEmpty) {
        nextPollingData = await postProductionAssetsPollingImageV1(
          widget.token,
          projectId: widget.project.numericId,
          scriptId: _selectedScriptNumericId,
          assetIds: selected,
        );
        nextPromptPollingData = await postWorkbenchAssetsPollingPromptAssets(
          widget.token,
          widget.project.id,
          selected,
        );
      }
      final currentVisibleAssets = _filterAssetsByType(
        widget.visibleAssets(),
        _selectedType,
      );
      final nextSelection = chooseVisibleAssetSelection(
        currentVisibleAssets,
        preferredIds: _selectedIds,
        preferredNumericId: _focusedAssetNumericId,
      );
      if (!mounted) return;
      _updateWorkbenchState(() {
        if (includeProductionSummary) _productionData = nextProductionData;
        _pollingData = nextPollingData;
        _promptPollingData = nextPromptPollingData;
        _selectedIds
          ..clear()
          ..addAll(nextSelection);
        _focusedAssetNumericId = _selectedIds.isEmpty ? null : _selectedIds.first;
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
      if (mounted) {
        _updateWorkbenchState(() => _statusLine = '同步工作台摘要失败：$e');
      }
    } catch (e) {
      if (mounted) {
        _updateWorkbenchState(() => _statusLine = '同步工作台摘要失败：$e');
      }
    } finally {
      if (mounted) _updateWorkbenchState(() => _loadingSummary = false);
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    widget.onMutationStart();
    _updateWorkbenchState(() => _busyMutation = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (mounted) _updateWorkbenchState(() => _statusLine = '$e');
    } on FormatException catch (e) {
      if (mounted) _updateWorkbenchState(() => _statusLine = e.message);
    } catch (e) {
      if (mounted) _updateWorkbenchState(() => _statusLine = '$e');
    } finally {
      if (mounted) _updateWorkbenchState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.visibleAssets();
    final scopedAssets = _filterAssetsByType(visible, _selectedType);
    final typeSelections = collectAssetIdsByType(visible);
    final pollingSelections = _resolvePollingSelections(_pollingData);
    final promptSelections = _resolvePromptSelections(_promptPollingData);
    final selected = _sortedSelection();
    final selectedSingleAssetId = _resolveSingleSelectedAssetId(selected);
    return AssetGenerationWorkbenchDialogView(
      model: _buildAssetGenerationWorkbenchViewModel(
        scriptList: widget.scriptList,
        visibleAssets: visible,
        scopedAssets: scopedAssets,
        typeSelections: typeSelections,
        pollingSelections: pollingSelections,
        promptSelections: promptSelections,
        selectedIds: selected,
        selectedSingleAssetId: selectedSingleAssetId,
        filterScriptNumericId: widget.assetsFilterScriptNumericId[0],
        selectedScriptNumericId: _selectedScriptNumericId,
        selectedType: _selectedType,
        loadingSummary: _loadingSummary,
        busyMutation: _busyMutation,
        productionData: _productionData,
        pollingData: _pollingData,
        materialData: _materialData,
        batchData: _batchData,
        promptPollingData: _promptPollingData,
        statusLine: _statusLine,
        modelCtrl: _modelCtrl,
        resolutionCtrl: _resolutionCtrl,
        imageUrlCtrl: _imageUrlCtrl,
        batchNameCtrl: _batchNameCtrl,
        batchLimitCtrl: _batchLimitCtrl,
      ),
      callbacks: AssetGenerationWorkbenchDialogViewCallbacks(
        onScriptChanged: (value) {
          setState(() => _selectedScriptNumericId = value);
        },
        onImageUrlChanged: (_) => setState(() {}),
        onTypeChanged: (nextType) {
          _changeSelectedType(nextType, visible);
        },
        onSyncWorkbenchSnapshot: () {
          _syncWorkbenchSnapshot(includeProductionSummary: true);
        },
        onLoadMaterialContext: () {
          _runMutation(() async {
            final response = await postWorkbenchAssetsGetMaterialData(
              widget.token,
              widget.project.id,
            );
            if (mounted) {
              setState(() {
                _materialData = response;
                _statusLine = summarizeWorkbenchAssetMaterialData(response);
              });
            }
          });
        },
        onLoadBatchCandidates: () {
          _runMutation(() async {
            final effectiveType =
                _selectedType.isEmpty ? visible.first.assetType.trim() : _selectedType;
            final limit = int.tryParse(_batchLimitCtrl.text.trim()) ?? 10;
            if (effectiveType.isEmpty) {
              throw const FormatException('批量候选读取需要有效资产类型');
            }
            if (limit <= 0) {
              throw const FormatException('候选 limit 需要大于 0');
            }
            final response = await postWorkbenchAssetsBatchGenerationData(
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
                    '${summarizeWorkbenchBatchGenerationData(response)} · type=$effectiveType';
              });
            }
          });
        },
        onSelectAllVisible: () =>
            _applySelection(scopedAssets.map((a) => a.numericId), '已全选当前可见资产'),
        onRebuildSelectionByType: () => _applySelection(
          _selectedType.isEmpty
              ? scopedAssets.map((a) => a.numericId)
              : (typeSelections[_selectedType] ?? const <int>[]),
          _selectedType.isEmpty ? '已按全部类型重建选择' : '已按 $_selectedType 重建选择',
        ),
        onClearSelection: () => _applySelection(const <int>[], '已清空选择'),
        onBatchGenerateImages: () {
          _runMutation(() async {
            final response = await postProductionAssetsBatchGenerateAssetsImageV1(
              widget.token,
              projectId: widget.project.numericId,
              scriptId: _selectedScriptNumericId,
              assetIds: selected,
              model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
              resolution: _resolutionCtrl.text.trim().isEmpty
                  ? null
                  : _resolutionCtrl.text.trim(),
            );
            await _syncWorkbenchSnapshot(
              includeProductionSummary: true,
              lead: '已为 ${response.total} 条资产创建出图任务，队列 ${response.enqueued.length} 条',
            );
          });
        },
        onPollImageStatuses: () {
          _runMutation(() async {
            final response = await postProductionAssetsPollingImageV1(
              widget.token,
              projectId: widget.project.numericId,
              scriptId: _selectedScriptNumericId,
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
          });
        },
        onPollPromptStatuses: () {
          _runMutation(() async {
            final response = await postWorkbenchAssetsPollingPromptAssets(
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
          });
        },
        onDeleteDerivatives: () {
          _runMutation(() async {
            final response = await postProductionAssetsDeleteAssetsDerivativeV1(
              widget.token,
              projectId: widget.project.numericId,
              scriptId: _selectedScriptNumericId,
              assetIds: selected,
            );
            await widget.reloadAssetsAndStats();
            await _syncWorkbenchSnapshot(
              includeProductionSummary: true,
              lead:
                  '已删除 ${response.deleted} 个衍生图记录，资产 ${response.assetIds.join(", ")}',
            );
          });
        },
        onUpdateImageUrl: () {
          _runMutation(() async {
            final response = await postProductionAssetsUpdateAssetsUrlV1(
              widget.token,
              projectId: widget.project.numericId,
              scriptId: _selectedScriptNumericId,
              assetId: selectedSingleAssetId!,
              imageUrl: _imageUrlCtrl.text.trim(),
            );
            await widget.reloadAssetsAndStats();
            await _syncWorkbenchSnapshot(
              includeProductionSummary: true,
              lead: '已更新资产 #${response.assetId} 封面 URL：${response.message}',
            );
          });
        },
        onApplyPollingSelection: (label, ids) =>
            _applyScopedSelection(ids, '已按图片状态 $label 重建选择'),
        onApplyMaterialSelection: () => _applyScopedSelection(
          _materialData!.data.map((item) => item.id),
          '已按素材上下文重建选择',
        ),
        onApplyBatchSelection: () => _applyScopedSelection(
          _batchData!.data.map((item) => item.id),
          '已按批量候选重建选择',
        ),
        onApplyPromptSelection: (label, ids) =>
            _applyScopedSelection(ids, '已按 prompt 状态 $label 重建选择'),
        onToggleAsset: _toggleAssetSelection,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

