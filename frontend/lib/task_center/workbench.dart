part of 'section.dart';

/// 任务中心正式工作台，收拢筛选、列表与详情读取流程。
class _TaskCenterWorkbenchDialog extends StatefulWidget {
  const _TaskCenterWorkbenchDialog({
    required this.accessToken,
    required this.initialProjects,
    required this.initialTaskSummary,
    required this.initialCategoriesSummary,
    required this.initialNumericIdTaskDetail,
    required this.initialUuidDetails,
    required this.initialJobs,
  });

  final String accessToken;
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
  late final TextEditingController _pageCtrl;
  late final TextEditingController _limitCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _taskClassCtrl;
  late final TextEditingController _projectIdCtrl;
  late final TextEditingController _numericTaskIdCtrl;
  late final TextEditingController _uuidCtrl;

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

  @override
  void initState() {
    super.initState();
    _pageCtrl = TextEditingController(text: '1');
    _limitCtrl = TextEditingController(text: '10');
    _stateCtrl = TextEditingController();
    _taskClassCtrl = TextEditingController();
    _projectIdCtrl = TextEditingController(
      text: widget.initialProjects.isEmpty
          ? ''
          : widget.initialProjects.first.numericId.toString(),
    );
    _numericTaskIdCtrl = TextEditingController(
      text: widget.initialJobs.isEmpty
          ? ''
          : widget.initialJobs.first.numericTaskId.toString(),
    );
    _uuidCtrl = TextEditingController(
      text: widget.initialJobs.isEmpty ? '' : widget.initialJobs.first.id,
    );
    _projects = widget.initialProjects;
    _jobs = widget.initialJobs;
    _taskSummary = widget.initialTaskSummary;
    _categoriesSummary = widget.initialCategoriesSummary;
    _numericIdTaskDetailText = widget.initialNumericIdTaskDetail;
    _uuidDetails = widget.initialUuidDetails;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _limitCtrl.dispose();
    _stateCtrl.dispose();
    _taskClassCtrl.dispose();
    _projectIdCtrl.dispose();
    _numericTaskIdCtrl.dispose();
    _uuidCtrl.dispose();
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
        if (_projectIdCtrl.text.trim().isEmpty && rows.isNotEmpty) {
          _projectIdCtrl.text = rows.first.numericId.toString();
        }
        _statusLine = '已读取 ${rows.length} 个任务项目。';
        _loadingProjects = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
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
        _statusLine = e.toString();
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
    final page = int.tryParse(_pageCtrl.text.trim()) ?? 1;
    final limit = int.tryParse(_limitCtrl.text.trim()) ?? 10;
    final projectId = int.tryParse(_projectIdCtrl.text.trim());
    final state = _stateCtrl.text.trim();
    final taskClass = _taskClassCtrl.text.trim();
    setState(() {
      _loadingTasks = true;
      _statusLine = null;
    });
    try {
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
          _numericTaskIdCtrl.text = jobs.first.numericTaskId.toString();
          _uuidCtrl.text = jobs.first.id;
        }
        _statusLine = '已刷新 ${jobs.length} 条任务。';
        _loadingTasks = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
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
    final taskId = int.tryParse(_numericTaskIdCtrl.text.trim());
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
        _uuidCtrl.text = row.id;
        _loadingNumericIdTaskDetail = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
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
    final taskId = _uuidCtrl.text.trim();
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
        _numericTaskIdCtrl.text = row.numericTaskId.toString();
        _loadingUuidDetails = false;
      });
    } on RustApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _statusLine = e.toString();
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
        pageCtrl: _pageCtrl,
        limitCtrl: _limitCtrl,
        stateCtrl: _stateCtrl,
        taskClassCtrl: _taskClassCtrl,
        projectIdCtrl: _projectIdCtrl,
        numericTaskIdCtrl: _numericTaskIdCtrl,
        uuidCtrl: _uuidCtrl,
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
        onPickCategory: (value) => setState(() => _taskClassCtrl.text = value),
        onPickJob: (job) {
          setState(() {
            _numericTaskIdCtrl.text = job.numericTaskId.toString();
            _uuidCtrl.text = job.id;
          });
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}
