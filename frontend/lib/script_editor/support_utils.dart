part of 'support.dart';

String summarizeRelatedScriptAssets(
  AppLocalizations l10n,
  Iterable<ScriptRelatedAssetBrief> assets, {
  int maxItems = 4,
}) {
  final trimmed = assets
      .map((asset) => asset.name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (trimmed.isEmpty) {
    return l10n.scriptEditorRelatedAssetsNone;
  }
  final sep = l10n.scriptEditorRelatedAssetsNameSeparator;
  final visible = trimmed.take(maxItems).join(sep);
  if (trimmed.length <= maxItems) {
    return visible;
  }
  return l10n.scriptEditorRelatedAssetsOverflow(visible, trimmed.length);
}

String formatBinarySize(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
  }
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}

List<int> parseNumericIdSelection(String raw) {
  final seen = <int>{};
  final values = <int>[];
  for (final token in raw.split(RegExp(r'[^0-9]+'))) {
    if (token.isEmpty) {
      continue;
    }
    final id = int.tryParse(token);
    if (id == null || id <= 0 || seen.contains(id)) {
      continue;
    }
    seen.add(id);
    values.add(id);
  }
  return values;
}

String encodeNumericIdSelection(Iterable<int> ids) {
  return ids.map((id) => id.toString()).join(',');
}

List<ScriptBrief> syncScriptExtractStates(
  Iterable<ScriptBrief> scripts,
  Iterable<ScriptExtractStatePollRow> rows,
) {
  final byNumericId = <int, ScriptExtractStatePollRow>{
    for (final row in rows) row.numericId: row,
  };
  return scripts
      .map((script) {
        final next = byNumericId[script.numericId];
        if (next == null) {
          return script;
        }
        return ScriptBrief(
          numericId: script.numericId,
          name: script.name,
          extractState: next.extractState,
        );
      })
      .toList(growable: false);
}

List<ScriptWorkbenchDetailRow> syncScriptPreviewExtractStates(
  Iterable<ScriptWorkbenchDetailRow> rows,
  Iterable<ScriptExtractStatePollRow> updates,
) {
  final byNumericId = <int, ScriptExtractStatePollRow>{
    for (final row in updates) row.numericId: row,
  };
  return rows
      .map((row) {
        final next = byNumericId[row.numericId];
        if (next == null) {
          return row;
        }
        return ScriptWorkbenchDetailRow(
          numericId: row.numericId,
          name: row.name,
          content: row.content,
          extractState: next.extractState,
          errorReason: next.errorReason ?? row.errorReason,
          createTime: row.createTime,
          relatedAssets: row.relatedAssets,
        );
      })
      .toList(growable: false);
}

List<BatchAddScriptItemV1> buildBatchAddScriptItems({
  required int count,
  required int startingIndex,
  required String prefix,
  required String scriptData,
}) {
  return List<BatchAddScriptItemV1>.generate(
    count,
    (index) => BatchAddScriptItemV1(
      scriptName: '$prefix ${startingIndex + index}',
      scriptData: scriptData,
    ),
    growable: false,
  );
}
