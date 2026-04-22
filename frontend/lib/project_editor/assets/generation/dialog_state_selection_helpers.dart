part of 'dialog.dart';

typedef _SelectionApplyResult = ({
  List<int> selectedIds,
  int? focusedAssetNumericId,
  String statusLine,
});

typedef _TypeChangeSelectionResult = ({
  List<int> selectedIds,
  int? focusedAssetNumericId,
  String statusLine,
});

typedef _ToggleSelectionResult = ({
  List<int> selectedIds,
  int? focusedAssetNumericId,
  bool clearImageUrl,
});

_SelectionApplyResult _buildSelectionApplyResult({
  required Iterable<int> ids,
  required String label,
  required int? previousFocusedAssetNumericId,
}) {
  final selectedIds = sortUniqueAssetNumericIds(ids);
  final focusedAssetNumericId = selectedIds.isEmpty
      ? previousFocusedAssetNumericId
      : selectedIds.first;
  final statusLine = selectedIds.isEmpty
      ? '$label：没有可选资产'
      : '$label：已选择 ${selectedIds.length} 条资产';
  return (
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

_SelectionApplyResult _buildScopedSelectionApplyResult({
  required Iterable<int> candidateIds,
  required List<AssetRow> scopedAssets,
  required String label,
}) {
  final selectedIds = collectScopedAssetNumericIds(candidateIds, scopedAssets);
  final focusedAssetNumericId = selectedIds.isEmpty ? null : selectedIds.first;
  final statusLine = selectedIds.isEmpty
      ? '$label：当前可见资产中没有匹配项'
      : '$label：已选择 ${selectedIds.length} 条资产';
  return (
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

_TypeChangeSelectionResult _buildTypeChangeSelectionResult({
  required String nextType,
  required List<AssetRow> visibleAssets,
  required Set<int> preferredIds,
  required int? preferredNumericId,
}) {
  final nextVisibleAssets = _filterAssetsByType(visibleAssets, nextType);
  final selectedIds = chooseVisibleAssetSelection(
    nextVisibleAssets,
    preferredIds: preferredIds,
    preferredNumericId: preferredNumericId,
  );
  final focusedAssetNumericId = selectedIds.isEmpty ? null : selectedIds.first;
  final statusLine = nextType.isEmpty
      ? '正在切换到全部类型并同步工作台摘要…'
      : '正在切换到 $nextType 并同步工作台摘要…';
  return (
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

_ToggleSelectionResult _buildToggleSelectionResult({
  required Set<int> currentSelectedIds,
  required int? currentFocusedAssetNumericId,
  required int assetNumericId,
  required bool checked,
}) {
  final next = <int>{...currentSelectedIds};
  var focused = currentFocusedAssetNumericId;
  var clearImageUrl = false;
  if (checked) {
    next.add(assetNumericId);
    focused = assetNumericId;
    if (next.length == 1) {
      clearImageUrl = true;
    }
  } else {
    next.remove(assetNumericId);
    if (focused == assetNumericId) {
      final remaining = sortUniqueAssetNumericIds(next);
      focused = remaining.isEmpty ? null : remaining.first;
    }
  }
  return (
    selectedIds: sortUniqueAssetNumericIds(next),
    focusedAssetNumericId: focused,
    clearImageUrl: clearImageUrl,
  );
}

