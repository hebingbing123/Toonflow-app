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
