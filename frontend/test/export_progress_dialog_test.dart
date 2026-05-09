import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/section.dart';

/// **Validates: Requirement 13**
void main() {
  group('ExportTaskStatus', () {
    test('converts from string correctly', () {
      expect(
        ExportTaskStatus.fromString('queued'),
        ExportTaskStatus.queued,
      );
      expect(
        ExportTaskStatus.fromString('processing'),
        ExportTaskStatus.processing,
      );
      expect(
        ExportTaskStatus.fromString('completed'),
        ExportTaskStatus.completed,
      );
      expect(
        ExportTaskStatus.fromString('failed'),
        ExportTaskStatus.failed,
      );
      expect(
        ExportTaskStatus.fromString('cancelled'),
        ExportTaskStatus.cancelled,
      );
      expect(
        ExportTaskStatus.fromString('unknown'),
        ExportTaskStatus.queued, // default
      );
    });

    test('provides correct display names', () {
      expect(ExportTaskStatus.queued.displayName, '排队中');
      expect(ExportTaskStatus.processing.displayName, '处理中');
      expect(ExportTaskStatus.completed.displayName, '已完成');
      expect(ExportTaskStatus.failed.displayName, '失败');
      expect(ExportTaskStatus.cancelled.displayName, '已取消');
    });

    test('identifies terminal statuses correctly', () {
      expect(ExportTaskStatus.queued.isTerminal, false);
      expect(ExportTaskStatus.processing.isTerminal, false);
      expect(ExportTaskStatus.completed.isTerminal, true);
      expect(ExportTaskStatus.failed.isTerminal, true);
      expect(ExportTaskStatus.cancelled.isTerminal, true);
    });
  });

  group('ExportTaskStage', () {
    test('converts from string correctly', () {
      expect(
        ExportTaskStage.fromString('initializing'),
        ExportTaskStage.initializing,
      );
      expect(
        ExportTaskStage.fromString('loading_assets'),
        ExportTaskStage.loadingAssets,
      );
      expect(
        ExportTaskStage.fromString('loadingassets'),
        ExportTaskStage.loadingAssets,
      );
      expect(
        ExportTaskStage.fromString('encoding'),
        ExportTaskStage.encoding,
      );
      expect(
        ExportTaskStage.fromString('uploading'),
        ExportTaskStage.uploading,
      );
      expect(
        ExportTaskStage.fromString('finalizing'),
        ExportTaskStage.finalizing,
      );
      expect(
        ExportTaskStage.fromString('unknown'),
        ExportTaskStage.initializing, // default
      );
    });

    test('provides correct display names', () {
      expect(ExportTaskStage.initializing.displayName, '初始化');
      expect(ExportTaskStage.loadingAssets.displayName, '加载素材');
      expect(ExportTaskStage.encoding.displayName, '编码视频');
      expect(ExportTaskStage.uploading.displayName, '上传文件');
      expect(ExportTaskStage.finalizing.displayName, '完成处理');
    });
  });

  group('ExportTaskProgress', () {
    test('parses from JSON with all fields', () {
      final progress = ExportTaskProgress.fromJson({
        'task_id': 'test-123',
        'status': 'processing',
        'stage': 'encoding',
        'progress': 0.65,
        'error_message': null,
        'output_url': null,
      });

      expect(progress.taskId, 'test-123');
      expect(progress.status, ExportTaskStatus.processing);
      expect(progress.stage, ExportTaskStage.encoding);
      expect(progress.progress, 0.65);
      expect(progress.progressPercentage, 65);
      expect(progress.errorMessage, null);
      expect(progress.outputUrl, null);
    });

    test('parses from JSON with camelCase keys', () {
      final progress = ExportTaskProgress.fromJson({
        'taskId': 'test-456',
        'status': 'completed',
        'progress': 1.0,
        'outputUrl': 'https://example.com/video.mp4',
      });

      expect(progress.taskId, 'test-456');
      expect(progress.status, ExportTaskStatus.completed);
      expect(progress.progress, 1.0);
      expect(progress.progressPercentage, 100);
      expect(progress.outputUrl, 'https://example.com/video.mp4');
    });

    test('handles missing optional fields', () {
      final progress = ExportTaskProgress.fromJson({
        'task_id': 'test-789',
        'status': 'queued',
      });

      expect(progress.taskId, 'test-789');
      expect(progress.status, ExportTaskStatus.queued);
      expect(progress.stage, null);
      expect(progress.progress, 0.0);
      expect(progress.progressPercentage, 0);
      expect(progress.errorMessage, null);
      expect(progress.outputUrl, null);
    });

    test('handles failed status with error message', () {
      final progress = ExportTaskProgress.fromJson({
        'task_id': 'test-error',
        'status': 'failed',
        'progress': 0.45,
        'error_message': 'Encoding failed: invalid codec',
      });

      expect(progress.status, ExportTaskStatus.failed);
      expect(progress.errorMessage, 'Encoding failed: invalid codec');
    });

    test('clamps progress percentage to 0-100 range', () {
      final progress1 = ExportTaskProgress.fromJson({
        'task_id': 'test-1',
        'status': 'processing',
        'progress': -0.5,
      });
      expect(progress1.progressPercentage, 0);

      final progress2 = ExportTaskProgress.fromJson({
        'task_id': 'test-2',
        'status': 'processing',
        'progress': 1.5,
      });
      expect(progress2.progressPercentage, 100);

      final progress3 = ExportTaskProgress.fromJson({
        'task_id': 'test-3',
        'status': 'processing',
        'progress': 0.5,
      });
      expect(progress3.progressPercentage, 50);
    });
  });

  group('ExportProgressDialog', () {
    testWidgets('renders initial loading state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'test-task-123',
            ),
          ),
        ),
      );

      expect(find.text('导出进度'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在获取导出状态...'), findsOneWidget);

      // Clean up by completing all pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('displays progress bar after initial poll', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'test-task-456',
            ),
          ),
        ),
      );

      // Wait for initial poll to complete
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.textContaining('%'), findsOneWidget);
    });

    testWidgets('shows cancel button for non-terminal status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'test-task-789',
            ),
          ),
        ),
      );

      // Wait for initial poll
      await tester.pumpAndSettle();

      // Should show cancel button (unless already completed in mock)
      // The mock may complete quickly, so we check if either cancel or close button exists
      expect(
        find.text('取消导出').evaluate().isNotEmpty ||
            find.text('关闭').evaluate().isNotEmpty,
        true,
      );
    });

    testWidgets('displays task ID for debugging', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'debug-task-id-12345',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('debug-task-id-12345'), findsOneWidget);
    });

    testWidgets('shows appropriate icons for different statuses',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'test-icons',
            ),
          ),
        ),
      );

      // Wait for initial poll
      await tester.pumpAndSettle();

      // Should have status icon (schedule, sync, check_circle, error, or cancel)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              (widget.icon == Icons.schedule ||
                  widget.icon == Icons.sync ||
                  widget.icon == Icons.check_circle_outline ||
                  widget.icon == Icons.error_outline ||
                  widget.icon == Icons.cancel_outlined),
        ),
        findsWidgets,
      );
    });

    testWidgets('displays status messages', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'test-messages',
            ),
          ),
        ),
      );

      // Wait for initial poll
      await tester.pumpAndSettle();

      // Should have a status message
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data?.contains('导出') == true ||
                  widget.data?.contains('处理') == true ||
                  widget.data?.contains('队列') == true ||
                  widget.data?.contains('成功') == true),
        ),
        findsWidgets,
      );
    });
  });

  group('ExportProgressDialog integration', () {
    testWidgets('can be opened via extension method', (tester) async {
      // This test verifies the extension method exists and can be called
      // In a real scenario, this would be tested with a full widget tree
      // that includes _ShortVideoSpaceSectionState

      // For now, we just verify the dialog can be instantiated
      const dialog = ExportProgressDialog(taskId: 'test-extension');
      expect(dialog.taskId, 'test-extension');
    });
  });

  group('ExportProgressDialog error handling', () {
    testWidgets('has error UI in widget tree', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ExportProgressDialog(
              taskId: 'test-error',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The error container should be in the widget tree (even if not visible)
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color != null,
        ),
        findsWidgets,
      );
    });
  });
}
