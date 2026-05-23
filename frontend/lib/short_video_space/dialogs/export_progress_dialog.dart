part of '../section.dart';

/// Export progress dialog for tracking video export progress
///
/// This dialog:
/// - Polls export task status every 2 seconds
/// - Displays current stage and percentage
/// - Shows cancel button to abort export
/// - Offers explicit next actions after completion or failure
///
/// **Validates: Requirement 13**
extension _ShortVideoSpaceSectionExportProgressDialog
    on _ShortVideoSpaceSectionState {
  /// Opens the export progress dialog and starts polling
  ///
  /// Returns terminal status and whether the user wants to jump into history
  // ignore: unused_element
  Future<ExportProgressDialogResult> _openExportProgressDialog({
    required BuildContext context,
    required String taskId,
  }) async {
    final result = await showStudioDialog<ExportProgressDialogResult>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) {
        return ExportProgressDialog(
          taskId: taskId,
          accessToken: widget.accessToken,
        );
      },
    );
    return result ?? const ExportProgressDialogResult();
  }
}

class ExportProgressDialogResult {
  const ExportProgressDialogResult({
    this.completed = false,
    this.openHistoryRequested = false,
  });

  final bool completed;
  final bool openHistoryRequested;
}

/// Export task status
enum ExportTaskStatus {
  queued,
  processing,
  completed,
  failed,
  cancelled;

  static ExportTaskStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
      case 'queued':
        return ExportTaskStatus.queued;
      case 'running':
      case 'processing':
        return ExportTaskStatus.processing;
      case 'completed':
        return ExportTaskStatus.completed;
      case 'failed':
        return ExportTaskStatus.failed;
      case 'cancelled':
        return ExportTaskStatus.cancelled;
      default:
        return ExportTaskStatus.queued;
    }
  }

  String displayName(AppLocalizations l10n) {
    switch (this) {
      case ExportTaskStatus.queued:
        return l10n.shortVideoSpaceDialogExportProgressStatusQueued;
      case ExportTaskStatus.processing:
        return l10n.shortVideoSpaceDialogExportProgressStatusProcessing;
      case ExportTaskStatus.completed:
        return l10n.shortVideoSpaceDialogExportProgressStatusCompleted;
      case ExportTaskStatus.failed:
        return l10n.shortVideoSpaceDialogExportProgressStatusFailed;
      case ExportTaskStatus.cancelled:
        return l10n.shortVideoSpaceDialogExportProgressStatusCancelled;
    }
  }

  bool get isTerminal =>
      this == ExportTaskStatus.completed ||
      this == ExportTaskStatus.failed ||
      this == ExportTaskStatus.cancelled;
}

/// Export task stage
enum ExportTaskStage {
  initializing,
  loadingAssets,
  encoding,
  uploading,
  finalizing;

  static ExportTaskStage fromString(String value) {
    switch (value.toLowerCase()) {
      case 'preparing':
      case 'initializing':
        return ExportTaskStage.initializing;
      case 'loading_assets':
      case 'loadingassets':
        return ExportTaskStage.loadingAssets;
      case 'encoding':
        return ExportTaskStage.encoding;
      case 'uploading':
        return ExportTaskStage.uploading;
      case 'finalizing':
        return ExportTaskStage.finalizing;
      default:
        return ExportTaskStage.initializing;
    }
  }

  String displayName(AppLocalizations l10n) {
    switch (this) {
      case ExportTaskStage.initializing:
        return l10n.shortVideoSpaceDialogExportProgressStageInitializing;
      case ExportTaskStage.loadingAssets:
        return l10n.shortVideoSpaceDialogExportProgressStageLoadingAssets;
      case ExportTaskStage.encoding:
        return l10n.shortVideoSpaceDialogExportProgressStageEncoding;
      case ExportTaskStage.uploading:
        return l10n.shortVideoSpaceDialogExportProgressStageUploading;
      case ExportTaskStage.finalizing:
        return l10n.shortVideoSpaceDialogExportProgressStageFinalizing;
    }
  }
}

/// Export task progress data
class ExportTaskProgress {
  const ExportTaskProgress({
    required this.taskId,
    required this.status,
    required this.format,
    this.stage,
    this.progress = 0.0,
    this.errorMessage,
    this.outputUrl,
  });

  final String taskId;
  final ExportTaskStatus status;
  final String format;
  final ExportTaskStage? stage;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final String? outputUrl;

  factory ExportTaskProgress.fromJson(Map<String, dynamic> json) {
    return ExportTaskProgress(
      taskId: json['task_id'] as String? ?? json['taskId'] as String? ?? '',
      status: ExportTaskStatus.fromString(
        json['status'] as String? ?? 'queued',
      ),
      format: json['format'] as String? ?? 'mp4',
      stage: json['stage'] != null
          ? ExportTaskStage.fromString(json['stage'] as String)
          : null,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      errorMessage: json['error_message'] as String? ??
          json['errorMessage'] as String?,
      outputUrl:
          json['output_url'] as String? ?? json['outputUrl'] as String?,
    );
  }

  int get progressPercentage => (progress * 100).round().clamp(0, 100);
}

class ExportProgressDialog extends StatefulWidget {
  const ExportProgressDialog({
    super.key,
    required this.taskId,
    required this.accessToken,
  });

  final String taskId;
  final String? accessToken;

  @override
  State<ExportProgressDialog> createState() => _ExportProgressDialogState();
}

class _ExportProgressDialogState extends State<ExportProgressDialog> {
  Timer? _pollTimer;
  ExportTaskProgress? _progress;
  bool _cancelling = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    // Poll immediately
    _pollProgress();

    // Then poll every 2 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollProgress();
    });
  }

  Future<void> _pollProgress() async {
    if (!mounted) return;

    try {
      final progress = await _fetchExportProgress(widget.taskId);

      if (!mounted) return;

      setState(() {
        _progress = progress;
        _errorMessage = null;
      });

      // Auto-close on terminal status
      if (progress.status.isTerminal) {
        _pollTimer?.cancel();
        _pollTimer = null;
      }
    } catch (e) {
      if (!mounted) return;

      _pollTimer?.cancel();
      _pollTimer = null;

      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _errorMessage = l10n.shortVideoSpaceDialogExportProgressFetchError(describeUserVisibleApiErrorResolved(context, e));
      });
    }
  }

  /// Polls [GET /api/v1/jobs/:id] for **`video.export`** generation jobs.
  Future<ExportTaskProgress> _fetchExportProgress(String taskId) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      throw Exception(l10n.shortVideoSpaceDialogExportProgressSessionExpired);
    }
    final job = await fetchJob(token, taskId);
    final status = job.status.trim().toLowerCase();
    final payload = job.payload;
    ExportTaskStatus mapped;
    switch (status) {
      case 'running':
        mapped = ExportTaskStatus.processing;
        break;
      case 'succeeded':
        mapped = ExportTaskStatus.completed;
        break;
      case 'failed':
        mapped = ExportTaskStatus.failed;
        break;
      case 'cancelled':
        mapped = ExportTaskStatus.cancelled;
        break;
      default:
        mapped = ExportTaskStatus.queued;
    }
    double progress = 0.05;
    if (status == 'running') {
      progress = 0.55;
    } else if (status == 'succeeded') {
      progress = 1.0;
    }
    String? outputUrl;
    final result = job.result;
    if (result != null) {
      outputUrl = result['output_url'] as String? ??
          result['file_url'] as String? ??
          result['url'] as String?;
    }
    return ExportTaskProgress(
      taskId: job.id,
      status: mapped,
      format: payload['format'] as String? ?? 'mp4',
      stage: status == 'running'
          ? ExportTaskStage.encoding
          : ExportTaskStage.finalizing,
      progress: progress,
      errorMessage: job.errorMessage,
      outputUrl: outputUrl,
    );
  }

  Future<void> _cancelExport() async {
    if (_cancelling) return;

    final confirmed = await showCancelExportConfirmation(
      context,
      showDontShowAgain: true,
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
    });

    try {
      await _cancelExportTask(widget.taskId);

      if (!mounted) return;

      _pollTimer?.cancel();
      _pollTimer = null;
      Navigator.of(
        context,
      ).pop(const ExportProgressDialogResult(completed: false));
    } catch (e) {
      if (!mounted) return;

      final l10n = resolveAppLocalizationsForErrors(context);
      setState(() {
        _cancelling = false;
        _errorMessage = l10n.shortVideoSpaceDialogExportProgressCancelFailed(describeUserVisibleApiErrorResolved(context, e));
      });
    }
  }

  /// Calls [POST /api/v1/jobs/:id/cancel] for generation export jobs.
  Future<void> _cancelExportTask(String taskId) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      final l10n = resolveAppLocalizationsForErrors(context);
      throw Exception(l10n.shortVideoSpaceDialogExportProgressSessionExpired);
    }
    await cancelJob(token, taskId);
  }

  Future<void> _downloadExportOutput(ExportTaskProgress progress) async {
    final url = progress.outputUrl;
    if (url == null || url.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) {
      return;
    }
    final l10n = resolveAppLocalizationsForErrors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n.shortVideoSpaceDialogExportHistoryDownloadLinkCopied(
            getFormatDisplayName(l10n, progress.format.toLowerCase()),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final theme = Theme.of(context);
    final tokens = StudioTokens.of(context);
    final l10n = resolveAppLocalizationsForErrors(context);

    return StudioAlertDialog(
      scrollable: true,
      maxWidth: 520,
      maxHeightFactor: 0.85,
      title: Row(
        children: [
          const Icon(Icons.video_file_outlined),
          const SizedBox(width: 8),
          Text(l10n.shortVideoSpaceDialogExportProgressTitle),
          const Spacer(),
          if (progress != null && !progress.status.isTerminal)
            Text(
              progress.status.displayName(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: studioConstrainedDialogWidth(context, maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (progress == null) ...[
              if (_errorMessage != null) ...[
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                Center(
                  child: Text(l10n.shortVideoSpaceDialogExportProgressLoadingStatus),
                ),
              ],
            ] else ...[
              // Progress bar
              LinearProgressIndicator(
                value: progress.progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress.status == ExportTaskStatus.failed
                      ? theme.colorScheme.error
                      : progress.status == ExportTaskStatus.completed
                          ? StudioTokens.of(context).success
                          : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Progress percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (progress.stage != null)
                    Text(
                      progress.stage!.displayName(l10n),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      progress.status.displayName(l10n),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    '${progress.progressPercentage}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(progress.status),
                      size: 20,
                      color: tokens.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStatusMessage(progress, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(StudioSpacing.radiusDense),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),
            SelectableText(
              l10n.shortVideoSpaceDialogExportProgressTaskId(
                widget.taskId,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 8),
            Material(
              type: MaterialType.transparency,
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(top: 4, bottom: 8),
                initiallyExpanded: false,
                title: Text(
                  l10n.qualityReviewsFreshnessShowDetails,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
                children: [
                SelectableText(
                  l10n.shortVideoSpaceDialogExportProgressTaskId(
                    widget.taskId,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.textSecondary,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (progress == null && _errorMessage != null)
          FilledButton(
            onPressed: () => Navigator.of(
              context,
            ).pop(const ExportProgressDialogResult(completed: false)),
            child: Text(l10n.shortVideoSpaceDialogExportProgressCloseButton),
          ),
        if (progress != null && !progress.status.isTerminal)
          TextButton(
            onPressed: _cancelling ? null : _cancelExport,
            child: _cancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.shortVideoSpaceDialogExportProgressCancelButton),
          ),
        if (progress?.status.isTerminal == true)
          TextButton(
            onPressed: () => Navigator.of(context).pop(
              ExportProgressDialogResult(
                completed: progress?.status == ExportTaskStatus.completed,
                openHistoryRequested: true,
              ),
            ),
            child: Text(l10n.shortVideoSpaceExportHistory),
          ),
        if (progress?.status == ExportTaskStatus.completed &&
            (progress?.outputUrl?.trim().isNotEmpty ?? false))
          FilledButton.tonalIcon(
            onPressed: () => _downloadExportOutput(progress!),
            icon: const Icon(Icons.download_outlined),
            label: Text(l10n.shortVideoSpaceDialogExportHistoryDownload),
          ),
        if (progress?.status.isTerminal == true)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              ExportProgressDialogResult(
                completed: progress?.status == ExportTaskStatus.completed,
              ),
            ),
            child: Text(l10n.shortVideoSpaceDialogExportProgressCloseButton),
          ),
      ],
    );
  }

  IconData _getStatusIcon(ExportTaskStatus status) {
    switch (status) {
      case ExportTaskStatus.queued:
        return Icons.schedule;
      case ExportTaskStatus.processing:
        return Icons.sync;
      case ExportTaskStatus.completed:
        return Icons.check_circle_outline;
      case ExportTaskStatus.failed:
        return Icons.error_outline;
      case ExportTaskStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  String _getStatusMessage(ExportTaskProgress progress, AppLocalizations l10n) {
    switch (progress.status) {
      case ExportTaskStatus.queued:
        return l10n.shortVideoSpaceDialogExportProgressMessageQueued;
      case ExportTaskStatus.processing:
        if (progress.stage != null) {
          switch (progress.stage!) {
            case ExportTaskStage.initializing:
              return l10n.shortVideoSpaceDialogExportProgressMessageInitializing;
            case ExportTaskStage.loadingAssets:
              return l10n.shortVideoSpaceDialogExportProgressMessageLoadingAssets;
            case ExportTaskStage.encoding:
              return l10n.shortVideoSpaceDialogExportProgressMessageEncoding;
            case ExportTaskStage.uploading:
              return l10n.shortVideoSpaceDialogExportProgressMessageUploading;
            case ExportTaskStage.finalizing:
              return l10n.shortVideoSpaceDialogExportProgressMessageFinalizing;
          }
        }
        return l10n.shortVideoSpaceDialogExportProgressMessageProcessing;
      case ExportTaskStatus.completed:
        return l10n.shortVideoSpaceDialogExportProgressMessageCompleted;
      case ExportTaskStatus.failed:
        return progress.errorMessage ?? l10n.shortVideoSpaceDialogExportProgressMessageFailed;
      case ExportTaskStatus.cancelled:
        return l10n.shortVideoSpaceDialogExportProgressMessageCancelled;
    }
  }
}
