part of '../../../../home_page.dart';

extension _AssetGenerationWorkbenchState
    on _AssetGenerationWorkbenchDialogState {
  List<AssetRow> _filteredVisibleAssets() {
    final assets = widget.visibleAssets();
    if (_selectedType.isEmpty) return assets;
    return assets
        .where((a) => a.assetType.trim() == _selectedType)
        .toList(growable: false);
  }

  List<int> _sortedSelection() => sortUniqueAssetNumericIds(_selectedIds);

  void _applySelection(Iterable<int> ids, String label) {
    final next = sortUniqueAssetNumericIds(ids);
    _updateWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
      _focusedAssetNumericId = next.isEmpty
          ? _focusedAssetNumericId
          : next.first;
      _statusLine = next.isEmpty
          ? '$label：没有可选资产'
          : '$label：已选择 ${next.length} 条资产';
    });
  }

  void _applyScopedSelection(Iterable<int> candidateIds, String label) {
    final next = collectScopedAssetNumericIds(
      candidateIds,
      _filteredVisibleAssets(),
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
}
