part of 'view.dart';

extension _ProductionAssemblyExportLayoutExport on _ProductionAssemblyExportLayout {
  List<Widget> buildExportCheckWidgets(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final muted = studioMutedTextColor(context);
    final l10n = resolveAppLocalizationsForErrors(context);
    final latestExportCardFill = latestExportUi.isWarning
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.72)
        : StudioTokens.of(context).primarySoft.withValues(alpha: 0.4);
    final latestExportCardBorder = latestExportUi.isWarning
        ? theme.colorScheme.error.withValues(alpha: 0.22)
        : theme.colorScheme.primary.withValues(alpha: 0.18);
    final latestExportCardTextColor = latestExportUi.isWarning
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;
    final sectionSpacing =
        dense ? StudioSpacing.radiusComfort : StudioLayoutSpacing.cardInner;

    if (!exportCheckPanelUi.visible) {
      return const <Widget>[];
    }
    return <Widget>[
      SizedBox(height: sectionSpacing),
      _Panel(
        dense: dense,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shortVideoSpaceExportPreCheck,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            _ShortVideoPanelFetchBody(
              loading: exportCheckPanelUi.loading,
              unavailable: exportCheckPanelUi.unavailable,
              statusLine: exportCheckPanelUi.headline,
              onRetry: onRefreshExportCheck,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exportCheckPanelUi.headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  if (exportCheckPanelUi.metrics.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    StudioResponsiveChipGrid(
                      entranceKey: exportCheckPanelUi.metrics.length,
                      children: exportCheckPanelUi.metrics
                          .map(
                            (m) => _MetricChip(
                              label: m.label,
                              value: m.value,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                  if (exportCheckPanelUi.qualityGateLine.trim().isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    Text(
                      exportCheckPanelUi.qualityGateLine,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (exportCheckPanelUi
                  .qualityGateBlockingLines
                  .isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.shortVideoSpaceQualityGateBlockingReasons,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: StudioSpacing.chromeActionGap),
                for (final line
                    in exportCheckPanelUi.qualityGateBlockingLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
              if (exportCheckPanelUi.publishPlatformGapEntries.isNotEmpty ||
                  exportCheckPanelUi.publishBlockingLines.isNotEmpty ||
                  exportCheckPanelUi.publishWarningLines.isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.shortVideoSpacePublishExportCheckPublishSectionTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                for (final gap
                    in exportCheckPanelUi.publishPlatformGapEntries)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                    child: Text(
                      '${gap.title}: ${gap.facetSummary}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: gap.hasBlocking
                            ? tokens.danger
                            : tokens.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                for (final line in exportCheckPanelUi.publishBlockingLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                for (final line in exportCheckPanelUi.publishWarningLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.warning,
                      ),
                    ),
                  ),
              ],
              if (exportCheckPanelUi.storyboardGapEntries.isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.shortVideoSpacePublishExportCheckStoryboardGapsTitle,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                for (final gap in exportCheckPanelUi.storyboardGapEntries)
                  Theme(
                    data: theme.copyWith(
                      dividerColor: StudioPrimitives.transparent,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        left: StudioSpacing.xs,
                        bottom: StudioSpacing.xs,
                      ),
                      title: Text(
                        gap.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: gap.hasBlocking
                              ? tokens.danger
                              : tokens.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        gap.facetSummary,
                        style: theme.textTheme.bodySmall,
                      ),
                      children: [
                        for (final label in gap.codeLabels)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '· $label',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ] else if (exportCheckPanelUi.blockingLines.isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.shortVideoSpaceBlockingItems,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
                const SizedBox(height: StudioSpacing.chromeActionGap),
                for (final line in exportCheckPanelUi.blockingLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
              if (exportCheckPanelUi.warningLines.isNotEmpty) ...[
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  l10n.shortVideoSpaceWarningItems,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
                const SizedBox(height: StudioSpacing.chromeActionGap),
                for (final line in exportCheckPanelUi.warningLines)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                    child: Text(
                      line,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.warning,
                      ),
                    ),
                  ),
              ],
                ],
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              exportCheckPanelUi.detail,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            if (latestExportUi.visible) ...[
              const SizedBox(height: StudioSpacing.radiusComfort),
              Container(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                decoration: BoxDecoration(
                  color: latestExportCardFill,
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                  border: Border.all(color: latestExportCardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          latestExportUi.isWarning
                              ? Icons.warning_amber_rounded
                              : Icons.task_alt,
                          size: StudioIconSize.sm,
                          color: latestExportCardTextColor,
                        ),
                        const SizedBox(width: StudioSpacing.xs),
                        Expanded(
                          child: Text(
                            latestExportUi.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: latestExportCardTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((latestExportUi.statusLine ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: StudioSpacing.chromeActionGap),
                      Text(
                        latestExportUi.statusLine!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: latestExportCardTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if ((latestExportUi.activeTaskTitle ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: StudioSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(StudioLayoutSpacing.inlineGap),
                        decoration: BoxDecoration(
                          color: latestExportCardTextColor.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(
                            StudioSpacing.radiusDense,
                          ),
                          border: Border.all(
                            color: latestExportCardTextColor.withValues(
                              alpha: 0.14,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StudioRepaintBoundary(
                                  child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: latestExportUi.activeTaskRunning
                                      ? CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: latestExportCardTextColor,
                                        )
                                      : Icon(
                                          latestExportUi.activeTaskFailed
                                              ? Icons.error_outline
                                              : Icons.schedule,
                                          size: StudioIconSize.xxs,
                                          color: latestExportCardTextColor,
                                        ),
                                ),
                                ),
                                const SizedBox(width: StudioSpacing.xs),
                                Expanded(
                                  child: Text(
                                    latestExportUi.activeTaskTitle!,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                          color: latestExportCardTextColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            if ((latestExportUi.activeTaskDetail ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: StudioSpacing.xs),
                              Text(
                                latestExportUi.activeTaskDetail!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: latestExportCardTextColor
                                      .withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                            if ((latestExportUi.activeTaskError ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: StudioSpacing.chromeActionGap),
                              Text(
                                latestExportUi.activeTaskError!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: latestExportCardTextColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (latestExportUi.detail.isNotEmpty) ...[
                      const SizedBox(height: StudioSpacing.chromeActionGap),
                      Text(
                        latestExportUi.detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: latestExportCardTextColor,
                        ),
                      ),
                    ],
                    if (latestExportUi.meta.isNotEmpty) ...[
                      const SizedBox(height: StudioSpacing.xs),
                      for (final line in latestExportUi.meta)
                        Padding(
                          padding: const EdgeInsets.only(
                      bottom: StudioSpacing.chromeActionGap,
                    ),
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: latestExportCardTextColor.withValues(
                                alpha: 0.88,
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: StudioSpacing.radiusComfort),
                    StudioDenseActionRow(
                      children: [
                        if (latestExportUi.isWarning &&
                            onStartExport != null)
                          StudioDebouncedAction(
                            enabled: !exportActionBusy,
                            onPressed: exportActionBusy
                                ? null
                                : () async => onStartExport!(),
                            builder: (context, onPressed) =>
                                FilledButton.icon(
                              style: studioFormIconLabeledButtonStyle(context),
                              onPressed: onPressed,
                              icon: exportActionBusy
                                  ? const StudioRepaintBoundary(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.refresh),
                              label: Text(
                                exportActionBusy
                                    ? l10n.shortVideoSpaceExporting
                                    : l10n.shortVideoSpaceProductionLatestExportRerun,
                              ),
                            ),
                          ),
                        if (onDownloadLatestExport != null)
                          StudioDebouncedAction(
                            onPressed: () async => onDownloadLatestExport!(),
                            builder: (context, onPressed) => FilledButton.tonalIcon(
                              style: studioFormIconLabeledButtonStyle(context),
                              onPressed: onPressed,
                              icon: const Icon(Icons.download_outlined),
                              label: Text(
                                l10n.shortVideoSpaceDialogExportHistoryDownload,
                              ),
                            ),
                          ),
                        if ((latestExportUi.previewOutputUrl ?? '')
                            .trim()
                            .isNotEmpty)
                          OutlinedButton.icon(
                            style: studioFormOutlinedIconLabeledButtonStyle(
                              context,
                            ),
                            onPressed: () {
                              unawaited(
                                PreviewPlayerDialog.show(
                                  context,
                                  videoUrl:
                                      latestExportUi.previewOutputUrl!,
                                  videoRatio: videoRatio,
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.play_arrow,
                              size: StudioIconSize.sm,
                            ),
                            label: Text(
                              l10n.shortVideoTimelinePlayPreview,
                            ),
                          ),
                        if (onCancelLatestExportTask != null)
                          StudioDebouncedAction(
                            onPressed: shortVideoDebouncedVoid(
                              false,
                              onCancelLatestExportTask,
                            ),
                            builder: (context, onPressed) => OutlinedButton.icon(
                              style: studioFormOutlinedIconLabeledButtonStyle(context),
                              onPressed: onPressed,
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: Text(
                                l10n.shortVideoSpaceProductionAssemblyCancel,
                              ),
                            ),
                          ),
                        if (onRetryLatestExportTask != null)
                          StudioDebouncedAction(
                            onPressed: shortVideoDebouncedVoid(
                              false,
                              onRetryLatestExportTask,
                            ),
                            builder: (context, onPressed) =>
                                (latestExportUi.recommendedAction ==
                                        ShortVideoLatestExportAction.retry)
                                    ? FilledButton.icon(
                                        style: studioFormIconLabeledButtonStyle(
                                          context,
                                        ),
                                        onPressed: onPressed,
                                        icon: const Icon(Icons.refresh),
                                        label: Text(
                                          l10n.shortVideoSpaceProductionAssemblyRetryTask,
                                        ),
                                      )
                                    : FilledButton.tonalIcon(
                                        style: studioFormIconLabeledButtonStyle(
                                          context,
                                        ),
                                        onPressed: onPressed,
                                        icon: const Icon(Icons.refresh),
                                        label: Text(
                                          l10n.shortVideoSpaceProductionAssemblyRetryTask,
                                        ),
                                      ),
                          ),
                        if (latestExportUi.activeTaskFailed &&
                            onOpenProductionForAssemblyExport != null)
                          StudioDebouncedAction(
                            onPressed: shortVideoDebouncedVoid(
                              false,
                              onOpenProductionForAssemblyExport,
                            ),
                            builder: (context, onPressed) =>
                                (latestExportUi.recommendedAction ==
                                        ShortVideoLatestExportAction
                                            .openProductionWorkspace)
                                    ? FilledButton.icon(
                                        style: studioFormIconLabeledButtonStyle(
                                          context,
                                        ),
                                        onPressed: onPressed,
                                        icon: const Icon(
                                          Icons.movie_creation_outlined,
                                        ),
                                        label: Text(
                                          l10n.shortVideoSpaceOpenProductionWorkspace,
                                        ),
                                      )
                                    : OutlinedButton.icon(
                                        style:
                                            studioFormOutlinedIconLabeledButtonStyle(
                                          context,
                                        ),
                                        onPressed: onPressed,
                                        icon: const Icon(
                                          Icons.movie_creation_outlined,
                                        ),
                                        label: Text(
                                          l10n.shortVideoSpaceOpenProductionWorkspace,
                                        ),
                                      ),
                          ),
                        if (onOpenExportHistory != null)
                          StudioDebouncedAction(
                            onPressed: shortVideoDebouncedVoid(
                              false,
                              onOpenExportHistory,
                            ),
                            builder: (context, onPressed) => OutlinedButton.icon(
                              style: studioFormOutlinedIconLabeledButtonStyle(
                                context,
                              ),
                              onPressed: onPressed,
                              icon: const Icon(Icons.history),
                              label: Text(l10n.shortVideoSpaceExportHistory),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (localAssemblyBlockedHint != null &&
                localAssemblyBlockedHint!.trim().isNotEmpty) ...[
              const SizedBox(height: StudioSpacing.radiusComfort),
              Container(
                padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
                decoration: BoxDecoration(
                  color: StudioTokens.of(context).accentSoft,
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localAssemblyBlockedHint!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    if (onOpenDesktopDownloads != null) ...[
                      const SizedBox(height: StudioSpacing.radiusComfort),
                      StudioDebouncedAction(
                        onPressed: shortVideoDebouncedVoid(
                          false,
                          onOpenDesktopDownloads,
                        ),
                        builder: (context, onPressed) => FilledButton.tonalIcon(
                          style: studioFormIconLabeledButtonStyle(context),
                          onPressed: onPressed,
                          icon: const Icon(Icons.download_outlined),
                          label: Text(l10n.shortVideoDownloadDesktopApp),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: StudioSpacing.radiusComfort),
            StudioDenseActionRow(
              children: [
                StudioDebouncedAction(
                  enabled: !exportActionBusy &&
                      exportCheckPanelUi.exportReady &&
                      localAssemblyBlockedHint == null &&
                      onStartExport != null,
                  onPressed: onStartExport == null
                      ? null
                      : () async => onStartExport!(),
                  builder: (context, onPressed) => FilledButton.icon(
                    style: studioFormIconLabeledButtonStyle(context),
                    onPressed: onPressed,
                    icon: exportActionBusy
                        ? const StudioRepaintBoundary(
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: Text(
                      exportActionBusy
                          ? l10n.shortVideoSpaceExporting
                          : l10n.shortVideoSpaceStartExport,
                    ),
                  ),
                ),
                StudioDebouncedAction(
                  enabled: !exportActionBusy &&
                      !preAssemblyActionBusy &&
                      localAssemblyBlockedHint == null &&
                      assemblyInputPanelUi.gate.canPreAssembly &&
                      onStartPreAssembly != null,
                  onPressed: onStartPreAssembly == null
                      ? null
                      : () async => onStartPreAssembly!(),
                  builder: (context, onPressed) => Tooltip(
                    message: preAssemblyBlockedTooltip ?? '',
                    child: OutlinedButton.icon(
                      style: studioFormOutlinedIconLabeledButtonStyle(context),
                      onPressed: onPressed,
                      icon: preAssemblyActionBusy
                          ? const StudioRepaintBoundary(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.playlist_play_outlined),
                      label: Text(
                        preAssemblyActionBusy
                            ? l10n.shortVideoSpacePreAssemblyBusy
                            : l10n.shortVideoSpaceStartPreAssembly,
                      ),
                    ),
                  ),
                ),
                if (onOpenExportHistory != null)
                  StudioDebouncedAction(
                    enabled: !exportActionBusy,
                    onPressed: exportActionBusy
                        ? null
                        : shortVideoDebouncedVoid(false, onOpenExportHistory),
                    builder: (context, onPressed) => OutlinedButton.icon(
                      style: studioFormOutlinedIconLabeledButtonStyle(context),
                      onPressed: onPressed,
                      icon: const Icon(Icons.history),
                      label: Text(l10n.shortVideoSpaceExportHistory),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
];
  }
}
