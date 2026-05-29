import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Last-known-good JSON cache for pane data when connectivity fails (11.2).
abstract final class StudioOfflineCache {
  static const _prefix = 'studio.offline.v1.';

  static Future<void> putJson(String key, Object value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$key',
      jsonEncode(<String, dynamic>{
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'payload': value,
      }),
    );
  }

  static Future<Object?> readPayload(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final envelope = jsonDecode(raw);
    if (envelope is! Map<String, dynamic>) {
      return null;
    }
    return envelope['payload'];
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }
}
