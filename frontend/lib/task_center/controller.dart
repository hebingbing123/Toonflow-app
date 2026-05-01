import 'package:flutter/material.dart';

import '../rust_api.dart';

typedef TaskCenterAccessTokenProvider = String? Function();
typedef TaskCenterErrorSink = void Function(String? error);

class TaskCenterController extends ChangeNotifier {
  TaskCenterController({
    required TaskCenterAccessTokenProvider accessTokenProvider,
    required TaskCenterErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final TaskCenterAccessTokenProvider _accessTokenProvider;
  final TaskCenterErrorSink _onErrorChanged;

  bool loadingTaskProjects = false;
  bool loadingTaskCategories = false;
  bool loadingTaskApi = false;
  bool loadingTaskDetailsByNumericId = false;
  bool loadingTaskDetailsUuid = false;
  List<TaskCenterProjectItem>? taskProjects;
  List<JobRow>? taskApiJobs;
  String? taskCategoriesLine;
  String? taskApiSummaryLine;
  String? taskDetailNumericIdLine;
  String? taskDetailUuidLine;
  final TextEditingController taskDetailJobIdController =
      TextEditingController();

  void reset() {
    loadingTaskProjects = false;
    loadingTaskCategories = false;
    loadingTaskApi = false;
    loadingTaskDetailsByNumericId = false;
    loadingTaskDetailsUuid = false;
    taskProjects = null;
    taskApiJobs = null;
    taskCategoriesLine = null;
    taskApiSummaryLine = null;
    taskDetailNumericIdLine = null;
    taskDetailUuidLine = null;
    taskDetailJobIdController.clear();
    notifyListeners();
  }

  void selectTaskJob(JobRow job) {
    taskDetailJobIdController.text = job.id;
    notifyListeners();
  }

  void notifyJobIdChanged() {
    notifyListeners();
  }

  Future<void> loadTaskProjects() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskProjects = true;
    _onErrorChanged(null);
    taskProjects = null;
    notifyListeners();
    try {
      taskProjects = await postTasksGetProject(token);
    } on RustApiException catch (e) {
      _onErrorChanged(formatRustApiException(e));
    } catch (e) {
      _onErrorChanged(e.toString());
    } finally {
      loadingTaskProjects = false;
      notifyListeners();
    }
  }

  Future<void> loadTaskCategories() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskCategories = true;
    _onErrorChanged(null);
    taskCategoriesLine = null;
    notifyListeners();
    try {
      final rows = await postTasksGetTaskCategories(token);
      taskCategoriesLine = rows.isEmpty
          ? '(empty)'
          : rows.map((row) => row.taskClass).join(', ');
    } on RustApiException catch (e) {
      _onErrorChanged(formatRustApiException(e));
    } catch (e) {
      _onErrorChanged(e.toString());
    } finally {
      loadingTaskCategories = false;
      notifyListeners();
    }
  }

  Future<void> loadTaskApi() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskApi = true;
    _onErrorChanged(null);
    taskApiJobs = null;
    taskApiSummaryLine = null;
    notifyListeners();
    try {
      final projects = taskProjects ?? await postTasksGetProject(token);
      final projectId = projects.isEmpty ? null : projects.first.numericId;
      final rows = await postTasksGetTaskApi(
        token,
        page: 1,
        limit: 10,
        projectId: projectId,
      );
      final sample = rows.data
          .take(3)
          .map((job) => '${job.kind}:${job.status}')
          .join(', ');
      taskProjects = projects;
      taskApiJobs = rows.data;
      taskApiSummaryLine =
          'page=1 limit=10'
          '${projectId == null ? '' : ' projectId=$projectId'}'
          ' · total=${rows.total} · page_rows=${rows.data.length}'
          '${sample.isEmpty ? '' : ' · sample: $sample'}';
    } on RustApiException catch (e) {
      _onErrorChanged(formatRustApiException(e));
    } catch (e) {
      _onErrorChanged(e.toString());
    } finally {
      loadingTaskApi = false;
      notifyListeners();
    }
  }

  Future<void> probeTaskDetailByNumericId() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskDetailsByNumericId = true;
    _onErrorChanged(null);
    taskDetailNumericIdLine = null;
    notifyListeners();
    try {
      final jobs =
          taskApiJobs ??
          (await postTasksGetTaskApi(token, page: 1, limit: 10)).data;
      final target = jobs.isEmpty ? null : jobs.first;
      if (target == null) {
        throw StateError('no task rows available yet; run get-task-api first');
      }
      final row = await postTasksTaskDetails(token, target.numericTaskId);
      taskApiJobs = jobs;
      taskDetailNumericIdLine =
          'taskId=${row.numericTaskId} -> ${row.kind} · ${row.status} · uuid=${row.id}';
    } on RustApiException catch (e) {
      _onErrorChanged(formatRustApiException(e));
    } catch (e) {
      _onErrorChanged(e.toString());
    } finally {
      loadingTaskDetailsByNumericId = false;
      notifyListeners();
    }
  }

  Future<void> probeTaskDetailUuid() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    final jobId = taskDetailJobIdController.text.trim();
    if (jobId.isEmpty) return;
    loadingTaskDetailsUuid = true;
    _onErrorChanged(null);
    taskDetailUuidLine = null;
    notifyListeners();
    try {
      final row = await postTasksTaskDetailsByJobId(token, jobId);
      final parts = <String>[row.kind, row.status, 'updated ${row.updatedAt}'];
      if (row.claimedBy != null && row.claimedBy!.isNotEmpty) {
        parts.add('claimed_by=${row.claimedBy}');
      }
      if (row.errorMessage != null && row.errorMessage!.isNotEmpty) {
        parts.add('error=${row.errorMessage}');
      }
      taskDetailUuidLine = parts.join(' · ');
    } on RustApiException catch (e) {
      _onErrorChanged(formatRustApiException(e));
    } catch (e) {
      _onErrorChanged(e.toString());
    } finally {
      loadingTaskDetailsUuid = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    taskDetailJobIdController.dispose();
    super.dispose();
  }
}
