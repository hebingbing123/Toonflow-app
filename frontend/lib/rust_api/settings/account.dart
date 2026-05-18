import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class AccountExportJobRecordV1 {
  const AccountExportJobRecordV1({
    required this.id,
    required this.numericTaskId,
    required this.status,
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
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? errorMessage;
  final String? fileName;
  final String? contentType;
  final int? byteSize;
  final bool downloadReady;

  factory AccountExportJobRecordV1.fromJson(Map<String, dynamic> json) {
    return AccountExportJobRecordV1(
      id: json['id'] as String,
      numericTaskId: (json['numericTaskId'] as num).toInt(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      errorMessage: json['errorMessage'] as String?,
      fileName: json['fileName'] as String?,
      contentType: json['contentType'] as String?,
      byteSize: (json['byteSize'] as num?)?.toInt(),
      downloadReady: json['downloadReady'] == true,
    );
  }
}

class AccountExportsResponseV1 {
  const AccountExportsResponseV1({
    required this.items,
    required this.activeCount,
  });

  final List<AccountExportJobRecordV1> items;
  final int activeCount;

  factory AccountExportsResponseV1.fromJson(Map<String, dynamic> json) {
    final raw = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return AccountExportsResponseV1(
      items: raw
          .map(
            (item) =>
                AccountExportJobRecordV1.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AccountDeleteResponseV1 {
  const AccountDeleteResponseV1({
    required this.deletedUserId,
    required this.deletedAt,
    required this.ownedWorkspaceCount,
    required this.workspaceMembershipCount,
    required this.ownedProjectCount,
    required this.generationJobCount,
    required this.notificationCount,
    required this.localCleanupPaths,
  });

  final String deletedUserId;
  final DateTime deletedAt;
  final int ownedWorkspaceCount;
  final int workspaceMembershipCount;
  final int ownedProjectCount;
  final int generationJobCount;
  final int notificationCount;
  final List<String> localCleanupPaths;

  factory AccountDeleteResponseV1.fromJson(Map<String, dynamic> json) {
    final cleanup =
        json['localCleanupPaths'] as List<dynamic>? ?? const <dynamic>[];
    return AccountDeleteResponseV1(
      deletedUserId: json['deletedUserId'] as String,
      deletedAt: DateTime.parse(json['deletedAt'] as String),
      ownedWorkspaceCount: (json['ownedWorkspaceCount'] as num?)?.toInt() ?? 0,
      workspaceMembershipCount:
          (json['workspaceMembershipCount'] as num?)?.toInt() ?? 0,
      ownedProjectCount: (json['ownedProjectCount'] as num?)?.toInt() ?? 0,
      generationJobCount: (json['generationJobCount'] as num?)?.toInt() ?? 0,
      notificationCount: (json['notificationCount'] as num?)?.toInt() ?? 0,
      localCleanupPaths: cleanup
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class AccountExportDownloadV1 {
  const AccountExportDownloadV1({required this.bytes, required this.fileName});

  final Uint8List bytes;
  final String fileName;
}

Future<AccountExportJobRecordV1> createAccountExportV1(
  String accessToken, {
  bool includeAuditLogs = false,
  bool includeNotifications = true,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/account/export');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'includeAuditLogs': includeAuditLogs,
          'includeNotifications': includeNotifications,
        }),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  return AccountExportJobRecordV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AccountExportsResponseV1> fetchAccountExportsV1(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/account/exports');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  return AccountExportsResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<AccountExportDownloadV1> downloadAccountExportV1(
  String accessToken, {
  required String jobId,
  String? fallbackFileName,
}) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/settings/account/exports/$jobId/file',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(minutes: 2));
  ensureHttpSuccess(res);
  return AccountExportDownloadV1(
      bytes: res.bodyBytes,
      fileName:
        _fileNameFromContentDisposition(res.headers['content-disposition']) ??
        fallbackFileName ??
        'openflow-account-export-$jobId.zip',
  );
}

Future<AccountDeleteResponseV1> deleteAccountV1(
  String accessToken, {
  required String confirmPhrase,
  required bool acknowledgeIrreversible,
}) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/settings/account/delete');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'confirmPhrase': confirmPhrase,
          'acknowledgeIrreversible': acknowledgeIrreversible,
        }),
      )
      .timeout(const Duration(seconds: 30));
  ensureHttpSuccess(res);
  return AccountDeleteResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

String? _fileNameFromContentDisposition(String? raw) {
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
