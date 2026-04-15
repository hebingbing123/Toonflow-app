import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config.dart';
import '../core.dart';
import '../project/index.dart' as project_api;
import 'api.dart';

/// Task-center compatibility adapters layered over jobs and projects endpoints.
class TaskCenterProjectItem {
  const TaskCenterProjectItem({required this.numericId, required this.name});

  /// `app_project` numeric id column (compat JSON key **`id`**).
  final int numericId;
  final String name;

  factory TaskCenterProjectItem.fromJson(Map<String, dynamic> json) {
    return TaskCenterProjectItem(
      numericId: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}

class TaskCenterTaskClassRow {
  const TaskCenterTaskClassRow({required this.taskClass});

  /// Same as `app_generation_job.kind`.
  final String taskClass;

  factory TaskCenterTaskClassRow.fromJson(Map<String, dynamic> json) {
    return TaskCenterTaskClassRow(taskClass: json['taskClass'] as String);
  }
}

class TaskCenterGetTaskApiResult {
  const TaskCenterGetTaskApiResult({required this.data, required this.total});

  final List<JobRow> data;
  final int total;

  factory TaskCenterGetTaskApiResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>;
    return TaskCenterGetTaskApiResult(
      data: list
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// Compat **`POST /api/task/getProject`**: **`GET /api/v1/projects`** (paged), non-empty names only; **`id`** = **`numeric_id`**.
Future<List<TaskCenterProjectItem>> postTasksGetProject(
  String accessToken,
) async {
  final rows = await project_api.fetchAllProjectsPaged(accessToken);
  final out = <TaskCenterProjectItem>[];
  for (final r in rows) {
    final n = r.name?.trim() ?? '';
    if (n.isEmpty) {
      continue;
    }
    out.add(TaskCenterProjectItem(numericId: r.numericId, name: n));
  }
  return out;
}

/// Compat **`getTaskCategories`**: **`GET /api/v1/jobs/kinds`** → **`{ taskClass }`** rows.
Future<List<TaskCenterTaskClassRow>> postTasksGetTaskCategories(
  String accessToken,
) async {
  final kinds = await fetchJobKinds(accessToken);
  return kinds.map((k) => TaskCenterTaskClassRow(taskClass: k)).toList();
}

/// Compat **`getTaskApi`**: **`GET /api/v1/jobs/page`** (query: **`page`**, **`limit`**, **`state`**, **`task_class`**, **`project_id`**).
Future<TaskCenterGetTaskApiResult> postTasksGetTaskApi(
  String accessToken, {
  required int page,
  required int limit,
  String? state,
  String? taskClass,
  int? projectId,
}) async {
  final qp = <String, String>{
    'page': '$page',
    'limit': '$limit',
  };
  if (state != null && state.trim().isNotEmpty) {
    qp['state'] = state.trim();
  }
  if (taskClass != null && taskClass.trim().isNotEmpty) {
    qp['task_class'] = taskClass.trim();
  }
  if (projectId != null) {
    qp['project_id'] = '$projectId';
  }
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/jobs/page',
  ).replace(queryParameters: qp);
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 20));
  if (res.statusCode == 400) {
    throw RustApiException(res.body, statusCode: 400);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return TaskCenterGetTaskApiResult.fromJson(map);
}

/// Compat **`taskDetails`** with numeric **`numeric_task_id`**: **`GET /api/v1/jobs/task-detail/{id}`**.
Future<JobRow> postTasksTaskDetails(String accessToken, int taskId) async {
  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/jobs/task-detail/${Uri.encodeComponent('$taskId')}',
  );
  final res = await http
      .get(uri, headers: {'Authorization': 'Bearer $accessToken'})
      .timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) {
    throw RustApiException('not found', statusCode: 404);
  }
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return JobRow.fromJson(map);
}

/// Same payload as **`GET /api/v1/jobs/{id}`** (UUID).
Future<JobRow> postTasksTaskDetailsByJobId(
  String accessToken,
  String taskId,
) async {
  return fetchJob(accessToken, taskId);
}
