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
  Future<void> _openExportHistoryDialog({
    required BuildContext context,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return ExportHistoryDialog(
          projectId: _selectedProjectId ?? '',
          accessToken: widget.accessToken,
        );
      },
    );
  }
}

/// Time filter options for export history
enum ExportHistoryTimeFilter {
  all,
  today,
  week,
  month;

  String get displayName {
    switch (this) {
      case ExportHistoryTimeFilter.all:
        return '全部时间';
      case ExportHistoryTimeFilter.today:
        return '今天';
      case ExportHistoryTimeFilter.week:
        return '最近一周';
      case ExportHistoryTimeFilter.month:
        return '最近一月';
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

  String get displayName {
    switch (this) {
      case ExportHistoryStatusFilter.all:
        return '全部状态';
      case ExportHistoryStatusFilter.completed:
        return '已完成';
      case ExportHistoryStatusFilter.failed:
        return '失败';
      case ExportHistoryStatusFilter.cancelled:
        return '已取消';
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
        json['created_at'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      completedAt: json['completed_at'] != null || json['completedAt'] != null
          ? DateTime.parse(
              json['completed_at'] as String? ?? json['completedAt'] as String? ?? DateTime.now().toIso8601String(),
            )
          : null,
      outputUrl:
          json['output_url'] as String? ?? json['outputUrl'] as String?,
      errorMessage: json['error_message'] as String? ??
          json['errorMessage'] as String?,
      fileSize: (json['file_size'] as num?)?.toInt() ??
          (json['fileSize'] as num?)?.toInt(),
    );
  }

  String get formattedFileSize {
    if (fileSize == null) return '未知';
    final sizeInMB = fileSize! / (1024 * 1024);
    if (sizeInMB < 1) {
      return '${(fileSize! / 1024).toStringAsFixed(0)} KB';
    } else if (sizeInMB < 1024) {
      return '${sizeInMB.toStringAsFixed(1)} MB';
    } else {
      return '${(sizeInMB / 1024).toStringAsFixed(2)} GB';
    }
  }

  String get formattedDuration {
    if (completedAt == null) return '-';
    final duration = completedAt!.difference(createdAt);
    if (duration.inMinutes < 1) {
      return '${duration.inSeconds} 秒';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} 分钟';
    } else {
      return '${duration.inHours} 小时 ${duration.inMinutes % 60} 分钟';
    }
  }
}

class ExportHistoryDialog extends StatefulWidget {
  const ExportHistoryDialog({
    super.key,
    required this.projectId,
    required this.accessToken,
  });

  final String projectId;
  final String? accessToken;

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '加载导出历史失败: $e';
        _loading = false;
      });
    }
  }

  /// Fetch export history from backend
  Future<List<ExportHistoryItem>> _fetchExportHistory({
    required String projectId,
    required ExportHistoryStatusFilter statusFilter,
    required ExportHistoryTimeFilter timeFilter,
  }) async {
    final token = widget.accessToken?.trim();
    if (token == null || token.isEmpty) {
      throw Exception('会话已失效，请重新登录');
    }
    final String? status = switch (statusFilter) {
      ExportHistoryStatusFilter.all => null,
      ExportHistoryStatusFilter.completed => 'completed',
      ExportHistoryStatusFilter.failed => 'failed',
      ExportHistoryStatusFilter.cancelled => 'cancelled',
    };
    final tasks = await getExportTasksV1(
      token,
      projectId: projectId,
      status: status,
      limit: 200,
      offset: 0,
    );
    final items = tasks
        .map(
          (task) => ExportHistoryItem(
            taskId: task.id,
            status: ExportTaskStatus.fromString(task.status),
            format: task.format,
            resolution: (task.quality['resolution'] as String? ?? '1080p'),
            bitrate: _bitrateLabelFromQuality(task.quality),
            framerate: (task.quality['framerate'] as num?)?.toInt() ?? 30,
            createdAt: task.createdAt,
            completedAt: task.completedAt,
            outputUrl: task.outputUrl,
            errorMessage: task.error,
            fileSize: (task.quality['estimatedFileSizeBytes'] as num?)?.toInt(),
          ),
        )
        .toList(growable: false);

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

    return filtered;
  }

  String _bitrateLabelFromQuality(Map<String, dynamic> quality) {
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已复制下载链接（${item.format.toUpperCase()}）'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('下载失败: $e'),
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

  Future<void> _triggerDownload(String url, String taskId) async {
    await Clipboard.setData(ClipboardData(text: url));
    debugPrint('Export download url for task $taskId: $url');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.history),
          const SizedBox(width: 8),
          const Text('导出历史'),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadHistory,
            tooltip: '刷新',
          ),
        ],
      ),
      content: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filters
            Row(
              children: [
                // Status filter
                Expanded(
                  child: DropdownButtonFormField<ExportHistoryStatusFilter>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: '状态',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: ExportHistoryStatusFilter.values
                        .map(
                          (filter) => DropdownMenuItem(
                            value: filter,
                            child: Text(filter.displayName),
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
                  child: DropdownButtonFormField<ExportHistoryTimeFilter>(
                    initialValue: _timeFilter,
                    decoration: const InputDecoration(
                      labelText: '时间',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: ExportHistoryTimeFilter.values
                        .map(
                          (filter) => DropdownMenuItem(
                            value: filter,
                            child: Text(filter.displayName),
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

            // History list
            Expanded(
              child: _buildHistoryList(theme),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无导出记录',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '导出视频后，记录将显示在这里',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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

  Widget _buildHistoryItem(ExportHistoryItem item, ThemeData theme) {
    final isDownloading = _downloadingTasks.contains(item.taskId);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      leading: _buildStatusIcon(item.status, theme),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '${item.format.toUpperCase()} · ${getResolutionDisplayName(item.resolution)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(item.status, theme).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.status.displayName,
              style: TextStyle(
                fontSize: 12,
                color: _getStatusColor(item.status, theme),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            '创建时间: ${_formatDateTime(item.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          if (item.completedAt != null)
            Text(
              '完成时间: ${_formatDateTime(item.completedAt!)} · 耗时: ${item.formattedDuration}',
              style: theme.textTheme.bodySmall,
            ),
          if (item.fileSize != null)
            Text(
              '文件大小: ${item.formattedFileSize}',
              style: theme.textTheme.bodySmall,
            ),
          if (item.errorMessage != null) ...[
            const SizedBox(height: 4),
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
                    child: Text(
                      item.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '设置: ${getBitrateDisplayName(item.bitrate)} · ${item.framerate} FPS',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: item.status == ExportTaskStatus.completed && item.outputUrl != null
          ? FilledButton.icon(
              onPressed: isDownloading ? null : () => _downloadExport(item),
              icon: isDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(isDownloading ? '下载中...' : '下载'),
            )
          : null,
    );
  }

  Widget _buildStatusIcon(ExportTaskStatus status, ThemeData theme) {
    IconData icon;
    Color color;

    switch (status) {
      case ExportTaskStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case ExportTaskStatus.failed:
        icon = Icons.error;
        color = theme.colorScheme.error;
        break;
      case ExportTaskStatus.cancelled:
        icon = Icons.cancel;
        color = theme.colorScheme.onSurfaceVariant;
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
      child: Icon(icon, color: color, size: 24),
    );
  }

  Color _getStatusColor(ExportTaskStatus status, ThemeData theme) {
    switch (status) {
      case ExportTaskStatus.completed:
        return Colors.green;
      case ExportTaskStatus.failed:
        return theme.colorScheme.error;
      case ExportTaskStatus.cancelled:
        return theme.colorScheme.onSurfaceVariant;
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
