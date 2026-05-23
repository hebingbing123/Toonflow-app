part of '../section.dart';

/// Export history dialog for viewing past export tasks
///
/// This dialog:
/// - Displays list of export tasks with status, time, and settings
/// - Filters by status (all/completed/failed/cancelled)
/// - Filters by time range (all/today/week/month)
/// - Provides re-download functionality for completed exports
///
/// **Validates: Requirement 14**
extension _ShortVideoSpaceSectionExportHistoryDialog
    on _ShortVideoSpaceSectionState {
  /// Opens the export history dialog
  ///
  /// Shows all export tasks for the current project with filtering options
  // ignore: unused_element
  Future<ExportHistoryDialogResult> _openExportHistoryDialog({
    required BuildContext context,
    String? currentTaskId,
  }) async {
    final initialTaskId =
        currentTaskId ??
        (_activeAssemblyJob?.kind == 'video.export'
            ? _activeAssemblyJob?.id
            : null);
    final result = await showStudioDialog<ExportHistoryDialogResult>(
      context: context,
      builder: (dialogContext) {
        return ExportHistoryDialog(
          projectId: _selectedProjectId ?? '',
          accessToken: widget.accessToken,
          currentTaskId: initialTaskId,
          onOpenProductionWorkspace: () {
            Navigator.of(dialogContext).pop(
              ExportHistoryDialogResult(
                focusedTaskId: initialTaskId,
                shouldTrackFocusedTask: true,
                openProductionWorkspaceRequested: true,
              ),
            );
          },
        );
      },
    );
    return result ?? const ExportHistoryDialogResult();
  }
}

class ExportHistoryDialogResult {
  const ExportHistoryDialogResult({
    this.focusedTaskId,
    this.shouldTrackFocusedTask = false,
    this.openProductionWorkspaceRequested = false,
  });

  final String? focusedTaskId;
  final bool shouldTrackFocusedTask;
  final bool openProductionWorkspaceRequested;
}

typedef ExportHistoryFetchOverride =
    Future<List<ExportHistoryItem>> Function({
      required String projectId,
      required ExportHistoryStatusFilter statusFilter,
      required ExportHistoryTimeFilter timeFilter,
      String? focusedTaskId,
    });

typedef ExportHistoryDownloadOverride =
    Future<void> Function(String url, String taskId);

/// Time filter options for export history
enum ExportHistoryTimeFilter {
  all,
  today,
  week,
  month;

  String displayName(AppLocalizations l10n) {
    switch (this) {
      case ExportHistoryTimeFilter.all:
        return l10n.shortVideoSpaceDialogExportHistoryTimeFilterAll;
      case ExportHistoryTimeFilter.today:
        return l10n.shortVideoSpaceDialogExportHistoryTimeFilterToday;
      case ExportHistoryTimeFilter.week:
        return l10n.shortVideoSpaceDialogExportHistoryTimeFilterWeek;
      case ExportHistoryTimeFilter.month:
        return l10n.shortVideoSpaceDialogExportHistoryTimeFilterMonth;
    }
  }

  DateTime? get startDate {
    final now = DateTime.now();
    switch (this) {
      case ExportHistoryTimeFilter.all:
        return null;
      case ExportHistoryTimeFilter.today:
        return DateTime(now.year, now.month, now.day);
      case ExportHistoryTimeFilter.week:
        return now.subtract(const Duration(days: 7));
      case ExportHistoryTimeFilter.month:
        return now.subtract(const Duration(days: 30));
    }
  }
}

/// Status filter options for export history
enum ExportHistoryStatusFilter {
  all,
  completed,
  failed,
  cancelled;

  String displayName(AppLocalizations l10n) {
    switch (this) {
      case ExportHistoryStatusFilter.all:
        return l10n.shortVideoSpaceDialogExportHistoryStatusFilterAll;
      case ExportHistoryStatusFilter.completed:
        return l10n.shortVideoSpaceDialogExportHistoryStatusFilterCompleted;
      case ExportHistoryStatusFilter.failed:
        return l10n.shortVideoSpaceDialogExportHistoryStatusFilterFailed;
      case ExportHistoryStatusFilter.cancelled:
        return l10n.shortVideoSpaceDialogExportHistoryStatusFilterCancelled;
    }
  }

  bool matches(ExportTaskStatus status) {
    switch (this) {
      case ExportHistoryStatusFilter.all:
        return true;
      case ExportHistoryStatusFilter.completed:
        return status == ExportTaskStatus.completed;
      case ExportHistoryStatusFilter.failed:
        return status == ExportTaskStatus.failed;
      case ExportHistoryStatusFilter.cancelled:
        return status == ExportTaskStatus.cancelled;
    }
  }
}

/// Export history item data
class ExportHistoryItem {
  const ExportHistoryItem({
    required this.taskId,
    required this.status,
    required this.format,
    required this.resolution,
    required this.bitrate,
    required this.framerate,
    required this.createdAt,
    this.completedAt,
    this.outputUrl,
    this.errorMessage,
    this.failureCode,
    this.fileSize,
  });

  final String taskId;
  final ExportTaskStatus status;
  final String format;
  final String resolution;
  final String bitrate;
  final int framerate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? outputUrl;
  final String? errorMessage;
  final String? failureCode;
  final int? fileSize; // in bytes

  factory ExportHistoryItem.fromJson(Map<String, dynamic> json) {
    return ExportHistoryItem(
      taskId: json['task_id'] as String? ?? json['taskId'] as String? ?? '',
      status: ExportTaskStatus.fromString(
        json['status'] as String? ?? 'queued',
      ),
      format: json['format'] as String? ?? 'mp4',
      resolution: json['resolution'] as String? ?? '1080p',
      bitrate: json['bitrate'] as String? ?? 'medium',
      framerate: (json['framerate'] as num?)?.toInt() ?? 30,
      createdAt: DateTime.parse(
        json['created_at'] as String? ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      completedAt: json['completed_at'] != null || json['completedAt'] != null
          ? DateTime.parse(
              json['completed_at'] as String? ??
                  json['completedAt'] as String? ??
                  DateTime.now().toIso8601String(),
            )
          : null,
      outputUrl: json['output_url'] as String? ?? json['outputUrl'] as String?,
      errorMessage:
          json['error_message'] as String? ?? json['errorMessage'] as String?,
      failureCode:
          json['failure_code'] as String? ?? json['failureCode'] as String?,
      fileSize:
          (json['file_size'] as num?)?.toInt() ??
          (json['fileSize'] as num?)?.toInt(),
    );
  }

  String formattedFileSize(AppLocalizations l10n) {
    if (fileSize == null) {
      return l10n.shortVideoSpaceDialogExportHistoryFileSizeUnknown;
    }
    final sizeInMB = fileSize! / (1024 * 1024);
    if (sizeInMB < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryFileSizeKB(
        (fileSize! / 1024).toStringAsFixed(0),
      );
    } else if (sizeInMB < 1024) {
      return l10n.shortVideoSpaceDialogExportHistoryFileSizeMB(
        sizeInMB.toStringAsFixed(1),
      );
    } else {
      return l10n.shortVideoSpaceDialogExportHistoryFileSizeGB(
        (sizeInMB / 1024).toStringAsFixed(2),
      );
    }
  }

  String formattedDuration(AppLocalizations l10n) {
    if (completedAt == null) {
      return l10n.shortVideoSpaceDialogExportHistoryDurationDash;
    }
    final duration = completedAt!.difference(createdAt);
    if (duration.inMinutes < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryDurationSeconds(
        duration.inSeconds,
      );
    } else if (duration.inHours < 1) {
      return l10n.shortVideoSpaceDialogExportHistoryDurationMinutes(
        duration.inMinutes,
      );
    } else {
      return l10n.shortVideoSpaceDialogExportHistoryDurationHours(
        duration.inHours,
        duration.inMinutes % 60,
      );
    }
  }
}

String _bitrateLabelFromQualityMap(Map<String, dynamic> quality) {
  final raw = quality['bitrate'];
  if (raw is num) {
    if (raw >= 7000) {
      return 'high';
    }
    if (raw >= 3000) {
      return 'medium';
    }
    return 'low';
  }
  final text = quality['bitrateLabel'] as String?;
  if (text != null && text.trim().isNotEmpty) {
    return text.trim();
  }
  return 'medium';
}

ExportHistoryItem exportHistoryItemFromJob(JobRow job) {
  final status = switch (job.status) {
    'succeeded' => ExportTaskStatus.completed,
    'failed' => ExportTaskStatus.failed,
    'cancelled' => ExportTaskStatus.cancelled,
    'running' => ExportTaskStatus.processing,
    _ => ExportTaskStatus.queued,
  };
  final payload = job.payload;
  final quality = payload['quality'] as Map<String, dynamic>?;
  final format = payload['format'] as String? ?? 'mp4';
  final resolution =
      payload['resolution'] as String? ??
      quality?['resolution'] as String? ??
      '1080p';
  final bitrate =
      payload['bitrate_label'] as String? ??
      (quality == null ? null : _bitrateLabelFromQualityMap(quality)) ??
      'medium';
  final framerate =
      (payload['framerate'] as num?)?.toInt() ??
      (quality?['fps'] as num?)?.toInt() ??
      30;
  final result = job.result;
  final outputUrl = result == null
      ? null
      : result['output_url'] as String? ??
            result['file_url'] as String? ??
            result['url'] as String?;
  final fileSize = result == null
      ? null
      : (result['file_size'] as num?)?.toInt() ??
            (result['size_bytes'] as num?)?.toInt();
  final created = DateTime.tryParse(job.createdAt) ?? DateTime.now();
  final updated = DateTime.tryParse(job.updatedAt);
  return ExportHistoryItem(
    taskId: job.id,
    status: status,
    format: format,
    resolution: resolution,
    bitrate: bitrate,
    framerate: framerate,
    createdAt: created,
    completedAt: status == ExportTaskStatus.completed ? updated : null,
    outputUrl: outputUrl,
    errorMessage: job.errorMessage,
    failureCode: job.errorDetails?['code'] as String?,
    fileSize: fileSize,
  );
}

class ExportHistoryDialog extends StatefulWidget {
  const ExportHistoryDialog({
    super.key,
    required this.projectId,
    required this.accessToken,
    this.currentTaskId,
    this.onOpenProductionWorkspace,
    this.fetchHistoryOverride,
    this.downloadOverride,
  });

  final String projectId;
  final String? accessToken;
  final String? currentTaskId;
  final VoidCallback? onOpenProductionWorkspace;
  final ExportHistoryFetchOverride? fetchHistoryOverride;
  final ExportHistoryDownloadOverride? downloadOverride;

  @override
  State<ExportHistoryDialog> createState() => _ExportHistoryDialogState();
}

class _ExportHistoryDialogState extends State<ExportHistoryDialog> {
  ExportHistoryTimeFilter _timeFilter = ExportHistoryTimeFilter.all;
  ExportHistoryStatusFilter _statusFilter = ExportHistoryStatusFilter.all;
  List<ExportHistoryItem> _historyItems = [];
  bool _loading = true;
  String? _errorMessage;
  final Set<String> _downloadingTasks = {};
  Timer? _refreshTimer;
  String? _focusedTaskId;
  bool _shouldTrackFocusedTask = false;

  @override
  void initState() {
    super.initState();
    _focusedTaskId = widget.currentTaskId?.trim().isEmpty ?? true
        ? null
        : widget.currentTaskId!.trim();
    _loadHistory();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final items = await _fetchExportHistory(
        projectId: widget.projectId,
        statusFilter: _statusFilter,
        timeFilter: _timeFilter,
      );

      if (!mounted) return;

      setState(() {
        _historyItems = items;
        _loading = false;
      });
      _syncAutoRefresh(items);
    } catch (e) {
      if (!mounted) return;

      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _errorMessage = l10n.shortVideoSpaceDialogExportHistoryLoadError(
          describeUserVisibleApiErrorResolved(context, e),
        );
        _loading = false;
      });
      _syncAutoRefresh(const <ExportHistoryItem>[]);
    }
  }

  /// Fetch export history from backend
  Future<List<ExportHistoryItem>> _fetchExportHistory({
    required String projectId,
    required ExportHistoryStatusFilter statusFilter,
    required ExportHistoryTimeFilter timeFilter,
  }) async {
    final fetchOverride = widget.fetchHistoryOverride;
    if (fetchOverride != null) {
      return fetchOverride(
        projectId: projectId,
        statusFilter: statusFilter,
        timeFilter: timeFilter,
        focusedTaskId: _focusedTaskId,
      );
    }
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      if (!mounted) {
        throw StateError(
          'ExportHistoryDialog._fetchExportHistory: not mounted',
        );
      }
      throw Exception(
        resolveAppLocalizationsForErrors(
          context,
        ).shortVideoSpaceDialogExportHistorySessionExpired,
      );
    }
    final jobs = await fetchJobs(token, kind: 'video.export', limit: 100);
    final projectJobs = jobs
        .where((j) => j.payload['project_uuid']?.toString() == projectId)
        .toList(growable: false);
    final items = projectJobs
        .map(exportHistoryItemFromJob)
        .toList(growable: true);
    final currentTaskId = _focusedTaskId;
    if (currentTaskId != null &&
        currentTaskId.isNotEmpty &&
        items.every((item) => item.taskId != currentTaskId)) {
      final currentJob = await fetchJob(token, currentTaskId);
      if (currentJob.payload['project_uuid']?.toString() == projectId &&
          currentJob.kind == 'video.export') {
        items.add(exportHistoryItemFromJob(currentJob));
      }
    }

    // Apply filters
    var filtered = items.where((item) {
      // Status filter
      if (!statusFilter.matches(item.status)) return false;

      // Time filter
      final startDate = timeFilter.startDate;
      if (startDate != null && item.createdAt.isBefore(startDate)) {
        return false;
      }

      return true;
    }).toList();

    // Sort by creation time (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final focusedTaskId = _focusedTaskId;
    if (focusedTaskId != null && focusedTaskId.isNotEmpty) {
      filtered.sort((a, b) {
        final aFocused = a.taskId == focusedTaskId ? 1 : 0;
        final bFocused = b.taskId == focusedTaskId ? 1 : 0;
        if (aFocused != bFocused) {
          return bFocused.compareTo(aFocused);
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    }

    return filtered;
  }

  void _syncAutoRefresh(List<ExportHistoryItem> items) {
    final hasActive = items.any(
      (item) =>
          item.status == ExportTaskStatus.queued ||
          item.status == ExportTaskStatus.processing,
    );
    if (!hasActive) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_loading) {
        unawaited(_loadHistory());
      }
    });
  }

  Future<void> _downloadExport(ExportHistoryItem item) async {
    if (item.outputUrl == null || _downloadingTasks.contains(item.taskId)) {
      return;
    }

    setState(() {
      _downloadingTasks.add(item.taskId);
    });

    try {
      await _triggerDownload(item.outputUrl!, item.taskId);

      if (!mounted) return;

      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoSpaceDialogExportHistoryDownloadLinkCopied(
              getFormatDisplayName(l10n, item.format.toLowerCase()),
            ),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final l10n = resolveAppLocalizationsForErrors(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.shortVideoSpaceDialogExportHistoryDownloadFailed(
              describeUserVisibleApiErrorResolved(context, e),
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingTasks.remove(item.taskId);
        });
      }
    }
  }

  Future<void> _retryExport(ExportHistoryItem item) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty || _loading) {
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
      _focusedTaskId = item.taskId;
    });
    try {
      final updated = await retryJob(token, item.taskId);
      _focusedTaskId = updated.id;
      _shouldTrackFocusedTask = true;
      if (!mounted) {
        return;
      }
      await _loadHistory();
    } catch (e) {
      if (!mounted) {
        return;
      }
      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _errorMessage = l10n.shortVideoSpaceDialogExportHistoryLoadError(
          describeUserVisibleApiErrorResolved(context, e),
        );
        _loading = false;
      });
    }
  }

  void _openProductionWorkspace() {
    widget.onOpenProductionWorkspace?.call();
  }

  Future<void> _triggerDownload(String url, String taskId) async {
    final downloadOverride = widget.downloadOverride;
    if (downloadOverride != null) {
      await downloadOverride(url, taskId);
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    debugPrint('Export download url for task $taskId: $url');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);

    return StudioAlertDialog(
      maxWidth: 840,
      maxHeightFactor: 0.92,
      scrollable: false,
      showCloseButton: false,
      title: Row(
        children: [
          const Icon(Icons.history),
          const SizedBox(width: 8),
          Text(l10n.shortVideoSpaceDialogExportHistoryTitle),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadHistory,
            tooltip: l10n.shortVideoSpaceDialogExportHistoryRefresh,
          ),
        ],
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final fallbackHeight = (MediaQuery.sizeOf(context).height * 0.45)
              .clamp(280.0, 480.0);
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : fallbackHeight;
          return SizedBox(
            width: studioConstrainedDialogWidth(context, maxWidth: 800),
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_focusedTaskId != null && _focusedTaskId!.isNotEmpty) ...[
                  _buildCurrentTaskBanner(theme),
                  const SizedBox(height: 16),
                ],
                if (_errorMessage == null && !_loading) ...<Widget>[
                  Row(
                    children: [
                      // Status filter
                      Expanded(
                        child:
                            StudioDropdownButtonFormField<
                              ExportHistoryStatusFilter
                            >(
                              initialValue: _statusFilter,
                              decoration: InputDecoration(
                                labelText: l10n
                                    .shortVideoSpaceDialogExportHistoryStatusLabel,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: ExportHistoryStatusFilter.values
                                  .map(
                                    (filter) => DropdownMenuItem(
                                      value: filter,
                                      child: Text(filter.displayName(l10n)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _statusFilter = value;
                                });
                                _loadHistory();
                              },
                            ),
                      ),
                      const SizedBox(width: 16),
                      // Time filter
                      Expanded(
                        child:
                            StudioDropdownButtonFormField<
                              ExportHistoryTimeFilter
                            >(
                              initialValue: _timeFilter,
                              decoration: InputDecoration(
                                labelText: l10n
                                    .shortVideoSpaceDialogExportHistoryTimeLabel,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              items: ExportHistoryTimeFilter.values
                                  .map(
                                    (filter) => DropdownMenuItem(
                                      value: filter,
                                      child: Text(filter.displayName(l10n)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _timeFilter = value;
                                });
                                _loadHistory();
                              },
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // History list
                Expanded(child: _buildHistoryList(theme)),
              ],
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(
            ExportHistoryDialogResult(
              focusedTaskId: _focusedTaskId,
              shouldTrackFocusedTask: _shouldTrackFocusedTask,
            ),
          ),
          child: Text(l10n.shortVideoSpaceDialogExportHistoryClose),
        ),
      ],
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final tokens = StudioTokens.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.shortVideoSpaceDialogExportHistoryRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: tokens.textSecondary),
            const SizedBox(height: 16),
            Text(
              l10n.shortVideoSpaceDialogExportHistoryNoRecords,
              style: theme.textTheme.titleMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.shortVideoSpaceDialogExportHistoryNoRecordsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _historyItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _historyItems[index];
        return _buildHistoryItem(item, theme);
      },
    );
  }

  Widget _buildCurrentTaskBanner(ThemeData theme) {
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
        padding: const EdgeInsets.all(12),
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
      padding: const EdgeInsets.all(12),
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
                const SizedBox(height: 8),
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
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(ExportHistoryItem item, ThemeData theme) {
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildStatusIcon(item.status, theme),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${getFormatDisplayName(l10n, item.format.toLowerCase())} · ${getResolutionDisplayName(l10n, item.resolution)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isFocused) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(999),
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(
                  item.status,
                  theme,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.status.displayName(l10n),
                style: studioAccentBannerBodyStyle(
                  context,
                  _getStatusColor(item.status, theme),
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              l10n.shortVideoSpaceDialogExportHistoryCreatedAt(
                _formatDateTime(item.createdAt),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (item.completedAt != null)
              Text(
                l10n.shortVideoSpaceDialogExportHistoryCompletedAt(
                  _formatDateTime(item.completedAt!),
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
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (structuredFailureLine != null)
                            Text(
                              structuredFailureLine,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (rawErrorLine != null) ...[
                            if (structuredFailureLine != null)
                              const SizedBox(height: 8),
                            Text(
                              rawErrorLine,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
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
        trailing: _buildHistoryItemTrailing(
          item: item,
          isDownloading: isDownloading,
          l10n: l10n,
        ),
      ),
    );
  }

  Widget? _buildHistoryItemTrailing({
    required ExportHistoryItem item,
    required bool isDownloading,
    required AppLocalizations l10n,
  }) {
    if (item.status == ExportTaskStatus.completed && item.outputUrl != null) {
      return FilledButton.icon(
        onPressed: isDownloading ? null : () => _downloadExport(item),
        icon: isDownloading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download),
        label: Text(
          isDownloading
              ? l10n.shortVideoSpaceDialogExportHistoryDownloading
              : l10n.shortVideoSpaceDialogExportHistoryDownload,
        ),
      );
    }
    if (item.status == ExportTaskStatus.failed ||
        item.status == ExportTaskStatus.cancelled) {
      final recommendedAction = recommendExportFailureAction(
        _classifyExportFailurePhase(null, item.failureCode),
        item.failureCode,
      );
      final retryButton = OutlinedButton.icon(
        onPressed: _loading ? null : () => _retryExport(item),
        icon: const Icon(Icons.refresh),
        label: Text(l10n.shortVideoSpaceDialogExportHistoryRetry),
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
          onPressed: _openProductionWorkspace,
          icon: const Icon(Icons.movie_creation_outlined),
          label: Text(l10n.shortVideoSpaceOpenProductionWorkspace),
        );
      }
      if (recommendedAction == ShortVideoLatestExportAction.retry) {
        return FilledButton.icon(
          onPressed: _loading ? null : () => _retryExport(item),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.shortVideoSpaceDialogExportHistoryRetry),
        );
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          retryButton,
          if (widget.onOpenProductionWorkspace != null) openProductionButton,
        ],
      );
    }
    return null;
  }

  Widget _buildStatusIcon(ExportTaskStatus status, ThemeData theme) {
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: studioDecorativeIcon(icon, color: color, size: 24),
    );
  }

  Color _getStatusColor(ExportTaskStatus status, ThemeData theme) {
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

  String _formatDateTime(DateTime dateTime) {
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
