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

/// `POST /api/v1/tasks/get-project` — body `{}`, projects with non-empty names.
Future<List<LegacyTasksProjectItem>> postTasksGetProject(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/get-project');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => LegacyTasksProjectItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/tasks/get-task-categories` — distinct job kinds as `taskClass`.
Future<List<LegacyTasksTaskClassRow>> postTasksGetTaskCategories(
  String accessToken,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/get-task-categories');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  final data = map['data'] as List<dynamic>;
  return data
      .map((e) => LegacyTasksTaskClassRow.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// `POST /api/v1/tasks/get-task-api` — paginated `app_generation_job` with legacy filters.
Future<LegacyTasksGetTaskApiResult> postTasksGetTaskApi(
  String accessToken, {
  required int page,
  required int limit,
  String? state,
  String? taskClass,
  int? projectId,
}) async {
  final body = <String, dynamic>{'page': page, 'limit': limit};
  if (state != null) body['state'] = state;
  if (taskClass != null) body['taskClass'] = taskClass;
  if (projectId != null) body['projectId'] = projectId;
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/get-task-api');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 20));
  if (res.statusCode != 200) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
  final map = jsonDecode(res.body) as Map<String, dynamic>;
  return LegacyTasksGetTaskApiResult.fromJson(map);
}

/// `POST /api/v1/tasks/task-details` with numeric [taskId] — completes without error when the server
/// returns **501** (legacy SQLite `o_tasks.id` does not map to job UUIDs). For a job UUID, call
/// [fetchJob] or POST the same path with `{"taskId":"<uuid>"}` and expect **200**/404/503.
Future<void> postTasksTaskDetails(String accessToken, int taskId) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/task-details');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'taskId': taskId}),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode != 501) {
    throw RustApiException(res.body, statusCode: res.statusCode);
  }
}

/// `POST /api/v1/tasks/task-details` with a UUID [taskId] — same job payload as `GET /api/v1/jobs/{id}`.
Future<JobRow> postTasksTaskDetailsByJobId(
  String accessToken,
  String taskId,
) async {
  final uri = Uri.parse('$kApiBaseUrl/api/v1/tasks/task-details');
  final res = await http
      .post(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'taskId': taskId}),
      )
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
