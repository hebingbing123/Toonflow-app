import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/components/batch_operation_toolbar.dart';

Finder findShotSelectionTapTarget() => find.byType(ShotSelectionCheckbox);

void main() {
  group('BatchOperationToolbar', () {
    testWidgets('displays correct selected count', (WidgetTester tester) async {
      final selectedIds = <int>{1, 2, 3};

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: selectedIds,
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      expect(find.text('已选择: 3 / 10'), findsOneWidget);
    });

    testWidgets('shows select all button when not all selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      expect(find.text('全选'), findsOneWidget);
      expect(find.byIcon(Icons.select_all), findsOneWidget);
    });

    testWidgets('shows deselect all button when all selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 3,
              selectedIds: const {1, 2, 3},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      expect(find.text('取消全选'), findsOneWidget);
      expect(find.byIcon(Icons.deselect), findsOneWidget);
    });

    testWidgets('calls onSelectAll when select all button is tapped', (
      WidgetTester tester,
    ) async {
      var selectAllCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {},
              onSelectionChanged: (_) {},
              onSelectAll: () {
                selectAllCalled = true;
              },
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('全选'));
      expect(selectAllCalled, isTrue);
    });

    testWidgets('calls onDeselectAll when deselect all button is tapped', (
      WidgetTester tester,
    ) async {
      var deselectAllCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 3,
              selectedIds: const {1, 2, 3},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {
                deselectAllCalled = true;
              },
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('取消全选'));
      expect(deselectAllCalled, isTrue);
    });

    testWidgets('shows batch operation buttons only when items are selected', (
      WidgetTester tester,
    ) async {
      // Test with no selection
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      expect(find.text('批量启用'), findsNothing);
      expect(find.text('批量禁用'), findsNothing);
      expect(find.text('时长对齐'), findsNothing);
      expect(find.text('批量替换'), findsNothing);
      expect(find.text('批量配音'), findsNothing);

      // Test with selection
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      expect(find.text('批量启用'), findsOneWidget);
      expect(find.text('批量禁用'), findsOneWidget);
      expect(find.text('时长对齐'), findsOneWidget);
      expect(find.text('批量替换'), findsOneWidget);
      expect(find.text('批量配音'), findsOneWidget);
    });

    testWidgets('calls onBatchEnable when batch enable button is tapped', (
      WidgetTester tester,
    ) async {
      var batchEnableCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {
                batchEnableCalled = true;
              },
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('批量启用'));
      expect(batchEnableCalled, isTrue);
    });

    testWidgets('calls onBatchDisable when batch disable button is tapped', (
      WidgetTester tester,
    ) async {
      var batchDisableCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {
                batchDisableCalled = true;
              },
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('批量禁用'));
      expect(batchDisableCalled, isTrue);
    });

    testWidgets('calls onBatchUpdateDuration when duration button is tapped', (
      WidgetTester tester,
    ) async {
      var batchUpdateDurationCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {
                batchUpdateDurationCalled = true;
              },
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('时长对齐'));
      expect(batchUpdateDurationCalled, isTrue);
    });

    testWidgets('calls onBatchReplace when replace button is tapped', (
      WidgetTester tester,
    ) async {
      var batchReplaceCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {
                batchReplaceCalled = true;
              },
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('批量替换'));
      expect(batchReplaceCalled, isTrue);
    });

    testWidgets(
      'calls onBatchGenerateVoiceover when voiceover button is tapped',
      (WidgetTester tester) async {
        var batchGenerateVoiceoverCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BatchOperationToolbar(
                totalCount: 10,
                selectedIds: const {1, 2},
                onSelectionChanged: (_) {},
                onSelectAll: () {},
                onDeselectAll: () {},
                onBatchEnable: () {},
                onBatchDisable: () {},
                onBatchUpdateDuration: () {},
                onBatchReplace: () {},
                onBatchGenerateVoiceover: () {
                  batchGenerateVoiceoverCalled = true;
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('批量配音'));
        expect(batchGenerateVoiceoverCalled, isTrue);
      },
    );

    testWidgets('disables all buttons when operation is in progress', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
              isOperationInProgress: true,
            ),
          ),
        ),
      );

      // Find all buttons and verify they are disabled
      final selectAllButton = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('全选'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ),
      );
      expect(selectAllButton.onPressed, isNull);

      final batchEnableButton = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('批量启用'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ),
      );
      expect(batchEnableButton.onPressed, isNull);

      final batchDisableButton = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('批量禁用'),
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ),
      );
      expect(batchDisableButton.onPressed, isNull);
    });

    testWidgets('shows loading indicator when operation is in progress', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
              isOperationInProgress: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('checkbox is checked when all items are selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 3,
              selectedIds: const {1, 2, 3},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('checkbox is unchecked when no items are selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 3,
              selectedIds: const {},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('throttles batch operations with 1000ms delay', (
      WidgetTester tester,
    ) async {
      var batchEnableCallCount = 0;
      var currentTime = DateTime(2026, 1, 1, 0, 0, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {
                batchEnableCallCount++;
              },
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
              nowProvider: () => currentTime,
            ),
          ),
        ),
      );

      // First tap should succeed
      await tester.tap(find.text('批量启用'));
      await tester.pump();
      expect(batchEnableCallCount, 1);

      // Second tap within 1000ms should be throttled
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('批量启用'));
      await tester.pump();
      expect(batchEnableCallCount, 1); // Still 1, not incremented

      // Third tap after 1000ms should succeed
      currentTime = currentTime.add(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('批量启用'));
      await tester.pump();
      expect(batchEnableCallCount, 2);
    });

    testWidgets('shows throttle message when operation is throttled', (
      WidgetTester tester,
    ) async {
      final currentTime = DateTime(2026, 1, 1, 0, 0, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {},
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
              nowProvider: () => currentTime,
            ),
          ),
        ),
      );

      // First tap
      await tester.tap(find.text('批量启用'));
      await tester.pump();

      // Second tap within 1000ms should show throttle message
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('批量启用'));
      await tester.pump();

      expect(find.text('操作过于频繁，请稍后再试'), findsOneWidget);
    });

    testWidgets('throttles different batch operations independently', (
      WidgetTester tester,
    ) async {
      var batchEnableCallCount = 0;
      var batchDisableCallCount = 0;
      var currentTime = DateTime(2026, 1, 1, 0, 0, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {
                batchEnableCallCount++;
              },
              onBatchDisable: () {
                batchDisableCallCount++;
              },
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
              nowProvider: () => currentTime,
            ),
          ),
        ),
      );

      // Tap batch enable
      await tester.tap(find.text('批量启用'));
      await tester.pump();
      expect(batchEnableCallCount, 1);

      // Tap batch disable within 1000ms - should also be throttled
      // because throttle is shared across all batch operations
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('批量禁用'));
      await tester.pump();
      expect(batchDisableCallCount, 0); // Throttled

      // After 1000ms from first operation, batch disable should work
      currentTime = currentTime.add(const Duration(milliseconds: 1100));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('批量禁用'));
      await tester.pump();
      expect(batchDisableCallCount, 1);
    });

    testWidgets('does not throttle when operation is in progress', (
      WidgetTester tester,
    ) async {
      var batchEnableCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationToolbar(
              totalCount: 10,
              selectedIds: const {1, 2},
              onSelectionChanged: (_) {},
              onSelectAll: () {},
              onDeselectAll: () {},
              onBatchEnable: () {
                batchEnableCallCount++;
              },
              onBatchDisable: () {},
              onBatchUpdateDuration: () {},
              onBatchReplace: () {},
              onBatchGenerateVoiceover: () {},
              isOperationInProgress: true,
            ),
          ),
        ),
      );

      // Tap should not work because operation is in progress
      await tester.tap(find.text('批量启用'));
      await tester.pump();
      expect(batchEnableCallCount, 0);
    });
  });

  group('ShotSelectionCheckbox', () {
    testWidgets('displays checkbox with correct state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShotSelectionCheckbox(
              shotId: 1,
              isSelected: true,
              onSelectionChanged: (_) {},
              onRangeSelection: (shotId, isShiftPressed) {},
            ),
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('calls onSelectionChanged when tapped without Shift', (
      WidgetTester tester,
    ) async {
      var selectionChanged = false;
      var newValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShotSelectionCheckbox(
              shotId: 1,
              isSelected: false,
              onSelectionChanged: (value) {
                selectionChanged = true;
                newValue = value;
              },
              onRangeSelection: (shotId, isShiftPressed) {},
            ),
          ),
        ),
      );

      await tester.tap(findShotSelectionTapTarget());
      expect(selectionChanged, isTrue);
      expect(newValue, isTrue);
    });

    testWidgets('calls onRangeSelection when tapped with Shift', (
      WidgetTester tester,
    ) async {
      var rangeSelectionCalled = false;
      var shotId = 0;
      var isShiftPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShotSelectionCheckbox(
              shotId: 5,
              isSelected: false,
              onSelectionChanged: (_) {},
              onRangeSelection: (id, shift) {
                rangeSelectionCalled = true;
                shotId = id;
                isShiftPressed = shift;
              },
            ),
          ),
        ),
      );

      final focus = tester.widget<Focus>(
        find.descendant(
          of: find.byType(ShotSelectionCheckbox),
          matching: find.byType(Focus),
        ).first,
      );
      focus.onKeyEvent?.call(
        FocusNode(),
        const KeyDownEvent(
          timeStamp: Duration.zero,
          logicalKey: LogicalKeyboardKey.shiftLeft,
          physicalKey: PhysicalKeyboardKey.shiftLeft,
        ),
      );
      await tester.pump();
      final gestureDetector = tester.widget<GestureDetector>(
        find.descendant(
          of: find.byType(ShotSelectionCheckbox),
          matching: find.byType(GestureDetector),
        ).first,
      );
      gestureDetector.onTap?.call();

      expect(rangeSelectionCalled, isTrue);
      expect(shotId, equals(5));
      expect(isShiftPressed, isTrue);
    });

    testWidgets('does not respond to tap when disabled', (
      WidgetTester tester,
    ) async {
      var selectionChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShotSelectionCheckbox(
              shotId: 1,
              isSelected: false,
              onSelectionChanged: (_) {
                selectionChanged = true;
              },
              onRangeSelection: (shotId, isShiftPressed) {},
              isEnabled: false,
            ),
          ),
        ),
      );

      await tester.tap(findShotSelectionTapTarget());
      expect(selectionChanged, isFalse);
    });

    testWidgets('handles space key for accessibility', (
      WidgetTester tester,
    ) async {
      var selectionChanged = false;
      var newValue = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShotSelectionCheckbox(
              shotId: 1,
              isSelected: false,
              onSelectionChanged: (value) {
                selectionChanged = true;
                newValue = value;
              },
              onRangeSelection: (shotId, isShiftPressed) {},
            ),
          ),
        ),
      );

      // Focus the widget
      await tester.tap(findShotSelectionTapTarget());
      await tester.pumpAndSettle();

      // Press space key
      await tester.sendKeyEvent(LogicalKeyboardKey.space);

      expect(selectionChanged, isTrue);
      expect(newValue, isTrue);
    });
  });

  group('BatchOperationProgressDialog', () {
    testWidgets('displays progress information correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 10,
              completed: 5,
              successful: 4,
              failed: 1,
            ),
          ),
        ),
      );

      expect(find.text('批量启用镜头'), findsOneWidget);
      expect(find.text('进度: 5 / 10'), findsOneWidget);
      expect(find.text('成功: 4'), findsOneWidget);
      expect(find.text('失败: 1'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('displays failed items list when present', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 10,
              completed: 10,
              successful: 8,
              failed: 2,
              failedItems: const [
                BatchOperationFailedItem(shotId: 3, errorMessage: '视频 URL 无效'),
                BatchOperationFailedItem(shotId: 7, errorMessage: '网络连接失败'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('失败项:'), findsOneWidget);
      expect(find.text('分镜 #3'), findsOneWidget);
      expect(find.text('视频 URL 无效'), findsOneWidget);
      expect(find.text('分镜 #7'), findsOneWidget);
      expect(find.text('网络连接失败'), findsOneWidget);
    });

    testWidgets('shows cancel button when operation is not complete', (
      WidgetTester tester,
    ) async {
      var cancelCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 10,
              completed: 5,
              successful: 5,
              failed: 0,
              isComplete: false,
              onCancel: () {
                cancelCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      expect(cancelCalled, isTrue);
    });

    testWidgets('shows retry button when operation is complete with failures', (
      WidgetTester tester,
    ) async {
      var retryFailedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 10,
              completed: 10,
              successful: 8,
              failed: 2,
              isComplete: true,
              failedItems: const [
                BatchOperationFailedItem(shotId: 3, errorMessage: '视频 URL 无效'),
              ],
              onRetryFailed: () {
                retryFailedCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('重试失败项'), findsOneWidget);

      await tester.tap(find.text('重试失败项'));
      expect(retryFailedCalled, isTrue);
    });

    testWidgets('shows close button when operation is complete', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 10,
              completed: 10,
              successful: 10,
              failed: 0,
              isComplete: true,
            ),
          ),
        ),
      );

      expect(find.text('关闭'), findsOneWidget);
    });

    testWidgets('calculates progress correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 10,
              completed: 5,
              successful: 5,
              failed: 0,
            ),
          ),
        ),
      );

      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.5));
    });

    testWidgets('handles zero total gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchOperationProgressDialog(
              title: '批量启用镜头',
              total: 0,
              completed: 0,
              successful: 0,
              failed: 0,
            ),
          ),
        ),
      );

      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progressIndicator.value, equals(0.0));
    });
  });
}
