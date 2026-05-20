import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../platform/studio_load_state.dart';
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
  bool _disposed = false;
  List<TaskCenterProjectItem>? taskProjects;
  List<JobRow>? taskApiJobs;
  StudioLoadState taskApiLoadState = StudioLoadState.initial;
  Object? taskApiLastError;
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
    _notifyListenersIfMounted();
  }

  void selectTaskJob(JobRow job) {
    taskDetailJobIdController.text = job.id;
    _notifyListenersIfMounted();
  }

  void notifyJobIdChanged() {
    _notifyListenersIfMounted();
  }

  void _notifyListenersIfMounted() {
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  Future<void> loadTaskProjects() async {
    if (_disposed) return;
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskProjects = true;
    if (!_disposed) {
      _onErrorChanged(null);
    }
    taskProjects = null;
    _notifyListenersIfMounted();
    try {
      final projects = await postTasksGetProject(token);
      if (_disposed) return;
      taskProjects = projects;
    } catch (e) {
      if (_disposed) return;
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      if (!_disposed) {
        loadingTaskProjects = false;
        _notifyListenersIfMounted();
      }
    }
  }

  Future<void> loadTaskCategories() async {
    if (_disposed) return;
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskCategories = true;
    if (!_disposed) {
      _onErrorChanged(null);
    }
    taskCategoriesLine = null;
    _notifyListenersIfMounted();
    try {
      final rows = await postTasksGetTaskCategories(token);
      if (_disposed) return;
      taskCategoriesLine = rows.isEmpty
          ? _l10nResolved.jobsEmptyValue
          : rows.map((row) => row.taskClass).join(', ');
    } catch (e) {
      if (_disposed) return;
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      if (!_disposed) {
        loadingTaskCategories = false;
        _notifyListenersIfMounted();
      }
    }
  }

  Future<void> loadTaskApi() async {
    if (_disposed) return;
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskApi = true;
    taskApiLoadState = StudioLoadState.loading;
    if (!_disposed) {
      _onErrorChanged(null);
    }
    taskApiJobs = null;
    taskApiSummaryLine = null;
    taskApiLastError = null;
    _notifyListenersIfMounted();
    try {
      final projects = taskProjects ?? await postTasksGetProject(token);
      if (_disposed) return;
      final projectSelection = resolveTaskCenterProjectSelection(
        projects: projects,
        projectIdText: _projectIdTextProvider(),
        projectUuid: _projectUuidTextProvider(),
      );
      final projectId =
          projectSelection.projectId ??
          (projects.isEmpty ? null : projects.first.numericId);
      final fetched = await fetchJobs(token, limit: 100);
      if (_disposed) return;
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
      taskApiLoadState = StudioLoadState.success;
    } catch (e) {
      if (_disposed) return;
      taskApiLoadState = StudioLoadState.error;
      taskApiLastError = e;
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
        showGlobalSnackBar: false,
      );
    } finally {
      if (!_disposed) {
        loadingTaskApi = false;
        _notifyListenersIfMounted();
      }
    }
  }

  Future<void> probeTaskDetailByNumericId() async {
    if (_disposed) return;
    final token = _accessTokenProvider();
    if (token == null) return;
    loadingTaskDetailsByNumericId = true;
    if (!_disposed) {
      _onErrorChanged(null);
    }
    taskDetailNumericIdLine = null;
    _notifyListenersIfMounted();
    try {
      final jobs =
          taskApiJobs ??
          (await postTasksGetTaskApi(token, page: 1, limit: 10)).data;
      if (_disposed) return;
      final target = jobs.isEmpty ? null : jobs.first;
      if (target == null) {
        throw StateError('no task rows available yet; run get-task-api first');
      }
      final row = await postTasksTaskDetails(token, target.numericTaskId);
      if (_disposed) return;
      taskApiJobs = jobs;
      taskDetailNumericIdLine =
          'taskId=${row.numericTaskId} -> ${row.kind} · ${row.status} · uuid=${row.id}';
    } catch (e) {
      if (_disposed) return;
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      if (!_disposed) {
        loadingTaskDetailsByNumericId = false;
        _notifyListenersIfMounted();
      }
    }
  }

  Future<void> probeTaskDetailUuid() async {
    if (_disposed) return;
    final token = _accessTokenProvider();
    if (token == null) return;
    final jobId = taskDetailJobIdController.text.trim();
    if (jobId.isEmpty) return;
    loadingTaskDetailsUuid = true;
    if (!_disposed) {
      _onErrorChanged(null);
    }
    taskDetailUuidLine = null;
    _notifyListenersIfMounted();
    try {
      final row = await postTasksTaskDetailsByJobId(token, jobId);
      if (_disposed) return;
      final l10n = _l10nResolved;
      final parts = <String>[
        row.kind,
        row.status,
        l10n.taskCenterJobDetailUpdatedAt(row.updatedAt),
      ];
      if (row.claimedBy != null && row.claimedBy!.isNotEmpty) {
        parts.add(l10n.taskCenterJobDetailField('claimed_by', row.claimedBy!));
      }
      if (row.errorMessage != null && row.errorMessage!.isNotEmpty) {
        parts.add(l10n.taskCenterJobDetailField('error', row.errorMessage!));
      }
      taskDetailUuidLine = parts.join(' · ');
    } catch (e) {
      if (_disposed) return;
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _onErrorChanged,
        l10n: _l10nResolved,
      );
    } finally {
      if (!_disposed) {
        loadingTaskDetailsUuid = false;
        _notifyListenersIfMounted();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    taskDetailJobIdController.dispose();
    super.dispose();
  }
}

String _emptyScopeText() => '';
