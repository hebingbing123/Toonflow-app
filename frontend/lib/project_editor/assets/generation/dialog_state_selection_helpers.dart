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
  required AppLocalizations l10n,
  required Iterable<int> ids,
  required String label,
  required int? previousFocusedAssetNumericId,
}) {
  final selectedIds = sortUniqueAssetNumericIds(ids);
  final focusedAssetNumericId = selectedIds.isEmpty
      ? previousFocusedAssetNumericId
      : selectedIds.first;
  final statusLine = selectedIds.isEmpty
      ? l10n.projectEditorAssetGenWorkbenchSelectionLineEmpty(label)
      : l10n.projectEditorAssetGenWorkbenchSelectionLineCount(label, selectedIds.length);
  return (
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

_SelectionApplyResult _buildScopedSelectionApplyResult({
  required AppLocalizations l10n,
  required Iterable<int> candidateIds,
  required List<AssetRow> scopedAssets,
  required String label,
}) {
  final selectedIds = collectScopedAssetNumericIds(candidateIds, scopedAssets);
  final focusedAssetNumericId = selectedIds.isEmpty ? null : selectedIds.first;
  final statusLine = selectedIds.isEmpty
      ? l10n.projectEditorAssetGenWorkbenchScopedSelectionLineEmpty(label)
      : l10n.projectEditorAssetGenWorkbenchSelectionLineCount(label, selectedIds.length);
  return (
    selectedIds: selectedIds,
    focusedAssetNumericId: focusedAssetNumericId,
    statusLine: statusLine,
  );
}

_TypeChangeSelectionResult _buildTypeChangeSelectionResult({
  required AppLocalizations l10n,
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
      ? l10n.projectEditorAssetGenSwitchingTypeAll
      : l10n.projectEditorAssetGenSwitchingTypeNamed(nextType);
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

