import 'package:flutter/material.dart';

import '../rust_api.dart';

enum ShortVideoMode { animated, liveAction }

class ShortVideoSpaceSection extends StatefulWidget {
  const ShortVideoSpaceSection({
    super.key,
    required this.accessToken,
    required this.onOpenProjects,
    required this.onSyncProjectContext,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
  });

  final String? accessToken;
  final VoidCallback onOpenProjects;
  final ValueChanged<int> onSyncProjectContext;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;

  @override
  State<ShortVideoSpaceSection> createState() => _ShortVideoSpaceSectionState();
}

class _ShortVideoSpaceSectionState extends State<ShortVideoSpaceSection> {
  ShortVideoMode _mode = ShortVideoMode.animated;
  String _videoRatio = '9:16';
  bool _loadingProjects = false;
  bool _loadingProjectOverview = false;
  bool _creatingProject = false;
  bool _savingProjectConfig = false;
  List<ProjectRow> _projects = const <ProjectRow>[];
  ProjectStats? _projectStats;
  TaskCenterGetTaskApiResult? _recentProjectTasks;
  QualityScopeInsightRow? _qualityScopeInsight;
  List<BadCaseStatItem> _badCaseStats = const <BadCaseStatItem>[];
  String? _selectedProjectId;
  String? _projectConfigLine;

  bool get _isAnimated => _mode == ShortVideoMode.animated;

  ProjectRow? get _selectedProject {
    final projectId = _selectedProjectId;
    if (projectId == null) {
      return null;
    }
    for (final project in _projects) {
      if (project.id == projectId) {
        return project;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
    });
  }

  Future<void> _loadProjects() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _projects = const <ProjectRow>[];
        _selectedProjectId = null;
        _projectConfigLine = '当前未登录，暂时无法把短视频模式写回项目。';
      });
      return;
    }
    setState(() {
      _loadingProjects = true;
      _projectConfigLine = null;
    });
    try {
      final projects = await fetchProjects(token);
      if (!mounted) {
        return;
      }
      final selectedId = _resolveProjectIdAfterReload(projects);
      setState(() {
        _projects = projects;
        _selectedProjectId = selectedId;
      });
      _applyProjectPreset(_selectedProject);
      _syncSelectedProjectContext();
      _loadProjectOverview();
      if (projects.isEmpty) {
        setState(() {
          _projectConfigLine = '还没有项目，可先去项目区创建一个短剧项目。';
        });
      }
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '读取项目失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '读取项目失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjects = false;
        });
      }
    }
  }

  String? _resolveProjectIdAfterReload(List<ProjectRow> projects) {
    if (projects.isEmpty) {
      return null;
    }
    final currentId = _selectedProjectId;
    if (currentId != null &&
        projects.any((project) => project.id == currentId)) {
      return currentId;
    }
    return projects.first.id;
  }

  void _applyProjectPreset(ProjectRow? project) {
    if (project == null) {
      return;
    }
    setState(() {
      _mode = _modeFromProject(project);
      _videoRatio = _normalizeVideoRatio(project.videoRatio);
    });
  }

  void _syncSelectedProjectContext() {
    final project = _selectedProject;
    if (project == null) {
      return;
    }
    widget.onSyncProjectContext(project.numericId);
  }

  ShortVideoMode _modeFromProject(ProjectRow project) {
    final value = (project.mode ?? '').trim().toLowerCase();
    if (value.contains('live') ||
        value.contains('real') ||
        value.contains('真人')) {
      return ShortVideoMode.liveAction;
    }
    return ShortVideoMode.animated;
  }

  String _normalizeVideoRatio(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed == '16:9' || trimmed == '1:1') {
      return trimmed;
    }
    return '9:16';
  }

  Future<void> _loadProjectOverview() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      if (mounted) {
        setState(() {
          _projectStats = null;
          _recentProjectTasks = null;
          _qualityScopeInsight = null;
          _badCaseStats = const <BadCaseStatItem>[];
        });
      }
      return;
    }
    setState(() {
      _loadingProjectOverview = true;
      _projectStats = null;
      _recentProjectTasks = null;
      _qualityScopeInsight = null;
      _badCaseStats = const <BadCaseStatItem>[];
    });
    try {
      final results = await Future.wait<Object>([
        fetchProjectStatsByProjectId(token, project.id),
        postTasksGetTaskApi(
          token,
          page: 1,
          limit: 6,
          projectId: project.numericId,
        ),
        fetchQualityScopeInsights(
          token,
          projectId: project.numericId,
          limit: 1,
        ),
        fetchBadCaseStats(token, projectId: project.numericId, limit: 3),
      ]);
      if (!mounted) {
        return;
      }
      if (_selectedProjectId != project.id) {
        return;
      }
      setState(() {
        _projectStats = results[0] as ProjectStats;
        _recentProjectTasks = results[1] as TaskCenterGetTaskApiResult;
        final scopeRows = results[2] as List<QualityScopeInsightRow>;
        _qualityScopeInsight = scopeRows.isEmpty ? null : scopeRows.first;
        _badCaseStats = results[3] as List<BadCaseStatItem>;
      });
    } on RustApiException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectStats = null;
        _recentProjectTasks = null;
        _qualityScopeInsight = null;
        _badCaseStats = const <BadCaseStatItem>[];
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectStats = null;
        _recentProjectTasks = null;
        _qualityScopeInsight = null;
        _badCaseStats = const <BadCaseStatItem>[];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingProjectOverview = false;
        });
      }
    }
  }

  Future<void> _createProjectFromSpace() async {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _projectConfigLine = '请先登录后再创建短剧项目。';
      });
      return;
    }
    setState(() {
      _creatingProject = true;
      _projectConfigLine = null;
    });
    final defaultName = _isAnimated ? '动漫短剧项目' : '真人短剧项目';
    final storedMode = _isAnimated
        ? 'animated.short_drama'
        : 'live_action.short_drama';
    try {
      final created = await createProject(
        token,
        fields: {
          'name': defaultName,
          'projectType': 'short_drama',
          'mode': storedMode,
          'videoRatio': _videoRatio,
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = [created, ..._projects].toList(growable: false);
        _selectedProjectId = created.id;
        _projectConfigLine =
            '已新建项目 #${created.numericId}，并写入 ${_modeLabel(_mode)} · ${_videoRatioLabel(_videoRatio)}。';
      });
      _syncSelectedProjectContext();
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '新建项目失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '新建项目失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _creatingProject = false;
        });
      }
    }
  }

  Future<void> _saveProjectConfig() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      setState(() {
        _projectConfigLine = '请先登录并选择项目。';
      });
      return;
    }
    setState(() {
      _savingProjectConfig = true;
      _projectConfigLine = null;
    });
    final storedMode = _mode == ShortVideoMode.animated
        ? 'animated.short_drama'
        : 'live_action.short_drama';
    try {
      final updated = await updateProjectByProjectId(token, project.id, {
        'projectType': 'short_drama',
        'mode': storedMode,
        'videoRatio': _videoRatio,
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = _projects
            .map((row) => row.id == updated.id ? updated : row)
            .toList(growable: false);
        _selectedProjectId = updated.id;
        _projectConfigLine =
            '已写回项目 #${updated.numericId}：${_modeLabel(_mode)} · ${_videoRatioLabel(_videoRatio)}';
      });
      _syncSelectedProjectContext();
      _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '保存失败：${e.statusCode ?? '-'}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _projectConfigLine = '保存失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingProjectConfig = false;
        });
      }
    }
  }

  String _modeLabel(ShortVideoMode mode) {
    return mode == ShortVideoMode.animated ? '动漫短剧' : '真人短剧';
  }

  String _videoRatioLabel(String ratio) {
    switch (ratio) {
      case '16:9':
        return '横屏 16:9';
      case '1:1':
        return '方屏 1:1';
      default:
        return '竖屏 9:16';
    }
  }

  String _projectReadinessSummary(ProjectStats? stats) {
    if (stats == null) {
      return '读取项目统计后，会在这里提示你更适合先去脚本还是制作。';
    }
    if (stats.scriptCount <= 0) {
      return '当前项目还没有剧本，建议先去脚本工作区生成第一版。';
    }
    if (stats.storyboardCount <= 0) {
      return '已有剧本但还缺分镜，建议先继续脚本/分镜规划，再进入制作。';
    }
    if (stats.roleCount <= 0) {
      return '已有脚本和分镜，但角色资产还少，建议先补角色与参考素材。';
    }
    return '脚本、分镜和角色资产都已有基础，可以直接进入制作工作区继续出图和出片。';
  }

  String _spaceOverviewSummary() {
    if (_loadingProjectOverview) {
      return '正在汇总当前项目的脚本、任务和质检状态…';
    }
    final project = _selectedProject;
    if (project == null) {
      return '先选一个项目，Space 才能把当前模式、任务和质检线索收成同一张概览。';
    }
    final taskCount = _recentProjectTasks?.total ?? 0;
    final runningCount = _countTasksByStatus('running');
    final failedCount = _countTasksByStatus('failed');
    final quality = _qualityScopeInsight;
    if (_projectStats == null) {
      return '项目已选中，但概览还没读到。可以先刷新项目或直接进入脚本工作区。';
    }
    if (failedCount > 0) {
      return '这个项目最近有 $failedCount 个失败任务，建议先去任务中心定位失败点，再继续出图或出片。';
    }
    if (runningCount > 0) {
      return '当前还有 $runningCount 个任务在处理中，适合先去任务中心盯进度，同时准备下一轮脚本或素材。';
    }
    if (quality != null && quality.badCaseCount > 0) {
      return '这个项目已有 ${quality.badCaseCount} 条坏例记录，建议先看质量评审再决定是改脚本还是重做分镜。';
    }
    if (taskCount <= 0) {
      return _projectReadinessSummary(_projectStats);
    }
    return '当前项目最近已有 $taskCount 条任务记录，基础链路已经跑起来了，可以继续推进脚本、制作或质检复核。';
  }

  int _countTasksByStatus(String status) {
    final rows = _recentProjectTasks?.data ?? const <JobRow>[];
    return rows.where((row) => row.status == status).length;
  }

  String _qualitySummaryLine() {
    final insight = _qualityScopeInsight;
    if (insight == null) {
      return _isAnimated
          ? '质量评审还没有收敛出明显信号，后续会在这里提醒画风一致性、角色连续性和镜头节奏风险。'
          : '质量评审还没有收敛出明显信号，后续会在这里提醒表演自然度、真实感和口播节奏风险。';
    }
    final passRate = insight.passRatePercent.toStringAsFixed(0);
    if (_isAnimated) {
      return '当前项目自动/人工评审通过率约 $passRate%，已记录 ${insight.badCaseCount} 条坏例；继续重点盯角色一致性、画面连续性和镜头节奏。';
    }
    return '当前项目自动/人工评审通过率约 $passRate%，已记录 ${insight.badCaseCount} 条坏例；继续重点盯表演自然度、场景真实感和口播镜头质感。';
  }

  String _formatBadCaseLabel(BadCaseStatItem item) {
    final raw = (item.badCaseCategory ?? '').trim();
    if (raw.isEmpty) {
      return '未分类';
    }
    return raw.replaceAll('_', ' ');
  }

  String _formatTaskKind(JobRow row) {
    final kind = row.kind.trim();
    if (kind.isEmpty) {
      return '未命名任务';
    }
    return kind.replaceAll('.', ' / ');
  }

  String _formatTaskStatus(JobRow row) {
    switch (row.status) {
      case 'queued':
        return '排队中';
      case 'running':
        return '进行中';
      case 'succeeded':
        return '已完成';
      case 'failed':
        return '失败';
      case 'cancelled':
        return '已取消';
      default:
        return row.status;
    }
  }

  String _nextStepTitle() {
    final project = _selectedProject;
    if (project == null) {
      return '先选一个短剧项目';
    }
    if (_countTasksByStatus('failed') > 0) {
      return '先处理失败任务';
    }
    if ((_qualityScopeInsight?.badCaseCount ?? 0) > 0) {
      return '先看坏例和质检反馈';
    }
    final stats = _projectStats;
    if (stats == null || stats.scriptCount <= 0) {
      return '先生成第一版剧本';
    }
    if (stats.storyboardCount <= 0) {
      return '先补分镜和镜头结构';
    }
    if (stats.roleCount <= 0) {
      return _isAnimated ? '先补角色与画风资产' : '先补真人参考与角色设定';
    }
    return '可以直接推进制作与出片';
  }

  String _nextStepDetail() {
    final project = _selectedProject;
    if (project == null) {
      return '选中项目后，Space 才能把模式、任务、质检和工作区上下文收成同一条主链路。';
    }
    if (_countTasksByStatus('failed') > 0) {
      return '最近已有失败任务，先去任务中心确认是脚本、素材、出图还是出片环节卡住。';
    }
    if ((_qualityScopeInsight?.badCaseCount ?? 0) > 0) {
      return _isAnimated
          ? '当前更适合先看角色一致性、画面连续性和镜头节奏的坏例，再决定返工脚本还是分镜。'
          : '当前更适合先看表演自然度、场景真实感和口播镜头质感的坏例，再决定返工脚本还是镜头。';
    }
    final stats = _projectStats;
    if (stats == null || stats.scriptCount <= 0) {
      return _isAnimated
          ? '先在脚本工作区把动漫短剧的情绪节奏、角色关系和章节改编跑起来。'
          : '先在脚本工作区把真人短剧的对白自然度、口播感和场景调度跑起来。';
    }
    if (stats.storyboardCount <= 0) {
      return '剧本已经有了，但还没拆到分镜层；下一步适合继续脚本/分镜规划，再进制作。';
    }
    if (stats.roleCount <= 0) {
      return _isAnimated
          ? '分镜已经起步，但角色资产偏少，先补角色、画风和参考图会更稳。'
          : '分镜已经起步，但真人参考、角色设定和镜头参考还不够，先补这些会更稳。';
    }
    return _isAnimated
        ? '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区出图、出视频和复核。'
        : '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区推进真人镜头、视频生成和复核。';
  }

  VoidCallback _nextStepAction() {
    final stats = _projectStats;
    if (_selectedProject == null) {
      return widget.onOpenProjects;
    }
    if (_countTasksByStatus('failed') > 0) {
      return widget.onOpenTasks;
    }
    if ((_qualityScopeInsight?.badCaseCount ?? 0) > 0) {
      return widget.onOpenQuality;
    }
    if (stats == null || stats.scriptCount <= 0 || stats.storyboardCount <= 0) {
      return () {
        _syncSelectedProjectContext();
        widget.onOpenScriptWorkspace();
      };
    }
    return () {
      _syncSelectedProjectContext();
      widget.onOpenProductionWorkspace();
    };
  }

  String _nextStepButtonLabel() {
    final stats = _projectStats;
    if (_selectedProject == null) {
      return '先去项目区';
    }
    if (_countTasksByStatus('failed') > 0) {
      return '打开任务中心';
    }
    if ((_qualityScopeInsight?.badCaseCount ?? 0) > 0) {
      return '打开质量评审';
    }
    if (stats == null || stats.scriptCount <= 0 || stats.storyboardCount <= 0) {
      return '打开脚本工作区';
    }
    return '打开制作工作区';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final modeTitle = _isAnimated ? '动漫短剧' : '真人短剧';
    final modeSummary = _isAnimated
        ? '当前主链路更贴近动漫短剧，所以会优先强调画风、角色一致性、分镜出图和连续性。'
        : '真人短剧也应该成为同一个 Space 里的标准模式，后续重点会转向演员感、场景真实度、镜头参考和口播质感。';
    final modeAdvice = _isAnimated
        ? '建议先准备画风、视觉手册和角色资产，再进入脚本与制作流程。'
        : '建议先准备真人参考图、角色设定、镜头语气和视觉手册，再进入脚本与制作流程。';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('短视频 Space', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '参考 MoneyPrinterTurbo 的长处，先把“主题到成片”的链路聚成一个入口，再逐步把脚本、素材、旁白、字幕和质检串成标准流程。',
          style: theme.textTheme.bodyMedium?.copyWith(color: outline),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('创作模式', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<ShortVideoMode>(
                segments: const [
                  ButtonSegment(
                    value: ShortVideoMode.animated,
                    icon: Icon(Icons.auto_awesome_outlined),
                    label: Text('动漫短剧'),
                  ),
                  ButtonSegment(
                    value: ShortVideoMode.liveAction,
                    icon: Icon(Icons.person_outline),
                    label: Text('真人短剧'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  setState(() {
                    _mode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              Text(modeTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                modeSummary,
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              Text(modeAdvice, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('短视频目标配置', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                '把创作模式和画幅直接写回项目，后面的脚本与制作流程就能基于同一份项目配置继续工作。',
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: '目标项目',
                        border: OutlineInputBorder(),
                      ),
                      items: _projects
                          .map(
                            (project) => DropdownMenuItem<String>(
                              value: project.id,
                              child: Text(
                                '#${project.numericId} ${project.name?.trim().isNotEmpty == true ? project.name!.trim() : "未命名项目"}',
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _loadingProjects
                          ? null
                          : (value) {
                              setState(() {
                                _selectedProjectId = value;
                              });
                              _applyProjectPreset(_selectedProject);
                              _syncSelectedProjectContext();
                              _loadProjectOverview();
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loadingProjects ? null : _loadProjects,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(_loadingProjects ? '读取中' : '刷新项目'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<ShortVideoMode>(
                segments: const [
                  ButtonSegment(
                    value: ShortVideoMode.animated,
                    icon: Icon(Icons.auto_awesome_outlined),
                    label: Text('动漫短剧'),
                  ),
                  ButtonSegment(
                    value: ShortVideoMode.liveAction,
                    icon: Icon(Icons.person_outline),
                    label: Text('真人短剧'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  setState(() {
                    _mode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '9:16', label: Text('竖屏 9:16')),
                  ButtonSegment(value: '16:9', label: Text('横屏 16:9')),
                  ButtonSegment(value: '1:1', label: Text('方屏 1:1')),
                ],
                selected: {_videoRatio},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  setState(() {
                    _videoRatio = selection.first;
                  });
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _creatingProject
                        ? null
                        : _createProjectFromSpace,
                    icon: const Icon(Icons.add_circle_outline),
                    label: Text(_creatingProject ? '新建中' : '直接新建短剧项目'),
                  ),
                  FilledButton.icon(
                    onPressed: _savingProjectConfig ? null : _saveProjectConfig,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_savingProjectConfig ? '保存中' : '写回项目配置'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenProjects,
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('打开项目区继续细化'),
                  ),
                ],
              ),
              if (_projectConfigLine != null) ...[
                const SizedBox(height: 10),
                Text(_projectConfigLine!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 10),
              Text(
                _loadingProjectOverview
                    ? '正在读取当前项目准备度…'
                    : _projectReadinessSummary(_projectStats),
                style: theme.textTheme.bodySmall?.copyWith(color: outline),
              ),
              if (_projectStats != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetricChip(
                      label: '剧本',
                      value: _projectStats!.scriptCount.toString(),
                    ),
                    _MetricChip(
                      label: '分镜',
                      value: _projectStats!.storyboardCount.toString(),
                    ),
                    _MetricChip(
                      label: '角色',
                      value: _projectStats!.roleCount.toString(),
                    ),
                    _MetricChip(
                      label: '小说',
                      value: _projectStats!.novelCount.toString(),
                    ),
                    _MetricChip(
                      label: '视频',
                      value: _projectStats!.videoCount.toString(),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前项目概览', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                _spaceOverviewSummary(),
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetricChip(
                    label: '最近任务',
                    value: (_recentProjectTasks?.total ?? 0).toString(),
                  ),
                  _MetricChip(
                    label: '进行中',
                    value: _countTasksByStatus('running').toString(),
                  ),
                  _MetricChip(
                    label: '失败',
                    value: _countTasksByStatus('failed').toString(),
                  ),
                  _MetricChip(
                    label: '坏例',
                    value: (_qualityScopeInsight?.badCaseCount ?? 0).toString(),
                  ),
                  _MetricChip(
                    label: '通过率',
                    value:
                        '${(_qualityScopeInsight?.passRatePercent ?? 0).toStringAsFixed(0)}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_qualitySummaryLine(), style: theme.textTheme.bodySmall),
              if (_badCaseStats.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('最近坏例倾向', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _badCaseStats
                      .map(
                        (item) => _MetricChip(
                          label: _formatBadCaseLabel(item),
                          value: item.count.toString(),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
              if ((_recentProjectTasks?.data ?? const <JobRow>[])
                  .isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('最近任务流', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                for (final task in _recentProjectTasks!.data.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.fiber_manual_record,
                          size: 10,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_formatTaskKind(task)} · ${_formatTaskStatus(task)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('建议下一步', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(_nextStepTitle(), style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                _nextStepDetail(),
                style: theme.textTheme.bodyMedium?.copyWith(color: outline),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _nextStepAction(),
                icon: const Icon(Icons.arrow_forward_outlined),
                label: Text(_nextStepButtonLabel()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StageCard(
              title: '1. 立项',
              status: '现在可用',
              detail: _isAnimated
                  ? '从项目开始收口题材、画风、创作手册和角色资产。'
                  : '从项目开始收口题材、真人参考、创作手册和角色设定。',
            ),
            _StageCard(
              title: '2. 生成脚本',
              status: '现在可用',
              detail: _isAnimated
                  ? '复用脚本工作区的上下文探测、子 Agent 和正文回写。'
                  : '复用脚本工作区生成更贴近口播、表演和场景调度的脚本版本。',
            ),
            _StageCard(
              title: '3. 组织素材',
              status: '适合下一步补齐',
              detail: _isAnimated
                  ? '把素材检索、资产出图、镜头候选和旁白草稿收成同一段流程。'
                  : '把真人参考图、镜头候选、旁白草稿和素材筛选收成同一段流程。',
            ),
            _StageCard(
              title: '4. 出片与复核',
              status: '基础已在',
              detail: _isAnimated
                  ? '挂接制作工作区、任务中心和质量评审，形成可追踪的成片闭环。'
                  : '挂接制作工作区、任务中心和质量评审，重点补演员一致性与真实感复核。',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: outline),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('建议迁移顺序', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                _isAnimated
                    ? '先做单入口，再补链路。第一波只编排现有项目、脚本、制作、任务、质检能力；第二波再补自动旁白、字幕样式和一键成片。'
                    : '真人模式也先走同一入口。第一波先把用户选择显式化，后面再补真人参考素材、口播语气、镜头真实度和成片验收规则。',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onOpenProjects,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('项目'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _syncSelectedProjectContext();
                      widget.onOpenScriptWorkspace();
                    },
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('脚本工作区'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _syncSelectedProjectContext();
                      widget.onOpenProductionWorkspace();
                    },
                    icon: const Icon(Icons.movie_creation_outlined),
                    label: const Text('制作工作区'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenTasks,
                    icon: const Icon(Icons.checklist_outlined),
                    label: const Text('任务中心'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenQuality,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('质量评审'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.title,
    required this.status,
    required this.detail,
  });

  final String title;
  final String status;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              status,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(detail, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$label $value', style: theme.textTheme.labelMedium),
    );
  }
}
