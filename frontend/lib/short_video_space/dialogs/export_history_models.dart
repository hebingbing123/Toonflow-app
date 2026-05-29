part of '../section.dart';

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
  final outputUrl = outputUrlFromJobResult(result);
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
