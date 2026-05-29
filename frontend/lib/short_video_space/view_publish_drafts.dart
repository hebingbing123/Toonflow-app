part of 'view.dart';

class ShortVideoPublishDraftsPanel extends StatelessWidget {
  const ShortVideoPublishDraftsPanel({
    super.key,
    required this.publishPanelUi,
    this.showDraftList = true,
    this.showDraftDetail = true,
  });

  final ShortVideoPublishPanelUi publishPanelUi;
  final bool showDraftList;
  final bool showDraftDetail;

  @override
  Widget build(BuildContext context) {
    return _PublishDraftsPanel(
      publishPanelUi: publishPanelUi,
      showDraftList: showDraftList,
      showDraftDetail: showDraftDetail,
    );
  }
}

/// Draft list and management widget
class _PublishDraftsPanel extends StatelessWidget {
  const _PublishDraftsPanel({
    required this.publishPanelUi,
    this.showDraftList = true,
    this.showDraftDetail = true,
  });

  final ShortVideoPublishPanelUi publishPanelUi;
  final bool showDraftList;
  final bool showDraftDetail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);

    if (!publishPanelUi.visible) {
      return const SizedBox.shrink();
    }

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.shortVideoPublishPanelTitle,
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              if (publishPanelUi.onResetConfirmationDontShowAgain != null)
                TextButton(
                  onPressed: publishPanelUi.publishBusy
                      ? null
                      : () => publishPanelUi.onResetConfirmationDontShowAgain!
                            .call(context),
                  child: Text(
                    l10n.shortVideoPublishPanelResetDontShowAgain,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
          if (publishPanelUi.exportGateHint.trim().isNotEmpty) ...[
            Text(
              publishPanelUi.exportGateHint,
              style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
            ),
            const SizedBox(height: StudioSpacing.xs),
          ],
          if (publishPanelUi.unavailable)
            StudioApiErrorCallout(
              error: publishPanelUi.headline,
              onRetry: publishPanelUi.onRefreshPublish,
              emphasis: StudioApiErrorCalloutEmphasis.subtle,
            )
          else
            StudioAsyncDataView(
              loading: publishPanelUi.loading,
              scrollableLoading: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
            ),
            if (publishPanelUi.matrixDomesticLines.isNotEmpty &&
                showDraftDetail) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelMatrixDomesticLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: StudioSpacing.xs),
              for (final line in publishPanelUi.matrixDomesticLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
            ],
            if (publishPanelUi.matrixOverseasLines.isNotEmpty &&
                showDraftDetail) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelMatrixOverseasLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: StudioSpacing.xs),
              for (final line in publishPanelUi.matrixOverseasLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
            ],
            if (publishPanelUi.prepareLines.isNotEmpty && showDraftDetail) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelPrepareChecks,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: StudioSpacing.xs),
              for (final line in publishPanelUi.prepareLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
            ],
            if (publishPanelUi.draftLines.isNotEmpty && showDraftList) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Row(
                children: [
                  Text(
                    l10n.shortVideoPublishPanelDraftListHeading,
                    style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
                  ),
                  const Spacer(),
                  // P8: Multi-select toggle
                  if (publishPanelUi.onToggleMultiSelectMode != null)
                    TextButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onToggleMultiSelectMode,
                      icon: Icon(
                        publishPanelUi.multiSelectMode
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: StudioIconSize.sm,
                      ),
                      label: Text(
                        publishPanelUi.multiSelectMode
                            ? l10n.shortVideoPublishPanelMultiSelectExit
                            : l10n.shortVideoPublishPanelMultiSelectMode,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: StudioSpacing.xs),
              // P8: Multi-select toolbar
              if (publishPanelUi.multiSelectMode) ...[
                Container(
                  padding: const EdgeInsets.all(StudioSpacing.xs),
                  decoration: BoxDecoration(
                    color: StudioTokens.of(context).primarySoft.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            l10n.shortVideoPublishPanelSelectedDraftCount(
                              publishPanelUi.selectedDraftIds.length,
                            ),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onSelectAllDrafts,
                            child: Text(l10n.shortVideoPublishPanelSelectAll),
                          ),
                          TextButton(
                            onPressed: publishPanelUi.publishBusy
                                ? null
                                : publishPanelUi.onClearDraftSelection,
                            child: Text(
                              l10n.shortVideoPublishPanelClearSelection,
                            ),
                          ),
                        ],
                      ),
                      if (publishPanelUi.selectedDraftIds.isNotEmpty) ...[
                        const SizedBox(height: StudioSpacing.xs),
                        StudioDenseActionRow(
                          spacing: StudioSpacing.xs,
                          children: [
                            if (publishPanelUi.onBatchScheduleDrafts != null)
                              StudioDebouncedAction(
                                enabled: !publishPanelUi.publishBusy,
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : () async => publishPanelUi
                                          .onBatchScheduleDrafts!
                                          .call(context),
                                builder: (context, onPressed) =>
                                    FilledButton.tonalIcon(
                                  style: studioFormIconLabeledButtonStyle(
                                    context,
                                  ),
                                  onPressed: onPressed,
                                  icon: const Icon(
                                    Icons.schedule,
                                    size: StudioIconSize.sm,
                                  ),
                                  label: Text(
                                    l10n.shortVideoPublishPanelBatchSchedule,
                                  ),
                                ),
                              ),
                            if (publishPanelUi.onBatchPublishDrafts != null)
                              StudioDebouncedAction(
                                enabled: !publishPanelUi.publishBusy,
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : () async =>
                                        publishPanelUi.onBatchPublishDrafts!(),
                                builder: (context, onPressed) =>
                                    FilledButton.icon(
                                  style: studioFormIconLabeledButtonStyle(
                                    context,
                                  ),
                                  onPressed: onPressed,
                                  icon: const Icon(
                                    Icons.publish,
                                    size: StudioIconSize.sm,
                                  ),
                                  label: Text(
                                    l10n.shortVideoPublishPanelBatchPublish,
                                  ),
                                ),
                              ),
                            if (publishPanelUi.onBatchArchiveDrafts != null)
                              StudioDebouncedAction(
                                enabled: !publishPanelUi.publishBusy,
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : () async =>
                                        publishPanelUi.onBatchArchiveDrafts!(),
                                builder: (context, onPressed) =>
                                    OutlinedButton.icon(
                                  style: studioFormOutlinedIconLabeledButtonStyle(
                                    context,
                                  ),
                                  onPressed: onPressed,
                                  icon: const Icon(
                                    Icons.archive,
                                    size: StudioIconSize.sm,
                                  ),
                                  label: Text(
                                    l10n.shortVideoPublishPanelBatchArchive,
                                  ),
                                ),
                              ),
                            if (publishPanelUi.onCompareDrafts != null)
                              StudioDebouncedAction(
                                enabled: !publishPanelUi.publishBusy,
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : () async => publishPanelUi.onCompareDrafts!(),
                                builder: (context, onPressed) => OutlinedButton.icon(
                                  style: studioFormOutlinedIconLabeledButtonStyle(context),
                                  onPressed: onPressed,
                                  icon: const Icon(Icons.compare, size: StudioIconSize.sm),
                                  label: Text(
                                    l10n.shortVideoPublishPanelCompareDrafts,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                      // P8: Batch validation summary
                      if (publishPanelUi.batchValidation != null) ...[
                        const SizedBox(height: StudioSpacing.xs),
                        Container(
                          padding: const EdgeInsets.all(StudioSpacing.xs),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.shortVideoPublishPanelBatchValidationTitle,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: StudioSpacing.xs),
                              Text(
                                l10n.shortVideoPublishPanelBatchValidationSummary(
                                  publishPanelUi.batchValidation!.readyCount,
                                  publishPanelUi.batchValidation!.blockedCount,
                                ),
                                style: theme.textTheme.bodySmall,
                              ),
                              if (publishPanelUi
                                  .batchValidation!
                                  .blockedDrafts
                                  .isNotEmpty) ...[
                                const SizedBox(height: StudioSpacing.xs),
                                ...publishPanelUi.batchValidation!.blockedDrafts
                                    .take(3)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map(
                                      (entry) {
                                        final d = entry.value;
                                        return studioStaggeredItem(
                                          entry.key,
                                          entranceKey: publishPanelUi
                                              .batchValidation!
                                              .blockedDrafts
                                              .length,
                                          child: Padding(
                                        padding: const EdgeInsets.only(top: StudioSpacing.radiusHairline),
                                        child: Text(
                                          l10n.shortVideoPublishPanelBlockedDraftLine(
                                            d.title.isEmpty
                                                ? d.draftId.substring(0, 8)
                                                : d.title,
                                            d.blockingReasons
                                                .map((r) => r.message)
                                                .join(
                                                  l10n.shortVideoPublishPanelBlockingReasonsJoiner,
                                                ),
                                          ),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.error,
                                              ),
                                        ),
                                      ),
                                  );
                                },
                              ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
              ],
              // P8: Draft list with checkboxes
              for (
                var i = 0;
                i < publishPanelUi.publishDraftOptions.length;
                i++
              )
                Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.chromeActionGap),
                  child: publishPanelUi.multiSelectMode
                      ? StudioCheckboxListRow(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: publishPanelUi.selectedDraftIds.contains(
                            publishPanelUi.publishDraftOptions[i].id,
                          ),
                          onChanged: publishPanelUi.publishBusy
                              ? null
                              : (checked) {
                                  publishPanelUi.onToggleDraftSelection?.call(
                                    publishPanelUi.publishDraftOptions[i].id,
                                  );
                                },
                          title: Text(
                            publishPanelUi.draftLines[i],
                            style: theme.textTheme.bodySmall,
                          ),
                        )
                      : Text(
                          publishPanelUi.draftLines[i],
                          style: theme.textTheme.bodySmall,
                        ),
                ),
            ],
            if (publishPanelUi.publishDraftOptions.length > 1 &&
                publishPanelUi.onSelectPublishDraft != null &&
                showDraftDetail) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelCurrentDraftLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: StudioSpacing.xs),
              StudioDropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'publish_op_draft_${publishPanelUi.selectedPublishDraftId ?? "__none__"}',
                ),
                initialValue: publishPanelUi.selectedPublishDraftId,
                isExpanded: true,
                hint:
                    publishPanelUi.selectedPublishDraftId == null ||
                        publishPanelUi.selectedPublishDraftId!.trim().isEmpty
                    ? Text(l10n.shortVideoPublishPanelSelectDraftHint)
                    : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: publishPanelUi.publishDraftOptions
                    .map((d) {
                      final title = d.title.trim().isEmpty
                          ? l10n.shortVideoPublishPanelUntitledDraft
                          : d.title.trim();
                      final statusLabel = shortVideoPublishDraftStatusLabel(
                        l10n,
                        d.draftStatus,
                      );
                      return DropdownMenuItem<String>(
                        value: d.id,
                        child: Text(
                          l10n.shortVideoPublishDraftDropdownLabel(
                            title,
                            statusLabel,
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
                onChanged: publishPanelUi.publishBusy
                    ? null
                    : (v) {
                        if (v == null || v.trim().isEmpty) {
                          return;
                        }
                        publishPanelUi.onSelectPublishDraft?.call(v);
                      },
              ),
            ],
            if (!publishPanelUi.loading &&
                !publishPanelUi.unavailable &&
                publishPanelUi.publishPrimaryDraftId.isNotEmpty &&
                (publishPanelUi.publishDomesticTargetIds.isNotEmpty ||
                    publishPanelUi.publishOverseasTargetIds.isNotEmpty) &&
                showDraftDetail)
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide =
                      showDraftList &&
                      constraints.maxWidth >= kStudioTwoColumnMinWidth;
                  final editor = PublishPlatformCopyEditor(
                    key: ValueKey(
                      '${publishPanelUi.publishPrimaryDraftId}_${publishPanelUi.publishCopyEditorRevision}',
                    ),
                    draftId: publishPanelUi.publishPrimaryDraftId,
                    domesticPlatformIds:
                        publishPanelUi.publishDomesticTargetIds,
                    overseasPlatformIds:
                        publishPanelUi.publishOverseasTargetIds,
                    platformLabels: publishPanelUi.publishPlatformLabels,
                    platformCopy: publishPanelUi.publishPlatformCopySnapshot,
                    busy: publishPanelUi.publishBusy,
                    onCommit: publishPanelUi.onCommitPublishPlatformCopy,
                  );
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: StudioSpacing.sm),
                        editor,
                      ],
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: StudioSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.shortVideoPublishPanelCurrentDraftLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: studioPanelMutedColor(context),
                                ),
                              ),
                              const SizedBox(height: StudioSpacing.xs),
                              Text(
                                publishPanelUi.draftLines.isNotEmpty
                                    ? publishPanelUi.draftLines.first
                                    : publishPanelUi.publishPrimaryDraftId,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: StudioSpacing.sm),
                        Expanded(flex: 3, child: editor),
                      ],
                    ),
                  );
                },
              ),
            if (publishPanelUi.awaitingSemiAutoJobId != null &&
                publishPanelUi.onConfirmSemiAuto != null &&
                showDraftDetail) ...[
              const SizedBox(height: StudioSpacing.sm),
              StudioDebouncedAction(
                enabled: !publishPanelUi.publishBusy,
                onPressed: shortVideoDebouncedVoid(
                  publishPanelUi.publishBusy,
                  publishPanelUi.onConfirmSemiAuto,
                ),
                builder: (context, onPressed) => FilledButton.tonalIcon(
                  onPressed: onPressed,
                  icon: publishPanelUi.publishBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(l10n.shortVideoPublishPanelConfirmSemiAuto),
                ),
              ),
            ],
            if (publishPanelUi.publishAutomationModesByPlatform.isNotEmpty &&
                publishPanelUi.onChangePublishAutomationMode != null &&
                showDraftDetail) ...[
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.shortVideoPublishPanelAutomationByPlatform,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: StudioSpacing.xs),
              for (final entry
                  in publishPanelUi.publishAutomationModesByPlatform.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
                  child: Row(
                    children: [
                      Flexible(
                        flex: 2,
                        child: Text(
                          publishPanelUi.publishPlatformLabels[entry.key] ??
                              entry.key,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: StudioSpacing.xs),
                      Expanded(
                        child: StudioDropdownButtonFormField<String>(
                          initialValue: entry.value,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'full_auto',
                              child: Text(
                                shortVideoPublishAutomationModeLabel(
                                  l10n,
                                  'full_auto',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'semi_auto',
                              child: Text(
                                shortVideoPublishAutomationModeLabel(
                                  l10n,
                                  'semi_auto',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'manual_assisted',
                              child: Text(
                                shortVideoPublishAutomationModeLabel(
                                  l10n,
                                  'manual_assisted',
                                ),
                              ),
                            ),
                          ],
                          onChanged: publishPanelUi.publishBusy
                              ? null
                              : (next) {
                                  if (next == null || next == entry.value) {
                                    return;
                                  }
                                  publishPanelUi.onChangePublishAutomationMode
                                      ?.call(entry.key, next);
                                },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if ((publishPanelUi.onBootstrapPublishDraft != null ||
                publishPanelUi.onEnqueuePublishJob != null ||
                publishPanelUi.onEnqueueAllDrafts != null ||
                publishPanelUi.onRetryFailedPublishJobs != null ||
                publishPanelUi.onRefreshPublish != null ||
                publishPanelUi.onSuggestPublishCopy != null ||
                publishPanelUi.onClearPublishSchedule != null ||
                publishPanelUi.onScheduleFirstDraft != null ||
                publishPanelUi.onScheduleAllDraftsSameTime != null ||
                publishPanelUi.onOpenPublishTroubleshooting != null) &&
                showDraftDetail) ...[
              const SizedBox(height: StudioSpacing.sm),
              StudioDenseActionRow(
                spacing: StudioSpacing.xs,
                children: [
                  if (publishPanelUi.onRefreshPublish != null)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: shortVideoDebouncedVoid(
                        publishPanelUi.publishBusy,
                        publishPanelUi.onRefreshPublish,
                      ),
                      builder: (context, onPressed) => OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.shortVideoPublishPanelRefreshPublish),
                      ),
                    ),
                  if (publishPanelUi.onBootstrapPublishDraft != null)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: shortVideoDebouncedVoid(
                        publishPanelUi.publishBusy,
                        publishPanelUi.onBootstrapPublishDraft,
                      ),
                      builder: (context, onPressed) => FilledButton.tonalIcon(
                        style: studioFormIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: publishPanelUi.publishBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.note_add_outlined),
                        label: Text(l10n.shortVideoPublishPanelBootstrapDraft),
                      ),
                    ),
                  if (publishPanelUi.onEnqueuePublishJob != null)
                    StudioDebouncedAction(
                      enabled:
                          !publishPanelUi.publishBusy &&
                          publishPanelUi.exportReady,
                      onPressed:
                          (publishPanelUi.publishBusy ||
                              !publishPanelUi.exportReady)
                          ? null
                          : shortVideoDebouncedVoid(
                              false,
                              publishPanelUi.onEnqueuePublishJob,
                            ),
                      builder: (context, onPressed) => FilledButton.icon(
                        style: studioFormIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: publishPanelUi.publishBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          publishPanelUi.exportReady
                              ? l10n.shortVideoPublishPanelEnqueueJob
                              : l10n.shortVideoPublishPanelEnqueueJobBlocked,
                        ),
                      ),
                    ),
                  if (publishPanelUi.onEnqueueAllDrafts != null)
                    StudioDebouncedAction(
                      enabled:
                          !publishPanelUi.publishBusy &&
                          publishPanelUi.exportReady,
                      onPressed:
                          (publishPanelUi.publishBusy ||
                              !publishPanelUi.exportReady)
                          ? null
                          : shortVideoDebouncedVoid(
                              false,
                              publishPanelUi.onEnqueueAllDrafts,
                            ),
                      builder: (context, onPressed) => FilledButton.tonal(
                        style: studioFormTonalButtonStyle(context),
                        onPressed: onPressed,
                        child: Text(
                          publishPanelUi.exportReady
                              ? l10n.shortVideoPublishPanelEnqueueAllDrafts
                              : l10n
                                    .shortVideoPublishPanelEnqueueAllDraftsBlocked,
                        ),
                      ),
                    ),
                  if (publishPanelUi.onRetryFailedPublishJobs != null)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: shortVideoDebouncedVoid(
                        publishPanelUi.publishBusy,
                        publishPanelUi.onRetryFailedPublishJobs,
                      ),
                      builder: (context, onPressed) => FilledButton.tonal(
                        style: studioFormTonalButtonStyle(context),
                        onPressed: onPressed,
                        child: Text(l10n.shortVideoPublishPanelRetryFailedJobs),
                      ),
                    ),
                  if (publishPanelUi.onSuggestPublishCopy != null)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: shortVideoDebouncedVoid(
                        publishPanelUi.publishBusy,
                        publishPanelUi.onSuggestPublishCopy,
                      ),
                      builder: (context, onPressed) => OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(l10n.shortVideoPublishPanelSuggestCopy),
                      ),
                    ),
                  if (publishPanelUi.onClearPublishSchedule != null)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: shortVideoDebouncedVoid(
                        publishPanelUi.publishBusy,
                        publishPanelUi.onClearPublishSchedule,
                      ),
                      builder: (context, onPressed) => OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: const Icon(Icons.schedule_outlined),
                        label: Text(l10n.shortVideoPublishPanelClearSchedule),
                      ),
                    ),
                  if (publishPanelUi.onScheduleFirstDraft != null &&
                      publishPanelUi.publishPrimaryDraftId.isNotEmpty)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : () async => publishPanelUi.onScheduleFirstDraft!(
                              context,
                            ),
                      builder: (context, onPressed) => OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: const Icon(Icons.event_available_outlined),
                        label: Text(
                          l10n.shortVideoPublishPanelScheduleCurrentDraft,
                        ),
                      ),
                    ),
                  if (publishPanelUi.onScheduleAllDraftsSameTime != null &&
                      publishPanelUi.draftLines.length > 1)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : () async => publishPanelUi
                                .onScheduleAllDraftsSameTime!
                                .call(context),
                      builder: (context, onPressed) => OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(l10n.shortVideoPublishPanelScheduleAllDrafts),
                      ),
                    ),
                  if (publishPanelUi.onOpenPublishTroubleshooting != null)
                    StudioDebouncedAction(
                      enabled: !publishPanelUi.publishBusy,
                      onPressed: shortVideoDebouncedVoid(
                        publishPanelUi.publishBusy,
                        publishPanelUi.onOpenPublishTroubleshooting,
                      ),
                      builder: (context, onPressed) => OutlinedButton.icon(
                        style: studioFormOutlinedIconLabeledButtonStyle(context),
                        onPressed: onPressed,
                        icon: const Icon(Icons.bug_report_outlined),
                        label: Text(
                          l10n.shortVideoPublishPanelOpenTroubleshooting,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (publishPanelUi.publishBatchResultLines.isNotEmpty &&
                showDraftDetail) ...[
              const SizedBox(height: StudioSpacing.sm),
              Text(
                l10n.shortVideoPublishPanelBatchResultSummary,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: StudioSpacing.xs),
              ...publishPanelUi.publishBatchResultLines
                  .take(8)
                  .map(
                    (line) => Text(
                      l10n.shortVideoPublishBatchResultBulletLine(line),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
            ],
                ],
              ),
            ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            publishPanelUi.detail,
            style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
          ),
        ],
      ),
    );
  }
}
