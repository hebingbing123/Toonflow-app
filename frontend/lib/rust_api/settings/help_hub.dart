import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class HelpHubLinkItemV1 {
  const HelpHubLinkItemV1({
    required this.id,
    required this.title,
    required this.url,
  });

  final String id;
  final String title;
  final String url;

  factory HelpHubLinkItemV1.fromJson(Map<String, dynamic> json) {
    return HelpHubLinkItemV1(
      id: json['id'] as String,
      title: json['title'] as String,
      url: json['url'] as String,
    );
  }
}

class HelpHubLinksResponseV1 {
  const HelpHubLinksResponseV1({required this.items});

  final List<HelpHubLinkItemV1> items;

  factory HelpHubLinksResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>;
    return HelpHubLinksResponseV1(
      items: raw
          .cast<Map<String, dynamic>>()
          .map(HelpHubLinkItemV1.fromJson)
          .toList(growable: false),
    );
  }
}

/// `GET /api/v1/settings/help/hub` — OpenAPI `getSettingsHelpHubLinksV1`.
Future<HelpHubLinksResponseV1> getSettingsHelpHubLinksV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/help/hub');
  final res = await http
      .get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HelpHubLinksResponseV1.fromJson(map);
}
