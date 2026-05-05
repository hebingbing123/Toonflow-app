import 'package:flutter/material.dart';

import '../rust_api.dart';
import 'support.dart';
import 'view.dart';

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
  final ValueChanged<int?> onSyncProjectContext;
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
  String _targetMarket = 'domestic';
  List<String> _targetPlatforms = <String>['douyin'];
  String _durationStrategy = 'short';
  String _voiceProfile = '';
  String _subtitleStyle = '';
  String _bgmStrategy = '';
  bool _loadingProjects = false;
  bool _loadingProjectOverview = false;
  bool _creatingProject = false;
  bool _savingProjectConfig = false;
  List<ProjectRow> _projects = const <ProjectRow>[];
  ProjectStats? _projectStats;
  TaskCenterGetTaskApiResult? _recentProjectTasks;
  QualityScopeInsightRow? _qualityScopeInsight;
  List<BadCaseStatItem> _badCaseStats = const <BadCaseStatItem>[];
  int _sceneAssetCount = 0;
  int _clipAssetCount = 0;
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
      _targetMarket = project.targetMarket ?? 'domestic';
      final tp = project.targetPlatforms;
      _targetPlatforms = (tp != null && tp.isNotEmpty)
          ? List<String>.from(tp)
          : <String>['douyin'];
      _durationStrategy = project.durationStrategy ?? 'short';
      _voiceProfile = project.voiceProfile ?? '';
      _subtitleStyle = project.subtitleStyle ?? '';
      _bgmStrategy = project.bgmStrategy ?? '';
    });
  }

  void _onPublishPlatformTapped(String platformId) {
    setState(() {
      final next = List<String>.from(_targetPlatforms);
      if (next.contains(platformId)) {
        if (next.length <= 1) {
          return;
        }
        next.remove(platformId);
      } else {
        next.add(platformId);
      }
      _targetPlatforms = next;
    });
  }

  void _syncSelectedProjectContext() {
    final project = _selectedProject;
    widget.onSyncProjectContext(project?.numericId);
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
          _sceneAssetCount = 0;
          _clipAssetCount = 0;
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
      _sceneAssetCount = 0;
      _clipAssetCount = 0;
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
        fetchProjectAssetsByProjectId(
          token,
          project.id,
          assetType: 'scene',
          page: 1,
          limit: 1,
        ),
        fetchProjectAssetsByProjectId(
          token,
          project.id,
          assetType: 'clip',
          page: 1,
          limit: 1,
        ),
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
        _sceneAssetCount = (results[4] as ListAssetsResponse).total;
        _clipAssetCount = (results[5] as ListAssetsResponse).total;
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
        _sceneAssetCount = 0;
        _clipAssetCount = 0;
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
        _sceneAssetCount = 0;
        _clipAssetCount = 0;
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
          'targetMarket': _targetMarket,
          'targetPlatforms': _targetPlatforms,
          'durationStrategy': _durationStrategy,
          if (_voiceProfile.trim().isNotEmpty)
            'voiceProfile': _voiceProfile.trim(),
          if (_subtitleStyle.trim().isNotEmpty)
            'subtitleStyle': _subtitleStyle.trim(),
          if (_bgmStrategy.trim().isNotEmpty) 'bgmStrategy': _bgmStrategy.trim(),
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = [created, ..._projects].toList(growable: false);
        _selectedProjectId = created.id;
        _projectConfigLine =
            '已新建项目 #${created.numericId}，并写入 ${shortVideoModeLabel(_mode)} · ${shortVideoVideoRatioLabel(_videoRatio)}。';
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
      final body = <String, dynamic>{
        'projectType': 'short_drama',
        'mode': storedMode,
        'videoRatio': _videoRatio,
        'targetMarket': _targetMarket,
        'targetPlatforms': _targetPlatforms,
        'durationStrategy': _durationStrategy,
        'voiceProfile': _voiceProfile.trim().isEmpty
            ? null
            : _voiceProfile.trim(),
        'subtitleStyle':
            _subtitleStyle.trim().isEmpty ? null : _subtitleStyle.trim(),
        'bgmStrategy': _bgmStrategy.trim().isEmpty ? null : _bgmStrategy.trim(),
      };
      final updated = await updateProjectByProjectId(token, project.id, body);
      if (!mounted) {
        return;
      }
      setState(() {
        _projects = _projects
            .map((row) => row.id == updated.id ? updated : row)
            .toList(growable: false);
        _selectedProjectId = updated.id;
        _projectConfigLine =
            '已写回项目 #${updated.numericId}：${shortVideoModeLabel(_mode)} · ${shortVideoVideoRatioLabel(_videoRatio)} · 市场 $_targetMarket · 平台 ${_targetPlatforms.length} 个 · 时长 $_durationStrategy';
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

  VoidCallback _nextStepAction() {
    final plan = buildShortVideoNextStepPlan(
      isAnimated: _isAnimated,
      project: _selectedProject,
      stats: _projectStats,
      recentProjectTasks: _recentProjectTasks,
      qualityScopeInsight: _qualityScopeInsight,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    switch (plan.target) {
      case ShortVideoNextStepTarget.projects:
        return widget.onOpenProjects;
      case ShortVideoNextStepTarget.scriptWorkspace:
        return () {
          _syncSelectedProjectContext();
          widget.onOpenScriptWorkspace();
        };
      case ShortVideoNextStepTarget.productionWorkspace:
        return () {
          _syncSelectedProjectContext();
          widget.onOpenProductionWorkspace();
        };
      case ShortVideoNextStepTarget.tasks:
        return widget.onOpenTasks;
      case ShortVideoNextStepTarget.quality:
        return widget.onOpenQuality;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    final visualLabel = shortVideoVisualStyleLabel(project);
    final directionLabel = shortVideoDirectionLabel(project);
    final modeTitle = _isAnimated ? '动漫短剧' : '真人短剧';
    final modeSummary = _isAnimated
        ? '当前主链路更贴近动漫短剧，所以会优先强调画风、角色一致性、分镜出图和连续性。'
        : '真人短剧也应该成为同一个 Space 里的标准模式，后续重点会转向演员感、场景真实度、镜头参考和口播质感。';
    final modeAdvice = _isAnimated
        ? '建议先准备画风、视觉手册和角色资产，再进入脚本与制作流程。'
        : '建议先准备真人参考图、角色设定、镜头语气和视觉手册，再进入脚本与制作流程。';
    final projectOptions = _projects
        .map(
          (row) => ShortVideoProjectOption(
            id: row.id,
            label:
                '#${row.numericId} ${row.name?.trim().isNotEmpty == true ? row.name!.trim() : "未命名项目"}',
          ),
        )
        .toList(growable: false);
    final projectMetrics = _projectStats == null
        ? const <ShortVideoMetricData>[]
        : <ShortVideoMetricData>[
            ShortVideoMetricData(
              label: '剧本',
              value: _projectStats!.scriptCount.toString(),
            ),
            ShortVideoMetricData(
              label: '分镜',
              value: _projectStats!.storyboardCount.toString(),
            ),
            ShortVideoMetricData(
              label: '角色',
              value: _projectStats!.roleCount.toString(),
            ),
            ShortVideoMetricData(
              label: '小说',
              value: _projectStats!.novelCount.toString(),
            ),
            ShortVideoMetricData(
              label: '视频',
              value: _projectStats!.videoCount.toString(),
            ),
          ];
    final overviewMetrics = <ShortVideoMetricData>[
      ShortVideoMetricData(
        label: '最近任务',
        value: (_recentProjectTasks?.total ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: '进行中',
        value: shortVideoCountTasksByStatus(
          _recentProjectTasks,
          'running',
        ).toString(),
      ),
      ShortVideoMetricData(
        label: '失败',
        value: shortVideoCountTasksByStatus(
          _recentProjectTasks,
          'failed',
        ).toString(),
      ),
      ShortVideoMetricData(
        label: '坏例',
        value: (_qualityScopeInsight?.badCaseCount ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: '通过率',
        value:
            '${(_qualityScopeInsight?.passRatePercent ?? 0).toStringAsFixed(0)}%',
      ),
      ShortVideoMetricData(label: '场景', value: _sceneAssetCount.toString()),
      ShortVideoMetricData(label: 'clip', value: _clipAssetCount.toString()),
    ];
    final badCaseMetrics = _badCaseStats
        .map(
          (item) => ShortVideoMetricData(
            label: shortVideoFormatBadCaseLabel(item),
            value: item.count.toString(),
          ),
        )
        .toList(growable: false);
    final recentTaskLines = (_recentProjectTasks?.data ?? const <JobRow>[])
        .take(3)
        .map(
          (task) =>
              '${shortVideoFormatTaskKind(task)} · ${shortVideoFormatTaskStatus(task)}',
        )
        .toList(growable: false);
    final readinessItems = buildShortVideoReadinessItems(
      isAnimated: _isAnimated,
      project: project,
      stats: _projectStats,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    final nextStepPlan = buildShortVideoNextStepPlan(
      isAnimated: _isAnimated,
      project: project,
      stats: _projectStats,
      recentProjectTasks: _recentProjectTasks,
      qualityScopeInsight: _qualityScopeInsight,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    final stageCards = <ShortVideoStageCardData>[
      ShortVideoStageCardData(
        title: '1. 立项',
        status: '现在可用',
        detail: _isAnimated
            ? '从项目开始收口题材、画风、创作手册和角色资产。'
            : '从项目开始收口题材、真人参考、创作手册和角色设定。',
      ),
      ShortVideoStageCardData(
        title: '2. 生成脚本',
        status: '现在可用',
        detail: _isAnimated
            ? '复用脚本工作区的上下文探测、子 Agent 和正文回写。'
            : '复用脚本工作区生成更贴近口播、表演和场景调度的脚本版本。',
      ),
      ShortVideoStageCardData(
        title: '3. 组织素材',
        status: '适合下一步补齐',
        detail: _isAnimated
            ? '把素材检索、资产出图、镜头候选和旁白草稿收成同一段流程。'
            : '把真人参考图、镜头候选、旁白草稿和素材筛选收成同一段流程。',
      ),
      ShortVideoStageCardData(
        title: '4. 出片与复核',
        status: '基础已在',
        detail: _isAnimated
            ? '挂接制作工作区、任务中心和质量评审，形成可追踪的成片闭环。'
            : '挂接制作工作区、任务中心和质量评审，重点补演员一致性与真实感复核。',
      ),
    ];
    return ShortVideoSpaceView(
      mode: _mode,
      modeTitle: modeTitle,
      modeSummary: modeSummary,
      modeAdvice: modeAdvice,
      onModeChanged: (mode) {
        setState(() {
          _mode = mode;
        });
      },
      loadingProjects: _loadingProjects,
      projectOptions: projectOptions,
      selectedProjectId: _selectedProjectId,
      onProjectChanged: (value) {
        setState(() {
          _selectedProjectId = value;
        });
        _applyProjectPreset(_selectedProject);
        _syncSelectedProjectContext();
        _loadProjectOverview();
      },
      onRefreshProjects: _loadProjects,
      videoRatio: _videoRatio,
      onVideoRatioChanged: (value) {
        setState(() {
          _videoRatio = value;
        });
      },
      targetMarket: _targetMarket,
      onTargetMarketChanged: (value) {
        setState(() {
          _targetMarket = value;
        });
      },
      targetPlatforms: _targetPlatforms,
      onPublishPlatformTapped: _onPublishPlatformTapped,
      durationStrategy: _durationStrategy,
      onDurationStrategyChanged: (value) {
        setState(() {
          _durationStrategy = value;
        });
      },
      voiceProfile: _voiceProfile,
      onVoiceProfileChanged: (value) {
        setState(() {
          _voiceProfile = value;
        });
      },
      subtitleStyle: _subtitleStyle,
      onSubtitleStyleChanged: (value) {
        setState(() {
          _subtitleStyle = value;
        });
      },
      bgmStrategy: _bgmStrategy,
      onBgmStrategyChanged: (value) {
        setState(() {
          _bgmStrategy = value;
        });
      },
      creatingProject: _creatingProject,
      onCreateProject: _createProjectFromSpace,
      savingProjectConfig: _savingProjectConfig,
      onSaveProjectConfig: _saveProjectConfig,
      onOpenProjects: widget.onOpenProjects,
      projectConfigLine: _projectConfigLine,
      loadingProjectOverview: _loadingProjectOverview,
      projectReadinessSummary: shortVideoProjectReadinessSummary(_projectStats),
      visualLabel: visualLabel,
      directionLabel: directionLabel,
      projectMetrics: projectMetrics,
      spaceOverviewSummary: shortVideoSpaceOverviewSummary(
        loadingProjectOverview: _loadingProjectOverview,
        project: project,
        projectStats: _projectStats,
        recentProjectTasks: _recentProjectTasks,
        qualityScopeInsight: _qualityScopeInsight,
      ),
      overviewMetrics: overviewMetrics,
      qualitySummaryLine: shortVideoQualitySummaryLine(
        isAnimated: _isAnimated,
        insight: _qualityScopeInsight,
      ),
      badCaseMetrics: badCaseMetrics,
      recentTaskLines: recentTaskLines,
      readinessIntro: _isAnimated
          ? '动漫短剧更看重画风、角色和分镜连续性。'
          : '真人短剧更看重角色设定、场景参考、clip 镜头素材和口播手册。',
      readinessCountLabel:
          '${readinessItems.where((item) => item.ready).length}/${readinessItems.length}',
      readinessGapSummary: shortVideoReadinessGapSummary(
        isAnimated: _isAnimated,
        readinessItems: readinessItems,
      ),
      readinessItems: readinessItems,
      nextStepTitle: nextStepPlan.title,
      nextStepDetail: nextStepPlan.detail,
      onNextStep: _nextStepAction(),
      nextStepButtonLabel: nextStepPlan.buttonLabel,
      stageCards: stageCards,
      migrationSummary: _isAnimated
          ? '先做单入口，再补链路。第一波只编排现有项目、脚本、制作、任务、质检能力；第二波再补自动旁白、字幕样式和一键成片。'
          : '真人模式也先走同一入口。第一波先把用户选择显式化，后面再补真人参考素材、口播语气、镜头真实度和成片验收规则。',
      onOpenScriptWorkspace: () {
        _syncSelectedProjectContext();
        widget.onOpenScriptWorkspace();
      },
      onOpenProductionWorkspace: () {
        _syncSelectedProjectContext();
        widget.onOpenProductionWorkspace();
      },
      onOpenTasks: widget.onOpenTasks,
      onOpenQuality: widget.onOpenQuality,
    );
  }
}
