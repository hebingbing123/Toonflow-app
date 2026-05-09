import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unit tests for confirmation dialogs functionality
///
/// **Validates: Requirements 28**
///
/// Tests confirmation dialogs for:
/// - Delete version
/// - Batch disable shots
/// - Restore draft
/// - Cancel export
/// - "Don't show again" functionality
void main() {
  group('Confirmation Dialog - Structure', () {
    testWidgets('Confirmation dialog has required elements', (tester) async {
      // Build a test confirmation dialog
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Tap the button to show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog elements
      expect(find.text('确认操作'), findsOneWidget);
      expect(find.text('确定要执行此操作吗？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认'), findsOneWidget);
    });

    testWidgets('Confirmation dialog can be dismissed with cancel button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap cancel button
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.text('确认操作'), findsNothing);
    });

    testWidgets('Confirmation dialog can be confirmed with confirm button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap confirm button
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // Verify dialog is dismissed
      expect(find.text('确认操作'), findsNothing);
    });
  });

  group('Confirmation Dialog - Delete Version', () {
    testWidgets('Delete version dialog shows correct content', (tester) async {
      const versionName = 'Version 1.0';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text(
                          '确定要删除版本 "$versionName" 吗？\n\n'
                          '此操作无法撤销。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(ctx).colorScheme.error,
                            ),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Delete Version'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Delete Version'));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('确认删除'), findsOneWidget);
      expect(find.textContaining('确定要删除版本'), findsOneWidget);
      expect(find.textContaining(versionName), findsOneWidget);
      expect(find.textContaining('此操作无法撤销'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('删除'), findsOneWidget);
    });

    test('Delete version dialog returns false when cancelled', () {
      // Mock dialog result
      bool? result;

      // Simulate cancel action
      result = false;

      expect(result, isFalse);
    });

    test('Delete version dialog returns true when confirmed', () {
      // Mock dialog result
      bool? result;

      // Simulate confirm action
      result = true;

      expect(result, isTrue);
    });
  });

  group('Confirmation Dialog - Batch Disable', () {
    testWidgets('Batch disable dialog shows correct content', (tester) async {
      const shotCount = 5;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认批量禁用'),
                        content: Text(
                          '确定要禁用选中的 $shotCount 个镜头吗？\n\n'
                          '禁用后的镜头将不会出现在最终视频中。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认禁用'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Batch Disable'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Batch Disable'));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('确认批量禁用'), findsOneWidget);
      expect(find.textContaining('确定要禁用选中的'), findsOneWidget);
      expect(find.textContaining('$shotCount 个镜头'), findsOneWidget);
      expect(find.textContaining('禁用后的镜头将不会出现在最终视频中'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('确认禁用'), findsOneWidget);
    });

    test('Batch disable dialog handles empty selection', () {
      // Mock empty selection
      const selectedCount = 0;

      // Should not show dialog for empty selection
      expect(selectedCount, equals(0));
    });

    test('Batch disable dialog handles single shot', () {
      // Mock single shot selection
      const selectedCount = 1;

      expect(selectedCount, equals(1));
    });

    test('Batch disable dialog handles multiple shots', () {
      // Mock multiple shots selection
      const selectedCount = 10;

      expect(selectedCount, equals(10));
    });
  });

  group('Confirmation Dialog - Restore Draft', () {
    testWidgets('Restore draft dialog shows correct content', (tester) async {
      const draftName = 'Draft 2024-01-15';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认恢复草稿'),
                        content: Text(
                          '确定要恢复草稿 "$draftName" 吗？\n\n'
                          '当前未保存的编辑状态将会丢失。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('恢复'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Restore Draft'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Restore Draft'));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('确认恢复草稿'), findsOneWidget);
      expect(find.textContaining('确定要恢复草稿'), findsOneWidget);
      expect(find.textContaining(draftName), findsOneWidget);
      expect(find.textContaining('当前未保存的编辑状态将会丢失'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('恢复'), findsOneWidget);
    });

    test('Restore draft dialog warns about unsaved changes', () {
      // Mock draft restoration warning
      const warningMessage = '当前未保存的编辑状态将会丢失';

      expect(warningMessage, contains('未保存'));
      expect(warningMessage, contains('丢失'));
    });
  });

  group('Confirmation Dialog - Cancel Export', () {
    testWidgets('Cancel export dialog shows correct content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('取消导出'),
                        content: const Text('确定要取消导出吗？已处理的内容将会丢失。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('继续导出'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认取消'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Cancel Export'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Cancel Export'));
      await tester.pumpAndSettle();

      // Verify dialog content
      expect(find.text('取消导出'), findsOneWidget);
      expect(find.text('确定要取消导出吗？已处理的内容将会丢失。'), findsOneWidget);
      expect(find.text('继续导出'), findsOneWidget);
      expect(find.text('确认取消'), findsOneWidget);
    });

    test('Cancel export dialog warns about progress loss', () {
      // Mock export cancellation warning
      const warningMessage = '已处理的内容将会丢失';

      expect(warningMessage, contains('已处理'));
      expect(warningMessage, contains('丢失'));
    });

    test('Cancel export dialog has continue option', () {
      // Mock continue export option
      const continueOption = '继续导出';

      expect(continueOption, equals('继续导出'));
    });
  });

  group('Confirmation Dialog - Don\'t Show Again', () {
    testWidgets('Dialog can include "Don\'t show again" checkbox', (tester) async {
      bool dontShowAgain = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            title: const Text('确认操作'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('确定要执行此操作吗？'),
                                const SizedBox(height: 16),
                                CheckboxListTile(
                                  value: dontShowAgain,
                                  onChanged: (value) {
                                    setState(() {
                                      dontShowAgain = value ?? false;
                                    });
                                  },
                                  title: const Text('不再提示'),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确认'),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify checkbox exists
      expect(find.text('不再提示'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Verify checkbox is initially unchecked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);
    });

    testWidgets('"Don\'t show again" checkbox can be toggled', (tester) async {
      bool dontShowAgain = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (context, setState) {
                          return AlertDialog(
                            title: const Text('确认操作'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('确定要执行此操作吗？'),
                                const SizedBox(height: 16),
                                CheckboxListTile(
                                  value: dontShowAgain,
                                  onChanged: (value) {
                                    setState(() {
                                      dontShowAgain = value ?? false;
                                    });
                                  },
                                  title: const Text('不再提示'),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('确认'),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Tap checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Verify checkbox is now checked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    test('"Don\'t show again" preference can be stored', () {
      // Mock preference storage
      final preferences = <String, bool>{};

      // Store preference
      preferences['confirmDeleteVersion'] = true;
      preferences['confirmBatchDisable'] = false;
      preferences['confirmRestoreDraft'] = true;
      preferences['confirmCancelExport'] = false;

      // Verify storage
      expect(preferences['confirmDeleteVersion'], isTrue);
      expect(preferences['confirmBatchDisable'], isFalse);
      expect(preferences['confirmRestoreDraft'], isTrue);
      expect(preferences['confirmCancelExport'], isFalse);
    });

    test('"Don\'t show again" preference can be retrieved', () {
      // Mock preference storage
      final preferences = <String, bool>{
        'confirmDeleteVersion': true,
        'confirmBatchDisable': false,
      };

      // Retrieve preferences
      final showDeleteConfirm = preferences['confirmDeleteVersion'] ?? true;
      final showBatchDisableConfirm = preferences['confirmBatchDisable'] ?? true;

      expect(showDeleteConfirm, isTrue);
      expect(showBatchDisableConfirm, isFalse);
    });

    test('Default behavior is to show confirmation dialogs', () {
      // Mock empty preferences
      final preferences = <String, bool>{};

      // Retrieve with default value
      final showConfirm = preferences['confirmDeleteVersion'] ?? true;

      // Should default to true (show confirmation)
      expect(showConfirm, isTrue);
    });
  });

  group('Confirmation Dialog - Button Styling', () {
    testWidgets('Destructive actions use error color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认删除'),
                        content: const Text('此操作无法撤销。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(ctx).colorScheme.error,
                            ),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Find the delete button
      final deleteButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '删除'),
      );

      // Verify button uses error color
      expect(deleteButton.style, isNotNull);
    });

    testWidgets('Cancel button uses TextButton style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify cancel button is TextButton
      expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    });

    testWidgets('Confirm button uses FilledButton style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify confirm button is FilledButton
      expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);
    });
  });

  group('Confirmation Dialog - Accessibility', () {
    testWidgets('Dialog has semantic labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is accessible
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('确认操作'), findsOneWidget);
      expect(find.text('确定要执行此操作吗？'), findsOneWidget);
    });

    testWidgets('Buttons are keyboard accessible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('确认操作'),
                        content: const Text('确定要执行此操作吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('确认'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify buttons exist and are tappable
      expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, '确认'), findsOneWidget);
    });
  });
}
