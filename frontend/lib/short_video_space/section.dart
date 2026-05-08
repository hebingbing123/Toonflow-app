import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rust_api.dart';
import 'components/filter_panel.dart';
import 'components/version_manager.dart';
import 'state/operation_history.dart';
import 'support.dart';
import 'view.dart';

part 'section_project.dart';
part 'section_production.dart';
part 'section_production_assembly.dart';
part 'section_draft_management.dart';
part 'section_publish.dart';
part 'section_publish_scheduling.dart';
part 'section_publish_copy.dart';
part 'section_publish_batch.dart';
part 'section_undo_redo.dart';
part 'dialogs/voiceover_settings_dialog.dart';

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
  bool _batchCandidateBusy = false;
  bool _creatingProject = false;
  bool _savingProjectConfig = false;
  List<ProjectRow> _projects = const <ProjectRow>[];
  ProjectStats? _projectStats;
  TaskCenterGetTaskApiResult? _recentProjectTasks;
  QualityScopeInsightRow? _qualityScopeInsight;
  List<BadCaseStatItem> _badCaseStats = const <BadCaseStatItem>[];
  int _sceneAssetCount = 0;
  int _clipAssetCount = 0;
  ProjectShortVideoReadiness? _shotReadiness;
  bool _shotReadinessUnavailable = false;
  ProjectProductionOverview? _productionOverview;
  ProjectAssetsOverview? _projectAssetsOverview;
  ProjectShortVideoAssembly? _shortVideoAssembly;
  ProjectShortVideoExportCheck? _shortVideoExportCheck;
  List<ProductionStoryboardItemV1> _candidateCompareRows =
      const <ProductionStoryboardItemV1>[];
  List<QualityReview> _candidateCompareReviews = const <QualityReview>[];
  PublishPlatformMatrixResponse? _publishMatrix;
  bool _publishUnavailable = false;
  List<PublishDraftRow> _publishDrafts = const <PublishDraftRow>[];
  PublishPrepareCheckResponse? _publishPrepare;
  List<PublishJobRow> _publishJobs = const <PublishJobRow>[];
  List<PublishPerformanceAlertRow> _publishPerfAlerts =
      const <PublishPerformanceAlertRow>[];
  List<PublishAttemptAuditRow> _publishAuditRows =
      const <PublishAttemptAuditRow>[];
  String? _selectedPublishDraftId;
  Map<String, String> _publishAutomationModesByPlatform =
      <String, String>{};
  List<String> _publishBatchResultLines = const <String>[];
  bool _publishBusy = false;
  int _publishCopyEditorRevision = 0;
  String? _selectedProjectId;
  String? _projectConfigLine;
  bool? _operationFeedbackIsSuccess;

  // P8: Multi-select state
  bool _multiSelectMode = false;
  Set<String> _selectedDraftIds = <String>{};
  PublishBatchValidationResponse? _batchValidation;
  
  // P11: Delivery mode state
  String? _deliveryModeFilter;

  // P13.2: Operation history for undo/redo
  final OperationHistory _operationHistory = OperationHistory();

  // Task 12.2: Draft management state
  List<AssemblyDraft> _assemblyDrafts = const <AssemblyDraft>[];

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

  PublishDraftRow? get _activePublishDraft {
    if (_publishDrafts.isEmpty) {
      return null;
    }
    if (_publishDrafts.length == 1) {
      return _publishDrafts.first;
    }
    final selected = _selectedPublishDraftId;
    if (selected != null) {
      for (final d in _publishDrafts) {
        if (d.id == selected) {
          return d;
        }
      }
    }
    return null;
  }

  void _syncSelectedPublishDraftWith(List<PublishDraftRow> drafts) {
    if (drafts.isEmpty) {
      _selectedPublishDraftId = null;
      return;
    }
    if (drafts.length == 1) {
      _selectedPublishDraftId = drafts.first.id;
      return;
    }
    final current = _selectedPublishDraftId;
    if (current != null && drafts.any((d) => d.id == current)) {
      return;
    }
    _selectedPublishDraftId = null;
  }

  /// 与 [_activePublishDraft] 一致，但基于本次 API 返回的列表（投递前 state 可能未刷新）。
  String? _resolvePublishDraftIdFromList(List<PublishDraftRow> drafts) {
    if (drafts.isEmpty) {
      return null;
    }
    if (drafts.length == 1) {
      return drafts.first.id;
    }
    final sel = _selectedPublishDraftId;
    if (sel == null || sel.trim().isEmpty) {
      return null;
    }
    for (final d in drafts) {
      if (d.id == sel) {
        return d.id;
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

  // Project management methods moved to section_project.dart
  // Production methods moved to section_production.dart and section_production_assembly.dart
  // Publish methods moved to section_publish.dart, section_publish_scheduling.dart, section_publish_copy.dart, section_publish_batch.dart

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
    final po = _productionOverview;
    final overviewMetrics = <ShortVideoMetricData>[
      ShortVideoMetricData(
        label: '最近任务',
        value: (_recentProjectTasks?.total ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: po != null ? '生成任务' : '进行中',
        value: po != null
            ? po.runningGenerationJobCount.toString()
            : shortVideoCountTasksByStatus(
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
        value: po != null
            ? po.pendingReviewBadCaseCount.toString()
            : (_qualityScopeInsight?.badCaseCount ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: '通过率',
        value:
            '${(_qualityScopeInsight?.passRatePercent ?? 0).toStringAsFixed(0)}%',
      ),
      ShortVideoMetricData(label: '场景', value: _sceneAssetCount.toString()),
      ShortVideoMetricData(label: 'clip', value: _clipAssetCount.toString()),
    ];
    if (po != null && po.totalStoryboardCount > 0) {
      overviewMetrics.add(
        ShortVideoMetricData(
          label: '分镜就绪',
          value:
              '${po.readyStoryboardCount}/${po.totalStoryboardCount}',
        ),
      );
    }
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
    final shotReadinessUi = project == null
        ? const ShotReadinessUi(
            headline: '选择短剧项目后，会显示服务端分镜阻塞汇总。',
          )
        : buildShotReadinessUi(
            loadingProjectOverview: _loadingProjectOverview,
            readiness: _shotReadiness,
            readinessUnavailable: _shotReadinessUnavailable,
          );
    final assetsOverviewPanelUi = buildShortVideoAssetsOverviewPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      overview: _projectAssetsOverview,
    );
    final assemblyPanelUi = buildShortVideoAssemblyPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assembly: _shortVideoAssembly,
    );
    final exportCheckPanelUi = buildShortVideoExportCheckPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      exportCheck: _shortVideoExportCheck,
    );
    final accessToken = widget.accessToken;
    final publishPanelUi = buildShortVideoPublishPanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      publishUnavailable: _publishUnavailable,
      exportCheck: _shortVideoExportCheck,
      matrix: _publishMatrix,
      drafts: _publishDrafts,
      prepare: _publishPrepare,
      jobs: _publishJobs,
      performanceAlerts: _publishPerfAlerts,
      audits: _publishAuditRows,
      selectedPublishDraftId: _selectedPublishDraftId,
      onSelectPublishDraft: (draftId) {
        setState(() {
          _selectedPublishDraftId = draftId;
          _publishCopyEditorRevision++;
        });
        if (project != null && accessToken != null && accessToken.isNotEmpty) {
          unawaited(_refreshPublishSlice(project, accessToken));
        }
      },
      publishBusy: _publishBusy,
      onRefreshPublish: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_refreshPublishSlice(project, accessToken))
          : null,
      onBootstrapPublishDraft: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_bootstrapPublishDraft())
          : null,
      onEnqueuePublishJob: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_enqueuePublishJob())
          : null,
      onConfirmSemiAuto: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () => unawaited(_confirmSemiAutoPublish())
          : null,
      onSuggestPublishCopy: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable
          ? () => unawaited(_suggestPublishCopy())
          : null,
      onClearPublishSchedule: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_clearPublishSchedule())
          : null,
      publishTargetPlatformIds: _targetPlatforms,
      onEnqueueAllDrafts:
          project != null ? () => unawaited(_enqueueAllDraftJobs()) : null,
      onRetryFailedPublishJobs:
          project != null ? () => unawaited(_retryFailedPublishJobs()) : null,
      publishBatchResultLines: _publishBatchResultLines,
      publishAutomationModesByPlatform: _publishAutomationModesByPlatform,
      onChangePublishAutomationMode: (platformId, automationMode) {
        setState(() {
          _publishAutomationModesByPlatform = <String, String>{
            ..._publishAutomationModesByPlatform,
            platformId: automationMode,
          };
        });
      },
      publishCopyEditorRevision: _publishCopyEditorRevision,
      onCommitPublishPlatformCopy: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (platformId, title, description, tagsComma) =>
                _commitPublishPlatformCopy(
                  project,
                  accessToken,
                  platformId,
                  title,
                  description,
                  tagsComma,
                )
          : null,
      onScheduleFirstDraft: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx) => unawaited(
                _scheduleFirstDraft(ctx, project, accessToken),
              )
          : null,
      onScheduleAllDraftsSameTime: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.length > 1
          ? (ctx) => unawaited(
                _scheduleAllDraftsSameTime(ctx, project, accessToken),
              )
          : null,
      onPublishCalendarDayBulkSchedule: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx, day) => unawaited(
                _bulkScheduleDraftsForCalendarDay(
                  ctx,
                  project,
                  accessToken,
                  day,
                ),
              )
          : null,
      onOpenPublishTroubleshooting: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty
          ? () {
              _syncSelectedProjectContext();
              widget.onOpenTasks();
            }
          : null,
      // P8: Multi-select
      multiSelectMode: _multiSelectMode,
      selectedDraftIds: _selectedDraftIds,
      onToggleMultiSelectMode: _toggleMultiSelectMode,
      onToggleDraftSelection: _toggleDraftSelection,
      onSelectAllDrafts: _selectAllDrafts,
      onClearDraftSelection: _clearDraftSelection,
      onBatchScheduleDrafts: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx) => unawaited(_batchScheduleDrafts(ctx))
          : null,
      onBatchPublishDrafts: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_batchPublishDrafts())
          : null,
      onBatchArchiveDrafts: project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_batchArchiveDrafts())
          : null,
      onCompareDrafts: _publishDrafts.isNotEmpty ? _compareDrafts : null,
      batchValidation: _batchValidation,
      // P11: Delivery mode
      deliveryModeFilter: _deliveryModeFilter,
      onDeliveryModeFilterChanged: _onDeliveryModeFilterChanged,
    );
    final candidateCardUi = buildShortVideoCandidateCardUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assetsOverview: _projectAssetsOverview,
      onBatchGenerateCandidateClips:
          project != null && (_projectStats?.storyboardCount ?? 0) > 0
              ? _runBatchCandidateClips
              : null,
      batchGenerateCandidateClipsBusy: _batchCandidateBusy,
    );
    final candidateComparePanelUi = buildShortVideoCandidateComparePanelUi(
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      storyboardRows: _candidateCompareRows,
      readiness: _shotReadiness,
      reviews: _candidateCompareReviews,
      isLiveAction: !_isAnimated,
      onSetCurrent: _setComparedStoryboardCurrent,
      onOpenProductionWorkspace: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
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
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleUndoRedoKeyEvent(event);
        return KeyEventResult.ignored;
      },
      child: ShortVideoSpaceView(
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
      operationFeedbackIsSuccess: _operationFeedbackIsSuccess,
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
      assetsOverviewPanelUi: assetsOverviewPanelUi,
      assemblyPanelUi: assemblyPanelUi,
      exportCheckPanelUi: exportCheckPanelUi,
      publishPanelUi: publishPanelUi,
      onOpenProductionForAssemblyExport: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
      onOpenAssemblyClipDeskOps: project == null ||
              _shortVideoAssembly == null ||
              (_shortVideoAssembly?.scripts.isEmpty ?? true)
          ? null
          : () => unawaited(_openAssemblyClipDeskOps()),
      onOpenAssemblyDefaultsEditor: project == null || _shortVideoAssembly == null
          ? null
          : () => unawaited(_openAssemblyDefaultsEditor()),
      candidateCardUi: candidateCardUi,
      candidateComparePanelUi: candidateComparePanelUi,
      onOpenProjectsForCandidateAssets:
          project == null ? null : widget.onOpenProjects,
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
      shotReadinessUi: shotReadinessUi,
      onOpenProductionForShotReadiness: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
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
      ),
    );
  }
}
