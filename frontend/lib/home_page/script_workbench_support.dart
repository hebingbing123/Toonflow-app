import '../rust_api.dart';

LegacyScriptsGetScriptApiItem? findScriptContextByLegacyId(
  Iterable<LegacyScriptsGetScriptApiItem> rows,
  int legacyId,
) {
  for (final row in rows) {
    if (row.legacyId == legacyId) {
      return row;
    }
  }
  return null;
}

ScriptExtractStatePollRow? findScriptExtractStateByLegacyId(
  Iterable<ScriptExtractStatePollRow> rows,
  int legacyId,
) {
  for (final row in rows) {
    if (row.legacyId == legacyId) {
      return row;
    }
  }
  return null;
}

String summarizeRelatedScriptAssets(
  Iterable<LegacyScriptRelatedAssetBrief> assets, {
  int maxItems = 4,
}) {
  final trimmed = assets
      .map((asset) => asset.name.trim())
      .where((name) => name.isNotEmpty)
      .toList(growable: false);
  if (trimmed.isEmpty) {
    return '未关联素材';
  }
  final visible = trimmed.take(maxItems).join('、');
  if (trimmed.length <= maxItems) {
    return visible;
  }
  return '$visible 等 ${trimmed.length} 项';
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

List<int> parseLegacyIdSelection(String raw) {
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

String encodeLegacyIdSelection(Iterable<int> ids) {
  return ids.map((id) => id.toString()).join(',');
}

List<ScriptBrief> syncScriptExtractStates(
  Iterable<ScriptBrief> scripts,
  Iterable<ScriptExtractStatePollRow> rows,
) {
  final byLegacyId = <int, ScriptExtractStatePollRow>{
    for (final row in rows) row.legacyId: row,
  };
  return scripts
      .map((script) {
        final next = byLegacyId[script.legacyId];
        if (next == null) {
          return script;
        }
        return ScriptBrief(
          legacyId: script.legacyId,
          name: script.name,
          extractState: next.extractState,
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
