import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class ExportTaskV1 {
  const ExportTaskV1({
    required this.id,
    required this.projectId,
    this.versionId,
    required this.status,
    this.stage,
    required this.progress,
    required this.format,
    required this.quality,
    this.outputUrl,
    this.error,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? versionId;
  final String status;
  final String? stage;
  final int progress;
  final String format;
  final Map<String, dynamic> quality;
  final String? outputUrl;
  final String? error;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ExportTaskV1.fromJson(Map<String, dynamic> json) {
    DateTime? parseOptional(String key) {
      final raw = json[key];
      if (raw is! String || raw.trim().isEmpty) {
        return null;
      }
      return DateTime.parse(raw);
    }

    return ExportTaskV1(
      id: json['id'] as String? ?? '',
      projectId: json['projectId'] as String? ?? '',
      versionId: json['versionId'] as String?,
      status: json['status'] as String? ?? 'pending',
      stage: json['stage'] as String?,
      progress: (json['progress'] as num? ?? 0).toInt(),
      format: json['format'] as String? ?? 'mp4',
      quality: (json['quality'] as Map<String, dynamic>?) ?? const {},
      outputUrl: json['outputUrl'] as String?,
      error: json['error'] as String?,
      startedAt: parseOptional('startedAt'),
      completedAt: parseOptional('completedAt'),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class ExportQualityV1 {
  const ExportQualityV1({
    required this.resolution,
    required this.bitrate,
    required this.framerate,
  });

  final String resolution;
  final int bitrate;
  final int framerate;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'resolution': resolution,
    'bitrate': bitrate,
    'framerate': framerate,
  };
}

class CreateExportTaskRequestV1 {
  const CreateExportTaskRequestV1({
    required this.projectId,
    this.versionId,
    required this.format,
    required this.quality,
  });

  final String projectId;
  final String? versionId;
  final String format;
  final ExportQualityV1 quality;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'project_id': projectId,
    if (versionId != null) 'version_id': versionId,
    'format': format,
    'quality': quality.toJson(),
  };
}

Future<ExportTaskV1> postExportStartV1(
  String accessToken,
  CreateExportTaskRequestV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/export/start');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return ExportTaskV1.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<List<ExportTaskV1>> getExportTasksV1(
  String accessToken, {
  String? projectId,
  String? status,
  int? limit,
  int? offset,
}) async {
  final query = <String, String>{};
  if (projectId != null && projectId.trim().isNotEmpty) {
    query['project_id'] = projectId.trim();
  }
  if (status != null && status.trim().isNotEmpty) {
    query['status'] = status.trim();
  }
  if (limit != null) {
    query['limit'] = '$limit';
  }
  if (offset != null) {
    query['offset'] = '$offset';
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/export/tasks',
  ).replace(queryParameters: query.isEmpty ? null : query);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final payload = jsonDecode(res.body) as List<dynamic>;
  return payload
      .cast<Map<String, dynamic>>()
      .map(ExportTaskV1.fromJson)
      .toList(growable: false);
}

Future<ExportTaskV1> getExportTaskByIdV1(String accessToken, String taskId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/export/tasks/$taskId');
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return ExportTaskV1.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<void> postExportCancelV1(String accessToken, String taskId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/export/cancel');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'task_id': taskId}),
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
}
