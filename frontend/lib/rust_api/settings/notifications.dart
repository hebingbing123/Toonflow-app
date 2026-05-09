import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class NotificationRecordV1 {
  const NotificationRecordV1({
    required this.id,
    required this.userId,
    this.workspaceId,
    this.projectId,
    this.projectNumericId,
    this.jobId,
    required this.notificationType,
    required this.title,
    required this.message,
    this.linkPath,
    required this.payload,
    this.filePath,
    this.changedAt,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String userId;
  final String? workspaceId;
  final String? projectId;
  final int? projectNumericId;
  final String? jobId;
  final String notificationType;
  final String title;
  final String message;
  final String? linkPath;
  final Map<String, dynamic> payload;
  final String? filePath;
  final DateTime? changedAt;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRead => readAt != null;

  factory NotificationRecordV1.fromJson(Map<String, dynamic> json) {
    DateTime? parseOptionalDateTime(String key) {
      final raw = json[key];
      if (raw is! String || raw.trim().isEmpty) {
        return null;
      }
      return DateTime.parse(raw);
    }

    return NotificationRecordV1(
      id: (json['id'] as num).toInt(),
      userId: json['userId'] as String,
      workspaceId: json['workspaceId'] as String?,
      projectId: json['projectId'] as String?,
      projectNumericId: switch (json['projectNumericId']) {
        final num value => value.toInt(),
        _ => null,
      },
      jobId: json['jobId'] as String?,
      notificationType: json['notificationType'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      linkPath: json['linkPath'] as String?,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      filePath: json['filePath'] as String?,
      changedAt: parseOptionalDateTime('changedAt'),
      readAt: parseOptionalDateTime('readAt'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ListNotificationsEnvelopeV1 {
  const ListNotificationsEnvelopeV1({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
    this.nextBeforeId,
  });

  final List<NotificationRecordV1> items;
  final int unreadCount;
  final bool hasMore;
  final int? nextBeforeId;

  factory ListNotificationsEnvelopeV1.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return ListNotificationsEnvelopeV1(
      items: rawItems
          .cast<Map<String, dynamic>>()
          .map(NotificationRecordV1.fromJson)
          .toList(growable: false),
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
      hasMore: json['hasMore'] as bool? ?? false,
      nextBeforeId: switch (json['nextBeforeId']) {
        final num value => value.toInt(),
        _ => null,
      },
    );
  }
}

class ListNotificationsQueryV1 {
  const ListNotificationsQueryV1({
    this.notificationType,
    this.unreadOnly,
    this.query,
    this.limit,
    this.beforeId,
  });

  final String? notificationType;
  final bool? unreadOnly;
  final String? query;
  final int? limit;
  final int? beforeId;

  Map<String, String> toQueryParameters() {
    final out = <String, String>{};
    final typeText = notificationType?.trim();
    if (typeText != null && typeText.isNotEmpty) {
      out['notificationType'] = typeText;
    }
    if (unreadOnly != null) {
      out['unreadOnly'] = '$unreadOnly';
    }
    final queryText = query?.trim();
    if (queryText != null && queryText.isNotEmpty) {
      out['query'] = queryText;
    }
    if (limit != null) {
      out['limit'] = '$limit';
    }
    if (beforeId != null && beforeId! > 0) {
      out['beforeId'] = '$beforeId';
    }
    return out;
  }
}

class MarkNotificationsReadBodyV1 {
  const MarkNotificationsReadBodyV1({
    required this.ids,
    this.read,
  });

  final List<int> ids;
  final bool? read;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ids': ids,
      if (read != null) 'read': read,
    };
  }
}

class MarkNotificationsReadEnvelopeV1 {
  const MarkNotificationsReadEnvelopeV1({
    required this.items,
    required this.unreadCount,
  });

  final List<NotificationRecordV1> items;
  final int unreadCount;

  factory MarkNotificationsReadEnvelopeV1.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    return MarkNotificationsReadEnvelopeV1(
      items: rawItems
          .cast<Map<String, dynamic>>()
          .map(NotificationRecordV1.fromJson)
          .toList(growable: false),
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
    );
  }
}

class MarkAllNotificationsReadResponseV1 {
  const MarkAllNotificationsReadResponseV1({
    required this.updatedCount,
    required this.unreadCount,
  });

  final int updatedCount;
  final int unreadCount;

  factory MarkAllNotificationsReadResponseV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return MarkAllNotificationsReadResponseV1(
      updatedCount: (json['updatedCount'] as num? ?? 0).toInt(),
      unreadCount: (json['unreadCount'] as num? ?? 0).toInt(),
    );
  }
}

Future<ListNotificationsEnvelopeV1> getSettingsNotificationsV1(
  String accessToken, {
  ListNotificationsQueryV1 query = const ListNotificationsQueryV1(),
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications',
  ).replace(queryParameters: query.toQueryParameters());
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return ListNotificationsEnvelopeV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<MarkNotificationsReadEnvelopeV1> postSettingsNotificationsMarkReadV1(
  String accessToken,
  MarkNotificationsReadBodyV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/notifications/mark-read');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return MarkNotificationsReadEnvelopeV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<MarkAllNotificationsReadResponseV1>
postSettingsNotificationsMarkAllReadV1(String accessToken) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/mark-all-read',
  );
  final res = await http
      .post(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return MarkAllNotificationsReadResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
