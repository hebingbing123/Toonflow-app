import 'package:flutter/material.dart';

import 'previews.dart';
import '../../rust_api.dart';
import 'support.dart';

class TaskCenterSection extends StatelessWidget {
  const TaskCenterSection({
    super.key,
    required this.accessToken,
    required this.loadingTaskProjects,
    required this.loadingTaskCategories,
    required this.loadingTaskApi,
    required this.loadingTaskDetailsByNumericId,
    required this.loadingTaskDetailsUuid,
    required this.taskDetailJobIdController,
    required this.taskProjects,
    required this.taskCategoriesLine,
    required this.taskApiSummaryLine,
    required this.taskDetailNumericIdLine,
    required this.taskDetailUuidLine,
    required this.taskApiJobs,
    required this.onTaskDetailJobIdChanged,
    required this.onLoadTaskProjects,
    required this.onLoadTaskCategories,
    required this.onLoadTaskApi,
    required this.onProbeTaskDetailByNumericId,
    required this.onProbeTaskDetailUuid,
    required this.onSelectTaskJob,
  });

  final String? accessToken;
  final bool loadingTaskProjects;
  final bool loadingTaskCategories;
  final bool loadingTaskApi;
  final bool loadingTaskDetailsByNumericId;
  final bool loadingTaskDetailsUuid;
  final TextEditingController taskDetailJobIdController;
  final List<TaskCenterProjectItem>? taskProjects;
  final String? taskCategoriesLine;
  final String? taskApiSummaryLine;
  final String? taskDetailNumericIdLine;
  final String? taskDetailUuidLine;
  final List<JobRow>? taskApiJobs;
  final ValueChanged<String> onTaskDetailJobIdChanged;
  final VoidCallback onLoadTaskProjects;
  final VoidCallback onLoadTaskCategories;
  final VoidCallback onLoadTaskApi;
  final VoidCallback onProbeTaskDetailByNumericId;
  final VoidCallback onProbeTaskDetailUuid;
  final ValueChanged<JobRow> onSelectTaskJob;

  Future<void> _openTaskWorkbench(BuildContext context) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前未登录，无法读取任务中心')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _TaskCenterWorkbenchDialog(
        accessToken: token,
        initialProjects: taskProjects ?? const <TaskCenterProjectItem>[],
        initialTaskSummary: taskApiSummaryLine,
        initialCategoriesSummary: taskCategoriesLine,
        initialNumericIdTaskDetail: taskDetailNumericIdLine,
        initialUuidDetails: taskDetailUuidLine,
        initialJobs: taskApiJobs ?? const <JobRow>[],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    final projectSummary = taskProjects == null
        ? '尚未加载任务项目'
        : summarizeTaskProjects(taskProjects!);
    final taskSummary = taskApiJobs == null
        ? (taskApiSummaryLine ?? '尚未加载任务列表')
        : summarizeTaskJobs(taskApiJobs!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('任务中心', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '用正式工作台完成任务项目、分类、筛选列表和详情查看，主区不再依赖首条/UUID probe 按钮。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        TaskCenterActionsBar(
          loadingTaskApi: loadingTaskApi,
          onOpenWorkbench: () => _openTaskWorkbench(context),
          onLoadTaskApi: onLoadTaskApi,
        ),
        const SizedBox(height: 8),
        TaskCenterSummaryPreview(
          outlineColor: outline,
          projectSummary: projectSummary,
          taskSummary: taskSummary,
          taskCategoriesLine: taskCategoriesLine,
        ),
        const SizedBox(height: 8),
        TaskCenterCompatibilityPanel(
          outlineColor: outline,
          loadingTaskProjects: loadingTaskProjects,
          loadingTaskCategories: loadingTaskCategories,
          loadingTaskApi: loadingTaskApi,
          loadingTaskDetailsByNumericId: loadingTaskDetailsByNumericId,
          loadingTaskDetailsUuid: loadingTaskDetailsUuid,
          taskDetailJobIdController: taskDetailJobIdController,
          onTaskDetailJobIdChanged: onTaskDetailJobIdChanged,
          onLoadTaskProjects: onLoadTaskProjects,
          onLoadTaskCategories: onLoadTaskCategories,
          onLoadTaskApi: onLoadTaskApi,
          onProbeTaskDetailByNumericId: onProbeTaskDetailByNumericId,
          onProbeTaskDetailUuid: onProbeTaskDetailUuid,
        ),
        TaskCenterDetailsPreview(
          taskDetailNumericIdLine: taskDetailNumericIdLine,
          taskDetailUuidLine: taskDetailUuidLine,
        ),
        if (taskApiJobs != null) ...[
          TaskCenterJobsPreview(
            jobs: taskApiJobs!,
            onSelectTaskJob: onSelectTaskJob,
          ),
        ],
      ],
    );
  }
}

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
    final outline = Theme.of(context).colorScheme.outline;
    final projectSummary = summarizeTaskProjects(_projects);
    final jobSummary = _jobs.isEmpty
        ? (_taskSummary ?? '当前没有任务记录')
        : summarizeTaskJobs(_jobs);
    return AlertDialog(
      title: const Text('任务工作台'),
      content: SizedBox(
        width: 760,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '在一个对话框内完成任务项目/分类读取、按项目或分类筛选列表，以及按 numeric task id 或 UUID 查看详情。',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Text('筛选与列表', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    onPressed: _loadingProjects ? null : _loadProjects,
                    child: Text(_loadingProjects ? '…' : '刷新任务项目'),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingCategories ? null : _loadCategories,
                    child: Text(_loadingCategories ? '…' : '刷新任务分类'),
                  ),
                  FilledButton.tonal(
                    onPressed: _loadingTasks ? null : _loadTasks,
                    child: Text(_loadingTasks ? '…' : '按筛选加载任务'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                projectSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (_categoriesSummary != null) ...[
                const SizedBox(height: 4),
                Text(
                  _categoriesSummary!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                jobSummary,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pageCtrl,
                      decoration: const InputDecoration(labelText: '页码'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _limitCtrl,
                      decoration: const InputDecoration(labelText: '每页数量'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _projectIdCtrl,
                      decoration: const InputDecoration(
                        labelText: '项目 numeric ID（可空）',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _taskClassCtrl,
                      decoration: const InputDecoration(labelText: '任务分类（可空）'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _stateCtrl,
                decoration: const InputDecoration(labelText: '任务状态（可空）'),
              ),
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories
                      .take(6)
                      .map(
                        (row) => ActionChip(
                          label: Text(row.taskClass),
                          onPressed: () => setState(
                            () => _taskClassCtrl.text = row.taskClass,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if (_jobs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_jobs.length} 条任务',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ..._jobs
                    .take(8)
                    .map(
                      (job) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${job.kind} · ${job.status}'),
                        subtitle: Text('#${job.numericTaskId} · ${job.id}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          setState(() {
                            _numericTaskIdCtrl.text = job.numericTaskId
                                .toString();
                            _uuidCtrl.text = job.id;
                          });
                        },
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              Text('任务详情', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _numericTaskIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'numeric task id',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _loadingNumericIdTaskDetail
                        ? null
                        : _loadNumericIdTaskDetail,
                    child: Text(_loadingNumericIdTaskDetail ? '…' : '读取任务详情（numeric ID）'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _uuidCtrl,
                      decoration: const InputDecoration(labelText: '任务 UUID'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: _loadingUuidDetails ? null : _loadUuidDetails,
                    child: Text(_loadingUuidDetails ? '…' : '读取 UUID 详情'),
                  ),
                ],
              ),
              if (_numericIdTaskDetailText != null) ...[
                const SizedBox(height: 8),
                SelectableText('任务详情（numeric ID）：$_numericIdTaskDetailText'),
              ],
              if (_uuidDetails != null) ...[
                const SizedBox(height: 8),
                SelectableText('UUID 详情：$_uuidDetails'),
              ],
              if (_statusLine != null) ...[
                const SizedBox(height: 8),
                Text(
                  _statusLine!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: outline),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
