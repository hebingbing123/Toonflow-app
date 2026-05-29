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

class HelpHubConfigResponseV1 {
  const HelpHubConfigResponseV1({
    required this.workspaceId,
    required this.canManageWorkspace,
    required this.envItems,
    required this.workspaceItems,
    required this.userItems,
    required this.effectiveItems,
  });

  final String workspaceId;
  final bool canManageWorkspace;
  final List<HelpHubLinkItemV1> envItems;
  final List<HelpHubLinkItemV1> workspaceItems;
  final List<HelpHubLinkItemV1> userItems;
  final List<HelpHubLinkItemV1> effectiveItems;

  factory HelpHubConfigResponseV1.fromJson(Map<String, dynamic> json) {
    List<HelpHubLinkItemV1> parseList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(HelpHubLinkItemV1.fromJson)
          .toList(growable: false);
    }

    return HelpHubConfigResponseV1(
      workspaceId: json['workspaceId'] as String? ?? '',
      canManageWorkspace: json['canManageWorkspace'] == true,
      envItems: parseList('envItems'),
      workspaceItems: parseList('workspaceItems'),
      userItems: parseList('userItems'),
      effectiveItems: parseList('effectiveItems'),
    );
  }
}

Future<HelpHubConfigResponseV1> getSettingsHelpHubConfigV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/help/hub/config');
  final res = await http
      .get(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HelpHubConfigResponseV1.fromJson(map);
}

Future<HelpHubConfigResponseV1> postSettingsHelpHubUserLinksV1(
  String accessToken, {
  required List<HelpHubLinkItemV1> items,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/help/hub/user-links');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({
          'items': items
              .map((e) => {'id': e.id, 'title': e.title, 'url': e.url})
              .toList(growable: false),
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HelpHubConfigResponseV1.fromJson(map);
}

Future<HelpHubConfigResponseV1> postSettingsHelpHubWorkspaceLinksV1(
  String accessToken, {
  required List<HelpHubLinkItemV1> items,
}) async {
  final uri =
      Uri.parse('$kApiBaseUrl/api/v1/settings/help/hub/workspace-links');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode({
          'items': items
              .map((e) => {'id': e.id, 'title': e.title, 'url': e.url})
              .toList(growable: false),
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HelpHubConfigResponseV1.fromJson(map);
}

/// `GET /api/v1/settings/help/hub` — OpenAPI `getSettingsHelpHubLinksV1`.
Future<HelpHubLinksResponseV1> getSettingsHelpHubLinksV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/help/hub');
  final res = await http
      .get(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return HelpHubLinksResponseV1.fromJson(map);
}
