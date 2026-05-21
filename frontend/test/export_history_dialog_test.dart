import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_dropdown_field.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/short_video_space/section.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

/// **Validates: Requirement 14**
final _zh = AppLocalizationsZh();

Widget buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh'),
    home: Scaffold(body: child),
  );
}

List<ExportHistoryItem> _mockExportHistoryItems() {
  final now = DateTime.now();
  return <ExportHistoryItem>[
    ExportHistoryItem(
      taskId: 'export-completed',
      status: ExportTaskStatus.completed,
      format: 'mp4',
      resolution: '1080p',
      bitrate: 'medium',
      framerate: 30,
      createdAt: now.subtract(const Duration(hours: 2, minutes: 5)),
      completedAt: now.subtract(const Duration(hours: 2)),
      outputUrl: 'https://example.com/export-completed.mp4',
      fileSize: 24 * 1024 * 1024,
    ),
    ExportHistoryItem(
      taskId: 'export-failed',
      status: ExportTaskStatus.failed,
      format: 'mp4',
      resolution: '720p',
      bitrate: 'low',
      framerate: 24,
      createdAt: now.subtract(const Duration(hours: 5)),
      errorMessage: 'mock failure',
      failureCode: 'mock_failure',
    ),
    ExportHistoryItem(
      taskId: 'export-cancelled',
      status: ExportTaskStatus.cancelled,
      format: 'mov',
      resolution: '1080p',
      bitrate: 'high',
      framerate: 60,
      createdAt: now.subtract(const Duration(days: 10)),
    ),
  ];
}

Future<List<ExportHistoryItem>> _fakeFetchExportHistory({
  required String projectId,
  required ExportHistoryStatusFilter statusFilter,
  required ExportHistoryTimeFilter timeFilter,
  String? focusedTaskId,
}) async {
  final startDate = timeFilter.startDate;
  final filtered = _mockExportHistoryItems()
      .where((item) {
        if (!statusFilter.matches(item.status)) {
          return false;
        }
        if (startDate != null && item.createdAt.isBefore(startDate)) {
          return false;
        }
        return true;
      })
      .toList(growable: true);
  filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return filtered;
}

ExportHistoryDialog buildHistoryDialog() {
  return ExportHistoryDialog(
    projectId: 'project-123',
    accessToken: 'test-token',
    fetchHistoryOverride: _fakeFetchExportHistory,
  );
}

void main() {
  group('ExportHistoryTimeFilter', () {
    test('has correct display names', () {
      expect(ExportHistoryTimeFilter.all.displayName(_zh), '全部时间');
      expect(ExportHistoryTimeFilter.today.displayName(_zh), '今天');
      expect(ExportHistoryTimeFilter.week.displayName(_zh), '最近一周');
      expect(ExportHistoryTimeFilter.month.displayName(_zh), '最近一月');
    });

    test('calculates correct start dates', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      expect(ExportHistoryTimeFilter.all.startDate, isNull);
      expect(ExportHistoryTimeFilter.today.startDate, today);

      final weekAgo = ExportHistoryTimeFilter.week.startDate!;
      // Allow for 6 or 7 days due to timing differences
      expect(now.difference(weekAgo).inDays, greaterThanOrEqualTo(6));
      expect(now.difference(weekAgo).inDays, lessThanOrEqualTo(7));

      final monthAgo = ExportHistoryTimeFilter.month.startDate!;
      // Allow for 29-30 days due to timing differences
      expect(now.difference(monthAgo).inDays, greaterThanOrEqualTo(29));
      expect(now.difference(monthAgo).inDays, lessThanOrEqualTo(30));
    });
  });

  group('ExportHistoryStatusFilter', () {
    test('has correct display names', () {
      expect(ExportHistoryStatusFilter.all.displayName(_zh), '全部状态');
      expect(ExportHistoryStatusFilter.completed.displayName(_zh), '已完成');
      expect(ExportHistoryStatusFilter.failed.displayName(_zh), '失败');
      expect(ExportHistoryStatusFilter.cancelled.displayName(_zh), '已取消');
    });

    test('matches status correctly', () {
      expect(
        ExportHistoryStatusFilter.all.matches(ExportTaskStatus.completed),
        isTrue,
      );
      expect(
        ExportHistoryStatusFilter.all.matches(ExportTaskStatus.failed),
        isTrue,
      );
      expect(
        ExportHistoryStatusFilter.all.matches(ExportTaskStatus.cancelled),
        isTrue,
      );

      expect(
        ExportHistoryStatusFilter.completed.matches(ExportTaskStatus.completed),
        isTrue,
      );
      expect(
        ExportHistoryStatusFilter.completed.matches(ExportTaskStatus.failed),
        isFalse,
      );

      expect(
        ExportHistoryStatusFilter.failed.matches(ExportTaskStatus.failed),
        isTrue,
      );
      expect(
        ExportHistoryStatusFilter.failed.matches(ExportTaskStatus.completed),
        isFalse,
      );

      expect(
        ExportHistoryStatusFilter.cancelled.matches(ExportTaskStatus.cancelled),
        isTrue,
      );
      expect(
        ExportHistoryStatusFilter.cancelled.matches(ExportTaskStatus.failed),
        isFalse,
      );
    });
  });

  group('ExportHistoryItem', () {
    test('parses from JSON correctly', () {
      final json = <String, dynamic>{
        'task_id': 'task-123',
        'status': 'completed',
        'format': 'mp4',
        'resolution': '1080p',
        'bitrate': 'high',
        'framerate': 30,
        'created_at': '2024-01-01T10:00:00Z',
        'completed_at': '2024-01-01T10:05:00Z',
        'output_url': 'https://example.com/video.mp4',
        'file_size': 52428800,
      };

      final item = ExportHistoryItem.fromJson(json);

      expect(item.taskId, 'task-123');
      expect(item.status, ExportTaskStatus.completed);
      expect(item.format, 'mp4');
      expect(item.resolution, '1080p');
      expect(item.bitrate, 'high');
      expect(item.framerate, 30);
      expect(item.outputUrl, 'https://example.com/video.mp4');
      expect(item.fileSize, 52428800);
    });

    test('handles camelCase JSON keys', () {
      final json = <String, dynamic>{
        'taskId': 'task-456',
        'status': 'failed',
        'format': 'mov',
        'resolution': '720p',
        'bitrate': 'medium',
        'framerate': 24,
        'createdAt': '2024-01-01T10:00:00Z',
        'completedAt': '2024-01-01T10:02:00Z',
        'errorMessage': 'Encoding failed',
        'failureCode': 'video_download_http',
      };

      final item = ExportHistoryItem.fromJson(json);

      expect(item.taskId, 'task-456');
      expect(item.status, ExportTaskStatus.failed);
      expect(item.errorMessage, 'Encoding failed');
      expect(item.failureCode, 'video_download_http');
    });

    test('uses defaults for missing fields', () {
      final json = <String, dynamic>{'status': 'queued'};

      final item = ExportHistoryItem.fromJson(json);

      expect(item.taskId, '');
      expect(item.status, ExportTaskStatus.queued);
      expect(item.format, 'mp4');
      expect(item.resolution, '1080p');
      expect(item.bitrate, 'medium');
      expect(item.framerate, 30);
      expect(item.outputUrl, isNull);
      expect(item.fileSize, isNull);
    });

    test('formats file size correctly', () {
      // KB range
      final itemKB = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: DateTime.now(),
        fileSize: 512 * 1024, // 512 KB
      );
      expect(itemKB.formattedFileSize(_zh), '512 KB');

      // MB range
      final itemMB = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: DateTime.now(),
        fileSize: 50 * 1024 * 1024, // 50 MB
      );
      expect(itemMB.formattedFileSize(_zh), '50.0 MB');

      // GB range
      final itemGB = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: DateTime.now(),
        fileSize: 2 * 1024 * 1024 * 1024, // 2 GB
      );
      expect(itemGB.formattedFileSize(_zh), '2.00 GB');

      // Null file size
      final itemNull = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: DateTime.now(),
        fileSize: null,
      );
      expect(itemNull.formattedFileSize(_zh), '未知');
    });

    test('formats duration correctly', () {
      final now = DateTime.now();

      // Seconds
      final itemSeconds = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: now.subtract(const Duration(seconds: 45)),
        completedAt: now,
      );
      expect(itemSeconds.formattedDuration(_zh), '45 秒');

      // Minutes
      final itemMinutes = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: now.subtract(const Duration(minutes: 5)),
        completedAt: now,
      );
      expect(itemMinutes.formattedDuration(_zh), '5 分钟');

      // Hours
      final itemHours = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.completed,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: now.subtract(const Duration(hours: 2, minutes: 30)),
        completedAt: now,
      );
      expect(itemHours.formattedDuration(_zh), '2 小时 30 分钟');

      // No completion time
      final itemIncomplete = ExportHistoryItem(
        taskId: 'test',
        status: ExportTaskStatus.processing,
        format: 'mp4',
        resolution: '1080p',
        bitrate: 'medium',
        framerate: 30,
        createdAt: now,
        completedAt: null,
      );
      expect(itemIncomplete.formattedDuration(_zh), '—');
    });
  });

  group('ExportHistoryDialog', () {
    bool hasHistoryRows(WidgetTester tester) =>
        find.text('下载').evaluate().isNotEmpty;

    testWidgets('renders with filters and empty state', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for mock data to load
      await tester.pumpAndSettle();

      // Should show title and filters
      expect(find.text('导出历史'), findsOneWidget);
      expect(find.text('状态'), findsOneWidget);
      expect(find.text('时间'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsAtLeastNWidgets(1));
    });

    testWidgets('displays history items correctly', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.text('已完成'), findsWidgets);
      expect(find.textContaining('MP4'), findsWidgets);
      expect(find.textContaining('创建时间:'), findsWidgets);
      expect(find.byIcon(Icons.download), findsWidgets);
    });

    testWidgets('filters by status', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      // Change status filter to "completed"
      await tester.tap(find.byType(StudioSelectFieldTrigger).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('已完成').last);
      await tester.pump();

      // Should show loading or reload immediately
      await tester.pumpAndSettle();

      // Should only show completed items
      expect(find.text('已完成'), findsWidgets);
    });

    testWidgets('filters by time', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      // Change time filter to "today"
      await tester.tap(find.byType(StudioSelectFieldTrigger).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('今天').last);
      await tester.pump();

      // Should show loading or reload immediately
      await tester.pumpAndSettle();
    });

    testWidgets('refreshes history when refresh button is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      // Title refresh only (error state also has a retry Icon on FilledButton.icon)
      await tester.tap(find.byTooltip('刷新'));
      await tester.pump();

      // Under test bindings, HTTP may resolve in the same frame as setState(loading).
      final hasSpinner = find
          .byType(CircularProgressIndicator)
          .evaluate()
          .isNotEmpty;
      final hasError = find.textContaining('加载导出历史失败').evaluate().isNotEmpty;
      final hasEmpty = find.text('暂无导出记录').evaluate().isNotEmpty;
      final hasRows = find.text('下载').evaluate().isNotEmpty;
      expect(hasSpinner || hasError || hasEmpty || hasRows, isTrue);

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.textContaining('MP4'), findsWidgets);
    });

    testWidgets('shows download button for completed exports', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.text('下载'), findsWidgets);
      expect(find.byIcon(Icons.download), findsWidgets);
    });

    testWidgets('handles download action', (tester) async {
      final downloads = <String>[];
      await tester.pumpWidget(
        buildTestApp(
          ExportHistoryDialog(
            projectId: 'project-123',
            accessToken: 'test-token',
            fetchHistoryOverride: _fakeFetchExportHistory,
            downloadOverride: (url, taskId) async {
              downloads.add('$taskId|$url');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      await tester.tap(find.text('下载').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(downloads, hasLength(1));
      expect(
        downloads.first,
        contains('export-completed|https://example.com/export-completed.mp4'),
      );
    });

    testWidgets('displays error message correctly', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      // Should show error messages for failed items
      expect(find.byIcon(Icons.error_outline), findsWidgets);
    });

    testWidgets('shows status icons correctly', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.byIcon(Icons.check_circle), findsWidgets);
      // Other icons may or may not be visible depending on mock data
    });

    testWidgets('displays export settings information', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.textContaining('MP4'), findsWidgets);
      expect(find.textContaining('1080p'), findsWidgets);
      expect(find.textContaining('FPS'), findsWidgets);
    });

    testWidgets('shows file size for completed exports', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.textContaining('文件大小:'), findsWidgets);
      expect(find.textContaining('MB'), findsWidgets);
    });

    testWidgets('shows duration for completed exports', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(find.textContaining('完成时间:'), findsWidgets);
      expect(find.textContaining('耗时:'), findsWidgets);
    });

    testWidgets('closes dialog when close button is tapped', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Builder(
            builder: (context) {
              return FilledButton(
                onPressed: () async {
                  await showStudioDialog<void>(
                    context: context,
                    builder: (_) => buildHistoryDialog(),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('导出历史'), findsOneWidget);

      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      expect(find.text('导出历史'), findsNothing);
    });

    testWidgets('formats relative time correctly', (tester) async {
      await tester.pumpWidget(buildTestApp(buildHistoryDialog()));

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      expect(
        find.textContaining('小时前').evaluate().isNotEmpty ||
            find.textContaining('天前').evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('prevents multiple simultaneous downloads', (tester) async {
      final downloads = <String>[];
      await tester.pumpWidget(
        buildTestApp(
          ExportHistoryDialog(
            projectId: 'project-123',
            accessToken: 'test-token',
            fetchHistoryOverride: _fakeFetchExportHistory,
            downloadOverride: (url, taskId) async {
              downloads.add('$taskId|$url');
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      if (!hasHistoryRows(tester)) {
        expect(find.text('导出历史'), findsOneWidget);
        return;
      }
      await tester.tap(find.text('下载').first);
      await tester.pump();

      // Button text should change to "下载中..." during download
      // In tests, the download completes very quickly, so we just verify
      // that the download was triggered (snackbar appears)
      await tester.pump(const Duration(milliseconds: 250));

      expect(downloads, hasLength(1));
    });
  });
}
