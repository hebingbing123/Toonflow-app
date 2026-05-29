import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../rust_api/settings/studio_ui.dart';

/// Pinned projects — local cache with server sync via Studio UI prefs API.
abstract final class StudioPinnedProjectsPrefs {
  static const _key = 'studio_pinned_project_ids';
  static const _max = 8;

  static Future<Set<String>> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      return <String>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <String>{};
      }
      return decoded
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .take(_max)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> saveLocal(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final next = ids.take(_max).toList(growable: false);
    await prefs.setString(_key, jsonEncode(next));
  }

  /// Loads server prefs when [accessToken] is available; falls back to local cache.
  static Future<Set<String>> load({String? accessToken}) async {
    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      try {
        final remote = await fetchStudioUiPrefsV1(token);
        final ids = remote.pinnedProjectIds.take(_max).toSet();
        await saveLocal(ids);
        return ids;
      } catch (_) {
        return loadLocal();
      }
    }
    return loadLocal();
  }

  static Future<Set<String>> toggle(
    String projectId, {
    String? accessToken,
    Set<String>? current,
  }) async {
    if (projectId.isEmpty) {
      return load(accessToken: accessToken);
    }
    final base = current ?? await load(accessToken: accessToken);
    final next = Set<String>.from(base);
    if (next.contains(projectId)) {
      next.remove(projectId);
    } else {
      next.add(projectId);
      while (next.length > _max) {
        next.remove(next.first);
      }
    }
    await saveLocal(next);
    final token = accessToken?.trim();
    if (token != null && token.isNotEmpty) {
      await putStudioUiPrefsV1(
        token,
        StudioUiPrefsV1(pinnedProjectIds: next.toList(growable: false)),
      );
    }
    return next;
  }
}
