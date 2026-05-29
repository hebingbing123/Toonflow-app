// Part extensions call `setState` on `_ShortVideoSpaceSectionState`; analyzer treats
// extension `this` as the extension type, not `State` (false positive).
// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

extension _ShortVideoSpaceSectionResponsiveExtras on _ShortVideoSpaceSectionState {
  List<ShotPreviewPlaylistEntry> _timelineShotPreviewPlaylist() {
    return shotPreviewPlaylistFromTimeline(_shortVideoTimeline);
  }

  List<ShotPreviewPlaylistEntry>? _effectivePreviewPlaylist({
    required String? effectivePreviewUrl,
  }) {
    final playlist = _timelineShotPreviewPlaylist();
    if (playlist.isEmpty) {
      return null;
    }
    final muxedTimelinePreview = (_timelinePreviewUrl ?? '').trim().isNotEmpty;
    if (muxedTimelinePreview && effectivePreviewUrl != null) {
      return null;
    }
    return playlist;
  }

  Future<void> _openMobileCreationParamsSheet(BuildContext context) async {
    final l10n = resolveAppLocalizationsForErrors(context);
    final theme = Theme.of(context);
    await showStudioBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          StudioSpacing.sm,
          StudioSpacing.xs,
          StudioSpacing.sm,
          StudioSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.shortVideoMobileCreationParamsTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.shortVideoSpaceSectionCreativeMode,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ShortVideoMode>(
                segments: [
                  ButtonSegment(
                    value: ShortVideoMode.animated,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(l10n.shortVideoSpaceModeTitleAnimated),
                  ),
                  ButtonSegment(
                    value: ShortVideoMode.liveAction,
                    icon: const Icon(Icons.person_outline),
                    label: Text(l10n.shortVideoSpaceModeTitleLive),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  setState(() => _mode = selection.first);
                },
              ),
            ),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.shortVideoSpaceTargetConfiguration,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: StudioSpacing.xs),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment(value: '9:16', label: Text('9:16')),
                ButtonSegment(value: '16:9', label: Text('16:9')),
                ButtonSegment(value: '1:1', label: Text('1:1')),
              ],
              selected: <String>{_videoRatio},
              onSelectionChanged: (selection) {
                setState(() => _videoRatio = selection.first);
              },
            ),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.shortVideoMobileCreationParamsHint,
              style: studioMutedBodySmall(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildShortVideoMobileDock({
    required AppLocalizations l10n,
    required ShortVideoNextStepPlan nextStepPlan,
    required ProjectRow? project,
    required ShortVideoPublishPanelUi publishPanelUi,
    required VoidCallback? onStartExport,
    required bool exportActionBusy,
  }) {
    final paramsButton = OutlinedButton.icon(
      style: studioFormOutlinedIconLabeledButtonStyle(context),
      onPressed: () => unawaited(_openMobileCreationParamsSheet(context)),
      icon: const Icon(Icons.tune, size: StudioIconSize.sm),
      label: Text(l10n.shortVideoMobileCreationParamsOpen),
    );

    switch (widget.embedScope) {
      case ShortVideoSpaceEmbedScope.full:
        return StudioDenseActionRow(
          children: [
            paramsButton,
            FilledButton(
              style: studioFormPrimaryButtonStyle(context),
              onPressed: _nextStepAction(),
              child: Text(nextStepPlan.buttonLabel),
            ),
            OutlinedButton(
              style: studioFormSecondaryButtonStyle(context),
              onPressed: project == null
                  ? null
                  : () {
                      _syncSelectedProjectContext();
                      widget.onOpenProductionWorkspace();
                    },
              child: Text(l10n.studioStepOpenProduction),
            ),
          ],
        );
      case ShortVideoSpaceEmbedScope.assembly:
        return StudioDenseActionRow(
          children: [
            paramsButton,
            if (onStartExport != null)
              StudioDebouncedAction(
                enabled: !exportActionBusy,
                onPressed: exportActionBusy
                    ? null
                    : () async => onStartExport(),
                builder: (context, onPressed) => FilledButton.icon(
                  style: studioFormIconLabeledButtonStyle(context),
                  onPressed: onPressed,
                  icon: exportActionBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_upload_outlined),
                  label: Text(
                    exportActionBusy
                        ? l10n.shortVideoSpaceExporting
                        : l10n.shortVideoSpaceStartExport,
                  ),
                ),
              ),
          ],
        );
      case ShortVideoSpaceEmbedScope.publish:
        return StudioDenseActionRow(
          children: [
            paramsButton,
            if (publishPanelUi.onRefreshPublish != null)
              StudioDebouncedAction(
                enabled: !publishPanelUi.publishBusy,
                onPressed: publishPanelUi.publishBusy
                    ? null
                    : () async => publishPanelUi.onRefreshPublish!(),
                builder: (context, onPressed) => OutlinedButton.icon(
                  style: studioFormOutlinedIconLabeledButtonStyle(context),
                  onPressed: onPressed,
                  icon: const Icon(Icons.refresh, size: StudioIconSize.sm),
                  label: Text(l10n.shortVideoPublishPanelRefreshPublish),
                ),
              ),
            if (publishPanelUi.onBootstrapPublishDraft != null)
              StudioDebouncedAction(
                enabled: !publishPanelUi.publishBusy,
                onPressed: publishPanelUi.publishBusy
                    ? null
                    : () async => publishPanelUi.onBootstrapPublishDraft!(),
                builder: (context, onPressed) => FilledButton.tonalIcon(
                  style: studioFormIconLabeledButtonStyle(context),
                  onPressed: onPressed,
                  icon: const Icon(Icons.note_add_outlined, size: StudioIconSize.sm),
                  label: Text(l10n.shortVideoPublishPanelBootstrapDraft),
                ),
              ),
          ],
        );
      case ShortVideoSpaceEmbedScope.quality:
        return StudioDenseActionRow(
          children: [
            paramsButton,
            OutlinedButton.icon(
              style: studioFormOutlinedIconLabeledButtonStyle(context),
              onPressed: project == null
                  ? null
                  : () {
                      _syncSelectedProjectContext();
                      widget.onOpenQuality();
                    },
              icon: const Icon(Icons.fact_check_outlined, size: StudioIconSize.sm),
              label: Text(l10n.studioDeliverOpenQuality),
            ),
          ],
        );
    }
  }

  Widget _buildQualityMasterPane({
    required AppLocalizations l10n,
    required String qualitySummaryLine,
    required List<ShortVideoMetricData> badCaseMetrics,
  }) {
    final theme = Theme.of(context);
    return StudioCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.shortVideoQualityMasterPaneTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            qualitySummaryLine,
            style: studioMutedBodyMedium(context),
          ),
          if (badCaseMetrics.isNotEmpty) ...[
            const SizedBox(height: StudioSpacing.sm),
            for (final metric in badCaseMetrics)
              Padding(
                padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        metric.label,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      metric.value,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
