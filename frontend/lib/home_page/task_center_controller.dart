// ignore_for_file: invalid_use_of_protected_member

part of '../home_page.dart';

extension _HomePageTaskCenterController on _HomePageState {
  Future<void> _loadTaskProjects() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingTaskProjects = true;
      _error = null;
      _taskProjects = null;
    });
    try {
      final rows = await postTasksGetProject(token);
      if (!mounted) return;
      setState(() {
        _taskProjects = rows;
        _loadingTaskProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskProjects = false;
      });
    }
  }

  Future<void> _loadTaskCategories() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingTaskCategories = true;
      _error = null;
      _taskCategoriesLine = null;
    });
    try {
      final rows = await postTasksGetTaskCategories(token);
      if (!mounted) return;
      setState(() {
        _taskCategoriesLine = rows.isEmpty
            ? '(empty)'
            : rows.map((r) => r.taskClass).join(', ');
        _loadingTaskCategories = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskCategories = false;
      });
    }
  }

  Future<void> _loadTaskApi() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingTaskApi = true;
      _error = null;
      _taskApiJobs = null;
      _taskApiSummaryLine = null;
    });
    try {
      final projects = _taskProjects ?? await postTasksGetProject(token);
      final projectId = projects.isEmpty ? null : projects.first.id;
      final rows = await postTasksGetTaskApi(
        token,
        page: 1,
        limit: 10,
        projectId: projectId,
      );
      if (!mounted) return;
      final sample = rows.data
          .take(3)
          .map((j) => '${j.kind}:${j.status}')
          .join(', ');
      setState(() {
        _taskProjects = projects;
        _taskApiJobs = rows.data;
        _taskApiSummaryLine =
            'page=1 limit=10'
            '${projectId == null ? '' : ' projectId=$projectId'}'
            ' · total=${rows.total} · page_rows=${rows.data.length}'
            '${sample.isEmpty ? '' : ' · sample: $sample'}';
        _loadingTaskApi = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskApi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskApi = false;
      });
    }
  }

  Future<void> _probeTaskDetailLegacy() async {
    final token = _session?.accessToken;
    if (token == null) return;
    setState(() {
      _loadingTaskDetailsLegacy = true;
      _error = null;
      _taskDetailLegacyLine = null;
    });
    try {
      final jobs = _taskApiJobs ?? (await postTasksGetTaskApi(token, page: 1, limit: 10)).data;
      final target = jobs.isEmpty ? null : jobs.first;
      if (target == null) {
        throw StateError('no task rows available yet; run get-task-api first');
      }
      final row = await postTasksTaskDetails(token, target.legacyTaskId);
      if (!mounted) return;
      setState(() {
        _taskApiJobs = jobs;
        _taskDetailLegacyLine =
            'taskId=${row.legacyTaskId} -> ${row.kind} · ${row.status} · uuid=${row.id}';
        _loadingTaskDetailsLegacy = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskDetailsLegacy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskDetailsLegacy = false;
      });
    }
  }

  Future<void> _probeTaskDetailUuid() async {
    final token = _session?.accessToken;
    if (token == null) return;
    final jobId = _taskDetailJobIdCtrl.text.trim();
    if (jobId.isEmpty) return;
    setState(() {
      _loadingTaskDetailsUuid = true;
      _error = null;
      _taskDetailUuidLine = null;
    });
    try {
      final row = await postTasksTaskDetailsByJobId(token, jobId);
      if (!mounted) return;
      final parts = <String>[row.kind, row.status, 'updated ${row.updatedAt}'];
      if (row.claimedBy != null && row.claimedBy!.isNotEmpty) {
        parts.add('claimed_by=${row.claimedBy}');
      }
      if (row.errorMessage != null && row.errorMessage!.isNotEmpty) {
        parts.add('error=${row.errorMessage}');
      }
      setState(() {
        _taskDetailUuidLine = parts.join(' · ');
        _loadingTaskDetailsUuid = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskDetailsUuid = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingTaskDetailsUuid = false;
      });
    }
  }
}
