import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// `POST /api/v1/settings/danger/delete-all-data` — OpenAPI `postSettingsDangerDeleteAllDataV1` (typically **501**).
Future<int> postSettingsDangerDeleteAllDataV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/danger/delete-all-data');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// `POST /api/v1/settings/danger/clear-database` — OpenAPI `postSettingsDangerClearDatabaseV1` (typically **501**).
Future<int> postSettingsDangerClearDatabaseV1(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/danger/clear-database');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: '{}',
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}

/// OpenAPI **`AboutCheckUpdateResponse`** — desktop **`checkUpdate`** shape (**camelCase**).
class AboutCheckUpdateResponseV1 {
  const AboutCheckUpdateResponseV1({
    required this.needUpdate,
    required this.latestVersion,
    required this.reinstall,
    required this.time,
    this.url,
  });

  final bool needUpdate;
  final String latestVersion;
  final bool reinstall;
  final String time;
  final String? url;

  factory AboutCheckUpdateResponseV1.fromJson(Map<String, dynamic> json) {
    return AboutCheckUpdateResponseV1(
      needUpdate: json['needUpdate'] as bool,
      latestVersion: json['latestVersion'] as String,
      reinstall: json['reinstall'] as bool,
      time: json['time'] as String,
      url: json['url'] as String?,
    );
  }
}

/// `POST /api/v1/settings/about/check-update` — OpenAPI `postAboutCheckUpdateV1`.
Future<AboutCheckUpdateResponseV1> postAboutCheckUpdateV1(
  String accessToken,
  String source,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/about/check-update');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'source': source}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return AboutCheckUpdateResponseV1.fromJson(map);
}

/// `POST /api/v1/settings/about/download-app` — OpenAPI `postAboutDownloadAppV1` (always **200** after URL validation).
Future<int> postAboutDownloadAppV1(
  String accessToken, {
  required String url,
  required bool reinstall,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/about/download-app');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'url': url, 'reinstall': reinstall}),
      )
      .timeout(const Duration(seconds: 15));
  return res.statusCode;
}
