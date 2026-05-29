part of '../section.dart';

// Extension methods call setState on dialog State (same-library extension pattern).
// ignore_for_file: invalid_use_of_protected_member

extension _ExportHistoryDialogUi on _ExportHistoryDialogState {
  Widget buildHistoryList(ThemeData theme) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);

    return StudioAsyncDataView(
      loading: _loading,
      error: _errorMessage,
      onRetry: _loadHistory,
      loadingPlaceholder: StudioLoadingPlaceholder.list,
      loadingItemCount: 4,
      isEmpty: _historyItems.isEmpty,
      empty: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: tokens.textSecondary),
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.shortVideoSpaceDialogExportHistoryNoRecords,
              style: theme.textTheme.titleMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.shortVideoSpaceDialogExportHistoryNoRecordsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
      child: ListView.separated(
        itemCount: _historyItems.length,
        separatorBuilder: (context, index) => const Divider(height: StudioControlSize.dividerThickness),
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          return studioStaggeredItem(
            index,
            entranceKey: _historyItems.length,
            child: buildHistoryItem(item, theme),
          );
        },
      ),
    );
  }

  Widget buildCurrentTaskBanner(ThemeData theme) {
    final l10n = resolveAppLocalizationsForErrors(context);
    ExportHistoryItem? focused;
    for (final item in _historyItems) {
      if (item.taskId == _focusedTaskId) {
        focused = item;
        break;
      }
    }
    if (focused == null) {
      return Container(
        padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
        decoration: BoxDecoration(
          color: StudioTokens.of(context).accentSoft,
          borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        ),
        child: Text(
          'Task ID: ${_focusedTaskId!}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: BoxDecoration(
        color: StudioTokens.of(context).accentSoft,
        borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
        border: Border.all(
          color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            focused.status == ExportTaskStatus.processing ||
                    focused.status == ExportTaskStatus.queued
                ? Icons.sync
                : focused.status == ExportTaskStatus.failed
                ? Icons.error_outline
                : focused.status == ExportTaskStatus.cancelled
                ? Icons.cancel_outlined
                : Icons.task_alt,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: StudioLayoutSpacing.inlineGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${focused.status.displayName(l10n)} · ${getFormatDisplayName(l10n, focused.format.toLowerCase())}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: StudioSpacing.xs),
                Text(
                  'Task ID: ${focused.taskId}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
          if (focused.status == ExportTaskStatus.processing ||
              focused.status == ExportTaskStatus.queued)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: StudioControlSize.progressStroke),
            ),
        ],
      ),
    );
  }

  Widget buildHistoryItem(ExportHistoryItem item, ThemeData theme) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final isDownloading = _downloadingTasks.contains(item.taskId);
    final isFocused = item.taskId == _focusedTaskId;
    final failureCode = (item.failureCode ?? '').trim();
    final failureCodeLabel = failureCode.isEmpty
        ? null
        : videoExportFailureCodeLabel(l10n, failureCode);
    final structuredFailureLine = (failureCodeLabel ?? '').trim().isEmpty
        ? null
        : l10n.taskCenterStructuredFailure(failureCodeLabel!);
    final rawErrorLine = (item.errorMessage ?? '').trim().isEmpty
        ? null
        : item.errorMessage!.trim();

    final tokens = StudioTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: isFocused ? tokens.primarySoft.withValues(alpha: 0.55) : null,
        border: isFocused
            ? Border(left: BorderSide(color: tokens.primary, width: 3))
            : null,
      ),
      child: StudioListRow(
        onTap: () => setState(() => _focusedTaskId = item.taskId),
        onDownload: item.status == ExportTaskStatus.completed &&
                item.outputUrl != null &&
                !isDownloading
            ? () => _downloadExport(item)
            : null,
        onRetry: (item.status == ExportTaskStatus.failed ||
                item.status == ExportTaskStatus.cancelled) &&
            !_loading
            ? () => _retryExport(item)
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StudioSpacing.sm,
          vertical: StudioSpacing.xs,
        ),
        leading: buildStatusIcon(item.status, theme),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${getFormatDisplayName(l10n, item.format.toLowerCase())} · ${getResolutionDisplayName(l10n, item.resolution)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFocused) ...[
              const SizedBox(width: StudioSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.radiusHairline),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusPill),
                ),
                child: Text(
                  l10n.teamWorkspaceCurrentBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: StudioSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.xs, vertical: StudioSpacing.radiusHairline),
              decoration: BoxDecoration(
                color: getStatusColor(
                  item.status,
                  theme,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
              ),
              child: Text(
                item.status.displayName(l10n),
                style: studioAccentBannerBodyStyle(
                  context,
                  getStatusColor(item.status, theme),
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.shortVideoSpaceDialogExportHistoryCreatedAt(
                formatDateTime(item.createdAt),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (item.completedAt != null)
              Text(
                l10n.shortVideoSpaceDialogExportHistoryCompletedAt(
                  formatDateTime(item.completedAt!),
                  item.formattedDuration(l10n),
                ),
                style: theme.textTheme.bodySmall,
              ),
            Text(
              'Task ID: ${item.taskId}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            if (item.fileSize != null)
              Text(
                l10n.shortVideoSpaceDialogExportHistoryFileSize(
                  item.formattedFileSize(l10n),
                ),
                style: theme.textTheme.bodySmall,
              ),
            if (structuredFailureLine != null || rawErrorLine != null) ...[
              const SizedBox(height: StudioSpacing.xs),
              StudioApiErrorCallout(
                error: [
                  ?structuredFailureLine,
                  ?rawErrorLine,
                ].whereType<String>().join('\n'),
                emphasis: StudioApiErrorCalloutEmphasis.subtle,
              ),
            ],
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.shortVideoSpaceDialogExportHistorySettings(
                getBitrateDisplayName(l10n, item.bitrate),
                l10n.shortVideoExportSettingsFramerateOption(item.framerate),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
        trailing: buildHistoryItemTrailing(
          item: item,
          isDownloading: isDownloading,
          l10n: l10n,
        ),
      ),
    );
  }

  Widget? buildHistoryItemTrailing({
    required ExportHistoryItem item,
    required bool isDownloading,
    required AppLocalizations l10n,
  }) {
    if (item.status == ExportTaskStatus.completed && item.outputUrl != null) {
      return StudioDebouncedAction(
        enabled: !isDownloading,
        onPressed: isDownloading ? null : () async => _downloadExport(item),
        builder: (context, onPressed) => FilledButton.icon(
          style: studioFormIconLabeledButtonStyle(context),
          onPressed: onPressed,
          icon: isDownloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: StudioControlSize.progressStroke,
                  ),
                )
              : const Icon(Icons.download),
          label: Text(
            isDownloading
                ? l10n.shortVideoSpaceDialogExportHistoryDownloading
                : l10n.shortVideoSpaceDialogExportHistoryDownload,
          ),
        ),
      );
    }
    if (item.status == ExportTaskStatus.failed ||
        item.status == ExportTaskStatus.cancelled) {
      final recommendedAction = recommendExportFailureAction(
        _classifyExportFailurePhase(null, item.failureCode),
        item.failureCode,
      );
      final retryButton = StudioDebouncedAction(
        enabled: !_loading,
        onPressed: _loading ? null : () async => _retryExport(item),
        builder: (context, onPressed) => OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.shortVideoSpaceDialogExportHistoryRetry),
        ),
      );
      final openProductionButton = OutlinedButton.icon(
        onPressed: widget.onOpenProductionWorkspace == null
            ? null
            : _openProductionWorkspace,
        icon: const Icon(Icons.movie_creation_outlined),
        label: Text(l10n.shortVideoSpaceOpenProductionWorkspace),
      );
      if (recommendedAction ==
              ShortVideoLatestExportAction.openProductionWorkspace &&
          widget.onOpenProductionWorkspace != null) {
        return FilledButton.icon(
          style: studioFormIconLabeledButtonStyle(context),
          onPressed: _openProductionWorkspace,
          icon: const Icon(Icons.movie_creation_outlined),
          label: Text(l10n.shortVideoSpaceOpenProductionWorkspace),
        );
      }
      if (recommendedAction == ShortVideoLatestExportAction.retry) {
        return StudioDebouncedAction(
          enabled: !_loading,
          onPressed: _loading ? null : () async => _retryExport(item),
          builder: (context, onPressed) => FilledButton.icon(
            style: studioFormIconLabeledButtonStyle(context),
            onPressed: onPressed,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.shortVideoSpaceDialogExportHistoryRetry),
          ),
        );
      }
      return Wrap(
        spacing: StudioSpacing.xs,
        runSpacing: StudioSpacing.xs,
        children: [
          retryButton,
          if (widget.onOpenProductionWorkspace != null) openProductionButton,
        ],
      );
    }
    return null;
  }

  Widget buildStatusIcon(ExportTaskStatus status, ThemeData theme) {
    IconData icon;
    Color color;

    switch (status) {
      case ExportTaskStatus.completed:
        icon = Icons.check_circle;
        color = StudioTokens.of(context).success;
        break;
      case ExportTaskStatus.failed:
        icon = Icons.error;
        color = StudioTokens.of(context).danger;
        break;
      case ExportTaskStatus.cancelled:
        icon = Icons.cancel;
        color = StudioTokens.of(context).textSecondary;
        break;
      default:
        icon = Icons.schedule;
        color = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(StudioSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: studioDecorativeIcon(icon, color: color, size: StudioIconSize.lg),
    );
  }

  Color getStatusColor(ExportTaskStatus status, ThemeData theme) {
    switch (status) {
      case ExportTaskStatus.completed:
        return StudioTokens.of(context).success;
      case ExportTaskStatus.failed:
        return StudioTokens.of(context).danger;
      case ExportTaskStatus.cancelled:
        return StudioTokens.of(context).textSecondary;
      default:
        return theme.colorScheme.primary;
    }
  }

  String formatDateTime(DateTime dateTime) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryTimeJustNow;
    } else if (difference.inHours < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryTimeMinutesAgo(
        difference.inMinutes,
      );
    } else if (difference.inDays < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryTimeHoursAgo(
        difference.inHours,
      );
    } else if (difference.inDays < 7) {
      return l10n.shortVideoSpaceDialogExportHistoryTimeDaysAgo(
        difference.inDays,
      );
    } else {
      final localeName = Localizations.localeOf(context).toString();
      return DateFormat.yMMMd(localeName).add_Hm().format(dateTime);
    }
  }
}
