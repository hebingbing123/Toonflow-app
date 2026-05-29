import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';

class TtsGenerateRequestV1 {
  const TtsGenerateRequestV1({
    required this.projectId,
    required this.shotId,
    required this.text,
    required this.provider,
    required this.voiceId,
    this.emotion,
    this.speed,
  });

  final String projectId;
  final String shotId;
  final String text;
  final String provider;
  final String voiceId;
  final String? emotion;
  final double? speed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'project_id': projectId,
    'shot_id': shotId,
    'text': text,
    'provider': provider,
    'voice_id': voiceId,
    if (emotion != null && emotion!.trim().isNotEmpty) 'emotion': emotion,
    if (speed != null) 'speed': speed,
  };
}

class TtsGenerateResponseV1 {
  const TtsGenerateResponseV1({
    required this.taskId,
    required this.status,
    this.audioUrl,
  });

  final String taskId;
  final String status;
  final String? audioUrl;

  factory TtsGenerateResponseV1.fromJson(Map<String, dynamic> json) {
    return TtsGenerateResponseV1(
      taskId: json['task_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
    );
  }
}

class TtsBatchGenerateRequestV1 {
  const TtsBatchGenerateRequestV1({
    required this.projectId,
    required this.shots,
  });

  final String projectId;
  final List<TtsGenerateRequestV1> shots;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'project_id': projectId,
    'shots': shots.map((shot) => shot.toJson()).toList(growable: false),
  };
}

class TtsBatchGenerateResponseV1 {
  const TtsBatchGenerateResponseV1({
    required this.tasks,
    required this.total,
    required this.succeeded,
    required this.failed,
  });

  final List<TtsGenerateResponseV1> tasks;
  final int total;
  final int succeeded;
  final int failed;

  factory TtsBatchGenerateResponseV1.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['tasks'] as List<dynamic>? ?? const [];
    return TtsBatchGenerateResponseV1(
      tasks: rawTasks
          .whereType<Map<String, dynamic>>()
          .map(TtsGenerateResponseV1.fromJson)
          .toList(growable: false),
      total: (json['total'] as num? ?? 0).toInt(),
      succeeded: (json['succeeded'] as num? ?? 0).toInt(),
      failed: (json['failed'] as num? ?? 0).toInt(),
    );
  }
}

class TtsTaskV1 {
  const TtsTaskV1({
    required this.taskId,
    required this.projectId,
    this.shotId,
    required this.status,
    this.audioUrl,
    this.error,
    required this.createdAt,
    required this.updatedAt,
  });

  final String taskId;
  final String projectId;
  final String? shotId;
  final String status;
  final String? audioUrl;
  final String? error;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TtsTaskV1.fromJson(Map<String, dynamic> json) {
    return TtsTaskV1(
      taskId: json['task_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      shotId: json['shot_id'] as String?,
      status: json['status'] as String? ?? '',
      audioUrl: json['audio_url'] as String?,
      error: json['error'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TtsCancelResponseV1 {
  const TtsCancelResponseV1({
    required this.taskId,
    required this.cancelled,
  });

  final String taskId;
  final bool cancelled;

  factory TtsCancelResponseV1.fromJson(Map<String, dynamic> json) {
    return TtsCancelResponseV1(
      taskId: json['task_id'] as String? ?? '',
      cancelled: json['cancelled'] == true,
    );
  }
}

class TtsRetryRequestV1 {
  const TtsRetryRequestV1({
    required this.taskId,
    this.provider,
    this.voiceId,
    this.emotion,
    this.speed,
  });

  final String taskId;
  final String? provider;
  final String? voiceId;
  final String? emotion;
  final double? speed;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'task_id': taskId,
    if (provider != null && provider!.trim().isNotEmpty) 'provider': provider,
    if (voiceId != null && voiceId!.trim().isNotEmpty) 'voice_id': voiceId,
    if (emotion != null && emotion!.trim().isNotEmpty) 'emotion': emotion,
    if (speed != null) 'speed': speed,
  };
}

class TtsRetryResponseV1 {
  const TtsRetryResponseV1({
    required this.previousTaskId,
    required this.taskId,
    required this.status,
  });

  final String previousTaskId;
  final String taskId;
  final String status;

  factory TtsRetryResponseV1.fromJson(Map<String, dynamic> json) {
    return TtsRetryResponseV1(
      previousTaskId: json['previous_task_id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      status: json['status'] as String? ?? 'queued',
    );
  }
}

Future<TtsGenerateResponseV1> postTtsGenerateV1(
  String accessToken,
  TtsGenerateRequestV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/generate');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return TtsGenerateResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<TtsBatchGenerateResponseV1> postTtsBatchGenerateV1(
  String accessToken,
  TtsBatchGenerateRequestV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/batch-generate');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return TtsBatchGenerateResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<List<TtsTaskV1>> getTtsTasksV1(
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
    '$kApiBaseUrl/api/v1/tts/tasks',
  ).replace(queryParameters: query.isEmpty ? null : query);
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  final payload = jsonDecode(res.body) as List<dynamic>;
  return payload
      .whereType<Map<String, dynamic>>()
      .map(TtsTaskV1.fromJson)
      .toList(growable: false);
}

Future<TtsTaskV1> getTtsTaskByIdV1(String accessToken, String taskId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/tasks/$taskId');
  final res = await http
      .get(uri, headers: rustApiAuthHeaders(accessToken))
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return TtsTaskV1.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
}

Future<TtsCancelResponseV1> postTtsCancelV1(
  String accessToken,
  String taskId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/cancel');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(<String, dynamic>{'task_id': taskId}),
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return TtsCancelResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}

Future<TtsRetryResponseV1> postTtsRetryV1(
  String accessToken,
  TtsRetryRequestV1 body,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tts/retry');
  final res = await http
      .post(
        uri,
        headers: rustApiJsonAuthHeaders(accessToken),
        body: jsonEncode(body.toJson()),
      )
      .timeout(const Duration(seconds: 20));
  ensureHttpSuccess(res);
  return TtsRetryResponseV1.fromJson(
    jsonDecode(res.body) as Map<String, dynamic>,
  );
}
