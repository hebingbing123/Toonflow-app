part of '../section.dart';

/// Export progress dialog for tracking video export progress
///
/// This dialog:
/// - Polls export task status every 2 seconds
/// - Displays current stage and percentage
/// - Shows cancel button to abort export
/// - Auto-closes on completion or failure
///
/// **Validates: Requirement 13**
extension _ShortVideoSpaceSectionExportProgressDialog
    on _ShortVideoSpaceSectionState {
  /// Opens the export progress dialog and starts polling
  ///
  /// Returns true if export completed successfully, false if cancelled or failed
  // ignore: unused_element
  Future<bool> _openExportProgressDialog({
    required BuildContext context,
    required String taskId,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (dialogContext) {
        return ExportProgressDialog(
          taskId: taskId,
          accessToken: widget.accessToken,
        );
      },
    );
    return result ?? false;
  }
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
    this.stage,
    this.progress = 0.0,
    this.errorMessage,
    this.outputUrl,
  });

  final String taskId;
  final ExportTaskStatus status;
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

        // Wait a moment to show the final status
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        Navigator.of(context).pop(
          progress.status == ExportTaskStatus.completed,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _pollTimer?.cancel();
      _pollTimer = null;

      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _errorMessage = l10n.shortVideoSpaceDialogExportProgressFetchError(e.toString());
      });
    }
  }

  /// Polls [GET /api/v1/export/tasks/:id] via [getExportTaskByIdV1].
  Future<ExportTaskProgress> _fetchExportProgress(String taskId) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      throw Exception(l10n.shortVideoSpaceDialogExportProgressSessionExpired);
    }
    final task = await getExportTaskByIdV1(token, taskId);
    return ExportTaskProgress(
      taskId: task.id,
      status: ExportTaskStatus.fromString(task.status),
      stage: task.stage == null ? null : ExportTaskStage.fromString(task.stage!),
      progress: (task.progress / 100).clamp(0.0, 1.0),
      errorMessage: task.error,
      outputUrl: task.outputUrl,
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
      Navigator.of(context).pop(false);
    } catch (e) {
      if (!mounted) return;

      final l10n = AppLocalizations.of(context)!;
      setState(() {
        _cancelling = false;
        _errorMessage = l10n.shortVideoSpaceDialogExportProgressCancelFailed(e.toString());
      });
    }
  }

  /// Calls [POST /api/v1/export/cancel] via [postExportCancelV1].
  Future<void> _cancelExportTask(String taskId) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      throw Exception(l10n.shortVideoSpaceDialogExportProgressSessionExpired);
    }
    await postExportCancelV1(token, taskId);
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
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
        width: 480,
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
                const SizedBox(height: 12),
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
                          ? Colors.green
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
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(progress.status),
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getStatusMessage(progress, l10n),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
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

            // Task ID (for debugging) — show in loading / error / progress states
            const SizedBox(height: 12),
            Text(
              l10n.shortVideoSpaceDialogExportProgressTaskId(widget.taskId),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (progress == null && _errorMessage != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(false),
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
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              progress?.status == ExportTaskStatus.completed,
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
