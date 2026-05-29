import 'dart:convert';
import 'dart:typed_data';

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

class SyncContentComplianceAlertItemV1 {
  const SyncContentComplianceAlertItemV1({
    required this.stage,
    required this.level,
    required this.count,
    required this.title,
    required this.message,
    this.linkPath,
  });

  final String stage;
  final String level;
  final int count;
  final String title;
  final String message;
  final String? linkPath;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'stage': stage,
    'level': level,
    'count': count,
    'title': title,
    'message': message,
    if ((linkPath ?? '').trim().isNotEmpty) 'linkPath': linkPath!.trim(),
  };
}

class NotificationPreferencesV1 {
  const NotificationPreferencesV1({
    required this.mutedNotificationTypes,
    required this.mutedWorkspaceIds,
    required this.mutedProjectIds,
    required this.deliverCriticalEvenMuted,
    required this.contentComplianceClearedThrottleMinutes,
    required this.contentComplianceClearedStageThrottleMinutes,
    required this.contentComplianceClearedTemplates,
  });

  final List<String> mutedNotificationTypes;
  final List<String> mutedWorkspaceIds;
  final List<String> mutedProjectIds;
  final bool deliverCriticalEvenMuted;
  final int contentComplianceClearedThrottleMinutes;
  final Map<String, int> contentComplianceClearedStageThrottleMinutes;
  final List<ContentComplianceClearedTemplateItemV1>
  contentComplianceClearedTemplates;

  factory NotificationPreferencesV1.defaults() =>
      const NotificationPreferencesV1(
        mutedNotificationTypes: <String>[],
        mutedWorkspaceIds: <String>[],
        mutedProjectIds: <String>[],
        deliverCriticalEvenMuted: true,
        contentComplianceClearedThrottleMinutes: 30,
        contentComplianceClearedStageThrottleMinutes: <String, int>{},
        contentComplianceClearedTemplates:
            <ContentComplianceClearedTemplateItemV1>[],
      );

  factory NotificationPreferencesV1.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(Object? raw) {
      if (raw is! List) {
        return const <String>[];
      }
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    Map<String, int> parseStageMinutesMap(Object? raw) {
      if (raw is! Map) {
        return const <String, int>{};
      }
      final parsed = <String, int>{};
      raw.forEach((key, value) {
        final stage = key.toString().trim().toLowerCase();
        final minutes = (value as num?)?.toInt();
        if (stage.isEmpty || minutes == null) {
          return;
        }
        parsed[stage] = minutes;
      });
      return parsed;
    }

    return NotificationPreferencesV1(
      mutedNotificationTypes: parseStringList(json['mutedNotificationTypes']),
      mutedWorkspaceIds: parseStringList(json['mutedWorkspaceIds']),
      mutedProjectIds: parseStringList(json['mutedProjectIds']),
      deliverCriticalEvenMuted: json['deliverCriticalEvenMuted'] != false,
      contentComplianceClearedThrottleMinutes:
          (json['contentComplianceClearedThrottleMinutes'] as num?)?.toInt() ??
          30,
      contentComplianceClearedStageThrottleMinutes: parseStageMinutesMap(
        json['contentComplianceClearedStageThrottleMinutes'],
      ),
      contentComplianceClearedTemplates:
          (json['contentComplianceClearedTemplates'] as List<dynamic>? ??
                  const <dynamic>[])
              .map(
                (item) => ContentComplianceClearedTemplateItemV1.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false),
    );
  }

  NotificationPreferencesV1 copyWith({
    List<String>? mutedNotificationTypes,
    List<String>? mutedWorkspaceIds,
    List<String>? mutedProjectIds,
    bool? deliverCriticalEvenMuted,
    int? contentComplianceClearedThrottleMinutes,
    Map<String, int>? contentComplianceClearedStageThrottleMinutes,
    List<ContentComplianceClearedTemplateItemV1>?
    contentComplianceClearedTemplates,
  }) {
    return NotificationPreferencesV1(
      mutedNotificationTypes:
          mutedNotificationTypes ?? this.mutedNotificationTypes,
      mutedWorkspaceIds: mutedWorkspaceIds ?? this.mutedWorkspaceIds,
      mutedProjectIds: mutedProjectIds ?? this.mutedProjectIds,
      deliverCriticalEvenMuted:
          deliverCriticalEvenMuted ?? this.deliverCriticalEvenMuted,
      contentComplianceClearedThrottleMinutes:
          contentComplianceClearedThrottleMinutes ??
          this.contentComplianceClearedThrottleMinutes,
      contentComplianceClearedStageThrottleMinutes:
          contentComplianceClearedStageThrottleMinutes ??
          this.contentComplianceClearedStageThrottleMinutes,
      contentComplianceClearedTemplates:
          contentComplianceClearedTemplates ??
          this.contentComplianceClearedTemplates,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mutedNotificationTypes': mutedNotificationTypes,
    'mutedWorkspaceIds': mutedWorkspaceIds,
    'mutedProjectIds': mutedProjectIds,
    'deliverCriticalEvenMuted': deliverCriticalEvenMuted,
    'contentComplianceClearedThrottleMinutes':
        contentComplianceClearedThrottleMinutes,
    'contentComplianceClearedStageThrottleMinutes':
        contentComplianceClearedStageThrottleMinutes,
    'contentComplianceClearedTemplates': contentComplianceClearedTemplates
        .map(
          (item) => <String, dynamic>{
            'id': item.id,
            'label': item.label,
            'description': item.description,
            'policy': <String, dynamic>{
              'globalMinutes': item.policy.globalMinutes,
              'stageMinutes': item.policy.stageMinutes,
            },
          },
        )
        .toList(growable: false),
  };
}

class NotificationPreferencesAuditMetaV1 {
  const NotificationPreferencesAuditMetaV1({
    required this.updatedAt,
    required this.updatedBy,
    required this.source,
  });

  final DateTime? updatedAt;
  final String updatedBy;
  final String source;

  factory NotificationPreferencesAuditMetaV1.fromJson(
    Map<String, dynamic> json,
  ) {
    DateTime? parseNullableDateTime(Object? raw) {
      if (raw is! String || raw.trim().isEmpty) {
        return null;
      }
      return DateTime.tryParse(raw);
    }

    return NotificationPreferencesAuditMetaV1(
      updatedAt: parseNullableDateTime(json['updatedAt']),
      updatedBy: (json['updatedBy'] as String?)?.trim().isNotEmpty == true
          ? (json['updatedBy'] as String).trim()
          : 'self',
      source: (json['source'] as String?)?.trim().isNotEmpty == true
          ? (json['source'] as String).trim()
          : 'manual',
    );
  }
}

class NotificationPreferencesEnvelopeV1 {
  const NotificationPreferencesEnvelopeV1({
    required this.preferences,
    required this.audit,
  });

  final NotificationPreferencesV1 preferences;
  final NotificationPreferencesAuditMetaV1 audit;

  factory NotificationPreferencesEnvelopeV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return NotificationPreferencesEnvelopeV1(
      preferences: NotificationPreferencesV1.fromJson(
        json['preferences'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      audit: NotificationPreferencesAuditMetaV1.fromJson(
        json['audit'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class ContentComplianceClearedTemplatePolicyV1 {
  const ContentComplianceClearedTemplatePolicyV1({
    required this.globalMinutes,
    required this.stageMinutes,
  });

  final int globalMinutes;
  final Map<String, int> stageMinutes;

  factory ContentComplianceClearedTemplatePolicyV1.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawStage = json['stageMinutes'];
    final stageMinutes = <String, int>{};
    if (rawStage is Map) {
      rawStage.forEach((key, value) {
        final minutes = (value as num?)?.toInt();
        final stage = key.toString().trim().toLowerCase();
        if (minutes != null && stage.isNotEmpty) {
          stageMinutes[stage] = minutes;
        }
      });
    }
    return ContentComplianceClearedTemplatePolicyV1(
      globalMinutes: (json['globalMinutes'] as num?)?.toInt() ?? 30,
      stageMinutes: stageMinutes,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'globalMinutes': globalMinutes,
    'stageMinutes': stageMinutes,
  };
}

class ContentComplianceClearedTemplateItemV1 {
  const ContentComplianceClearedTemplateItemV1({
    required this.id,
    required this.label,
    required this.description,
    required this.policy,
    required this.kind,
    required this.canEdit,
    required this.canDelete,
  });

  final String id;
  final String label;
  final String description;
  final ContentComplianceClearedTemplatePolicyV1 policy;
  final String kind;
  final bool canEdit;
  final bool canDelete;

  factory ContentComplianceClearedTemplateItemV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceClearedTemplateItemV1(
      id: (json['id'] as String?)?.trim() ?? '',
      label: (json['label'] as String?)?.trim() ?? '',
      description: (json['description'] as String?)?.trim() ?? '',
      policy: ContentComplianceClearedTemplatePolicyV1.fromJson(
        json['policy'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      kind: (json['kind'] as String?)?.trim().toLowerCase() ?? 'custom',
      canEdit: json['canEdit'] != false,
      canDelete: json['canDelete'] != false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'description': description,
    'policy': policy.toJson(),
    'kind': kind,
    'canEdit': canEdit,
    'canDelete': canDelete,
  };
}

class WorkspaceSharedComplianceTemplatesV1 {
  const WorkspaceSharedComplianceTemplatesV1({
    required this.workspaceId,
    required this.canManage,
    required this.templates,
  });

  final String workspaceId;
  final bool canManage;
  final List<ContentComplianceClearedTemplateItemV1> templates;

  factory WorkspaceSharedComplianceTemplatesV1.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawTemplates =
        json['templates'] as List<dynamic>? ?? const <dynamic>[];
    return WorkspaceSharedComplianceTemplatesV1(
      workspaceId: (json['workspaceId'] as String?)?.trim() ?? '',
      canManage: json['canManage'] == true,
      templates: rawTemplates
          .map(
            (item) => ContentComplianceClearedTemplateItemV1.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class ContentComplianceClearedTemplateAuditItemV1 {
  const ContentComplianceClearedTemplateAuditItemV1({
    required this.at,
    required this.actorUserId,
    required this.action,
    required this.templateId,
    required this.note,
  });

  final DateTime? at;
  final String actorUserId;
  final String action;
  final String templateId;
  final String? note;

  factory ContentComplianceClearedTemplateAuditItemV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentComplianceClearedTemplateAuditItemV1(
      at: DateTime.tryParse((json['at'] as String?)?.trim() ?? ''),
      actorUserId: (json['actorUserId'] as String?)?.trim() ?? '',
      action: (json['action'] as String?)?.trim() ?? '',
      templateId: (json['templateId'] as String?)?.trim() ?? '',
      note: (json['note'] as String?)?.trim(),
    );
  }
}

class WorkspaceSharedComplianceAuditExportRecordV1 {
  const WorkspaceSharedComplianceAuditExportRecordV1({
    required this.exportedAt,
    required this.actorUserId,
    required this.format,
    required this.fileName,
    required this.templateId,
    required this.action,
    required this.startAt,
    required this.endAt,
    required this.jobId,
    required this.exportDelivery,
  });

  final DateTime? exportedAt;
  final String actorUserId;
  final String format;
  final String fileName;
  final String? templateId;
  final String? action;
  final String? startAt;
  final String? endAt;
  /// Present when export was produced by async job (`exportDelivery` == `async`).
  final String? jobId;
  /// `sync` (inline GET export) or `async` (background job file).
  final String? exportDelivery;

  factory WorkspaceSharedComplianceAuditExportRecordV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkspaceSharedComplianceAuditExportRecordV1(
      exportedAt: DateTime.tryParse(
        (json['exportedAt'] as String?)?.trim() ?? '',
      ),
      actorUserId: (json['actorUserId'] as String?)?.trim() ?? '',
      format: (json['format'] as String?)?.trim() ?? '',
      fileName: (json['fileName'] as String?)?.trim() ?? '',
      templateId: (json['templateId'] as String?)?.trim(),
      action: (json['action'] as String?)?.trim(),
      startAt: (json['startAt'] as String?)?.trim(),
      endAt: (json['endAt'] as String?)?.trim(),
      jobId: (json['jobId'] as String?)?.trim(),
      exportDelivery: (json['exportDelivery'] as String?)?.trim(),
    );
  }
}

class WorkspaceSharedAuditExportJobRecordV1 {
  const WorkspaceSharedAuditExportJobRecordV1({
    required this.id,
    required this.numericTaskId,
    required this.status,
    required this.workspaceId,
    required this.createdAt,
    required this.updatedAt,
    required this.errorMessage,
    required this.fileName,
    required this.contentType,
    required this.byteSize,
    required this.downloadReady,
  });

  final String id;
  final int numericTaskId;
  final String status;
  final String workspaceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;
  final String? fileName;
  final String? contentType;
  final int? byteSize;
  final bool downloadReady;

  factory WorkspaceSharedAuditExportJobRecordV1.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkspaceSharedAuditExportJobRecordV1(
      id: (json['id'] as String?)?.trim() ?? '',
      numericTaskId: (json['numericTaskId'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?)?.trim() ?? '',
      workspaceId: (json['workspaceId'] as String?)?.trim() ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?)?.trim() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?)?.trim() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      errorMessage: (json['errorMessage'] as String?)?.trim(),
      fileName: (json['fileName'] as String?)?.trim(),
      contentType: (json['contentType'] as String?)?.trim(),
      byteSize: (json['byteSize'] as num?)?.toInt(),
      downloadReady: json['downloadReady'] == true,
    );
  }
}

class WorkspaceSharedAuditExportDownloadV1 {
  const WorkspaceSharedAuditExportDownloadV1({
    required this.bytes,
    required this.fileName,
    this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  /// Response `Content-Type` when present (helps Web blob MIME).
  final String? contentType;
}

String? _workspaceAuditExportFileNameFromDisposition(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  final utf8Match = RegExp(
    r'''filename\*=UTF-8''([^;]+)''',
    caseSensitive: false,
  ).firstMatch(raw);
  if (utf8Match != null) {
    return Uri.decodeComponent(utf8Match.group(1)!);
  }
  final plainMatch = RegExp(
    r'''filename="?([^";]+)"?''',
    caseSensitive: false,
  ).firstMatch(raw);
  return plainMatch?.group(1);
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
      .get(uri, headers: rustApiAuthHeaders(accessToken))
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
        headers: rustApiJsonAuthHeaders(accessToken),
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
      .post(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return MarkAllNotificationsReadResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<int> syncContentComplianceAlertsV1(
  String accessToken,
  List<SyncContentComplianceAlertItemV1> alerts,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/sync',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{
          'alerts': alerts.map((item) => item.toJson()).toList(growable: false),
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return (json['syncedCount'] as num?)?.toInt() ?? 0;
}

Future<NotificationPreferencesV1> fetchNotificationPreferencesV1(
  String accessToken,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/preferences',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return NotificationPreferencesV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<NotificationPreferencesV1> saveNotificationPreferencesV1(
  String accessToken,
  NotificationPreferencesV1 preferences,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/preferences',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(preferences.toJson()),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return NotificationPreferencesV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<NotificationPreferencesEnvelopeV1> fetchNotificationPreferencesExportV1(
  String accessToken,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/preferences/export',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return NotificationPreferencesEnvelopeV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<List<ContentComplianceClearedTemplateItemV1>>
fetchContentComplianceClearedTemplatesV1(String accessToken) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final rawTemplates = json['templates'] as List<dynamic>? ?? const <dynamic>[];
  return rawTemplates
      .map(
        (item) => ContentComplianceClearedTemplateItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}

Future<List<ContentComplianceClearedTemplateItemV1>>
upsertContentComplianceClearedTemplateV1(
  String accessToken,
  ContentComplianceClearedTemplateItemV1 template,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'template': template.toJson()}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final rawTemplates = json['templates'] as List<dynamic>? ?? const <dynamic>[];
  return rawTemplates
      .map(
        (item) => ContentComplianceClearedTemplateItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}

Future<List<ContentComplianceClearedTemplateItemV1>>
deleteContentComplianceClearedTemplateV1(String accessToken, String id) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates',
  );
  final res = await http
      .delete(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final rawTemplates = json['templates'] as List<dynamic>? ?? const <dynamic>[];
  return rawTemplates
      .map(
        (item) => ContentComplianceClearedTemplateItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}

Future<WorkspaceSharedComplianceTemplatesV1>
fetchWorkspaceSharedComplianceClearedTemplatesV1(String accessToken) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return WorkspaceSharedComplianceTemplatesV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<WorkspaceSharedComplianceTemplatesV1>
upsertWorkspaceSharedComplianceClearedTemplateV1(
  String accessToken,
  ContentComplianceClearedTemplateItemV1 template,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'template': template.toJson()}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return WorkspaceSharedComplianceTemplatesV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<WorkspaceSharedComplianceTemplatesV1>
deleteWorkspaceSharedComplianceClearedTemplateV1(
  String accessToken,
  String id,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared',
  );
  final res = await http
      .delete(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return WorkspaceSharedComplianceTemplatesV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<(List<ContentComplianceClearedTemplateAuditItemV1>, bool, int?)>
fetchWorkspaceSharedComplianceClearedTemplateAuditV1(
  String accessToken, {
  String? templateId,
  String? action,
  DateTime? startAt,
  DateTime? endAt,
  int limit = 20,
  int offset = 0,
}) async {
  final query = <String, String>{
    'limit': '${limit.clamp(1, 100)}',
    'offset': '${offset < 0 ? 0 : offset}',
  };
  if (templateId != null && templateId.trim().isNotEmpty) {
    query['templateId'] = templateId.trim();
  }
  if (action != null && action.trim().isNotEmpty) {
    query['action'] = action.trim();
  }
  if (startAt != null) {
    query['startAt'] = startAt.toUtc().toIso8601String();
  }
  if (endAt != null) {
    query['endAt'] = endAt.toUtc().toIso8601String();
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit',
  ).replace(queryParameters: query);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
  final items = raw
      .map(
        (item) => ContentComplianceClearedTemplateAuditItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .toList(growable: false);
  final hasMore = json['hasMore'] == true;
  final nextOffset = (json['nextOffset'] as num?)?.toInt();
  return (items, hasMore, nextOffset);
}

Future<(String, String)> exportWorkspaceSharedComplianceClearedTemplateAuditV1(
  String accessToken, {
  required String format,
  String? templateId,
  String? action,
  DateTime? startAt,
  DateTime? endAt,
}) async {
  final normalizedFormat = format.trim().toLowerCase();
  final query = <String, String>{
    'format': normalizedFormat == 'csv' ? 'csv' : 'json',
  };
  if (templateId != null && templateId.trim().isNotEmpty) {
    query['templateId'] = templateId.trim();
  }
  if (action != null && action.trim().isNotEmpty) {
    query['action'] = action.trim();
  }
  if (startAt != null) {
    query['startAt'] = startAt.toUtc().toIso8601String();
  }
  if (endAt != null) {
    query['endAt'] = endAt.toUtc().toIso8601String();
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export',
  ).replace(queryParameters: query);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  return (
    (json['fileName'] as String?)?.trim() ??
        'workspace_shared_template_audit.txt',
    json['content'] as String? ?? '',
  );
}

Future<WorkspaceSharedAuditExportJobRecordV1>
postWorkspaceSharedComplianceClearedTemplateAuditExportAsyncV1(
  String accessToken, {
  required String format,
  String? templateId,
  String? action,
  DateTime? startAt,
  DateTime? endAt,
}) async {
  final normalizedFormat = format.trim().toLowerCase();
  final body = <String, dynamic>{
    'format': normalizedFormat == 'csv' ? 'csv' : 'json',
  };
  if (templateId != null && templateId.trim().isNotEmpty) {
    body['templateId'] = templateId.trim();
  }
  if (action != null && action.trim().isNotEmpty) {
    body['action'] = action.trim();
  }
  if (startAt != null) {
    body['startAt'] = startAt.toUtc().toIso8601String();
  }
  if (endAt != null) {
    body['endAt'] = endAt.toUtc().toIso8601String();
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-async',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  return WorkspaceSharedAuditExportJobRecordV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<WorkspaceSharedAuditExportJobRecordV1>
fetchWorkspaceSharedComplianceClearedTemplateAuditExportJobV1(
  String accessToken, {
  required String jobId,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/${Uri.encodeComponent(jobId)}',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  return WorkspaceSharedAuditExportJobRecordV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<WorkspaceSharedAuditExportDownloadV1>
downloadWorkspaceSharedComplianceClearedTemplateAuditExportJobFileV1(
  String accessToken, {
  required String jobId,
  String? fallbackFileName,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/export-jobs/${Uri.encodeComponent(jobId)}/file',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(minutes: 2));
  ensureHttpSuccess(res);
  return WorkspaceSharedAuditExportDownloadV1(
    bytes: Uint8List.fromList(res.bodyBytes),
    fileName:
        _workspaceAuditExportFileNameFromDisposition(
          res.headers['content-disposition'],
        ) ??
        fallbackFileName ??
        'workspace_shared_template_audit-$jobId.bin',
    contentType: res.headers['content-type']?.trim(),
  );
}

Future<(List<WorkspaceSharedComplianceAuditExportRecordV1>, bool, int?)>
fetchWorkspaceSharedComplianceClearedTemplateAuditExportsV1(
  String accessToken, {
  String? format,
  DateTime? exportedStartAt,
  DateTime? exportedEndAt,
  int limit = 20,
  int offset = 0,
}) async {
  final query = <String, String>{
    'limit': '${limit.clamp(1, 100)}',
    'offset': '${offset < 0 ? 0 : offset}',
  };
  if (format != null && format.trim().isNotEmpty) {
    query['format'] = format.trim().toLowerCase();
  }
  if (exportedStartAt != null) {
    query['exportedStartAt'] = exportedStartAt.toUtc().toIso8601String();
  }
  if (exportedEndAt != null) {
    query['exportedEndAt'] = exportedEndAt.toUtc().toIso8601String();
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/shared/audit/exports',
  ).replace(queryParameters: query);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
  final items = raw
      .map(
        (item) => WorkspaceSharedComplianceAuditExportRecordV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .toList(growable: false);
  final hasMore = json['hasMore'] == true;
  final nextOffset = (json['nextOffset'] as num?)?.toInt();
  return (items, hasMore, nextOffset);
}

Future<(bool, List<ContentComplianceClearedTemplateItemV1>)>
applyContentComplianceClearedTemplateV1(String accessToken, String id) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/apply',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'id': id}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final applied = json['applied'] == true;
  final rawTemplates = json['templates'] as List<dynamic>? ?? const <dynamic>[];
  final templates = rawTemplates
      .map(
        (item) => ContentComplianceClearedTemplateItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
  return (applied, templates);
}

Future<List<ContentComplianceClearedTemplateItemV1>>
reorderContentComplianceClearedTemplatesV1(
  String accessToken,
  List<String> ids,
) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/reorder',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'ids': ids}),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final rawTemplates = json['templates'] as List<dynamic>? ?? const <dynamic>[];
  return rawTemplates
      .map(
        (item) => ContentComplianceClearedTemplateItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}

Future<
  (List<ContentComplianceClearedTemplateItemV1>, List<String>, List<String>)
>
exportContentComplianceClearedTemplatesV1(String accessToken) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/export',
  );
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final templates = (json['templates'] as List<dynamic>? ?? const <dynamic>[])
      .map(
        (item) => ContentComplianceClearedTemplateItemV1.fromJson(
          item as Map<String, dynamic>,
        ),
      )
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
  final order = (json['order'] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString().trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  final recent = (json['recent'] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString().trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  return (templates, order, recent);
}

Future<
  (
    int,
    List<ContentComplianceClearedTemplateItemV1>,
    List<String>,
    List<String>,
  )
>
importContentComplianceClearedTemplatesV1(
  String accessToken, {
  required List<ContentComplianceClearedTemplateItemV1> templates,
  required List<String> order,
  required List<String> recent,
  required String mode,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/notifications/content-compliance/cleared-templates/import',
  );
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{
          'templates': templates
              .map((item) => item.toJson())
              .toList(growable: false),
          'order': order,
          'recent': recent,
          'mode': mode,
        }),
      )
      .timeout(const Duration(seconds: 15));
  ensureHttpSuccess(res);
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final importedCount = (json['importedCount'] as num?)?.toInt() ?? 0;
  final outTemplates =
      (json['templates'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) => ContentComplianceClearedTemplateItemV1.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
  final outOrder = (json['order'] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString().trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  final outRecent = (json['recent'] as List<dynamic>? ?? const <dynamic>[])
      .map((item) => item.toString().trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  return (importedCount, outTemplates, outOrder, outRecent);
}
