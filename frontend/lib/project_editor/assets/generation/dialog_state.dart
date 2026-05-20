part of 'dialog.dart';

class _AssetGenerationWorkbenchDialogState
    extends State<AssetGenerationWorkbenchDialog> {
  late final _AssetGenerationWorkbenchControllers _ctrls;

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
  BillingEstimateResponse? _batchEstimate;

  @override
  void initState() {
    super.initState();
    _ctrls = _AssetGenerationWorkbenchControllers.create();
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
    _ctrls.dispose();
    super.dispose();
  }

  void _updateWorkbenchState(VoidCallback action) {
    setState(action);
  }

  List<int> _sortedSelection() => sortUniqueAssetNumericIds(_selectedIds);

  void _applySelection(Iterable<int> ids, String label) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = _buildSelectionApplyResult(
      l10n: l10n,
      ids: ids,
      label: label,
      previousFocusedAssetNumericId: _focusedAssetNumericId,
    );
    _updateWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(result.selectedIds);
      _focusedAssetNumericId = result.focusedAssetNumericId;
      _statusLine = result.statusLine;
    });
  }

  void _applyScopedSelection(Iterable<int> candidateIds, String label) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = _buildScopedSelectionApplyResult(
      l10n: l10n,
      candidateIds: candidateIds,
      scopedAssets: _filterAssetsByType(widget.visibleAssets(), _selectedType),
      label: label,
    );
    _updateWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(result.selectedIds);
      _focusedAssetNumericId = result.focusedAssetNumericId;
      _statusLine = result.statusLine;
    });
  }

  Future<void> _changeSelectedType(
    String nextType,
    List<AssetRow> visible,
  ) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final result = _buildTypeChangeSelectionResult(
      l10n: l10n,
      nextType: nextType,
      visibleAssets: visible,
      preferredIds: _selectedIds,
      preferredNumericId: _focusedAssetNumericId,
    );
    _updateWorkbenchState(() {
      _selectedType = nextType;
      _selectedIds
        ..clear()
        ..addAll(result.selectedIds);
      _focusedAssetNumericId = result.focusedAssetNumericId;
      _statusLine = result.statusLine;
    });
    await _syncWorkbenchSnapshot(includeProductionSummary: true);
  }

  void _toggleAssetSelection(AssetRow asset, bool checked) {
    final result = _buildToggleSelectionResult(
      currentSelectedIds: _selectedIds,
      currentFocusedAssetNumericId: _focusedAssetNumericId,
      assetNumericId: asset.numericId,
      checked: checked,
    );
    _updateWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(result.selectedIds);
      _focusedAssetNumericId = result.focusedAssetNumericId;
      if (result.clearImageUrl) {
        _ctrls.imageUrlCtrl.clear();
      }
    });
  }

  Future<void> _syncWorkbenchSnapshot({
    required bool includeProductionSummary,
    String? lead,
  }) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    _updateWorkbenchState(() {
      _loadingSummary = true;
      _statusLine = _buildSnapshotLoadingStatusLine(l10n, lead);
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
      final snapshotApply = _buildSnapshotApplyResult(
        l10n: l10n,
        lead: lead,
        visibleAssets: widget.visibleAssets(),
        selectedType: _selectedType,
        preferredIds: _selectedIds,
        preferredNumericId: _focusedAssetNumericId,
        productionData: includeProductionSummary ? nextProductionData : _productionData,
        pollingData: nextPollingData,
        promptPollingData: nextPromptPollingData,
      );
      if (!mounted) return;
      _updateWorkbenchState(() {
        if (includeProductionSummary) _productionData = nextProductionData;
        _pollingData = nextPollingData;
        _promptPollingData = nextPromptPollingData;
        _selectedIds
          ..clear()
          ..addAll(snapshotApply.selectedIds);
        _focusedAssetNumericId = snapshotApply.focusedAssetNumericId;
        _statusLine = snapshotApply.statusLine;
      });
    } catch (e) {
      if (mounted) {
        _updateWorkbenchState(
          () => _statusLine = l10n.projectEditorAssetGenSyncSnapshotFailed(describeUserVisibleApiErrorResolved(context, e)),
        );
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
    } on FormatException catch (e) {
      if (mounted) _updateWorkbenchState(() => _statusLine = e.message);
    } catch (e) {
      if (mounted) {
        _updateWorkbenchState(
          () => _statusLine = describeUserVisibleApiErrorResolved(context, e),
        );
      }
    } finally {
      if (mounted) _updateWorkbenchState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        modelCtrl: _ctrls.modelCtrl,
        resolutionCtrl: _ctrls.resolutionCtrl,
        imageUrlCtrl: _ctrls.imageUrlCtrl,
        batchNameCtrl: _ctrls.batchNameCtrl,
        batchLimitCtrl: _ctrls.batchLimitCtrl,
        accessToken: widget.token,
        projectUuid: widget.project.id,
        batchAssetCount: selected.length.clamp(1, 999),
        onBatchEstimateChanged: (est) => _batchEstimate = est,
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
                _statusLine = summarizeWorkbenchAssetMaterialData(response, l10n);
              });
            }
          });
        },
        onLoadBatchCandidates: () {
          _runMutation(() async {
            final request = _buildBatchCandidatesRequest(
              l10n: l10n,
              selectedType: _selectedType,
              visibleAssets: visible,
              batchNameText: _ctrls.batchNameCtrl.text,
              batchLimitText: _ctrls.batchLimitCtrl.text,
            );
            final response = await postWorkbenchAssetsBatchGenerationData(
              widget.token,
              projectId: widget.project.id,
              assetType: request.assetType,
              name: request.name,
              limit: request.limit,
            );
            if (mounted) {
              setState(() {
                _batchData = response;
                _statusLine = _buildBatchCandidatesStatusLine(
                  l10n: l10n,
                  response: response,
                  assetType: request.assetType,
                );
              });
            }
          });
        },
        onSelectAllVisible: () => _applySelection(
          scopedAssets.map((a) => a.numericId),
          l10n.projectEditorAssetGenSelectionLabelSelectAllVisible,
        ),
        onRebuildSelectionByType: () => _applySelection(
          _selectedType.isEmpty
              ? scopedAssets.map((a) => a.numericId)
              : (typeSelections[_selectedType] ?? const <int>[]),
          _selectedType.isEmpty
              ? l10n.projectEditorAssetGenSelectionLabelRebuildAllTypes
              : l10n.projectEditorAssetGenSelectionLabelRebuildForType(_selectedType),
        ),
        onClearSelection: () => _applySelection(
          const <int>[],
          l10n.projectEditorAssetGenSelectionLabelClear,
        ),
        onBatchGenerateImages: () async {
          final est = _batchEstimate;
          if (est != null && mounted) {
            final ok = await showStudioCostConfirmSheet(
              context: context,
              estimate: est,
            );
            if (!ok || !mounted) return;
          }
          _runMutation(() async {
            final response = await postProductionAssetsBatchGenerateAssetsImageV1(
              widget.token,
              projectId: widget.project.numericId,
              scriptId: _selectedScriptNumericId,
              assetIds: selected,
              model: _ctrls.modelCtrl.text.trim().isEmpty
                  ? null
                  : _ctrls.modelCtrl.text.trim(),
              resolution: _ctrls.resolutionCtrl.text.trim().isEmpty
                  ? null
                  : _ctrls.resolutionCtrl.text.trim(),
            );
            await _syncWorkbenchSnapshot(
              includeProductionSummary: true,
              lead: _buildBatchGenerateLead(
                l10n: l10n,
                total: response.total,
                enqueuedCount: response.enqueued.length,
              ),
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
                _statusLine = _buildWorkbenchPollingStatusLine(
                  l10n: l10n,
                  scopedAssets: scopedAssets,
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
                _statusLine = _buildWorkbenchPollingStatusLine(
                  l10n: l10n,
                  scopedAssets: scopedAssets,
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
              lead: _buildDeleteDerivativesLead(
                l10n: l10n,
                deleted: response.deleted,
                assetIds: response.assetIds,
              ),
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
              imageUrl: _ctrls.imageUrlCtrl.text.trim(),
            );
            await widget.reloadAssetsAndStats();
            await _syncWorkbenchSnapshot(
              includeProductionSummary: true,
              lead: _buildUpdateImageUrlLead(
                l10n: l10n,
                assetId: response.assetId,
                message: response.message,
              ),
            );
          });
        },
        onApplyPollingSelection: (label, ids) => _applyScopedSelection(
          ids,
          l10n.projectEditorAssetGenSelectionLabelRebuildImageState(label),
        ),
        onApplyMaterialSelection: () => _applyScopedSelection(
          _materialData!.data.map((item) => item.id),
          l10n.projectEditorAssetGenSelectionLabelRebuildMaterialContext,
        ),
        onApplyBatchSelection: () => _applyScopedSelection(
          _batchData!.data.map((item) => item.id),
          l10n.projectEditorAssetGenSelectionLabelRebuildBatchCandidates,
        ),
        onApplyPromptSelection: (label, ids) => _applyScopedSelection(
          ids,
          l10n.projectEditorAssetGenSelectionLabelRebuildPromptState(label),
        ),
        onToggleAsset: _toggleAssetSelection,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

