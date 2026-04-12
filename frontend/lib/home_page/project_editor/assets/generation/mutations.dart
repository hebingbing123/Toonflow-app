part of '../../../../home_page.dart';

extension _AssetGenerationWorkbenchMutations
    on _AssetGenerationWorkbenchDialogState {
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
      final currentVisibleAssets = _filteredVisibleAssets();
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
        _focusedAssetNumericId = _selectedIds.isEmpty
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
}
