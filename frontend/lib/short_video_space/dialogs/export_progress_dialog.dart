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
      case 'queued':
        return ExportTaskStatus.queued;
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

  String get displayName {
    switch (this) {
      case ExportTaskStatus.queued:
        return '排队中';
      case ExportTaskStatus.processing:
        return '处理中';
      case ExportTaskStatus.completed:
        return '已完成';
      case ExportTaskStatus.failed:
        return '失败';
      case ExportTaskStatus.cancelled:
        return '已取消';
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

  String get displayName {
    switch (this) {
      case ExportTaskStage.initializing:
        return '初始化';
      case ExportTaskStage.loadingAssets:
        return '加载素材';
      case ExportTaskStage.encoding:
        return '编码视频';
      case ExportTaskStage.uploading:
        return '上传文件';
      case ExportTaskStage.finalizing:
        return '完成处理';
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
  });

  final String taskId;

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
      // TODO: Replace with actual API call when backend endpoint is ready
      // For now, simulate progress
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

      setState(() {
        _errorMessage = '获取进度失败: $e';
      });
    }
  }

  /// Fetch export progress from backend
  ///
  /// TODO: Replace with actual API call when backend endpoint is ready
  /// Expected endpoint: GET /api/v1/export/tasks/{taskId}
  Future<ExportTaskProgress> _fetchExportProgress(String taskId) async {
    // Simulate API call with mock data
    // Remove the delay in tests to avoid timer issues
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      // In debug/test mode, use minimal delay
      await Future.delayed(Duration.zero);
    } else {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Mock progressive status for demonstration
    // In real implementation, this would call the backend API
    final now = DateTime.now().millisecondsSinceEpoch;
    final elapsed = (now % 10000) / 10000.0; // 0.0 to 1.0 over 10 seconds

    if (elapsed < 0.2) {
      return ExportTaskProgress(
        taskId: taskId,
        status: ExportTaskStatus.queued,
        progress: 0.0,
      );
    } else if (elapsed < 0.4) {
      return ExportTaskProgress(
        taskId: taskId,
        status: ExportTaskStatus.processing,
        stage: ExportTaskStage.initializing,
        progress: 0.1,
      );
    } else if (elapsed < 0.6) {
      return ExportTaskProgress(
        taskId: taskId,
        status: ExportTaskStatus.processing,
        stage: ExportTaskStage.loadingAssets,
        progress: 0.3,
      );
    } else if (elapsed < 0.8) {
      return ExportTaskProgress(
        taskId: taskId,
        status: ExportTaskStatus.processing,
        stage: ExportTaskStage.encoding,
        progress: 0.6,
      );
    } else if (elapsed < 0.9) {
      return ExportTaskProgress(
        taskId: taskId,
        status: ExportTaskStatus.processing,
        stage: ExportTaskStage.uploading,
        progress: 0.85,
      );
    } else {
      return ExportTaskProgress(
        taskId: taskId,
        status: ExportTaskStatus.completed,
        stage: ExportTaskStage.finalizing,
        progress: 1.0,
        outputUrl: 'https://example.com/export/video.mp4',
      );
    }
  }

  Future<void> _cancelExport() async {
    if (_cancelling) return;

    final confirmed = await showCancelExportConfirmation(
      context,
      showDontShowAgain: false, // TODO: Enable after proper SharedPreferences setup
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _cancelling = true;
    });

    try {
      // TODO: Replace with actual API call when backend endpoint is ready
      // Expected endpoint: POST /api/v1/export/cancel
      await _cancelExportTask(widget.taskId);

      if (!mounted) return;

      _pollTimer?.cancel();
      _pollTimer = null;
      Navigator.of(context).pop(false);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _cancelling = false;
        _errorMessage = '取消失败: $e';
      });
    }
  }

  /// Cancel export task
  ///
  /// TODO: Replace with actual API call when backend endpoint is ready
  Future<void> _cancelExportTask(String taskId) async {
    // Simulate API call with minimal delay in tests
    if (const bool.fromEnvironment('dart.vm.product') == false) {
      await Future.delayed(Duration.zero);
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.video_file_outlined),
          const SizedBox(width: 8),
          const Text('导出进度'),
          const Spacer(),
          if (progress != null && !progress.status.isTerminal)
            Text(
              progress.status.displayName,
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
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              const Center(
                child: Text('正在获取导出状态...'),
              ),
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
                      progress.stage!.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    Text(
                      progress.status.displayName,
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
                        _getStatusMessage(progress),
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

              // Task ID (for debugging)
              const SizedBox(height: 12),
              Text(
                '任务 ID: ${widget.taskId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (progress != null && !progress.status.isTerminal)
          TextButton(
            onPressed: _cancelling ? null : _cancelExport,
            child: _cancelling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('取消导出'),
          ),
        if (progress?.status.isTerminal == true)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              progress?.status == ExportTaskStatus.completed,
            ),
            child: const Text('关闭'),
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

  String _getStatusMessage(ExportTaskProgress progress) {
    switch (progress.status) {
      case ExportTaskStatus.queued:
        return '导出任务已加入队列，等待处理...';
      case ExportTaskStatus.processing:
        if (progress.stage != null) {
          switch (progress.stage!) {
            case ExportTaskStage.initializing:
              return '正在初始化导出任务...';
            case ExportTaskStage.loadingAssets:
              return '正在加载视频素材和音频文件...';
            case ExportTaskStage.encoding:
              return '正在编码视频，这可能需要几分钟...';
            case ExportTaskStage.uploading:
              return '正在上传导出的视频文件...';
            case ExportTaskStage.finalizing:
              return '正在完成最后的处理步骤...';
          }
        }
        return '正在处理导出任务...';
      case ExportTaskStatus.completed:
        return '导出成功完成！视频已准备好下载。';
      case ExportTaskStatus.failed:
        return progress.errorMessage ?? '导出失败，请重试或联系支持。';
      case ExportTaskStatus.cancelled:
        return '导出已被取消。';
    }
  }
}
