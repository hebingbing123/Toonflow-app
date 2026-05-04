import 'package:flutter/material.dart';

import '../rust_api.dart';

enum ShortVideoMode { animated, liveAction }

class ShortVideoSpaceSection extends StatefulWidget {
  const ShortVideoSpaceSection({
    super.key,
    required this.accessToken,
    required this.onOpenProjects,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
  });

  final String? accessToken;
  final VoidCallback onOpenProjects;
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
  bool _savingProjectConfig = false;
  List<ProjectRow> _projects = const <ProjectRow>[];
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
                    onPressed: widget.onOpenScriptWorkspace,
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('脚本工作区'),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenProductionWorkspace,
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
