part of 'index.dart';

class LegacyTasksProjectItem {
  const LegacyTasksProjectItem({required this.id, required this.name});

  /// `app_project.legacy_id`.
  final int id;
  final String name;

  factory LegacyTasksProjectItem.fromJson(Map<String, dynamic> json) {
    return LegacyTasksProjectItem(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
    );
  }
}

class LegacyTasksTaskClassRow {
  const LegacyTasksTaskClassRow({required this.taskClass});

  /// Same as `app_generation_job.kind`.
  final String taskClass;

  factory LegacyTasksTaskClassRow.fromJson(Map<String, dynamic> json) {
    return LegacyTasksTaskClassRow(taskClass: json['taskClass'] as String);
  }
}

class LegacyTasksGetTaskApiResult {
  const LegacyTasksGetTaskApiResult({required this.data, required this.total});

  final List<JobRow> data;
  final int total;

  factory LegacyTasksGetTaskApiResult.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>;
    return LegacyTasksGetTaskApiResult(
      data: list
          .map((e) => JobRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
    );
  }
}

/// Compat **`POST /api/task/getProject`**: **`GET /api/v1/projects`** (paged), non-empty names only; **`id`** = **`legacy_id`**.
Future<List<LegacyTasksProjectItem>> postTasksGetProject(
  String accessToken,
) async {
  final rows = await _fetchAllProjectsPaged(accessToken);
  final out = <LegacyTasksProjectItem>[];
  for (final r in rows) {
    final n = r.name?.trim() ?? '';
    if (n.isEmpty) {
      continue;
    }
    out.add(LegacyTasksProjectItem(id: r.legacyId, name: n));
  }
  return out;
}

/// Compat **`getTaskCategories`**: **`GET /api/v1/jobs/kinds`** → **`{ taskClass }`** rows.
Future<List<LegacyTasksTaskClassRow>> postTasksGetTaskCategories(
  String accessToken,
) async {
  final kinds = await fetchJobKinds(accessToken);
  return kinds.map((k) => LegacyTasksTaskClassRow(taskClass: k)).toList();
}

/// Compat **`getTaskApi`**: **`GET /api/v1/jobs/page`** (query: **`page`**, **`limit`**, **`state`**, **`task_class`**, **`project_id`**).
Future<LegacyTasksGetTaskApiResult> postTasksGetTaskApi(
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
  return LegacyTasksGetTaskApiResult.fromJson(map);
}

/// Compat **`taskDetails`** with numeric **`legacy_task_id`**: **`GET /api/v1/jobs/task-detail/{id}`**.
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
