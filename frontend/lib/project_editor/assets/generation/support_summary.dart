part of 'support.dart';

String summarizeProductionAssetData(AssetsDataResponseV1 response, AppLocalizations l10n) {
  if (response.assets.isEmpty) {
    return l10n.projectEditorAssetSummaryProductionEmpty;
  }
  final typeCounts = SplayTreeMap<String, int>();
  for (final asset in response.assets) {
    final type = asset.type.trim().isEmpty ? 'unknown' : asset.type.trim();
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;
  }
  final typesLine = typeCounts.entries
      .map((entry) => l10n.projectEditorAssetSummaryTypeCount(entry.key, entry.value))
      .join(' · ');
  final sampleLine = response.assets
      .take(3)
      .map((asset) => '#${asset.id} ${asset.name}')
      .join(', ');
  return l10n.projectEditorAssetSummaryProductionLine(
    response.total,
    typesLine,
    sampleLine,
  );
}

String summarizeAssetPollingStatuses(Iterable<AssetImageStatusV1> statuses, AppLocalizations l10n) {
  final rows = statuses.toList(growable: false);
  if (rows.isEmpty) {
    return l10n.projectEditorAssetSummaryPollingEmpty;
  }
  final states = SplayTreeMap<String, int>();
  for (final row in rows) {
    final state = row.latestState?.trim();
    final key = (state == null || state.isEmpty) ? 'unknown' : state;
    states[key] = (states[key] ?? 0) + 1;
  }
  final stateLine = states.entries
      .map((entry) => l10n.projectEditorAssetSummaryStateCount(entry.key, entry.value))
      .join(' · ');
  final sampleLine = rows
      .take(3)
      .map((row) => l10n.projectEditorAssetSummaryImageCount(row.assetId, row.imageCount))
      .join(', ');
  return l10n.projectEditorAssetSummaryPollingLine(
    rows.length,
    stateLine,
    sampleLine,
  );
}

String summarizeWorkbenchAssetMaterialData(WorkbenchAssetMaterialDataResponse data, AppLocalizations l10n) {
  return l10n.projectEditorAssetSummaryMaterialContext(
    data.data.length,
    data.video.length,
  );
}

String summarizeWorkbenchBatchGenerationData(
  WorkbenchAssetBatchGenerationResponse data,
  AppLocalizations l10n,
) {
  if (data.data.isEmpty) {
    return l10n.projectEditorAssetSummaryBatchEmpty;
  }
  final sampleLine = data.data
      .take(3)
      .map((row) => '#${row.id} ${row.name}')
      .join(', ');
  return l10n.projectEditorAssetSummaryBatchLine(
    data.data.length,
    data.total,
    sampleLine,
  );
}

String summarizeWorkbenchPromptPolling(
  Iterable<WorkbenchAssetPollingPromptItem> rows,
  AppLocalizations l10n,
) {
  final items = rows.toList(growable: false);
  if (items.isEmpty) {
    return l10n.projectEditorAssetSummaryPromptEmpty;
  }
  final states = SplayTreeMap<String, int>();
  for (final row in items) {
    final key = row.promptState.trim().isEmpty ? 'unknown' : row.promptState;
    states[key] = (states[key] ?? 0) + 1;
  }
  final stateLine = states.entries
      .map((entry) => l10n.projectEditorAssetSummaryStateCount(entry.key, entry.value))
      .join(' · ');
  return l10n.projectEditorAssetSummaryPromptLine(
    items.length,
    stateLine,
  );
}

String summarizeAssetWorkbenchSnapshot({
  required Iterable<AssetRow> visibleAssets,
  required Iterable<int> selectedIds,
  required AppLocalizations l10n,
  AssetsDataResponseV1? productionData,
  AssetsPollingImageResponseV1? pollingData,
  Iterable<WorkbenchAssetPollingPromptItem>? promptPollingData,
  String? lead,
}) {
  final visibleById = <int, AssetRow>{
    for (final asset in visibleAssets) asset.numericId: asset,
  };
  final scopedSelection = sortUniqueAssetNumericIds(
    selectedIds.where(visibleById.containsKey),
  );
  final selectionLine = switch (scopedSelection.length) {
    0 => l10n.projectEditorAssetSummarySelectionNone,
    1 => l10n.projectEditorAssetSummarySelectionSingle(
        scopedSelection.first,
        visibleById[scopedSelection.first]?.name ?? "",
      ).trim(),
    _ => l10n.projectEditorAssetSummarySelectionMultiple(
        scopedSelection.length,
        scopedSelection.take(3).map((id) => "#$id ${visibleById[id]?.name ?? ""}".trim()).join(", "),
      ),
  };
  final parts = <String>[
    if (lead != null && lead.trim().isNotEmpty) lead.trim(),
    selectionLine,
    if (productionData != null) summarizeProductionAssetData(productionData, l10n),
    if (pollingData != null) summarizeAssetPollingStatuses(pollingData.statuses, l10n),
    if (promptPollingData != null)
      summarizeWorkbenchPromptPolling(promptPollingData, l10n),
  ];
  return parts.join(l10n.projectEditorAssetSummaryWorkbenchPartsSeparator);
}
