part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionBuildPanels on _ShortVideoSpaceSectionState {
  _ShortVideoSectionBuildBundle compileSectionBuildBundle(BuildContext context) {
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
    if (po != null &&
        readinessRollup != null &&
        readinessRollup.totalStoryboards > 0) {
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
    final qualitySummaryLine = shortVideoQualitySummaryLine(
      l10n,
      isAnimated: _isAnimated,
      insight: _qualityScopeInsight,
    );
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
    final assemblyScripts =
        _shortVideoAssembly?.scripts ?? const <ShortVideoAssemblyScriptGroup>[];
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
        final at = DateTime.tryParse(
          row.mediaSlots?.lastWriteback?.at?.trim() ?? '',
        );
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
        : ExportTaskStage.fromString(
            _activeExportTask!.stage!,
          ).displayName(l10n);
    final activeExportFailurePhaseDisplay =
        (activeExportFailurePhaseKey ?? '').isEmpty
        ? null
        : ExportTaskStage.fromString(
            activeExportFailurePhaseKey!,
          ).displayName(l10n);
    final activeExportFailureCodeDisplay = activeExportFailureCode.isEmpty
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
    final activeExportFormat =
        (_activeExportTask?.format ??
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
                DateFormat(
                  'yyyy-MM-dd HH:mm',
                ).format(activeExportCreatedAt.toLocal()),
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
    final latestExportCompletedAtLine = latestExport?.completedAt == null
        ? null
        : '${l10n.shortVideoSpaceDialogExportHistoryCompletedAt}: ${DateFormat('yyyy-MM-dd HH:mm').format(latestExport!.completedAt!.toLocal())}';
    final latestExportFileSizeLine = latestExport?.fileSize == null
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
            title: latestExport != null
                ? '${ExportTaskStatus.completed.displayName(l10n)} · ${getFormatDisplayName(l10n, latestExport.format.toLowerCase())} · ${getResolutionDisplayName(l10n, latestExport.resolution)}'
                : '${ExportTaskStatus.failed.displayName(l10n)} · ${getFormatDisplayName(l10n, activeExportFormat)}',
            detail: latestExport?.taskId ?? activeExportJob?.id ?? '',
            previewOutputUrl: latestExport?.outputUrl?.trim(),
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
    return _ShortVideoSectionBuildBundle(
      project: project,
      l10n: l10n,
      visualLabel: visualLabel,
      directionLabel: directionLabel,
      modeTitle: modeTitle,
      modeSummary: modeSummary,
      modeAdvice: modeAdvice,
      projectOptions: projectOptions,
      projectMetrics: projectMetrics,
      overviewMetrics: overviewMetrics,
      qualitySummaryLine: qualitySummaryLine,
      badCaseMetrics: badCaseMetrics,
      recentTaskLines: recentTaskLines,
      readinessItems: readinessItems,
      shotReadinessUi: shotReadinessUi,
      assetsOverviewPanelUi: assetsOverviewPanelUi,
      assemblyPanelUi: assemblyPanelUi,
      assemblyInputPanelUi: assemblyInputPanelUi,
      exportCheckPanelUi: exportCheckPanelUi,
      latestExportUi: latestExportUi,
      preAssemblyBlockedTooltip: preAssemblyBlockedTooltip,
      localAssemblyBlockedHint: localAssemblyBlockedHint,
      localAssemblyReady: localAssemblyReady,
      assemblyVersionManagerPanel: assemblyVersionManagerPanel,
      accessToken: accessToken,
      runtimeDescriptor: runtimeDescriptor,
      latestExport: latestExport,
      publishPanelUi: publishPanelUi,
      candidateCardUi: candidateCardUi,
      candidateComparePanelUi: candidateComparePanelUi,
      nextStepPlan: nextStepPlan,
      stageCards: stageCards,
    );
  }
}
