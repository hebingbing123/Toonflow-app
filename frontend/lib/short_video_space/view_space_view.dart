part of 'view.dart';

class ShortVideoSpaceView extends StatelessWidget {
  const ShortVideoSpaceView({
    super.key,
    this.embedScope = ShortVideoSpaceEmbedScope.full,
    this.publishSectionKey,
    this.qualitySectionKey,
    this.desktopCapabilityPanel,
    required this.mode,
    required this.modeTitle,
    required this.modeSummary,
    required this.modeAdvice,
    required this.onModeChanged,
    required this.loadingProjects,
    required this.projectOptions,
    required this.selectedProjectId,
    required this.onProjectChanged,
    required this.onRefreshProjects,
    required this.videoRatio,
    required this.onVideoRatioChanged,
    required this.targetMarket,
    required this.onTargetMarketChanged,
    required this.targetPlatforms,
    required this.onPublishPlatformTapped,
    required this.durationStrategy,
    required this.onDurationStrategyChanged,
    required this.voiceProfile,
    required this.onVoiceProfileChanged,
    required this.subtitleStyle,
    required this.onSubtitleStyleChanged,
    required this.bgmStrategy,
    required this.onBgmStrategyChanged,
    required this.creatingProject,
    required this.onCreateProject,
    required this.savingProjectConfig,
    required this.onSaveProjectConfig,
    required this.onOpenProjects,
    required this.projectConfigLine,
    required this.operationFeedbackIsSuccess,
    required this.loadingProjectOverview,
    required this.projectReadinessSummary,
    required this.visualLabel,
    required this.directionLabel,
    required this.projectMetrics,
    required this.spaceOverviewSummary,
    required this.overviewMetrics,
    required this.qualitySummaryLine,
    required this.badCaseMetrics,
    required this.recentTaskLines,
    required this.assetsOverviewPanelUi,
    required this.assemblyPanelUi,
    required this.assemblyInputPanelUi,
    required this.exportCheckPanelUi,
    required this.latestExportUi,
    this.onStartExport,
    this.onStartPreAssembly,
    this.onOpenExportHistory,
    this.onDownloadLatestExport,
    this.onCancelLatestExportTask,
    this.onRetryLatestExportTask,
    this.exportActionBusy = false,
    this.preAssemblyActionBusy = false,
    this.localAssemblyBlockedHint,
    this.onFixAssemblyStoryboard,
    this.onFixAssemblyProduction,
    this.onFixAssemblyClipDesk,
    this.onOpenAssemblyTaskCenter,
    this.onCancelAssemblyJob,
    this.onRetryAssemblyJob,
    this.onCreateDraftFromAssemblyJob,
    this.preAssemblyBlockedTooltip,
    required this.publishPanelUi,
    this.onOpenProductionForAssemblyExport,
    this.onOpenDesktopDownloads,
    this.onOpenAssemblyClipDeskOps,
    this.onOpenAssemblyDefaultsEditor,
    this.onRefreshExportCheck,
    this.assemblyVersionManagerPanel,
    required this.candidateCardUi,
    required this.candidateComparePanelUi,
    this.projectCharactersPanel,
    this.shortVideoTimelinePanel,
    this.onOpenProjectsForCandidateAssets,
    required this.readinessIntro,
    required this.readinessCountLabel,
    required this.readinessGapSummary,
    required this.readinessItems,
    required this.shotReadinessUi,
    this.onOpenProductionForShotReadiness,
    required this.nextStepTitle,
    required this.nextStepDetail,
    required this.onNextStep,
    required this.nextStepButtonLabel,
    required this.stageCards,
    required this.migrationSummary,
    required this.onOpenScriptWorkspace,
    required this.onOpenProductionWorkspace,
    required this.onOpenTasks,
    required this.onOpenQuality,
    this.runningJobCount = 0,
    this.assemblyInputPanelKey,
    this.onResetConfirmationDontShowAgain,
    this.hideMasterPanels = false,
    this.splitPublishDraftPanels = false,
    this.hideQualityOverview = false,
    this.accessToken,
  });

  final String? accessToken;
  final String targetMarket;
  final ValueChanged<String> onTargetMarketChanged;
  final List<String> targetPlatforms;
  final ValueChanged<String> onPublishPlatformTapped;
  final String durationStrategy;
  final ValueChanged<String> onDurationStrategyChanged;
  final String voiceProfile;
  final ValueChanged<String> onVoiceProfileChanged;
  final String subtitleStyle;
  final ValueChanged<String> onSubtitleStyleChanged;
  final String bgmStrategy;
  final ValueChanged<String> onBgmStrategyChanged;
  final Widget? desktopCapabilityPanel;

  final ShortVideoMode mode;
  final String modeTitle;
  final String modeSummary;
  final String modeAdvice;
  final ValueChanged<ShortVideoMode> onModeChanged;
  final bool loadingProjects;
  final List<ShortVideoProjectOption> projectOptions;
  final String? selectedProjectId;
  final ValueChanged<String?> onProjectChanged;
  final VoidCallback onRefreshProjects;
  final String videoRatio;
  final ValueChanged<String> onVideoRatioChanged;
  final bool creatingProject;
  final VoidCallback onCreateProject;
  final bool savingProjectConfig;
  final VoidCallback onSaveProjectConfig;
  final VoidCallback onOpenProjects;
  final String? projectConfigLine;
  final bool? operationFeedbackIsSuccess;
  final bool loadingProjectOverview;
  final String projectReadinessSummary;
  final String? visualLabel;
  final String? directionLabel;
  final List<ShortVideoMetricData> projectMetrics;
  final String spaceOverviewSummary;
  final List<ShortVideoMetricData> overviewMetrics;
  final String qualitySummaryLine;
  final List<ShortVideoMetricData> badCaseMetrics;
  final List<String> recentTaskLines;
  final ShortVideoAssetsOverviewPanelUi assetsOverviewPanelUi;
  final ShortVideoAssemblyPanelUi assemblyPanelUi;
  final AssemblyInputPanelUi assemblyInputPanelUi;
  final ShortVideoExportCheckPanelUi exportCheckPanelUi;
  final ShortVideoLatestExportUi latestExportUi;
  final VoidCallback? onStartExport;
  final VoidCallback? onStartPreAssembly;
  final VoidCallback? onOpenExportHistory;
  final VoidCallback? onDownloadLatestExport;
  final VoidCallback? onCancelLatestExportTask;
  final VoidCallback? onRetryLatestExportTask;
  final bool exportActionBusy;
  final bool preAssemblyActionBusy;
  final String? localAssemblyBlockedHint;
  final VoidCallback? onFixAssemblyStoryboard;
  final VoidCallback? onFixAssemblyProduction;
  final VoidCallback? onFixAssemblyClipDesk;
  final VoidCallback? onOpenAssemblyTaskCenter;
  final VoidCallback? onCancelAssemblyJob;
  final VoidCallback? onRetryAssemblyJob;
  final VoidCallback? onCreateDraftFromAssemblyJob;
  final String? preAssemblyBlockedTooltip;
  final ShortVideoPublishPanelUi publishPanelUi;
  final VoidCallback? onOpenProductionForAssemblyExport;
  final VoidCallback? onOpenDesktopDownloads;
  final VoidCallback? onOpenAssemblyClipDeskOps;
  final VoidCallback? onOpenAssemblyDefaultsEditor;
  final VoidCallback? onRefreshExportCheck;
  final Widget? assemblyVersionManagerPanel;
  final ShortVideoCandidateCardUi candidateCardUi;
  final ShortVideoCandidateComparePanelUi candidateComparePanelUi;
  final Widget? projectCharactersPanel;
  final Widget? shortVideoTimelinePanel;
  final VoidCallback? onOpenProjectsForCandidateAssets;
  final String readinessIntro;
  final String readinessCountLabel;
  final String readinessGapSummary;
  final List<ShortVideoReadinessItem> readinessItems;
  final ShotReadinessUi shotReadinessUi;
  final VoidCallback? onOpenProductionForShotReadiness;
  final String nextStepTitle;
  final String nextStepDetail;
  final VoidCallback onNextStep;
  final String nextStepButtonLabel;
  final List<ShortVideoStageCardData> stageCards;
  final String migrationSummary;
  final VoidCallback onOpenScriptWorkspace;
  final VoidCallback onOpenProductionWorkspace;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenQuality;
  final int runningJobCount;
  final Key? assemblyInputPanelKey;

  /// Clears local destructive-confirm "don't show again" prefs (always available).
  final void Function(BuildContext context)? onResetConfirmationDontShowAgain;

  final bool hideMasterPanels;
  final bool splitPublishDraftPanels;
  final bool hideQualityOverview;

  final ShortVideoSpaceEmbedScope embedScope;
  final Key? publishSectionKey;
  final Key? qualitySectionKey;

  bool get _compactEmbed => embedScope != ShortVideoSpaceEmbedScope.full;

  bool get _showAssemblyPanels =>
      !_compactEmbed || embedScope == ShortVideoSpaceEmbedScope.assembly;

  bool get _showPublishPanels =>
      !_compactEmbed || embedScope == ShortVideoSpaceEmbedScope.publish;

  bool get _showQualityPanels =>
      !_compactEmbed || embedScope == ShortVideoSpaceEmbedScope.quality;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_compactEmbed) ...[
          const SizedBox(height: StudioLayoutSpacing.section),
          StudioPaneHeader(
            title: l10n.shortVideoSpacePageTitle,
            subtitle: l10n.shortVideoSpacePageSubtitle,
            showBack: false,
            titleStyle: studioProjectTitleStyle(context),
            trailing: RiskyOperationConfirmPrefsOverflowMenu(
              tooltip: l10n.notificationsRiskyPrefsTooltip,
            ),
          ),
          if (desktopCapabilityPanel != null) ...[
            const SizedBox(height: StudioLayoutSpacing.section),
            desktopCapabilityPanel!,
          ],
          const SizedBox(height: StudioLayoutSpacing.section),
          _Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.shortVideoSpaceSectionCreativeMode,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: StudioSpacing.xs),
                _ModeSegmentedButton(mode: mode, onChanged: onModeChanged),
                const SizedBox(height: StudioSpacing.sm),
                Text(modeTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: StudioSpacing.xs),
                Text(modeSummary, style: studioMutedBodyMedium(context)),
                const SizedBox(height: StudioSpacing.xs),
                Text(modeAdvice, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.section),
          _ProjectSelectorPanel(
            mode: mode,
            onModeChanged: onModeChanged,
            loadingProjects: loadingProjects,
            projectOptions: projectOptions,
            selectedProjectId: selectedProjectId,
            onProjectChanged: onProjectChanged,
            onRefreshProjects: onRefreshProjects,
            videoRatio: videoRatio,
            onVideoRatioChanged: onVideoRatioChanged,
            targetMarket: targetMarket,
            onTargetMarketChanged: onTargetMarketChanged,
            targetPlatforms: targetPlatforms,
            onPublishPlatformTapped: onPublishPlatformTapped,
            durationStrategy: durationStrategy,
            onDurationStrategyChanged: onDurationStrategyChanged,
            voiceProfile: voiceProfile,
            onVoiceProfileChanged: onVoiceProfileChanged,
            subtitleStyle: subtitleStyle,
            onSubtitleStyleChanged: onSubtitleStyleChanged,
            bgmStrategy: bgmStrategy,
            onBgmStrategyChanged: onBgmStrategyChanged,
            creatingProject: creatingProject,
            onCreateProject: onCreateProject,
            savingProjectConfig: savingProjectConfig,
            onSaveProjectConfig: onSaveProjectConfig,
            onOpenProjects: onOpenProjects,
            projectConfigLine: projectConfigLine,
            operationFeedbackIsSuccess: operationFeedbackIsSuccess,
            loadingProjectOverview: loadingProjectOverview,
            projectReadinessSummary: projectReadinessSummary,
            visualLabel: visualLabel,
            directionLabel: directionLabel,
            projectMetrics: projectMetrics,
            onResetConfirmationDontShowAgain: onResetConfirmationDontShowAgain,
          ),
        ],
        if (_showQualityPanels && !hideQualityOverview) ...[
          KeyedSubtree(
            key: qualitySectionKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (!_compactEmbed) const SizedBox(height: StudioLayoutSpacing.section),
                _Panel(
                  dense: _compactEmbed,
                  child: _OverviewMigrationPanel(
                    spaceOverviewSummary: spaceOverviewSummary,
                    overviewMetrics: overviewMetrics,
                    qualitySummaryLine: qualitySummaryLine,
                    badCaseMetrics: badCaseMetrics,
                    recentTaskLines: recentTaskLines,
                    migrationSummary: migrationSummary,
                    onOpenProjects: onOpenProjects,
                    onOpenScriptWorkspace: onOpenScriptWorkspace,
                    onOpenProductionWorkspace: onOpenProductionWorkspace,
                    onOpenTasks: onOpenTasks,
                    onOpenQuality: onOpenQuality,
                    runningJobCount: runningJobCount,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_showAssemblyPanels || _showQualityPanels) ...[
          if (!_compactEmbed || _showQualityPanels)
            const SizedBox(height: StudioLayoutSpacing.section),
          _ProductionPanel(
            dense: _compactEmbed,
            videoRatio: videoRatio,
            assetsOverviewPanelUi: assetsOverviewPanelUi,
            assemblyPanelUi: assemblyPanelUi,
            assemblyInputPanelUi: assemblyInputPanelUi,
            exportCheckPanelUi: exportCheckPanelUi,
            latestExportUi: latestExportUi,
            onStartExport: onStartExport,
            onStartPreAssembly: onStartPreAssembly,
            onOpenExportHistory: onOpenExportHistory,
            onDownloadLatestExport: onDownloadLatestExport,
            onCancelLatestExportTask: onCancelLatestExportTask,
            onRetryLatestExportTask: onRetryLatestExportTask,
            exportActionBusy: exportActionBusy,
            preAssemblyActionBusy: preAssemblyActionBusy,
            localAssemblyBlockedHint: localAssemblyBlockedHint,
            onFixAssemblyStoryboard: onFixAssemblyStoryboard,
            onFixAssemblyProduction: onFixAssemblyProduction,
            onFixAssemblyClipDesk: onFixAssemblyClipDesk,
            onOpenAssemblyTaskCenter: onOpenAssemblyTaskCenter,
            onCancelAssemblyJob: onCancelAssemblyJob,
            onRetryAssemblyJob: onRetryAssemblyJob,
            onCreateDraftFromAssemblyJob: onCreateDraftFromAssemblyJob,
            preAssemblyBlockedTooltip: preAssemblyBlockedTooltip,
            onOpenProductionForAssemblyExport:
                onOpenProductionForAssemblyExport,
            onOpenDesktopDownloads: onOpenDesktopDownloads,
            onOpenAssemblyClipDeskOps: onOpenAssemblyClipDeskOps,
            onOpenAssemblyDefaultsEditor: onOpenAssemblyDefaultsEditor,
            onRefreshExportCheck: onRefreshExportCheck,
            assemblyVersionManagerPanel: assemblyVersionManagerPanel,
            assemblyInputPanelKey: assemblyInputPanelKey,
          ),
        ],
        if (_showPublishPanels) ...[
          KeyedSubtree(
            key: publishSectionKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PublishDraftsPanel(
                  publishPanelUi: publishPanelUi,
                  showDraftList: !splitPublishDraftPanels,
                  showDraftDetail: true,
                ),
                _PublishCalendarPanel(publishPanelUi: publishPanelUi),
                _PublishJobsPanel(publishPanelUi: publishPanelUi),
                _PublishAuditPanel(publishPanelUi: publishPanelUi),
              ],
            ),
          ),
        ],
        if (!_compactEmbed && !hideMasterPanels) ...[
          if (projectCharactersPanel != null) ...[
            projectCharactersPanel!,
            const SizedBox(height: StudioLayoutSpacing.section),
          ],
          if (shortVideoTimelinePanel != null) ...[
            shortVideoTimelinePanel!,
            const SizedBox(height: StudioLayoutSpacing.section),
          ],
          ShortVideoCandidateCompareSection(
            accessToken: accessToken,
            candidateCardUi: candidateCardUi,
            candidateComparePanelUi: candidateComparePanelUi,
            videoRatio: videoRatio,
            onOpenProjectsForCandidateAssets: onOpenProjectsForCandidateAssets,
          ),
          const SizedBox(height: StudioLayoutSpacing.section),
          _Panel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tokens = StudioTokens.of(context);
                final sideBySide =
                    constraints.maxWidth >= kStudioTwoColumnMinWidth;

                final modeReadinessBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shortVideoSpaceSectionModeReadiness,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        final inlineHeader =
                            innerConstraints.maxWidth >=
                            kStudioCompactHeaderMinWidth;
                        final intro = Text(
                          readinessIntro,
                          style: studioMutedBodyMedium(context),
                        );
                        final readyChip = _MetricChip(
                          label: l10n.shortVideoSpaceReadinessReadyChip,
                          value: readinessCountLabel,
                        );
                        if (inlineHeader) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: intro),
                              const SizedBox(width: StudioSpacing.sm),
                              readyChip,
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            intro,
                            const SizedBox(height: StudioSpacing.xs),
                            readyChip,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: StudioLayoutSpacing.inlineGap),
                    Text(
                      readinessGapSummary,
                      style: studioMutedBodySmall(context),
                    ),
                    const SizedBox(height: StudioSpacing.sm),
                    _ReadinessFlowStrip(items: readinessItems),
                  ],
                );

                final shotReadinessBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shortVideoSpaceSectionShotReadinessServer,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    _ShortVideoPanelFetchBody(
                      loading: shotReadinessUi.loading,
                      unavailable: shotReadinessUi.unavailable,
                      statusLine: shotReadinessUi.loading
                          ? l10n.shortVideoSpaceShotReadinessLoading
                          : shotReadinessUi.unavailable
                          ? l10n.shortVideoSpaceShotReadinessUnavailableHint
                          : shotReadinessUi.headline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shotReadinessUi.headline != null)
                            Text(
                              shotReadinessUi.headline!,
                              style: studioMutedBodyMedium(context),
                            ),
                          if (shotReadinessUi.reasonLines.isNotEmpty) ...[
                            const SizedBox(height: StudioSpacing.xs),
                            for (final line in shotReadinessUi.reasonLines)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: StudioSpacing.chromeActionGap,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      size: StudioIconSize.xs,
                                      color: theme.colorScheme.tertiary,
                                    ),
                                    const SizedBox(width: StudioSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        line,
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
                    if (!shotReadinessUi.loading &&
                        !shotReadinessUi.unavailable &&
                        shotReadinessUi.shotDetailLines.isNotEmpty) ...[
                        const SizedBox(height: StudioSpacing.xs),
                        Text(
                          l10n.shortVideoSpaceShotReadinessPriorityShots,
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: StudioSpacing.xs),
                        for (final line in shotReadinessUi.shotDetailLines)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: StudioSpacing.chromeActionGap,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  Icons.movie_filter_outlined,
                                  size: StudioIconSize.xs,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: StudioSpacing.xs),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                    if (!shotReadinessUi.loading &&
                        !shotReadinessUi.unavailable &&
                        onOpenProductionForShotReadiness != null) ...[
                      const SizedBox(height: StudioLayoutSpacing.inlineGap),
                      OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onOpenProductionForShotReadiness,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: Text(
                          l10n.shortVideoSpaceOpenProductionBoardButton,
                        ),
                      ),
                    ],
                  ],
                );

                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 3, child: modeReadinessBlock),
                      const SizedBox(width: StudioLayoutSpacing.section + 4),
                      Expanded(flex: 2, child: shotReadinessBlock),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    modeReadinessBlock,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: StudioLayoutSpacing.section - 4,
                      ),
                      child: Divider(
                        height: 1,
                        color: tokens.borderSubtle,
                      ),
                    ),
                    shotReadinessBlock,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: StudioLayoutSpacing.section),
          _Panel(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tokens = StudioTokens.of(context);
                final sideBySide =
                    constraints.maxWidth >= kStudioTwoColumnMinWidth;
                final nextStepBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.shortVideoSpaceSectionSuggestedNext,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(nextStepTitle, style: theme.textTheme.titleMedium),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(nextStepDetail, style: studioMutedBodyMedium(context)),
                    const SizedBox(height: StudioSpacing.sm),
                    FilledButton.icon(
                      style: studioFormIconLabeledButtonStyle(context),
                      onPressed: onNextStep,
                      icon: const Icon(Icons.arrow_forward_outlined),
                      label: Text(nextStepButtonLabel),
                    ),
                  ],
                );
                final stageFlow = _StageFlowStrip(cards: stageCards);
                if (sideBySide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(flex: 4, child: nextStepBlock),
                      const SizedBox(width: StudioLayoutSpacing.section + 4),
                      Expanded(flex: 8, child: stageFlow),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    nextStepBlock,
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: StudioLayoutSpacing.section - 4,
                      ),
                      child: Divider(
                        height: 1,
                        color: tokens.borderSubtle,
                      ),
                    ),
                    stageFlow,
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
