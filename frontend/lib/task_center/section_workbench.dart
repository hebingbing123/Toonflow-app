part of 'section.dart';

/// 任务中心正式工作台，收拢筛选、列表与详情读取流程。
class _TaskCenterWorkbenchDialog extends StatefulWidget {
  const _TaskCenterWorkbenchDialog({
    required this.accessToken,
    required this.initialProjectNumericId,
    required this.initialProjectUuid,
    required this.initialProjects,
    required this.initialTaskSummary,
    required this.initialCategoriesSummary,
    required this.initialNumericIdTaskDetail,
    required this.initialUuidDetails,
    required this.initialJobs,
    this.onNavigateExportJobDeepLink,
    this.onNavigateDomainDeepLink,
  });

  final String accessToken;
  final int? initialProjectNumericId;
  final String? initialProjectUuid;
  final List<TaskCenterProjectItem> initialProjects;
  final String? initialTaskSummary;
  final String? initialCategoriesSummary;
  final String? initialNumericIdTaskDetail;
  final String? initialUuidDetails;
  final List<JobRow> initialJobs;
  final void Function(TaskCenterExportJobDeepLink link)?
      onNavigateExportJobDeepLink;
  final void Function(TaskCenterDomainDeepLink link)? onNavigateDomainDeepLink;

  @override
  State<_TaskCenterWorkbenchDialog> createState() =>
      _TaskCenterWorkbenchDialogState();
}

class _TaskCenterWorkbenchDialogState
    extends State<_TaskCenterWorkbenchDialog> {
  late final _TaskCenterWorkbenchControllers _ctrls;
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;

  List<TaskCenterProjectItem> _projects = const <TaskCenterProjectItem>[];
  List<TaskCenterTaskClassRow> _categories = const <TaskCenterTaskClassRow>[];
  List<JobRow> _jobs = const <JobRow>[];
  String? _taskSummary;
  String? _categoriesSummary;
  String? _numericIdTaskDetailText;
  String? _uuidDetails;
  String? _statusLine;
  bool _loadingProjects = false;
  bool _loadingCategories = false;
  bool _loadingTasks = false;
  bool _loadingNumericIdTaskDetail = false;
  bool _loadingUuidDetails = false;
  bool _liveUpdatesConnected = false;
  String? _retryingJobId;
  String? _cancellingJobId;

  @override
  void initState() {
    super.initState();
    _ctrls = _TaskCenterWorkbenchControllers.create(
      initialProjectNumericId: widget.initialProjectNumericId,
      initialProjectUuid: widget.initialProjectUuid,
      initialProjects: widget.initialProjects,
      initialJobs: widget.initialJobs,
    );
    _projects = widget.initialProjects;
    _jobs = widget.initialJobs;
    _taskSummary = widget.initialTaskSummary;
    _categoriesSummary = widget.initialCategoriesSummary;
    _numericIdTaskDetailText = widget.initialNumericIdTaskDetail;
    _uuidDetails = widget.initialUuidDetails;
    unawaited(_openLiveUpdates());
  }

  @override
  void dispose() {
    unawaited(_closeLiveUpdates());
    _ctrls.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _loadingProjects = true;
      _statusLine = null;
    });
    try {
      final rows = await postTasksGetProject(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _projects = rows;
        final selection = resolveTaskCenterProjectSelection(
          projects: rows,
          projectIdText: _ctrls.projectIdCtrl.text,
          projectUuid: _ctrls.projectUuidCtrl.text,
        );
        if (selection.projectUuid != null) {
          _ctrls.projectUuidCtrl.text = selection.projectUuid!;
        }
        if (_ctrls.projectIdCtrl.text.trim().isEmpty &&
            selection.projectId != null) {
          _ctrls.projectIdCtrl.text = selection.projectId.toString();
        } else if (_ctrls.projectIdCtrl.text.trim().isEmpty && rows.isNotEmpty) {
          _ctrls.projectIdCtrl.text = rows.first.numericId.toString();
          _ctrls.projectUuidCtrl.text =
              rows.first.projectUuid ?? _ctrls.projectUuidCtrl.text;
        }
        _statusLine = l10n.taskCenterStatusLoadedTaskProjects(rows.length);
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingProjects = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _loadingCategories = true;
      _statusLine = null;
    });
    try {
      final rows = await postTasksGetTaskCategories(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _categories = rows;
        _categoriesSummary = summarizeTaskCategories(l10n, rows);
        _statusLine = l10n.taskCenterStatusLoadedTaskCategories(rows.length);
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingCategories = false;
      });
    }
  }

  Future<void> _loadTasks() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final limit = int.tryParse(_ctrls.limitCtrl.text.trim()) ?? 10;
    final state = _ctrls.stateCtrl.text.trim();
    final taskClass = _ctrls.taskClassCtrl.text.trim();
    setState(() {
      _loadingTasks = true;
      _statusLine = null;
    });
    try {
      await _openLiveUpdates();
      final projectSelection = resolveTaskCenterProjectSelection(
        projects: _projects,
        projectIdText: _ctrls.projectIdCtrl.text,
        projectUuid: _ctrls.projectUuidCtrl.text,
      );
      final projectId = projectSelection.projectId;
      final fetched = await fetchJobs(
        widget.accessToken,
        status: state.isEmpty ? null : state,
        limit: (limit < 1 ? 10 : limit).clamp(1, 100),
      );
      if (!mounted) return;
      var jobs = filterTaskCenterJobsForProject(
        jobs: fetched,
        projectNumericId: projectId,
        projectUuid: projectSelection.projectUuid,
      );
      if (taskClass.isNotEmpty) {
        final needle = taskClass.toLowerCase();
        jobs = jobs
            .where((job) => job.kind.toLowerCase().contains(needle))
            .toList(growable: false);
      }
      final grouped = groupJobsByPhase(jobs);
      setState(() {
        _jobs = jobs;
        if (projectSelection.projectUuid != null) {
          _ctrls.projectUuidCtrl.text = projectSelection.projectUuid!;
        }
        if (_ctrls.projectIdCtrl.text.trim().isEmpty && projectId != null) {
          _ctrls.projectIdCtrl.text = projectId.toString();
        }
        _taskSummary =
            'fetchJobs limit=${(limit < 1 ? 10 : limit).clamp(1, 100)}'
            '${projectId == null ? '' : ' projectId=$projectId'}'
            '${projectSelection.resolvedFromUuid && projectSelection.projectUuid != null ? ' projectUuid=${projectSelection.projectUuid}' : ''}'
            '${state.isEmpty ? '' : ' status=$state'}'
            '${taskClass.isEmpty ? '' : ' kind~$taskClass'}'
            ' · rows=${jobs.length}'
            ' · ${summarizeGroupedTaskJobs(l10n, grouped)}';
        if (jobs.isNotEmpty) {
          _ctrls.numericTaskIdCtrl.text = jobs.first.numericTaskId.toString();
          _ctrls.uuidCtrl.text = jobs.first.id;
        }
        _statusLine = l10n.taskCenterStatusRefreshedTasks(jobs.length);
        _loadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingTasks = false;
      });
    }
  }

  Future<void> _loadNumericIdTaskDetail() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final taskId = int.tryParse(_ctrls.numericTaskIdCtrl.text.trim());
    if (taskId == null) {
      setState(() => _statusLine = l10n.taskCenterErrInvalidNumericTaskId);
      return;
    }
    setState(() {
      _loadingNumericIdTaskDetail = true;
      _statusLine = null;
    });
    try {
      final row = await postTasksTaskDetails(widget.accessToken, taskId);
      if (!mounted) return;
      setState(() {
        _numericIdTaskDetailText = formatTaskJobDetails(l10n, row);
        _ctrls.uuidCtrl.text = row.id;
        _loadingNumericIdTaskDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingNumericIdTaskDetail = false;
      });
    }
  }

  Future<void> _loadUuidDetails() async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final taskId = _ctrls.uuidCtrl.text.trim();
    if (taskId.isEmpty) {
      setState(() => _statusLine = l10n.taskCenterErrFillTaskUuid);
      return;
    }
    setState(() {
      _loadingUuidDetails = true;
      _statusLine = null;
    });
    try {
      final row = await postTasksTaskDetailsByJobId(widget.accessToken, taskId);
      if (!mounted) return;
      setState(() {
        _uuidDetails = formatTaskJobDetails(l10n, row);
        _ctrls.numericTaskIdCtrl.text = row.numericTaskId.toString();
        _loadingUuidDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _loadingUuidDetails = false;
      });
    }
  }

  Future<void> _retryFailedJob(JobRow job) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (job.status != 'failed') {
      return;
    }
    setState(() {
      _retryingJobId = job.id;
      _statusLine = null;
    });
    try {
      final updated = await retryJob(widget.accessToken, job.id);
      if (!mounted) return;
      setState(() {
        _mergeJobUpdate(updated, origin: l10n.taskCenterOriginRetrySubmitted);
        _retryingJobId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _retryingJobId = null;
      });
    }
  }

  Future<void> _cancelQueuedJob(JobRow job) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    if (job.status != 'queued' && job.status != 'running') {
      return;
    }
    setState(() {
      _cancellingJobId = job.id;
      _statusLine = null;
    });
    try {
      final updated = await cancelJob(widget.accessToken, job.id);
      if (!mounted) return;
      setState(() {
        _mergeJobUpdate(updated, origin: l10n.taskCenterOriginTaskCancelled);
        _cancellingJobId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = describeUserVisibleApiError(l10n, e);
        _cancellingJobId = null;
      });
    }
  }

  Future<void> _runWritebackCompensation(JobRow job) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    setState(() {
      _ctrls.uuidCtrl.text = job.id;
      _ctrls.numericTaskIdCtrl.text = job.numericTaskId.toString();
      _statusLine = l10n.taskCenterStatusEnteredWritebackCompensation;
    });
    await _loadUuidDetails();
  }

  Future<void> _openLiveUpdates() async {
    if (_ws != null) {
      return;
    }
    try {
      final channel = WebSocketChannel.connect(
        rustWebSocketUri(kApiBaseUrl, accessToken: widget.accessToken),
      );
      _ws = channel;
      _wsSub = channel.stream.listen(
        (message) => _handleWsMessage(message.toString()),
        onError: (_) {
          if (!mounted) return;
          setState(() {
            _liveUpdatesConnected = false;
            _ws = null;
            _wsSub = null;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _liveUpdatesConnected = false;
            _ws = null;
            _wsSub = null;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _liveUpdatesConnected = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveUpdatesConnected = false;
      });
    }
  }

  Future<void> _closeLiveUpdates() async {
    await _wsSub?.cancel();
    await _ws?.sink.close();
    _wsSub = null;
    _ws = null;
  }

  void _handleWsMessage(String raw) {
    final l10n = resolveAppLocalizationsForErrors(context);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'generation.job.updated') {
        return;
      }
      final payload = decoded['payload'];
      if (payload is! Map<String, dynamic> || !mounted) {
        return;
      }
      final row = JobRow.fromJson(payload);
      setState(() {
        _mergeJobUpdate(row, origin: l10n.taskCenterOriginRealtimeUpdate);
      });
    } catch (_) {
      // Ignore unrelated frames.
    }
  }

  void _mergeJobUpdate(JobRow row, {required String origin}) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final nextJobs = List<JobRow>.from(_jobs);
    final index = nextJobs.indexWhere((item) => item.id == row.id);
    final matchesFilters = _matchesCurrentFilters(row);
    if (index >= 0 && matchesFilters) {
      nextJobs[index] = row;
    } else if (index >= 0 && !matchesFilters) {
      nextJobs.removeAt(index);
    } else if (matchesFilters) {
      nextJobs.insert(0, row);
    }
    _jobs = nextJobs;

    if (_ctrls.numericTaskIdCtrl.text.trim() == row.numericTaskId.toString()) {
      _numericIdTaskDetailText = formatTaskJobDetails(l10n, row);
    }
    if (_ctrls.uuidCtrl.text.trim() == row.id) {
      _uuidDetails = formatTaskJobDetails(l10n, row);
    }
    _statusLine = l10n.taskCenterStatusMergedUpdate(
      origin,
      row.numericTaskId,
      row.kind,
      row.status,
    );
  }

  bool _matchesCurrentFilters(JobRow row) {
    final taskClass = _ctrls.taskClassCtrl.text.trim();
    final state = _ctrls.stateCtrl.text.trim();
    final projectId = int.tryParse(_ctrls.projectIdCtrl.text.trim());
    final projectUuid = _trimmedNonEmpty(_ctrls.projectUuidCtrl.text);
    final rowProjectScope = taskCenterProjectScopeFromMap(row.payload);
    final matchesTaskClass = taskClass.isEmpty || row.kind == taskClass;
    final matchesState = state.isEmpty || row.status == state;
    final matchesProject =
        (projectId == null ||
            rowProjectScope.projectNumericId == null ||
            rowProjectScope.projectNumericId == projectId) &&
        (projectUuid == null ||
            rowProjectScope.projectUuid == null ||
            rowProjectScope.projectUuid == projectUuid);
    return matchesTaskClass && matchesState && matchesProject;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final projectSummary = summarizeTaskProjects(l10n, _projects);
    final phaseFilter = _ctrls.productionPhaseCtrl.text.trim();
    final filteredJobs = phaseFilter.isEmpty
        ? _jobs
        : _jobs
            .where((job) => taskCenterShortVideoStageKey(job) == phaseFilter)
            .toList(growable: false);
    final jobSummary = _jobs.isEmpty
        ? (_taskSummary ?? l10n.taskCenterJobsEmpty)
        : summarizeTaskJobs(l10n, _jobs);
    return TaskCenterWorkbenchDialogView(
      model: TaskCenterWorkbenchDialogViewModel(
        projectSummary: projectSummary,
        jobSummary: jobSummary,
        pageCtrl: _ctrls.pageCtrl,
        limitCtrl: _ctrls.limitCtrl,
        stateCtrl: _ctrls.stateCtrl,
        taskClassCtrl: _ctrls.taskClassCtrl,
        projectIdCtrl: _ctrls.projectIdCtrl,
        projectUuidCtrl: _ctrls.projectUuidCtrl,
        numericTaskIdCtrl: _ctrls.numericTaskIdCtrl,
        uuidCtrl: _ctrls.uuidCtrl,
        productionPhaseCtrl: _ctrls.productionPhaseCtrl,
        categories: _categories,
        jobs: filteredJobs,
        categoriesSummary: _categoriesSummary,
        numericIdTaskDetailText: _numericIdTaskDetailText,
        uuidDetails: _uuidDetails,
        statusLine: _statusLine,
        loadingProjects: _loadingProjects,
        loadingCategories: _loadingCategories,
        loadingTasks: _loadingTasks,
        loadingNumericIdTaskDetail: _loadingNumericIdTaskDetail,
        loadingUuidDetails: _loadingUuidDetails,
        retryingJobId: _retryingJobId,
        cancellingJobId: _cancellingJobId,
        liveUpdatesConnected: _liveUpdatesConnected,
      ),
      callbacks: TaskCenterWorkbenchDialogViewCallbacks(
        onLoadProjects: () {
          _loadProjects();
        },
        onLoadCategories: () {
          _loadCategories();
        },
        onLoadTasks: () {
          _loadTasks();
        },
        onLoadNumericIdTaskDetail: () {
          _loadNumericIdTaskDetail();
        },
        onLoadUuidDetails: () {
          _loadUuidDetails();
        },
        onPickCategory: (value) =>
            setState(() => _ctrls.taskClassCtrl.text = value),
        onPickJob: (job) {
          setState(() {
            _ctrls.numericTaskIdCtrl.text = job.numericTaskId.toString();
            _ctrls.uuidCtrl.text = job.id;
          });
          final link = tryParseTaskCenterDomainDeepLink(job);
          final handler = widget.onNavigateDomainDeepLink;
          if (link != null &&
              handler != null &&
              (link.storyboardNumericId != null || link.scriptNumericId != null)) {
            Navigator.of(context).pop();
            handler(link);
          }
        },
        onPickProductionPhase: (key) {
          setState(() => _ctrls.productionPhaseCtrl.text = key);
        },
        onRetryFailedJob: (job) {
          _retryFailedJob(job);
        },
        onCancelQueuedJob: (job) {
          _cancelQueuedJob(job);
        },
        onCompensateWritebackJob: (job) {
          _runWritebackCompensation(job);
        },
        onClose: () => Navigator.of(context).pop(),
        onNavigateExportJobDeepLink:
            widget.onNavigateExportJobDeepLink == null
            ? null
            : (link) {
                Navigator.of(context).pop();
                widget.onNavigateExportJobDeepLink!(link);
              },
        onNavigateDomainDeepLink: widget.onNavigateDomainDeepLink == null
            ? null
            : (link) {
                Navigator.of(context).pop();
                widget.onNavigateDomainDeepLink!(link);
              },
      ),
    );
  }
}

String? _trimmedNonEmpty(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  return value;
}
