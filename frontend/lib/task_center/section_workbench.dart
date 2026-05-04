part of 'section.dart';

/// 任务中心正式工作台，收拢筛选、列表与详情读取流程。
class _TaskCenterWorkbenchDialog extends StatefulWidget {
  const _TaskCenterWorkbenchDialog({
    required this.accessToken,
    required this.initialProjectNumericId,
    required this.initialProjects,
    required this.initialTaskSummary,
    required this.initialCategoriesSummary,
    required this.initialNumericIdTaskDetail,
    required this.initialUuidDetails,
    required this.initialJobs,
  });

  final String accessToken;
  final int? initialProjectNumericId;
  final List<TaskCenterProjectItem> initialProjects;
  final String? initialTaskSummary;
  final String? initialCategoriesSummary;
  final String? initialNumericIdTaskDetail;
  final String? initialUuidDetails;
  final List<JobRow> initialJobs;

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
    setState(() {
      _loadingProjects = true;
      _statusLine = null;
    });
    try {
      final rows = await postTasksGetProject(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _projects = rows;
        if (_ctrls.projectIdCtrl.text.trim().isEmpty && rows.isNotEmpty) {
          _ctrls.projectIdCtrl.text = rows.first.numericId.toString();
        }
        _statusLine = '已读取 ${rows.length} 个任务项目。';
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _loadingProjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingProjects = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = true;
      _statusLine = null;
    });
    try {
      final rows = await postTasksGetTaskCategories(widget.accessToken);
      if (!mounted) return;
      setState(() {
        _categories = rows;
        _categoriesSummary = summarizeTaskCategories(rows);
        _statusLine = '已读取 ${rows.length} 个任务分类。';
        _loadingCategories = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingCategories = false;
      });
    }
  }

  Future<void> _loadTasks() async {
    final page = int.tryParse(_ctrls.pageCtrl.text.trim()) ?? 1;
    final limit = int.tryParse(_ctrls.limitCtrl.text.trim()) ?? 10;
    final projectId = int.tryParse(_ctrls.projectIdCtrl.text.trim());
    final state = _ctrls.stateCtrl.text.trim();
    final taskClass = _ctrls.taskClassCtrl.text.trim();
    setState(() {
      _loadingTasks = true;
      _statusLine = null;
    });
    try {
      await _openLiveUpdates();
      final rows = await postTasksGetTaskApi(
        widget.accessToken,
        page: page < 1 ? 1 : page,
        limit: limit < 1 ? 10 : limit,
        projectId: projectId,
        state: state.isEmpty ? null : state,
        taskClass: taskClass.isEmpty ? null : taskClass,
      );
      if (!mounted) return;
      final jobs = rows.data;
      setState(() {
        _jobs = jobs;
        _taskSummary =
            'page=${page < 1 ? 1 : page} limit=${limit < 1 ? 10 : limit}'
            '${projectId == null ? '' : ' projectId=$projectId'}'
            '${state.isEmpty ? '' : ' state=$state'}'
            '${taskClass.isEmpty ? '' : ' taskClass=$taskClass'}'
            ' · total=${rows.total} · page_rows=${jobs.length}';
        if (jobs.isNotEmpty) {
          _ctrls.numericTaskIdCtrl.text = jobs.first.numericTaskId.toString();
          _ctrls.uuidCtrl.text = jobs.first.id;
        }
        _statusLine = '已刷新 ${jobs.length} 条任务。';
        _loadingTasks = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _loadingTasks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingTasks = false;
      });
    }
  }

  Future<void> _loadNumericIdTaskDetail() async {
    final taskId = int.tryParse(_ctrls.numericTaskIdCtrl.text.trim());
    if (taskId == null) {
      setState(() => _statusLine = '请填写合法的任务 numeric ID。');
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
        _numericIdTaskDetailText = formatTaskJobDetails(row);
        _ctrls.uuidCtrl.text = row.id;
        _loadingNumericIdTaskDetail = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _loadingNumericIdTaskDetail = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingNumericIdTaskDetail = false;
      });
    }
  }

  Future<void> _loadUuidDetails() async {
    final taskId = _ctrls.uuidCtrl.text.trim();
    if (taskId.isEmpty) {
      setState(() => _statusLine = '请填写任务 UUID。');
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
        _uuidDetails = formatTaskJobDetails(row);
        _ctrls.numericTaskIdCtrl.text = row.numericTaskId.toString();
        _loadingUuidDetails = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _loadingUuidDetails = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _loadingUuidDetails = false;
      });
    }
  }

  Future<void> _retryFailedJob(JobRow job) async {
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
        _mergeJobUpdate(updated, origin: '已提交重试');
        _retryingJobId = null;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _retryingJobId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _retryingJobId = null;
      });
    }
  }

  Future<void> _cancelQueuedJob(JobRow job) async {
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
        _mergeJobUpdate(updated, origin: '已取消任务');
        _cancellingJobId = null;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = formatRustApiException(e);
        _cancellingJobId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
        _cancellingJobId = null;
      });
    }
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
        _mergeJobUpdate(row, origin: '收到实时更新');
      });
    } catch (_) {
      // Ignore unrelated frames.
    }
  }

  void _mergeJobUpdate(JobRow row, {required String origin}) {
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
      _numericIdTaskDetailText = formatTaskJobDetails(row);
    }
    if (_ctrls.uuidCtrl.text.trim() == row.id) {
      _uuidDetails = formatTaskJobDetails(row);
    }
    _statusLine = '$origin：#${row.numericTaskId} ${row.kind} -> ${row.status}';
  }

  bool _matchesCurrentFilters(JobRow row) {
    final taskClass = _ctrls.taskClassCtrl.text.trim();
    final state = _ctrls.stateCtrl.text.trim();
    final projectId = int.tryParse(_ctrls.projectIdCtrl.text.trim());
    final rowProjectId = _jobProjectId(row);
    final matchesTaskClass = taskClass.isEmpty || row.kind == taskClass;
    final matchesState = state.isEmpty || row.status == state;
    final matchesProject =
        projectId == null || rowProjectId == null || rowProjectId == projectId;
    return matchesTaskClass && matchesState && matchesProject;
  }

  int? _jobProjectId(JobRow row) {
    final payload = row.payload;
    final candidates = <Object?>[
      payload['project_id'],
      payload['projectId'],
      payload['project_numeric_id'],
      payload['projectNumericId'],
    ];
    for (final value in candidates) {
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final projectSummary = summarizeTaskProjects(_projects);
    final jobSummary = _jobs.isEmpty
        ? (_taskSummary ?? '当前没有任务记录')
        : summarizeTaskJobs(_jobs);
    return TaskCenterWorkbenchDialogView(
      model: TaskCenterWorkbenchDialogViewModel(
        projectSummary: projectSummary,
        jobSummary: jobSummary,
        pageCtrl: _ctrls.pageCtrl,
        limitCtrl: _ctrls.limitCtrl,
        stateCtrl: _ctrls.stateCtrl,
        taskClassCtrl: _ctrls.taskClassCtrl,
        projectIdCtrl: _ctrls.projectIdCtrl,
        numericTaskIdCtrl: _ctrls.numericTaskIdCtrl,
        uuidCtrl: _ctrls.uuidCtrl,
        categories: _categories,
        jobs: _jobs,
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
        },
        onRetryFailedJob: (job) {
          _retryFailedJob(job);
        },
        onCancelQueuedJob: (job) {
          _cancelQueuedJob(job);
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
