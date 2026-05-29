import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class StudioUiPrefsV1 {
  const StudioUiPrefsV1({required this.pinnedProjectIds});

  final List<String> pinnedProjectIds;

  factory StudioUiPrefsV1.fromJson(Map<String, dynamic> json) {
    final raw =
        json['pinnedProjectIds'] as List<dynamic>? ??
        json['pinned_project_ids'] as List<dynamic>? ??
        const <dynamic>[];
    return StudioUiPrefsV1(
      pinnedProjectIds: raw.map((item) => '$item').toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'pinnedProjectIds': pinnedProjectIds,
  };
}

/// `GET /api/v1/settings/studio-ui/prefs`
Future<StudioUiPrefsV1> fetchStudioUiPrefsV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/studio-ui/prefs');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return StudioUiPrefsV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

/// `PUT /api/v1/settings/studio-ui/prefs`
Future<StudioUiPrefsV1> putStudioUiPrefsV1(
  String accessToken,
  StudioUiPrefsV1 prefs,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/studio-ui/prefs');
  final res = await http
      .put(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(prefs.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return StudioUiPrefsV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
