part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionBuildLayout on _ShortVideoSpaceSectionState {
  Widget buildShortVideoSectionLayout(
    BuildContext context,
    _ShortVideoSectionBuildBundle bundle,
  ) {
    final useResponsiveShell =
        widget.embedScope == ShortVideoSpaceEmbedScope.full ||
        widget.embedScope == ShortVideoSpaceEmbedScope.assembly ||
        widget.embedScope == ShortVideoSpaceEmbedScope.publish ||
        widget.embedScope == ShortVideoSpaceEmbedScope.quality;
    final previewUrlRaw = (_timelinePreviewUrl ?? bundle.latestExport?.outputUrl ?? '')
        .trim();
    final effectivePreviewUrl =
        previewUrlRaw.isEmpty ? null : previewUrlRaw;
    final effectivePreviewPlaylist = _effectivePreviewPlaylist(
      effectivePreviewUrl: effectivePreviewUrl,
    );

    final spaceView = ShortVideoSpaceView(
              embedScope: widget.embedScope,
              hideMasterPanels: useResponsiveShell,
              splitPublishDraftPanels:
                  useResponsiveShell &&
                  widget.embedScope == ShortVideoSpaceEmbedScope.publish,
              hideQualityOverview:
                  useResponsiveShell &&
                  widget.embedScope == ShortVideoSpaceEmbedScope.quality,
              publishSectionKey: _publishSectionKey,
              qualitySectionKey: _qualitySectionKey,
              desktopCapabilityPanel: const ShortVideoDesktopCapabilityPanel(),
              mode: _mode,
              modeTitle: bundle.modeTitle,
              modeSummary: bundle.modeSummary,
              modeAdvice: bundle.modeAdvice,
              onModeChanged: (mode) {
                setState(() {
                  _mode = mode;
                });
              },
              loadingProjects: _loadingProjects,
              projectOptions: bundle.projectOptions,
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
                bundle.l10n,
              ),
              visualLabel: bundle.visualLabel,
              directionLabel: bundle.directionLabel,
              projectMetrics: bundle.projectMetrics,
              spaceOverviewSummary: shortVideoSpaceOverviewSummary(
                l10n: bundle.l10n,
                loadingProjectOverview: _loadingProjectOverview,
                project: bundle.project,
                projectStats: _projectStats,
                recentProjectTasks: _recentProjectTasks,
                qualityScopeInsight: _qualityScopeInsight,
              ),
              overviewMetrics: bundle.overviewMetrics,
              qualitySummaryLine: bundle.qualitySummaryLine,
              badCaseMetrics: bundle.badCaseMetrics,
              recentTaskLines: bundle.recentTaskLines,
              assetsOverviewPanelUi: bundle.assetsOverviewPanelUi,
              assemblyPanelUi: bundle.assemblyPanelUi,
              assemblyInputPanelUi: bundle.assemblyInputPanelUi,
              exportCheckPanelUi: bundle.exportCheckPanelUi,
              latestExportUi: bundle.latestExportUi,
              preAssemblyBlockedTooltip: bundle.preAssemblyBlockedTooltip,
              onFixAssemblyStoryboard: bundle.project == null
                  ? null
                  : () {
                      _syncSelectedProjectContext();
                      widget.onOpenScriptWorkspace();
                    },
              onFixAssemblyProduction: bundle.project == null
                  ? null
                  : () {
                      _syncSelectedProjectContext();
                      widget.onOpenProductionWorkspace();
                    },
              onFixAssemblyClipDesk:
                  bundle.project == null ||
                      _shortVideoAssembly == null ||
                      (_shortVideoAssembly?.scripts.isEmpty ?? true)
                  ? null
                  : () => unawaited(_openAssemblyClipDeskOps()),
              onOpenAssemblyTaskCenter: bundle.project == null
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
                  bundle.project != null &&
                      bundle.accessToken != null &&
                      bundle.accessToken.isNotEmpty &&
                      bundle.localAssemblyReady
                  ? () => unawaited(_startExportFlow())
                  : null,
              onStartPreAssembly:
                  bundle.project != null &&
                      bundle.accessToken != null &&
                      bundle.accessToken.isNotEmpty &&
                      bundle.localAssemblyReady
                  ? () => unawaited(_startPreAssemblyFlow())
                  : null,
              preAssemblyActionBusy: _preAssemblyActionBusy,
              onOpenExportHistory:
                  bundle.project != null &&
                      bundle.accessToken != null &&
                      bundle.accessToken.isNotEmpty
                  ? () => unawaited(_openExportHistoryFlow())
                  : null,
              onDownloadLatestExport:
                  bundle.latestExport != null &&
                      bundle.accessToken != null &&
                      bundle.accessToken.isNotEmpty &&
                      (bundle.latestExport.outputUrl?.trim().isNotEmpty ?? false)
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
              localAssemblyBlockedHint: bundle.localAssemblyBlockedHint,
              publishPanelUi: bundle.publishPanelUi,
              onOpenProductionForAssemblyExport: bundle.project == null
                  ? null
                  : () {
                      _syncSelectedProjectContext();
                      widget.onOpenProductionWorkspace();
                    },
              onOpenDesktopDownloads: bundle.runtimeDescriptor.showDownloadCallToAction
                  ? () => unawaited(
                      launchUrl(
                        Uri.parse(kOpenflowDesktopDownloadsUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    )
                  : null,
              onOpenAssemblyClipDeskOps:
                  bundle.project == null ||
                      _shortVideoAssembly == null ||
                      (_shortVideoAssembly?.scripts.isEmpty ?? true)
                  ? null
                  : () => unawaited(_openAssemblyClipDeskOps()),
              onOpenAssemblyDefaultsEditor:
                  bundle.project == null || _shortVideoAssembly == null
                  ? null
                  : () => unawaited(_openAssemblyDefaultsEditor()),
              onRefreshExportCheck: bundle.project == null
                  ? null
                  : () => unawaited(_loadProjectOverview()),
              assemblyVersionManagerPanel: bundle.assemblyVersionManagerPanel,
              candidateCardUi: bundle.candidateCardUi,
              candidateComparePanelUi: bundle.candidateComparePanelUi,
              projectCharactersPanel: _buildProjectCharactersPanel(),
              shortVideoTimelinePanel: _buildShortVideoTimelinePanel(),
              onOpenProjectsForCandidateAssets: bundle.project == null
                  ? null
                  : widget.onOpenProjects,
              readinessIntro: _isAnimated
                  ? bundle.l10n.shortVideoReadinessIntroAnimated
                  : bundle.l10n.shortVideoReadinessIntroLive,
              readinessCountLabel:
                  '${bundle.readinessItems.where((item) => item.ready).length}/${bundle.readinessItems.length}',
              readinessGapSummary: shortVideoReadinessGapSummary(
                bundle.l10n,
                isAnimated: _isAnimated,
                readinessItems: bundle.readinessItems,
              ),
              readinessItems: bundle.readinessItems,
              shotReadinessUi: bundle.shotReadinessUi,
              onOpenProductionForShotReadiness: bundle.project == null
                  ? null
                  : () {
                      _syncSelectedProjectContext();
                      widget.onOpenProductionWorkspace();
                    },
              nextStepTitle: bundle.nextStepPlan.title,
              nextStepDetail: bundle.nextStepPlan.detail,
              onNextStep: _nextStepAction(),
              nextStepButtonLabel: bundle.nextStepPlan.buttonLabel,
              stageCards: bundle.stageCards,
              migrationSummary: _isAnimated
                  ? bundle.l10n.shortVideoMigrationSummaryAnimated
                  : bundle.l10n.shortVideoMigrationSummaryLive,
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
              accessToken: widget.accessToken,
            );

    final detailColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedScope == ShortVideoSpaceEmbedScope.full)
          PanelConsistencyAlert(
            status: _panelVersionManager.checkConsistency(),
            onRefresh: () => unawaited(_loadProjectOverview()),
          ),
        if (widget.embedScope == ShortVideoSpaceEmbedScope.full)
          const SizedBox(height: StudioSpacing.sm),
        spaceView,
      ],
    );

    final Widget body;
    if (useResponsiveShell) {
      final timelinePanel = _buildShortVideoTimelinePanel();
      body = ShortVideoResponsiveShell(
        videoRatio: _videoRatio,
        previewVideoUrl: effectivePreviewUrl,
        previewBusy: _timelinePreviewBusy,
        previewPlaylist: effectivePreviewPlaylist,
        masterPane: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.embedScope == ShortVideoSpaceEmbedScope.publish)
              ShortVideoPublishDraftsPanel(
                publishPanelUi: bundle.publishPanelUi,
                showDraftList: true,
                showDraftDetail: false,
              )
            else if (widget.embedScope == ShortVideoSpaceEmbedScope.quality)
              _buildQualityMasterPane(
                l10n: bundle.l10n,
                qualitySummaryLine: bundle.qualitySummaryLine,
                badCaseMetrics: bundle.badCaseMetrics,
              )
            else ...[
              if (timelinePanel != null) ...[
                timelinePanel,
                if (widget.embedScope == ShortVideoSpaceEmbedScope.full)
                  const SizedBox(height: StudioLayoutSpacing.section),
              ],
              if (widget.embedScope == ShortVideoSpaceEmbedScope.full)
                ShortVideoCandidateCompareSection(
                  accessToken: widget.accessToken,
                  candidateCardUi: bundle.candidateCardUi,
                  candidateComparePanelUi: bundle.candidateComparePanelUi,
                  videoRatio: _videoRatio,
                  onOpenProjectsForCandidateAssets: bundle.project == null
                      ? null
                      : widget.onOpenProjects,
                ),
            ],
          ],
        ),
        detailPane: detailColumn,
        mobileDock: _buildShortVideoMobileDock(
          l10n: bundle.l10n,
          nextStepPlan: bundle.nextStepPlan,
          project: bundle.project,
          publishPanelUi: bundle.publishPanelUi,
          onStartExport: bundle.project == null
              ? null
              : () => unawaited(_startExportFlow()),
          exportActionBusy: _exportActionBusy,
        ),
        onOpenImmersivePreview:
            effectivePreviewUrl == null &&
                (effectivePreviewPlaylist == null ||
                    effectivePreviewPlaylist.isEmpty)
            ? null
            : () => ShortVideoImmersivePreviewPage.push(
                  context,
                  videoRatio: _videoRatio,
                  videoUrl: effectivePreviewUrl,
                  playlist: effectivePreviewPlaylist,
                  blockPop: _timelinePreviewBusy,
                ),
      );
    } else {
      body = SingleChildScrollView(child: detailColumn);
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        return _handleKeyboardShortcuts(event);
      },
      child: useResponsiveShell ? ShortVideoDeferredBody(child: body) : body,
    );
  }
}
