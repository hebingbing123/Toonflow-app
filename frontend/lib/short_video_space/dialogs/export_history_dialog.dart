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
          const SizedBox(width: StudioSpacing.xs),
          Text(l10n.shortVideoSpaceDialogExportHistoryTitle),
          const Spacer(),
          StudioDebouncedAction(
            enabled: !_loading,
            onPressed: _loading ? null : () async => _loadHistory(),
            builder: (context, onPressed) => StudioIconButton(
              icon: Icons.refresh,
              label: l10n.shortVideoSpaceDialogExportHistoryRefresh,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final fallbackHeight = (MediaQuery.sizeOf(context).height * 0.45)
              .clamp(StudioLayoutSize.fieldStandard, 480.0);
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
                  buildCurrentTaskBanner(theme),
                  const SizedBox(height: StudioSpacing.sm),
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
                      const SizedBox(width: StudioSpacing.sm),
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
                  const SizedBox(height: StudioSpacing.sm),
                ],

                // History list
                Expanded(child: buildHistoryList(theme)),
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

}
