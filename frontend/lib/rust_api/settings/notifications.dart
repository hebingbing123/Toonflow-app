import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class NotificationRecordV1 {
  const NotificationRecordV1({
    required this.id,
    required this.userId,
    required this.workspaceId,
    required this.projectId,
    required this.projectNumericId,
    required this.jobId,
    required this.notificationType,
    required this.title,
    required this.message,
    required this.linkPath,
    required this.payload,
    required this.filePath,
    required this.changedAt,
    required this.readAt,
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

  bool get isUnread => readAt == null;

  factory NotificationRecordV1.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDateTime(Object? raw) {
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
      projectNumericId: (json['projectNumericId'] as num?)?.toInt(),
      jobId: json['jobId'] as String?,
      notificationType: json['notificationType'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      linkPath: json['linkPath'] as String?,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      filePath: json['filePath'] as String?,
      changedAt: parseNullableDateTime(json['changedAt']),
      readAt: parseNullableDateTime(json['readAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class NotificationsListEnvelopeV1 {
  const NotificationsListEnvelopeV1({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
    required this.nextBeforeId,
  });

  final List<NotificationRecordV1> items;
  final int unreadCount;
  final bool hasMore;
  final int? nextBeforeId;

  factory NotificationsListEnvelopeV1.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return NotificationsListEnvelopeV1(
      items: rawItems
          .map(
            (item) =>
                NotificationRecordV1.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      hasMore: json['hasMore'] == true,
      nextBeforeId: (json['nextBeforeId'] as num?)?.toInt(),
    );
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
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return MarkNotificationsReadEnvelopeV1(
      items: rawItems
          .map(
            (item) =>
                NotificationRecordV1.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
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
      updatedCount: (json['updatedCount'] as num?)?.toInt() ?? 0,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

Future<NotificationsListEnvelopeV1> fetchNotificationsV1(
  String accessToken, {
  String? notificationType,
  bool unreadOnly = false,
  String? query,
  int limit = 50,
  int? beforeId,
}) async {
  final queryParameters = <String, String>{'limit': '$limit'};
  if (notificationType != null && notificationType.trim().isNotEmpty) {
    queryParameters['notificationType'] = notificationType.trim();
  }
  if (unreadOnly) {
    queryParameters['unreadOnly'] = 'true';
  }
  if (query != null && query.trim().isNotEmpty) {
    queryParameters['query'] = query.trim();
  }
  if (beforeId != null) {
    queryParameters['beforeId'] = '$beforeId';
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications',
  ).replace(queryParameters: queryParameters);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return NotificationsListEnvelopeV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<MarkNotificationsReadEnvelopeV1> markNotificationsReadV1(
  String accessToken,
  List<int> ids, {
  bool read = true,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/notifications/mark-read');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'ids': ids, 'read': read}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return MarkNotificationsReadEnvelopeV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<MarkAllNotificationsReadResponseV1> markAllNotificationsReadV1(
  String accessToken,
) async {
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
