import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists last opened projects for «继续创作» (max 3).
abstract final class StudioRecentProjectsPrefs {
  static const _key = 'studio_recent_project_ids';
  static const _max = 3;

  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <String>[];
      return decoded
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .take(_max)
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  static Future<void> record(String projectId) async {
    if (projectId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final next = <String>[
      projectId,
      ...current.where((id) => id != projectId),
    ].take(_max).toList(growable: false);
    await prefs.setString(_key, jsonEncode(next));
  }
}
