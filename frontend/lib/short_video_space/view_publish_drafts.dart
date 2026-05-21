part of 'view.dart';

class ShortVideoPublishDraftsPanel extends StatelessWidget {
  const ShortVideoPublishDraftsPanel({super.key, required this.publishPanelUi});

  final ShortVideoPublishPanelUi publishPanelUi;

  @override
  Widget build(BuildContext context) {
    return _PublishDraftsPanel(publishPanelUi: publishPanelUi);
  }
}

/// Draft list and management widget
class _PublishDraftsPanel extends StatelessWidget {
  const _PublishDraftsPanel({required this.publishPanelUi});

  final ShortVideoPublishPanelUi publishPanelUi;

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
          const SizedBox(height: 8),
          if (publishPanelUi.exportGateHint.trim().isNotEmpty) ...[
            Text(
              publishPanelUi.exportGateHint,
              style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
            ),
            const SizedBox(height: 8),
          ],
          if (publishPanelUi.loading)
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
            )
          else if (publishPanelUi.unavailable)
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
            )
          else ...[
            Text(
              publishPanelUi.headline,
              style: theme.textTheme.bodyMedium?.copyWith(color: studioPanelMutedColor(context)),
            ),
            if (publishPanelUi.matrixDomesticLines.isNotEmpty) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelMatrixDomesticLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: 6),
              for (final line in publishPanelUi.matrixDomesticLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
            ],
            if (publishPanelUi.matrixOverseasLines.isNotEmpty) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelMatrixOverseasLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: 6),
              for (final line in publishPanelUi.matrixOverseasLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
            ],
            if (publishPanelUi.prepareLines.isNotEmpty) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelPrepareChecks,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: 6),
              for (final line in publishPanelUi.prepareLines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(line, style: theme.textTheme.bodySmall),
                ),
            ],
            if (publishPanelUi.draftLines.isNotEmpty) ...[
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
                        size: 18,
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
              const SizedBox(height: 6),
              // P8: Multi-select toolbar
              if (publishPanelUi.multiSelectMode) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: StudioTokens.of(context).primarySoft.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
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
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (publishPanelUi.onBatchScheduleDrafts != null)
                              FilledButton.tonalIcon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : () => publishPanelUi.onBatchScheduleDrafts
                                          ?.call(context),
                                icon: const Icon(Icons.schedule, size: 18),
                                label: Text(
                                  l10n.shortVideoPublishPanelBatchSchedule,
                                ),
                              ),
                            if (publishPanelUi.onBatchPublishDrafts != null)
                              FilledButton.icon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : publishPanelUi.onBatchPublishDrafts,
                                icon: const Icon(Icons.publish, size: 18),
                                label: Text(
                                  l10n.shortVideoPublishPanelBatchPublish,
                                ),
                              ),
                            if (publishPanelUi.onBatchArchiveDrafts != null)
                              OutlinedButton.icon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : publishPanelUi.onBatchArchiveDrafts,
                                icon: const Icon(Icons.archive, size: 18),
                                label: Text(
                                  l10n.shortVideoPublishPanelBatchArchive,
                                ),
                              ),
                            if (publishPanelUi.onCompareDrafts != null)
                              OutlinedButton.icon(
                                onPressed: publishPanelUi.publishBusy
                                    ? null
                                    : publishPanelUi.onCompareDrafts,
                                icon: const Icon(Icons.compare, size: 18),
                                label: Text(
                                  l10n.shortVideoPublishPanelCompareDrafts,
                                ),
                              ),
                          ],
                        ),
                      ],
                      // P8: Batch validation summary
                      if (publishPanelUi.batchValidation != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(6),
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
                              const SizedBox(height: 4),
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
                                const SizedBox(height: 4),
                                ...publishPanelUi.batchValidation!.blockedDrafts
                                    .take(3)
                                    .map(
                                      (d) => Padding(
                                        padding: const EdgeInsets.only(top: 2),
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
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // P8: Draft list with checkboxes
              for (
                var i = 0;
                i < publishPanelUi.publishDraftOptions.length;
                i++
              )
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: publishPanelUi.multiSelectMode
                      ? CheckboxListTile(
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
                publishPanelUi.onSelectPublishDraft != null) ...[
              const SizedBox(height: StudioLayoutSpacing.inlineGap),
              Text(
                l10n.shortVideoPublishPanelCurrentDraftLabel,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: 6),
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
                    publishPanelUi.publishOverseasTargetIds.isNotEmpty)) ...[
              const SizedBox(height: 12),
              PublishPlatformCopyEditor(
                key: ValueKey(
                  '${publishPanelUi.publishPrimaryDraftId}_${publishPanelUi.publishCopyEditorRevision}',
                ),
                draftId: publishPanelUi.publishPrimaryDraftId,
                domesticPlatformIds: publishPanelUi.publishDomesticTargetIds,
                overseasPlatformIds: publishPanelUi.publishOverseasTargetIds,
                platformLabels: publishPanelUi.publishPlatformLabels,
                platformCopy: publishPanelUi.publishPlatformCopySnapshot,
                busy: publishPanelUi.publishBusy,
                onCommit: publishPanelUi.onCommitPublishPlatformCopy,
              ),
            ],
            if (publishPanelUi.awaitingSemiAutoJobId != null &&
                publishPanelUi.onConfirmSemiAuto != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: publishPanelUi.publishBusy
                    ? null
                    : publishPanelUi.onConfirmSemiAuto,
                icon: publishPanelUi.publishBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(l10n.shortVideoPublishPanelConfirmSemiAuto),
              ),
            ],
            if (publishPanelUi.publishAutomationModesByPlatform.isNotEmpty &&
                publishPanelUi.onChangePublishAutomationMode != null) ...[
              const SizedBox(height: 12),
              Text(
                l10n.shortVideoPublishPanelAutomationByPlatform,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: 6),
              for (final entry
                  in publishPanelUi.publishAutomationModesByPlatform.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 150,
                        child: Text(
                          publishPanelUi.publishPlatformLabels[entry.key] ??
                              entry.key,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
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
            if (publishPanelUi.onBootstrapPublishDraft != null ||
                publishPanelUi.onEnqueuePublishJob != null ||
                publishPanelUi.onEnqueueAllDrafts != null ||
                publishPanelUi.onRetryFailedPublishJobs != null ||
                publishPanelUi.onRefreshPublish != null ||
                publishPanelUi.onSuggestPublishCopy != null ||
                publishPanelUi.onClearPublishSchedule != null ||
                publishPanelUi.onScheduleFirstDraft != null ||
                publishPanelUi.onScheduleAllDraftsSameTime != null ||
                publishPanelUi.onOpenPublishTroubleshooting != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (publishPanelUi.onRefreshPublish != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onRefreshPublish,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.shortVideoPublishPanelRefreshPublish),
                    ),
                  if (publishPanelUi.onBootstrapPublishDraft != null)
                    FilledButton.tonalIcon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onBootstrapPublishDraft,
                      icon: publishPanelUi.publishBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.note_add_outlined),
                      label: Text(l10n.shortVideoPublishPanelBootstrapDraft),
                    ),
                  if (publishPanelUi.onEnqueuePublishJob != null)
                    FilledButton.icon(
                      onPressed:
                          (publishPanelUi.publishBusy ||
                              !publishPanelUi.exportReady)
                          ? null
                          : publishPanelUi.onEnqueuePublishJob,
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
                  if (publishPanelUi.onEnqueueAllDrafts != null)
                    FilledButton.tonal(
                      onPressed:
                          (publishPanelUi.publishBusy ||
                              !publishPanelUi.exportReady)
                          ? null
                          : publishPanelUi.onEnqueueAllDrafts,
                      child: Text(
                        publishPanelUi.exportReady
                            ? l10n.shortVideoPublishPanelEnqueueAllDrafts
                            : l10n.shortVideoPublishPanelEnqueueAllDraftsBlocked,
                      ),
                    ),
                  if (publishPanelUi.onRetryFailedPublishJobs != null)
                    FilledButton.tonal(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onRetryFailedPublishJobs,
                      child: Text(l10n.shortVideoPublishPanelRetryFailedJobs),
                    ),
                  if (publishPanelUi.onSuggestPublishCopy != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onSuggestPublishCopy,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: Text(l10n.shortVideoPublishPanelSuggestCopy),
                    ),
                  if (publishPanelUi.onClearPublishSchedule != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onClearPublishSchedule,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(l10n.shortVideoPublishPanelClearSchedule),
                    ),
                  if (publishPanelUi.onScheduleFirstDraft != null &&
                      publishPanelUi.publishPrimaryDraftId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : () => publishPanelUi.onScheduleFirstDraft?.call(
                              context,
                            ),
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(
                        l10n.shortVideoPublishPanelScheduleCurrentDraft,
                      ),
                    ),
                  if (publishPanelUi.onScheduleAllDraftsSameTime != null &&
                      publishPanelUi.draftLines.length > 1)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : () => publishPanelUi.onScheduleAllDraftsSameTime
                                ?.call(context),
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(l10n.shortVideoPublishPanelScheduleAllDrafts),
                    ),
                  if (publishPanelUi.onOpenPublishTroubleshooting != null)
                    OutlinedButton.icon(
                      onPressed: publishPanelUi.publishBusy
                          ? null
                          : publishPanelUi.onOpenPublishTroubleshooting,
                      icon: const Icon(Icons.bug_report_outlined),
                      label: Text(
                        l10n.shortVideoPublishPanelOpenTroubleshooting,
                      ),
                    ),
                ],
              ),
            ],
            if (publishPanelUi.publishBatchResultLines.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                l10n.shortVideoPublishPanelBatchResultSummary,
                style: theme.textTheme.labelSmall?.copyWith(color: studioPanelMutedColor(context)),
              ),
              const SizedBox(height: 6),
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
          const SizedBox(height: 8),
          Text(
            publishPanelUi.detail,
            style: theme.textTheme.bodySmall?.copyWith(color: studioPanelMutedColor(context)),
          ),
        ],
      ),
    );
  }
}
