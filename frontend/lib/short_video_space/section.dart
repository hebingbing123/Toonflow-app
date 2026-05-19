import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../l10n/short_video_generation_blocked.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../native_bridge/native_bridge_bootstrap.dart';
import '../project_studio/studio_snapshot_bus.dart';
import '../rust_api.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_dropdown_field.dart';
import '../task_center/support.dart';
import 'desktop_capability.dart';
import 'components/batch_operation_toolbar.dart';
import 'components/filter_panel.dart';
import 'components/version_manager.dart';
import 'panel_versioning.dart';
import 'dialogs/confirmation_dialogs.dart';
import 'dialogs/publish_draft_compare_dialog.dart';
import 'state/operation_history.dart';
import 'support.dart';
import 'view.dart';

part 'section_project.dart';
part 'section_production.dart';
part 'section_production_assembly.dart';
part 'section_production_batch_operations.dart';
part 'section_draft_management.dart';
part 'section_publish.dart';
part 'section_publish_scheduling.dart';
part 'section_publish_copy.dart';
part 'section_publish_batch.dart';
part 'section_undo_redo.dart';
part 'section_keyboard_shortcuts.dart';
part 'section_characters.dart';
part 'section_timeline.dart';
part 'section_timeline_m2m3.dart';
part 'section_timeline_m4.dart';
part 'dialogs/voiceover_settings_dialog.dart';
part 'dialogs/export_settings_dialog.dart';
part 'dialogs/export_progress_dialog.dart';
part 'dialogs/export_history_dialog.dart';
part 'components/audio_preview_player.dart';

/// Scroll/focus target when opening short-video space from studio deliver.
enum ShortVideoSpaceInitialFocus { none, assembly }

String? _classifyExportFailurePhase(
  String? stage,
  String? code,
) {
  final normalizedStage = (stage ?? '').trim().toLowerCase();
  if (normalizedStage.isNotEmpty) {
    return normalizedStage;
  }
  switch ((code ?? '').trim().toLowerCase()) {
    case 'payload_missing_source_url':
    case 'payload_source_url_empty':
    case 'video_download_http':
    case 'video_download_stream':
    case 'video_content_length_exceeds_limit':
    case 'video_body_exceeds_limit':
      return 'loading_assets';
    case 'payload_format_invalid':
    case 'video_format_mismatch_no_transcode':
    case 'export_provider_failed':
      return 'encoding';
    case 'local_export_dir_unset':
    case 'export_directory_create_failed':
    case 'export_file_persist_failed':
      return 'finalizing';
    default:
      return null;
  }
}

ShortVideoLatestExportAction recommendExportFailureAction(
  String? failurePhaseKey,
  String? failureCode,
) {
  final code = (failureCode ?? '').trim().toLowerCase();
  final phase = (failurePhaseKey ?? '').trim().toLowerCase();
  if (code == 'payload_format_invalid' ||
      code == 'payload_missing_source_url' ||
      code == 'payload_source_url_empty' ||
      code == 'video_download_http' ||
      code == 'video_download_stream' ||
      code == 'video_content_length_exceeds_limit' ||
      code == 'video_body_exceeds_limit' ||
      phase == 'loading_assets') {
    return ShortVideoLatestExportAction.openProductionWorkspace;
  }
  return ShortVideoLatestExportAction.retry;
}

class ShortVideoSpaceSection extends StatefulWidget {
  const ShortVideoSpaceSection({
    super.key,
    required this.accessToken,
    this.initialProjectUuid,
    this.initialFocus = ShortVideoSpaceInitialFocus.none,
    this.snapshotBus,
    required this.onOpenProjects,
    required this.onSyncProjectContext,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
  });

  final String? accessToken;
  final String? initialProjectUuid;
  final ShortVideoSpaceInitialFocus initialFocus;
  final StudioSnapshotBus? snapshotBus;
  final VoidCallback onOpenProjects;
  final ValueChanged<ShortVideoProjectScope?> onSyncProjectContext;
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
  bool _confirmCandidatesBusy = false;
  bool _creatingProject = false;
  bool _savingProjectConfig = false;
  bool _exportActionBusy = false;
  bool _preAssemblyActionBusy = false;
  JobRow? _activeAssemblyJob;
  ExportTaskV1? _activeExportTask;
  ExportHistoryItem? _latestSuccessfulExport;
  Timer? _assemblyJobPollTimer;
  final PanelVersionManager _panelVersionManager = PanelVersionManager();
  final GlobalKey _assemblyInputPanelKey = GlobalKey();
  StudioSnapshotBus get _snapshotBus => widget.snapshotBus ?? kStudioSnapshotBus;
  var _scopedRunningJobCount = 0;
  var _didScrollToInitialFocus = false;
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
  ProjectShortVideoTimelineV1? _shortVideoTimeline;
  bool _loadingTimeline = false;
  bool _timelineSaveBusy = false;
  bool _timelinePreviewBusy = false;
  String? _timelinePreviewUrl;
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
  Map<String, String> _publishAutomationModesByPlatform = <String, String>{};
  List<String> _publishBatchResultLines = const <String>[];
  bool _publishBusy = false;
  int _publishCopyEditorRevision = 0;

  /// Monotonic id so stale in-flight [_refreshPublishSlice] results are ignored.
  int _publishRefreshRequestId = 0;
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
  List<AssemblyVersion> _assemblyVersions = const <AssemblyVersion>[];
  String _currentAssemblyVersionId = 'default';
  VoiceoverSettings? _ttsRetrySettings;
  String _ttsTaskCenterStatusFilter = '';
  bool _ttsTaskCenterGroupedByShot = true;
  String _ttsTaskCenterKeyword = '';
  List<ProjectCharacterV1> _projectCharacters = const <ProjectCharacterV1>[];
  bool _loadingCharacters = false;
  String? _charactersStatusLine;
  final AudioPlayer _characterPreviewPlayer = AudioPlayer();
  final NativeBridgeBootstrap _nativeBridgeBootstrap =
      NativeBridgeBootstrap.instance;

  bool get _isAnimated => _mode == ShortVideoMode.animated;

  @override
  void initState() {
    super.initState();
    _snapshotBus.addListener(_onSnapshotBusChanged);
    _nativeBridgeBootstrap.addListener(_onNativeBridgeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProjects();
      _maybeScrollToInitialFocus();
    });
  }

  @override
  void dispose() {
    _snapshotBus.removeListener(_onSnapshotBusChanged);
    _nativeBridgeBootstrap.removeListener(_onNativeBridgeChanged);
    _assemblyJobPollTimer?.cancel();
    unawaited(_characterPreviewPlayer.dispose());
    super.dispose();
  }

  void _onNativeBridgeChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _onSnapshotBusChanged() {
    final pending = _snapshotBus.pendingKeys;
    if (pending.isEmpty) {
      return;
    }
    unawaited(_applySnapshotInvalidation(pending));
  }

  Future<void> _applySnapshotInvalidation(Set<StudioSnapshotKey> keys) async {
    final reloadOverview = keys.any(
      (k) =>
          k == StudioSnapshotKey.readiness ||
          k == StudioSnapshotKey.assembly ||
          k == StudioSnapshotKey.exportCheck ||
          k == StudioSnapshotKey.assets ||
          k == StudioSnapshotKey.jobs,
    );
    if (reloadOverview) {
      await _loadProjectOverview();
    }
    if (keys.contains(StudioSnapshotKey.assemblyVersions) && !reloadOverview) {
      await _loadDraftsAndVersions();
    }
    if (keys.contains(StudioSnapshotKey.timeline)) {
      await _loadShortVideoTimeline();
    }
    _snapshotBus.clearPending(keys);
  }

  void _invalidateProductionSnapshots({
    bool includeJobs = false,
    Iterable<StudioSnapshotKey> extra = const <StudioSnapshotKey>[],
  }) {
    _snapshotBus.invalidate(<StudioSnapshotKey>[
      ...StudioSnapshotInvalidation.workbenchMedia,
      if (includeJobs) StudioSnapshotKey.jobs,
      ...extra,
    ]);
  }

  Future<void> _refreshProductionOverview() async {
    _invalidateProductionSnapshots();
  }

  void _maybeScrollToInitialFocus() {
    if (_didScrollToInitialFocus) {
      return;
    }
    if (widget.initialFocus != ShortVideoSpaceInitialFocus.assembly) {
      return;
    }
    final ctx = _assemblyInputPanelKey.currentContext;
    if (ctx == null) {
      return;
    }
    _didScrollToInitialFocus = true;
    unawaited(
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _refreshScopedJobCounts() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      if (mounted) {
        setState(() => _scopedRunningJobCount = 0);
      }
      return;
    }
    try {
      final active = await Future.wait([
        fetchJobs(token, status: 'running', limit: 50),
        fetchJobs(token, status: 'queued', limit: 50),
      ]);
      final running = [...active[0], ...active[1]];
      final count = running
          .where((j) => j.payload['project_uuid']?.toString() == project.id)
          .length;
      if (mounted) {
        setState(() => _scopedRunningJobCount = count);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _scopedRunningJobCount = 0);
      }
    }
  }

  int _beginPublishRefreshRequest() => ++_publishRefreshRequestId;

  bool _isLatestPublishRefreshRequest(int requestId) =>
      requestId == _publishRefreshRequestId;

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

  void _syncSelectedDraftIdsWith(List<PublishDraftRow> drafts) {
    _selectedDraftIds = shortVideoFilterExistingDraftIds(
      _selectedDraftIds,
      drafts,
    );
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
  void didUpdateWidget(covariant ShortVideoSpaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFocus == ShortVideoSpaceInitialFocus.assembly &&
        oldWidget.initialFocus != ShortVideoSpaceInitialFocus.assembly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeScrollToInitialFocus();
      });
    }
    final oldUuid = oldWidget.initialProjectUuid?.trim();
    final nextUuid = widget.initialProjectUuid?.trim();
    if (oldUuid == nextUuid || _projects.isEmpty) {
      return;
    }
    final nextSelectedId = resolveShortVideoSelectedProjectId(
      _projects,
      currentProjectId: _selectedProjectId,
      preferredProjectUuid: nextUuid,
      preferScopedProjectUuid: true,
    );
    if (nextSelectedId == null || nextSelectedId == _selectedProjectId) {
      return;
    }
    setState(() {
      _selectedProjectId = nextSelectedId;
    });
    _applyProjectPreset(_selectedProject);
    _syncSelectedProjectContext();
    _loadProjectOverview();
  }

  // Project management methods moved to section_project.dart
  // Production methods moved to section_production.dart and section_production_assembly.dart
  // Publish methods moved to section_publish.dart, section_publish_scheduling.dart, section_publish_copy.dart, section_publish_batch.dart

  @override
  Widget build(BuildContext context) {
    final project = _selectedProject;
    final l10n = resolveAppLocalizationsForErrors(context);
    final visualLabel = shortVideoVisualStyleLabel(project, l10n);
    final directionLabel = shortVideoDirectionLabel(project, l10n);
    final modeTitle = _isAnimated
        ? l10n.shortVideoSpaceModeTitleAnimated
        : l10n.shortVideoSpaceModeTitleLive;
    final modeSummary = _isAnimated
        ? l10n.shortVideoSpaceModeSummaryAnimated
        : l10n.shortVideoSpaceModeSummaryLive;
    final modeAdvice = _isAnimated
        ? l10n.shortVideoSpaceModeAdviceAnimated
        : l10n.shortVideoSpaceModeAdviceLive;
    final projectOptions = _projects
        .map(
          (row) => ShortVideoProjectOption(
            id: row.id,
            label:
                '#${row.numericId} ${row.name?.trim().isNotEmpty == true ? row.name!.trim() : l10n.shortVideoProjectOptionUnnamed}',
          ),
        )
        .toList(growable: false);
    final projectMetrics = _projectStats == null
        ? const <ShortVideoMetricData>[]
        : <ShortVideoMetricData>[
            ShortVideoMetricData(
              label: l10n.shortVideoMetricScript,
              value: _projectStats!.scriptCount.toString(),
            ),
            ShortVideoMetricData(
              label: l10n.shortVideoMetricStoryboard,
              value: _projectStats!.storyboardCount.toString(),
            ),
            ShortVideoMetricData(
              label: l10n.shortVideoMetricRole,
              value: _projectStats!.roleCount.toString(),
            ),
            ShortVideoMetricData(
              label: l10n.shortVideoMetricNovel,
              value: _projectStats!.novelCount.toString(),
            ),
            ShortVideoMetricData(
              label: l10n.shortVideoMetricVideo,
              value: _projectStats!.videoCount.toString(),
            ),
          ];
    final po = _productionOverview;
    final overviewMetrics = <ShortVideoMetricData>[
      ShortVideoMetricData(
        label: l10n.shortVideoMetricRecentTasks,
        value: (_recentProjectTasks?.total ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: po != null
            ? l10n.shortVideoMetricGenerationJobs
            : l10n.shortVideoMetricInProgress,
        value: po != null
            ? po.runningGenerationJobCount.toString()
            : shortVideoCountTasksByStatus(
                _recentProjectTasks,
                'running',
              ).toString(),
      ),
      ShortVideoMetricData(
        label: l10n.shortVideoMetricFailed,
        value: shortVideoCountTasksByStatus(
          _recentProjectTasks,
          'failed',
        ).toString(),
      ),
      ShortVideoMetricData(
        label: l10n.shortVideoMetricBadCases,
        value: po != null
            ? po.pendingReviewBadCaseCount.toString()
            : (_qualityScopeInsight?.badCaseCount ?? 0).toString(),
      ),
      ShortVideoMetricData(
        label: l10n.shortVideoMetricPassRate,
        value:
            '${(_qualityScopeInsight?.passRatePercent ?? 0).toStringAsFixed(0)}%',
      ),
      ShortVideoMetricData(
        label: l10n.shortVideoMetricScenes,
        value: _sceneAssetCount.toString(),
      ),
      ShortVideoMetricData(
        label: l10n.shortVideoMetricClips,
        value: _clipAssetCount.toString(),
      ),
    ];
    if (po != null && po.totalStoryboardCount > 0) {
      overviewMetrics.add(
        ShortVideoMetricData(
          label: l10n.shortVideoMetricStoryboardReadiness,
          value: '${po.readyStoryboardCount}/${po.totalStoryboardCount}',
        ),
      );
    }
    final readinessRollup = _shotReadiness?.rollup;
    if (po != null && readinessRollup != null && readinessRollup.totalStoryboards > 0) {
      overviewMetrics.add(
        ShortVideoMetricData(
          label: l10n.shortVideoMetricProductionPhase,
          value: l10n.shortVideoProductionPhaseSnippet(
            po.readyStoryboardCount,
            po.runningGenerationJobCount,
            readinessRollup.blockedCount,
          ),
        ),
      );
    }
    final badCaseMetrics = _badCaseStats
        .map(
          (item) => ShortVideoMetricData(
            label: shortVideoFormatBadCaseLabel(l10n, item),
            value: item.count.toString(),
          ),
        )
        .toList(growable: false);
    final recentTaskLines = (_recentProjectTasks?.data ?? const <JobRow>[])
        .take(3)
        .map(
          (task) =>
              '${shortVideoFormatTaskKind(l10n, task)} · ${shortVideoFormatTaskStatus(l10n, task)}',
        )
        .toList(growable: false);
    final readinessItems = buildShortVideoReadinessItems(
      l10n,
      isAnimated: _isAnimated,
      project: project,
      stats: _projectStats,
      sceneAssetCount: _sceneAssetCount,
      clipAssetCount: _clipAssetCount,
    );
    final shotReadinessUi = project == null
        ? ShotReadinessUi(
            headline: l10n.shortVideoShotReadinessSelectProjectHint,
          )
        : buildShotReadinessUi(
            l10n: l10n,
            loadingProjectOverview: _loadingProjectOverview,
            readiness: _shotReadiness,
            readinessUnavailable: _shotReadinessUnavailable,
          );
    final assetsOverviewPanelUi = buildShortVideoAssetsOverviewPanelUi(
      l10n: l10n,
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      overview: _projectAssetsOverview,
    );
    final assemblyPanelUi = buildShortVideoAssemblyPanelUi(
      l10n: l10n,
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assembly: _shortVideoAssembly,
    );
    final Widget? assemblyVersionManagerPanel =
        project != null &&
            _shortVideoAssembly != null &&
            _shortVideoAssembly!.scripts.isNotEmpty
        ? VersionManager(
            versions: _assemblyVersions,
            currentVersionId: _currentAssemblyVersionId,
            drafts: _assemblyDrafts,
            onCreateVersion: _handleCreateVersion,
            onSwitchVersion: _handleSwitchVersion,
            onDeleteVersion: _handleDeleteVersion,
            onSaveDraft: _handleSaveDraft,
            onRestoreDraft: _handleRestoreDraft,
            onDeleteDraft: _handleDeleteDraft,
          )
        : null;
    final exportCheckPanelUi = buildShortVideoExportCheckPanelUi(
      l10n: l10n,
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      exportCheck: _shortVideoExportCheck,
    );
    final runtimeDescriptor = resolveDesktopRuntimeDescriptor(l10n: l10n);
    final bridgeSnapshot = _nativeBridgeBootstrap.snapshot;
    final localAssemblyBlockedHint = resolveLocalAssemblyBlockedHint(
      l10n: l10n,
      runtime: runtimeDescriptor,
      snapshot: bridgeSnapshot,
    );
    final localAssemblyReady = canUseLocalAssemblyActions(
      runtime: runtimeDescriptor,
      snapshot: bridgeSnapshot,
    );
    final assemblyGate = buildAssemblyGateUi(
      l10n: l10n,
      exportCheck: _shortVideoExportCheck,
      assembly: _shortVideoAssembly,
    );
    final assemblyInputPanelUi = buildAssemblyInputPanelUi(
      l10n: l10n,
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assembly: _shortVideoAssembly,
      exportCheck: _shortVideoExportCheck,
      activeJob: _activeAssemblyJob,
    );
    final assemblyScripts = _shortVideoAssembly?.scripts ?? const <ShortVideoAssemblyScriptGroup>[];
    final allAssemblyShots = assemblyScripts
        .expand((script) => script.shots)
        .toList(growable: false);
    final totalAssemblyShots = allAssemblyShots.length;
    final selectedAssemblyShots = allAssemblyShots
        .where((shot) => (shot.selectedMediaUrl ?? '').trim().isNotEmpty)
        .length;
    final voiceoverReadyShots = allAssemblyShots
        .where(
          (shot) =>
              shot.voiceoverAssetReady ||
              (shot.voiceoverAudioUrl ?? '').trim().isNotEmpty,
        )
        .length;
    DateTime? latestSelectionWritebackAt;
    if (_candidateCompareRows.isNotEmpty &&
        totalAssemblyShots > 0 &&
        _candidateCompareRows.length == totalAssemblyShots) {
      for (final row in _candidateCompareRows) {
        final at = DateTime.tryParse(row.mediaSlots?.lastWriteback?.at?.trim() ?? '');
        if (at == null) {
          continue;
        }
        final currentLatestWritebackAt = latestSelectionWritebackAt;
        if (currentLatestWritebackAt == null ||
            at.isAfter(currentLatestWritebackAt)) {
          latestSelectionWritebackAt = at;
        }
      }
    }
    final latestExport = _latestSuccessfulExport;
    final latestExportCompletedAt = latestExport?.completedAt;
    final activeExportJob = _activeAssemblyJob?.kind == 'video.export'
        ? _activeAssemblyJob
        : null;
    final activeExportStatus = (activeExportJob?.status ?? '').trim();
    final activeExportFailed =
        activeExportJob != null && activeExportStatus == 'failed';
    final activeExportInFlight =
        activeExportJob != null &&
        activeExportStatus.isNotEmpty &&
        activeExportStatus != 'succeeded' &&
        activeExportStatus != 'failed' &&
        activeExportStatus != 'cancelled';
    final activeExportCreatedAt = activeExportJob == null
        ? null
        : DateTime.tryParse(activeExportJob.createdAt);
    final activeExportStatusDisplay = activeExportJob == null
        ? null
        : ExportTaskStatus.fromString(activeExportStatus).displayName(l10n);
    final activeExportFailureCode =
        (activeExportJob?.errorDetails?['code'] ?? '').toString().trim();
    final activeExportFailurePhaseKey = _classifyExportFailurePhase(
      _activeExportTask?.stage,
      activeExportFailureCode,
    );
    final activeExportStageDisplay = _activeExportTask?.stage == null
        ? null
        : ExportTaskStage.fromString(_activeExportTask!.stage!).displayName(l10n);
    final activeExportFailurePhaseDisplay =
        (activeExportFailurePhaseKey ?? '').isEmpty
        ? null
        : ExportTaskStage.fromString(activeExportFailurePhaseKey!)
            .displayName(l10n);
    final activeExportFailureCodeDisplay =
        activeExportFailureCode.isEmpty
        ? null
        : videoExportFailureCodeLabel(l10n, activeExportFailureCode);
    final activeExportRecommendedAction = activeExportFailed
        ? recommendExportFailureAction(
            activeExportFailurePhaseKey,
            activeExportFailureCode,
          )
        : ShortVideoLatestExportAction.none;
    final activeExportProgressDisplay = _activeExportTask == null
        ? null
        : '${_activeExportTask!.progress.clamp(0, 100)}%';
    final activeExportFormat = (_activeExportTask?.format ??
            activeExportJob?.payload['format']?.toString() ??
            'mp4')
        .toLowerCase();
    final activeExportShortId = activeExportJob == null
        ? ''
        : activeExportJob.id.length <= 8
        ? activeExportJob.id
        : activeExportJob.id.substring(0, 8);
    final activeExportTaskTitle = (activeExportInFlight || activeExportFailed)
        ? '${activeExportStatusDisplay ?? ExportTaskStatus.queued.displayName(l10n)} · ${l10n.shortVideoSpaceProductionAssemblyTask} $activeExportShortId'
        : null;
    final activeExportTaskDetail = (activeExportInFlight || activeExportFailed)
        ? <String>[
            if (activeExportCreatedAt != null)
              l10n.shortVideoSpaceDialogExportHistoryCreatedAt(
                DateFormat('yyyy-MM-dd HH:mm').format(activeExportCreatedAt.toLocal()),
              ),
            if (activeExportFailed &&
                (activeExportFailurePhaseDisplay ?? '').trim().isNotEmpty)
              activeExportFailurePhaseDisplay!,
            if (!activeExportFailed &&
                (activeExportStageDisplay ?? '').trim().isNotEmpty)
              activeExportStageDisplay!,
            if (activeExportInFlight &&
                (activeExportProgressDisplay ?? '').trim().isNotEmpty)
              activeExportProgressDisplay!,
          ].join(' · ')
        : null;
    final activeExportError = activeExportFailed
        ? <String>[
            if ((activeExportFailureCodeDisplay ?? '').trim().isNotEmpty)
              activeExportFailureCodeDisplay!,
            if ((_activeExportTask?.error?.trim().isNotEmpty ?? false))
              _activeExportTask!.error!.trim()
            else if ((activeExportJob.errorMessage?.trim().isNotEmpty ?? false))
              activeExportJob.errorMessage!.trim()
            else
              l10n.shortVideoSpaceDialogExportProgressMessageFailed,
          ].join(' · ')
        : null;
    final latestExportCompletedAtLine =
        latestExport?.completedAt == null
        ? null
        : '${l10n.shortVideoSpaceDialogExportHistoryCompletedAt}: ${DateFormat('yyyy-MM-dd HH:mm').format(latestExport!.completedAt!.toLocal())}';
    final latestExportFileSizeLine =
        latestExport?.fileSize == null
        ? null
        : '${l10n.shortVideoSpaceDialogExportHistoryFileSize}: ${latestExport!.formattedFileSize}';
    final hasNewerExportInFlight =
        latestExport != null &&
        activeExportInFlight &&
        activeExportCreatedAt != null &&
        latestExportCompletedAt != null &&
        activeExportCreatedAt.isAfter(latestExportCompletedAt);
    final exportStaleAgainstSelection =
        latestExport != null &&
        latestExportCompletedAt != null &&
        latestSelectionWritebackAt != null &&
        latestSelectionWritebackAt.isAfter(latestExportCompletedAt);
    final latestExportStatusLine = hasNewerExportInFlight
        ? activeExportStatus == 'running'
              ? l10n.shortVideoSpaceProductionLatestExportNewerRunning
              : l10n.shortVideoSpaceProductionLatestExportNewerQueued
        : exportStaleAgainstSelection
        ? l10n.shortVideoSpaceProductionLatestExportStaleSelection
        : latestExport == null
        ? null
        : totalAssemblyShots > 0
        ? l10n.shortVideoSpaceProductionLatestExportSelectionSummary(
            selectedAssemblyShots,
            totalAssemblyShots,
          )
        : null;
    final latestExportUi = latestExport == null && !activeExportFailed
        ? const ShortVideoLatestExportUi()
        : ShortVideoLatestExportUi(
            visible: true,
            isWarning:
                activeExportFailed ||
                hasNewerExportInFlight ||
                exportStaleAgainstSelection,
            title:
                latestExport != null
                ? '${ExportTaskStatus.completed.displayName(l10n)} · ${getFormatDisplayName(l10n, latestExport.format.toLowerCase())} · ${getResolutionDisplayName(l10n, latestExport.resolution)}'
                : '${ExportTaskStatus.failed.displayName(l10n)} · ${getFormatDisplayName(l10n, activeExportFormat)}',
            detail: latestExport?.taskId ?? activeExportJob?.id ?? '',
            statusLine: latestExportStatusLine,
            activeTaskTitle: activeExportTaskTitle,
            activeTaskDetail: activeExportTaskDetail,
            activeTaskRunning:
                activeExportStatus == 'running' ||
                activeExportStatus == 'processing',
            activeTaskFailed: activeExportFailed,
            activeTaskError: activeExportError,
            recommendedAction: activeExportRecommendedAction,
            meta: <String>[
              if (latestExportCompletedAtLine != null) ...[
                latestExportCompletedAtLine,
              ],
              if (latestExportFileSizeLine != null) ...[
                latestExportFileSizeLine,
              ],
              if (latestExport != null && totalAssemblyShots > 0)
                l10n.shortVideoSpaceProductionLatestExportVoiceoverSummary(
                  voiceoverReadyShots,
                  totalAssemblyShots,
                ),
              if (latestExport != null)
                '${latestExport.bitrate} · ${latestExport.framerate}fps'
              else
                getFormatDisplayName(l10n, activeExportFormat),
            ],
          );
    final preAssemblyBlockedTooltip = !localAssemblyReady
        ? localAssemblyBlockedHint
        : assemblyGate.canPreAssembly
        ? null
        : (assemblyGate.blockingReasonLines.isNotEmpty
              ? assemblyGate.blockingReasonLines.first
              : l10n.shortVideoSpaceAssemblyGatePreAssemblyBlocked);
    final accessToken = widget.accessToken;
    final publishPanelUi = buildShortVideoPublishPanelUi(
      l10n: l10n,
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
      onRefreshPublish:
          project != null && accessToken != null && accessToken.isNotEmpty
          ? () => unawaited(_refreshPublishSlice(project, accessToken))
          : null,
      onBootstrapPublishDraft:
          project != null && accessToken != null && accessToken.isNotEmpty
          ? () => unawaited(_bootstrapPublishDraft())
          : null,
      onEnqueuePublishJob:
          project != null && accessToken != null && accessToken.isNotEmpty
          ? () => unawaited(_enqueuePublishJob())
          : null,
      onConfirmSemiAuto:
          project != null && accessToken != null && accessToken.isNotEmpty
          ? () => unawaited(_confirmSemiAutoPublish())
          : null,
      onSuggestPublishCopy:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable
          ? () => unawaited(_suggestPublishCopy())
          : null,
      onClearPublishSchedule:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_clearPublishSchedule())
          : null,
      publishTargetPlatformIds: _targetPlatforms,
      onEnqueueAllDrafts: project != null
          ? () => unawaited(_enqueueAllDraftJobs())
          : null,
      onRetryFailedPublishJobs: project != null
          ? () => unawaited(_retryFailedPublishJobs())
          : null,
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
      onCommitPublishPlatformCopy:
          project != null &&
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
      onScheduleFirstDraft:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx) => unawaited(_scheduleFirstDraft(ctx, project, accessToken))
          : null,
      onScheduleAllDraftsSameTime:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.length > 1
          ? (ctx) =>
                unawaited(_scheduleAllDraftsSameTime(ctx, project, accessToken))
          : null,
      onPublishCalendarDayBulkSchedule:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx, day) => unawaited(
              _bulkScheduleDraftsForCalendarDay(ctx, project, accessToken, day),
            )
          : null,
      onOpenPublishTroubleshooting:
          project != null && accessToken != null && accessToken.isNotEmpty
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
      onBatchScheduleDrafts:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? (ctx) => unawaited(_batchScheduleDrafts(ctx))
          : null,
      onBatchPublishDrafts:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_batchPublishDrafts())
          : null,
      onBatchArchiveDrafts:
          project != null &&
              accessToken != null &&
              accessToken.isNotEmpty &&
              !_publishUnavailable &&
              _publishDrafts.isNotEmpty
          ? () => unawaited(_batchArchiveDrafts())
          : null,
      onCompareDrafts: _publishDrafts.isNotEmpty ? _compareDrafts : null,
      batchValidation: _batchValidation,
      onResetConfirmationDontShowAgain: (ctx) =>
          unawaited(runResetRiskyOperationConfirmPrefsFlow(ctx)),
      // P11: Delivery mode
      deliveryModeFilter: _deliveryModeFilter,
      onDeliveryModeFilterChanged: _onDeliveryModeFilterChanged,
    );
    final candidateCardUi = buildShortVideoCandidateCardUi(
      l10n: l10n,
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      assetsOverview: _projectAssetsOverview,
      onBatchGenerateCandidateClips:
          project != null && (_projectStats?.storyboardCount ?? 0) > 0
          ? _runBatchCandidateClips
          : null,
      batchGenerateCandidateClipsBusy: _batchCandidateBusy,
      onConfirmStoryboardCandidates: project != null
          ? _confirmStoryboardCandidates
          : null,
      confirmStoryboardCandidatesBusy: _confirmCandidatesBusy,
      candidatePendingStoryboardCount: _candidatePendingStoryboardCount(),
    );
    final candidateComparePanelUi = buildShortVideoCandidateComparePanelUi(
      l10n: l10n,
      projectSelected: project != null,
      loadingProjectOverview: _loadingProjectOverview,
      storyboardRows: _candidateCompareRows,
      readiness: _shotReadiness,
      reviews: _candidateCompareReviews,
      isLiveAction: !_isAnimated,
      onSetCurrent: _setComparedStoryboardCurrent,
      onSelectCandidateVideo: _selectComparedStoryboardVideo,
      onOpenProductionWorkspace: project == null
          ? null
          : () {
              _syncSelectedProjectContext();
              widget.onOpenProductionWorkspace();
            },
    );
    final nextStepPlan = buildShortVideoNextStepPlan(
      l10n: l10n,
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
        title: l10n.shortVideoStageCard1Title,
        status: l10n.shortVideoStageCard1Status,
        detail: _isAnimated
            ? l10n.shortVideoStageCard1DetailAnimated
            : l10n.shortVideoStageCard1DetailLive,
      ),
      ShortVideoStageCardData(
        title: l10n.shortVideoStageCard2Title,
        status: l10n.shortVideoStageCard2Status,
        detail: _isAnimated
            ? l10n.shortVideoStageCard2DetailAnimated
            : l10n.shortVideoStageCard2DetailLive,
      ),
      ShortVideoStageCardData(
        title: l10n.shortVideoStageCard3Title,
        status: l10n.shortVideoStageCard3Status,
        detail: _isAnimated
            ? l10n.shortVideoStageCard3DetailAnimated
            : l10n.shortVideoStageCard3DetailLive,
      ),
      ShortVideoStageCardData(
        title: l10n.shortVideoStageCard4Title,
        status: l10n.shortVideoStageCard4Status,
        detail: _isAnimated
            ? l10n.shortVideoStageCard4DetailAnimated
            : l10n.shortVideoStageCard4DetailLive,
      ),
    ];
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        return _handleKeyboardShortcuts(event);
      },
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelConsistencyAlert(
              status: _panelVersionManager.checkConsistency(),
              onRefresh: () => unawaited(_loadProjectOverview()),
            ),
            const SizedBox(height: 12),
            ShortVideoSpaceView(
        desktopCapabilityPanel: const ShortVideoDesktopCapabilityPanel(),
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
        projectReadinessSummary: shortVideoProjectReadinessSummary(
          _projectStats,
          l10n,
        ),
        visualLabel: visualLabel,
        directionLabel: directionLabel,
        projectMetrics: projectMetrics,
        spaceOverviewSummary: shortVideoSpaceOverviewSummary(
          l10n: l10n,
          loadingProjectOverview: _loadingProjectOverview,
          project: project,
          projectStats: _projectStats,
          recentProjectTasks: _recentProjectTasks,
          qualityScopeInsight: _qualityScopeInsight,
        ),
        overviewMetrics: overviewMetrics,
        qualitySummaryLine: shortVideoQualitySummaryLine(
          l10n,
          isAnimated: _isAnimated,
          insight: _qualityScopeInsight,
        ),
        badCaseMetrics: badCaseMetrics,
        recentTaskLines: recentTaskLines,
        assetsOverviewPanelUi: assetsOverviewPanelUi,
        assemblyPanelUi: assemblyPanelUi,
        assemblyInputPanelUi: assemblyInputPanelUi,
        exportCheckPanelUi: exportCheckPanelUi,
        latestExportUi: latestExportUi,
        preAssemblyBlockedTooltip: preAssemblyBlockedTooltip,
        onFixAssemblyStoryboard: project == null
            ? null
            : () {
                _syncSelectedProjectContext();
                widget.onOpenScriptWorkspace();
              },
        onFixAssemblyProduction: project == null
            ? null
            : () {
                _syncSelectedProjectContext();
                widget.onOpenProductionWorkspace();
              },
        onFixAssemblyClipDesk:
            project == null ||
                _shortVideoAssembly == null ||
                (_shortVideoAssembly?.scripts.isEmpty ?? true)
            ? null
            : () => unawaited(_openAssemblyClipDeskOps()),
        onOpenAssemblyTaskCenter: project == null
            ? null
            : () {
                _syncSelectedProjectContext();
                widget.onOpenTasks();
              },
        onCancelAssemblyJob: _activeAssemblyJob != null
            ? () => unawaited(_cancelActiveAssemblyJob())
            : null,
        onRetryAssemblyJob: _activeAssemblyJob != null
            ? () => unawaited(_retryActiveAssemblyJob())
            : null,
        onCreateDraftFromAssemblyJob:
            _activeAssemblyJob?.status == 'succeeded' &&
                _activeAssemblyJob?.kind == 'short_video.pre_assembly'
            ? () => unawaited(_createDraftFromPreAssemblyJob())
            : null,
        onStartExport:
            project != null &&
                accessToken != null &&
                accessToken.isNotEmpty &&
                localAssemblyReady
            ? () => unawaited(_startExportFlow())
            : null,
        onStartPreAssembly:
            project != null &&
                accessToken != null &&
                accessToken.isNotEmpty &&
                localAssemblyReady
            ? () => unawaited(_startPreAssemblyFlow())
            : null,
        preAssemblyActionBusy: _preAssemblyActionBusy,
        onOpenExportHistory:
            project != null && accessToken != null && accessToken.isNotEmpty
            ? () => unawaited(_openExportHistoryFlow())
            : null,
        onDownloadLatestExport:
            latestExport != null &&
                accessToken != null &&
                accessToken.isNotEmpty &&
                (latestExport.outputUrl?.trim().isNotEmpty ?? false)
            ? () => unawaited(_downloadLatestSuccessfulExport())
            : null,
        onCancelLatestExportTask:
            _activeAssemblyJob?.kind == 'video.export' &&
                _activeAssemblyJob?.status != 'succeeded' &&
                _activeAssemblyJob?.status != 'failed' &&
                _activeAssemblyJob?.status != 'cancelled'
            ? () => unawaited(_cancelActiveAssemblyJob())
            : null,
        onRetryLatestExportTask:
            _activeAssemblyJob?.kind == 'video.export' &&
                _activeAssemblyJob?.status == 'failed'
            ? () => unawaited(_retryActiveAssemblyJob())
            : null,
        exportActionBusy: _exportActionBusy,
        localAssemblyBlockedHint: localAssemblyBlockedHint,
        publishPanelUi: publishPanelUi,
        onOpenProductionForAssemblyExport: project == null
            ? null
            : () {
                _syncSelectedProjectContext();
                widget.onOpenProductionWorkspace();
              },
        onOpenDesktopDownloads: runtimeDescriptor.showDownloadCallToAction
            ? () => unawaited(
                launchUrl(
                  Uri.parse(kOpenflowDesktopDownloadsUrl),
                  mode: LaunchMode.externalApplication,
                ),
              )
            : null,
        onOpenAssemblyClipDeskOps:
            project == null ||
                _shortVideoAssembly == null ||
                (_shortVideoAssembly?.scripts.isEmpty ?? true)
            ? null
            : () => unawaited(_openAssemblyClipDeskOps()),
        onOpenAssemblyDefaultsEditor:
            project == null || _shortVideoAssembly == null
            ? null
            : () => unawaited(_openAssemblyDefaultsEditor()),
        assemblyVersionManagerPanel: assemblyVersionManagerPanel,
        candidateCardUi: candidateCardUi,
        candidateComparePanelUi: candidateComparePanelUi,
        projectCharactersPanel: _buildProjectCharactersPanel(),
        shortVideoTimelinePanel: _buildShortVideoTimelinePanel(),
        onOpenProjectsForCandidateAssets: project == null
            ? null
            : widget.onOpenProjects,
        readinessIntro: _isAnimated
            ? l10n.shortVideoReadinessIntroAnimated
            : l10n.shortVideoReadinessIntroLive,
        readinessCountLabel:
            '${readinessItems.where((item) => item.ready).length}/${readinessItems.length}',
        readinessGapSummary: shortVideoReadinessGapSummary(
          l10n,
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
            ? l10n.shortVideoMigrationSummaryAnimated
            : l10n.shortVideoMigrationSummaryLive,
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
        runningJobCount: _scopedRunningJobCount,
        assemblyInputPanelKey: _assemblyInputPanelKey,
        onResetConfirmationDontShowAgain: (ctx) =>
            unawaited(runResetRiskyOperationConfirmPrefsFlow(ctx)),
        ),
          ],
        ),
      ),
    );
  }
}
