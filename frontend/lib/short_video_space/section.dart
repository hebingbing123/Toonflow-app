import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../demo/product_demo_mode.dart';
import '../demo/short_video_demo_data.dart';
import '../demo/studio_demo_data.dart';
import '../l10n/app_localizations.dart';
import '../platform/studio_content_heuristics.dart';
import '../platform/studio_optimistic_mutation.dart';
import '../platform/studio_optimistic_publish_draft.dart';
import '../l10n/short_video_generation_blocked.dart';
import '../local_prefs/risky_operation_confirm_prefs.dart';
import '../native_bridge/native_bridge_bootstrap.dart';
import '../project_studio/studio_snapshot_bus.dart';
import '../rust_api.dart';
import '../design_system/components/studio_card.dart';
import '../design_system/components/studio_dialog_shell.dart';
import '../design_system/components/studio_icon_button.dart';
import '../design_system/components/studio_async_data_view.dart';
import '../design_system/components/studio_entrance_motion.dart';
import '../design_system/components/studio_empty_state.dart';
import '../design_system/components/studio_ai_generation_shimmer.dart';
import '../design_system/components/studio_loading_placeholders.dart';
import '../design_system/ix/studio_render_lock_scope.dart';
import '../design_system/components/studio_repaint_boundary.dart';
import '../design_system/studio_scheduler.dart';
import '../design_system/ix/studio_api_error_callout.dart';
import '../design_system/components/studio_text_styles.dart';
import '../design_system/components/studio_dense_action_row.dart';
import '../design_system/components/studio_debounced_action.dart';
import '../design_system/components/studio_surfaces.dart';
import '../design_system/layout_breakpoints.dart';
import '../design_system/studio_responsive_layout.dart';
import '../design_system/tokens.dart';
import '../design_system/components/studio_dropdown_field.dart';
import '../design_system/components/studio_decorative_icon.dart';
import '../design_system/studio_typography.dart';
import '../design_system/ix/studio_mobile_affordances.dart';
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
import 'components/preview_player.dart';
import 'short_video_preview_playlist.dart';
import 'layout/short_video_responsive_shell.dart';
import 'routes/immersive_preview_page.dart';
import 'deferred_section.dart';
import 'package:openflow_app/design_system/ix/studio_context_menu.dart';

part 'section_export_failure_helpers.dart';
part 'section_publish_sync.dart';
part 'section_build.dart';
part 'section_build_locals.dart';
part 'section_build_panels.dart';
part 'section_build_layout.dart';
part 'section_project.dart';
part 'section_production.dart';
part 'section_production_assembly.dart';
part 'section_production_assembly_jobs.dart';
part 'section_production_assembly_clip_desk_filters.dart';
part 'section_production_assembly_clip_desk.dart';
part 'section_production_assembly_tts.dart';
part 'section_production_assembly_widgets.dart';
part 'section_production_batch_clip_ops.dart';
part 'section_production_batch_voiceover.dart';
part 'section_production_batch_progress.dart';
part 'section_draft_management.dart';
part 'section_publish.dart';
part 'section_publish_scheduling.dart';
part 'section_publish_copy.dart';
part 'section_publish_batch.dart';
part 'section_undo_redo.dart';
part 'section_keyboard_shortcuts.dart';
part 'section_characters.dart';
part 'section_responsive_extras.dart';
part 'section_timeline.dart';
part 'section_timeline_widgets.dart';
part 'section_timeline_m2m3.dart';
part 'section_timeline_m4.dart';
part 'dialogs/voiceover_settings_dialog.dart';
part 'dialogs/export_settings_dialog.dart';
part 'dialogs/export_progress_dialog.dart';
part 'dialogs/export_history_models.dart';
part 'dialogs/export_history_dialog_widgets.dart';
part 'dialogs/export_history_dialog.dart';
part 'components/audio_preview_player.dart';

class ShortVideoSpaceSection extends StatefulWidget {
  const ShortVideoSpaceSection({
    super.key,
    required this.accessToken,
    this.debugProjects,
    this.debugPublishDrafts,
    this.debugOverviewSnapshot,
    this.initialProjectUuid,
    this.initialFocus = ShortVideoSpaceInitialFocus.none,
    this.embedScope = ShortVideoSpaceEmbedScope.full,
    this.snapshotBus,
    required this.onOpenProjects,
    required this.onSyncProjectContext,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
  });

  final String? accessToken;
  final List<ProjectRow>? debugProjects;
  final List<PublishDraftRow>? debugPublishDrafts;
  final ShortVideoDemoSnapshot? debugOverviewSnapshot;
  final String? initialProjectUuid;
  final ShortVideoSpaceInitialFocus initialFocus;
  final ShortVideoSpaceEmbedScope embedScope;
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
  var _assemblyJobPollBackoffSeconds = 3;
  final PanelVersionManager _panelVersionManager = PanelVersionManager();
  final GlobalKey _assemblyInputPanelKey = GlobalKey();
  final GlobalKey _publishSectionKey = GlobalKey();
  final GlobalKey _qualitySectionKey = GlobalKey();
  StudioSnapshotBus get _snapshotBus =>
      widget.snapshotBus ?? kStudioSnapshotBus;
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
  Object? _timelineLoadError;
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
  Object? _charactersLoadError;
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
    if (widget.debugProjects != null) {
      _projects = widget.debugProjects!;
      if (_projects.isNotEmpty) {
        _selectedProjectId = _projects.first.id;
      }
    }
    if (widget.debugPublishDrafts != null) {
      _publishDrafts = widget.debugPublishDrafts!;
      _syncSelectedPublishDraftWith(_publishDrafts);
    }
    if (widget.debugOverviewSnapshot != null) {
      _applyDemoOverviewSnapshot(widget.debugOverviewSnapshot!);
    }
    StudioScheduler.scheduleOnceUntil('short_video_section_init', () {
      if (!mounted) return;
      if (widget.debugProjects == null &&
          !ProductDemoMode.instance.shouldSkipLiveApi) {
        _loadProjects();
      } else if (widget.debugOverviewSnapshot != null &&
          _selectedProject != null) {
        _syncSelectedProjectContext();
      }
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
    GlobalKey? targetKey;
    switch (widget.initialFocus) {
      case ShortVideoSpaceInitialFocus.assembly:
        targetKey = _assemblyInputPanelKey;
      case ShortVideoSpaceInitialFocus.none:
        switch (widget.embedScope) {
          case ShortVideoSpaceEmbedScope.publish:
            targetKey = _publishSectionKey;
          case ShortVideoSpaceEmbedScope.quality:
            targetKey = _qualitySectionKey;
          case ShortVideoSpaceEmbedScope.full:
          case ShortVideoSpaceEmbedScope.assembly:
            return;
        }
    }
    final ctx = targetKey.currentContext;
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


  @override
  void didUpdateWidget(covariant ShortVideoSpaceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.initialFocus != oldWidget.initialFocus ||
            widget.embedScope != oldWidget.embedScope) &&
        (widget.initialFocus == ShortVideoSpaceInitialFocus.assembly ||
            widget.embedScope == ShortVideoSpaceEmbedScope.publish ||
            widget.embedScope == ShortVideoSpaceEmbedScope.quality)) {
      _didScrollToInitialFocus = false;
      StudioScheduler.scheduleOnceUntil('short_video_section_focus_scroll', () {
        if (!mounted) return;
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
  Widget build(BuildContext context) => buildShortVideoSpaceSection(context);
}
