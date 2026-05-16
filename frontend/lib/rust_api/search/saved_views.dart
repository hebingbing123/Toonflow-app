import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

/// One saved global-search view (`GET`/`PUT /api/v1/search/saved-views`), camelCase on the wire.
class SearchSavedViewItem {
  const SearchSavedViewItem({
    required this.id,
    required this.title,
    required this.query,
    this.workspaceName,
    this.workspaceId,
    required this.pinned,
    required this.resultTypes,
    this.timeFrom,
    this.timeTo,
    this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    required this.useCount,
  });

  final String id;
  final String title;
  final String query;
  final String? workspaceName;

  /// Workspace UUID string (optional); sent as `workspaceId` JSON field.
  final String? workspaceId;
  final bool pinned;
  final List<String> resultTypes;
  final DateTime? timeFrom;
  final DateTime? timeTo;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int useCount;

  factory SearchSavedViewItem.fromJson(Map<String, dynamic> json) {
    return SearchSavedViewItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      query: json['query'] as String? ?? '',
      workspaceName: json['workspaceName'] as String?,
      workspaceId: json['workspaceId'] as String?,
      pinned: json['pinned'] as bool? ?? false,
      resultTypes: (json['resultTypes'] as List? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(growable: false),
      timeFrom: _parseIso(json['timeFrom'] as String?),
      timeTo: _parseIso(json['timeTo'] as String?),
      createdAt: _parseIso(json['createdAt'] as String?),
      updatedAt:
          _parseIso(json['updatedAt'] as String?) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      lastUsedAt: _parseIso(json['lastUsedAt'] as String?),
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'query': query,
      if (workspaceName != null) 'workspaceName': workspaceName,
      if (workspaceId != null && workspaceId!.isNotEmpty)
        'workspaceId': workspaceId,
      'pinned': pinned,
      'resultTypes': resultTypes,
      if (timeFrom != null)
        'timeFrom': timeFrom!.toUtc().toIso8601String(),
      if (timeTo != null) 'timeTo': timeTo!.toUtc().toIso8601String(),
      if (createdAt != null)
        'createdAt': createdAt!.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'useCount': useCount,
    };
  }

  static DateTime? _parseIso(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }
}

/// `GET /api/v1/search/saved-views`
Future<List<SearchSavedViewItem>> getSearchSavedViews(String accessToken) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/search/saved-views');
  final res = await http
      .get(uri, headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
      })
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body) as Map<String, dynamic>;
  final items = decoded['items'] as List<dynamic>? ?? const <dynamic>[];
  return items
      .map(
        (dynamic e) =>
            SearchSavedViewItem.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(growable: false);
}

/// `PUT /api/v1/search/saved-views` — full replace for the current user.
Future<List<SearchSavedViewItem>> putSearchSavedViews(
  String accessToken,
  List<SearchSavedViewItem> items,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/search/saved-views');
  final body = jsonEncode(<String, dynamic>{
    'items': items.map((SearchSavedViewItem e) => e.toJson()).toList(),
  });
  final res = await http
      .put(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: body,
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  final decoded = jsonDecode(res.body) as Map<String, dynamic>;
  final out = decoded['items'] as List<dynamic>? ?? const <dynamic>[];
  return out
      .map(
        (dynamic e) =>
            SearchSavedViewItem.fromJson(Map<String, dynamic>.from(e as Map)),
      )
      .toList(growable: false);
}
