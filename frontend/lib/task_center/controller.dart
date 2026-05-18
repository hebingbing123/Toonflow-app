import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../rust_api.dart';
import 'support.dart';

typedef TaskCenterAccessTokenProvider = String? Function();
typedef TaskCenterErrorSink = void Function(String? error);
typedef TaskCenterScopeTextProvider = String Function();
typedef TaskCenterL10nProvider = AppLocalizations? Function();

class TaskCenterController extends ChangeNotifier {
  TaskCenterController({
    required TaskCenterAccessTokenProvider accessTokenProvider,
    required TaskCenterErrorSink onErrorChanged,
    required TaskCenterL10nProvider l10nProvider,
    TaskCenterScopeTextProvider? projectIdTextProvider,
    TaskCenterScopeTextProvider? projectUuidTextProvider,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider,
       _projectIdTextProvider = projectIdTextProvider ?? _emptyScopeText,
       _projectUuidTextProvider = projectUuidTextProvider ?? _emptyScopeText;

  final TaskCenterAccessTokenProvider _accessTokenProvider;
  final TaskCenterErrorSink _onErrorChanged;
  final TaskCenterL10nProvider _l10nProvider;
  final TaskCenterScopeTextProvider _projectIdTextProvider;
  final TaskCenterScopeTextProvider _projectUuidTextProvider;

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

  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  Future<void> loadTaskProjects() async {
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskProjects = true;
    _onErrorChanged(null);
    taskProjects = null;
    notifyListeners();
    try {
      taskProjects = await postTasksGetProject(token);
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
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
          ? _l10nResolved.jobsEmptyValue
          : rows.map((row) => row.taskClass).join(', ');
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
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
      final projectSelection = resolveTaskCenterProjectSelection(
        projects: projects,
        projectIdText: _projectIdTextProvider(),
        projectUuid: _projectUuidTextProvider(),
      );
      final projectId =
          projectSelection.projectId ??
          (projects.isEmpty ? null : projects.first.numericId);
      final fetched = await fetchJobs(token, limit: 100);
      final scoped = filterTaskCenterJobsForProject(
        jobs: fetched,
        projectNumericId: projectId,
        projectUuid: projectSelection.projectUuid,
      );
      final grouped = groupJobsByPhase(scoped);
      taskProjects = projects;
      taskApiJobs = scoped;
      taskApiSummaryLine =
          'fetchJobs limit=100'
          '${projectId == null ? '' : ' projectId=$projectId'}'
          '${projectSelection.resolvedFromUuid && projectSelection.projectUuid != null ? ' projectUuid=${projectSelection.projectUuid}' : ''}'
          ' · rows=${scoped.length}'
          ' · ${summarizeGroupedTaskJobs(_l10nResolved, grouped)}';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
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
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
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
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
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

String _emptyScopeText() => '';
