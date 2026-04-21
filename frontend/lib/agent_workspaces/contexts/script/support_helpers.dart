part of 'support.dart';

List<Map<String, dynamic>> _extractResultItems(Object? result) {
  if (result is! Map<String, dynamic>) {
    return const <Map<String, dynamic>>[];
  }
  final items = result['items'];
  if (items is! List) return const <Map<String, dynamic>>[];
  return items.whereType<Map<String, dynamic>>().toList(growable: false);
}

Map<String, dynamic>? _extractPlanDataMap(Map<String, dynamic>? result) {
  if (result == null) return null;
  final data = result['data'];
  if (data is Map<String, dynamic>) return data;
  return null;
}

Map<String, dynamic>? _buildNovelStageArgs(List<Map<String, dynamic>> items) {
  final ids = extractScriptWorkspaceNovelIds(<String, dynamic>{'items': items});
  if (ids.isEmpty) return null;
  return <String, dynamic>{'novelId': ids.first};
}
