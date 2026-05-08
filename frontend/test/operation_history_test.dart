import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/state/operation_history.dart';

void main() {
  group('Operation', () {
    test('getDescription returns custom description when provided', () {
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
        description: '自定义操作描述',
      );

      expect(operation.getDescription(), '自定义操作描述');
    });

    test('getDescription returns default description for known operation types',
        () {
      final testCases = {
        'enable': '启用镜头',
        'disable': '禁用镜头',
        'reorder': '重排镜头顺序',
        'duration': '调整镜头时长',
        'replace': '替换视频',
        'batch_enable': '批量启用镜头',
        'batch_disable': '批量禁用镜头',
        'batch_duration': '批量时长对齐',
        'batch_replace': '批量替换视频',
      };

      for (final entry in testCases.entries) {
        final operation = Operation(
          type: entry.key,
          timestamp: DateTime.now(),
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        );

        expect(operation.getDescription(), entry.value);
      }
    });

    test('getDescription returns generic description for unknown operation type',
        () {
      final operation = Operation(
        type: 'unknown_operation',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      expect(operation.getDescription(), '编辑操作');
    });

    test('copyWith creates a new operation with overridden fields', () {
      final original = Operation(
        type: 'enable',
        timestamp: DateTime(2024, 1, 1),
        beforeState: {'enabled': false},
        afterState: {'enabled': true},
        undo: () async {},
        redo: () async {},
        description: '原始描述',
      );

      final copied = original.copyWith(
        type: 'disable',
        description: '新描述',
      );

      expect(copied.type, 'disable');
      expect(copied.description, '新描述');
      expect(copied.timestamp, original.timestamp);
      expect(copied.beforeState, original.beforeState);
      expect(copied.afterState, original.afterState);
    });
  });

  group('OperationHistory - Basic State', () {
    test('initial state has no operations', () {
      final history = OperationHistory();

      expect(history.canUndo, false);
      expect(history.canRedo, false);
      expect(history.undoCount, 0);
      expect(history.redoCount, 0);
    });

    test('recordOperation adds operation to undo stack', () {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(operation);

      expect(history.canUndo, true);
      expect(history.canRedo, false);
      expect(history.undoCount, 1);
      expect(history.redoCount, 0);
    });

    test('recordOperation clears redo stack', () async {
      final history = OperationHistory();
      final op1 = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );
      final op2 = Operation(
        type: 'disable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(op1);
      await history.undo();
      expect(history.canRedo, true);

      history.recordOperation(op2);
      expect(history.canRedo, false);
      expect(history.redoCount, 0);
    });

    test('clearHistory removes all operations', () {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(operation);
      history.clearHistory();

      expect(history.canUndo, false);
      expect(history.canRedo, false);
      expect(history.undoCount, 0);
      expect(history.redoCount, 0);
    });
  });

  group('OperationHistory - Undo/Redo Logic', () {
    test('undo executes undo function and moves operation to redo stack',
        () async {
      var undoExecuted = false;
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          undoExecuted = true;
        },
        redo: () async {},
      );

      history.recordOperation(operation);
      final result = await history.undo();

      expect(result, true);
      expect(undoExecuted, true);
      expect(history.canUndo, false);
      expect(history.canRedo, true);
      expect(history.undoCount, 0);
      expect(history.redoCount, 1);
    });

    test('undo returns false when undo stack is empty', () async {
      final history = OperationHistory();
      final result = await history.undo();

      expect(result, false);
    });

    test('undo restores operation to undo stack on failure', () async {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          throw Exception('Undo failed');
        },
        redo: () async {},
      );

      history.recordOperation(operation);

      try {
        await history.undo();
      } catch (e) {
        // Expected exception
      }
      expect(history.canUndo, true);
      expect(history.undoCount, 1);
    });

    test('redo executes redo function and moves operation to undo stack',
        () async {
      var redoExecuted = false;
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {
          redoExecuted = true;
        },
      );

      history.recordOperation(operation);
      await history.undo();

      final result = await history.redo();

      expect(result, true);
      expect(redoExecuted, true);
      expect(history.canUndo, true);
      expect(history.canRedo, false);
      expect(history.undoCount, 1);
      expect(history.redoCount, 0);
    });

    test('redo returns false when redo stack is empty', () async {
      final history = OperationHistory();
      final result = await history.redo();

      expect(result, false);
    });

    test('redo restores operation to redo stack on failure', () async {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {
          throw Exception('Redo failed');
        },
      );

      history.recordOperation(operation);
      await history.undo();

      try {
        await history.redo();
      } catch (e) {
        // Expected exception
      }
      expect(history.canRedo, true);
      expect(history.redoCount, 1);
    });

    test('multiple undo/redo operations maintain correct stack state',
        () async {
      final history = OperationHistory();
      final operations = List.generate(
        3,
        (i) => Operation(
          type: 'enable',
          timestamp: DateTime.now(),
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        ),
      );

      for (final op in operations) {
        history.recordOperation(op);
      }

      expect(history.undoCount, 3);
      expect(history.redoCount, 0);

      await history.undo();
      expect(history.undoCount, 2);
      expect(history.redoCount, 1);

      await history.undo();
      expect(history.undoCount, 1);
      expect(history.redoCount, 2);

      await history.redo();
      expect(history.undoCount, 2);
      expect(history.redoCount, 1);
    });
  });

  group('OperationHistory - History Stack Management', () {
    test('enforces max history size limit', () {
      final history = OperationHistory(maxHistorySize: 3);

      for (var i = 0; i < 5; i++) {
        history.recordOperation(Operation(
          type: 'enable',
          timestamp: DateTime.now(),
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        ));
      }

      expect(history.undoCount, 3);
    });

    test('removes oldest operation when exceeding max size', () {
      final history = OperationHistory(maxHistorySize: 2);
      final timestamps = [
        DateTime(2024, 1, 1),
        DateTime(2024, 1, 2),
        DateTime(2024, 1, 3),
      ];

      for (final timestamp in timestamps) {
        history.recordOperation(Operation(
          type: 'enable',
          timestamp: timestamp,
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        ));
      }

      final historyList = history.getHistoryList();
      expect(historyList.length, 2);
      expect(historyList.first.timestamp, timestamps[1]);
      expect(historyList.last.timestamp, timestamps[2]);
    });

    test('peekUndo returns last operation without removing it', () {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(operation);
      final peeked = history.peekUndo();

      expect(peeked, isNotNull);
      expect(peeked?.type, 'enable');
      expect(history.undoCount, 1);
    });

    test('peekUndo returns null when undo stack is empty', () {
      final history = OperationHistory();
      expect(history.peekUndo(), isNull);
    });

    test('peekRedo returns last operation without removing it', () async {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(operation);
      await history.undo();
      final peeked = history.peekRedo();

      expect(peeked, isNotNull);
      expect(peeked?.type, 'enable');
      expect(history.redoCount, 1);
    });

    test('peekRedo returns null when redo stack is empty', () {
      final history = OperationHistory();
      expect(history.peekRedo(), isNull);
    });

    test('getHistoryList returns unmodifiable list of undo operations', () {
      final history = OperationHistory();
      final operations = List.generate(
        3,
        (i) => Operation(
          type: 'enable',
          timestamp: DateTime.now(),
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        ),
      );

      for (final op in operations) {
        history.recordOperation(op);
      }

      final historyList = history.getHistoryList();
      expect(historyList.length, 3);
      expect(() => historyList.add(operations[0]), throwsUnsupportedError);
    });

    test('undoStack and redoStack return unmodifiable lists', () {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(operation);
      history.undo();

      expect(() => history.undoStack.add(operation), throwsUnsupportedError);
      expect(() => history.redoStack.add(operation), throwsUnsupportedError);
    });
  });

  group('OperationHistory - Summary and State Reporting', () {
    test('getSummary returns complete state information', () {
      final history = OperationHistory(maxHistorySize: 50);
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
        description: '测试操作',
      );

      history.recordOperation(operation);
      final summary = history.getSummary();

      expect(summary['canUndo'], true);
      expect(summary['canRedo'], false);
      expect(summary['undoCount'], 1);
      expect(summary['redoCount'], 0);
      expect(summary['maxHistorySize'], 50);
      expect(summary['lastUndoOperation'], '测试操作');
      expect(summary['lastRedoOperation'], isNull);
    });

    test('getSummary reflects state after undo', () async {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
        description: '测试操作',
      );

      history.recordOperation(operation);
      await history.undo();
      final summary = history.getSummary();

      expect(summary['canUndo'], false);
      expect(summary['canRedo'], true);
      expect(summary['undoCount'], 0);
      expect(summary['redoCount'], 1);
      expect(summary['lastUndoOperation'], isNull);
      expect(summary['lastRedoOperation'], '测试操作');
    });
  });

  group('OperationHistory - Operation Recording', () {
    test('records operation with complete state information', () {
      final history = OperationHistory();
      final beforeState = {'shotId': 123, 'enabled': false};
      final afterState = {'shotId': 123, 'enabled': true};
      final timestamp = DateTime.now();

      final operation = Operation(
        type: 'enable',
        timestamp: timestamp,
        beforeState: beforeState,
        afterState: afterState,
        undo: () async {},
        redo: () async {},
        description: '启用镜头 123',
      );

      history.recordOperation(operation);
      final recorded = history.peekUndo();

      expect(recorded, isNotNull);
      expect(recorded?.type, 'enable');
      expect(recorded?.timestamp, timestamp);
      expect(recorded?.beforeState, beforeState);
      expect(recorded?.afterState, afterState);
      expect(recorded?.description, '启用镜头 123');
    });

    test('maintains chronological order of operations', () {
      final history = OperationHistory();
      final timestamps = [
        DateTime(2024, 1, 1, 10, 0),
        DateTime(2024, 1, 1, 11, 0),
        DateTime(2024, 1, 1, 12, 0),
      ];

      for (final timestamp in timestamps) {
        history.recordOperation(Operation(
          type: 'enable',
          timestamp: timestamp,
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        ));
      }

      final historyList = history.getHistoryList();
      expect(historyList[0].timestamp, timestamps[0]);
      expect(historyList[1].timestamp, timestamps[1]);
      expect(historyList[2].timestamp, timestamps[2]);
    });
  });

  group('OperationHistory - Edge Cases', () {
    test('handles rapid undo/redo cycles', () async {
      final history = OperationHistory();
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      );

      history.recordOperation(operation);

      for (var i = 0; i < 10; i++) {
        await history.undo();
        await history.redo();
      }

      expect(history.canUndo, true);
      expect(history.canRedo, false);
      expect(history.undoCount, 1);
      expect(history.redoCount, 0);
    });

    test('handles empty history operations gracefully', () async {
      final history = OperationHistory();

      expect(await history.undo(), false);
      expect(await history.redo(), false);
      expect(history.peekUndo(), isNull);
      expect(history.peekRedo(), isNull);
      expect(history.getHistoryList(), isEmpty);
    });

    test('custom max history size of 1 works correctly', () {
      final history = OperationHistory(maxHistorySize: 1);

      history.recordOperation(Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      ));

      history.recordOperation(Operation(
        type: 'disable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
      ));

      expect(history.undoCount, 1);
      expect(history.peekUndo()?.type, 'disable');
    });

    test('large max history size handles many operations', () {
      final history = OperationHistory(maxHistorySize: 1000);

      for (var i = 0; i < 500; i++) {
        history.recordOperation(Operation(
          type: 'enable',
          timestamp: DateTime.now(),
          beforeState: {},
          afterState: {},
          undo: () async {},
          redo: () async {},
        ));
      }

      expect(history.undoCount, 500);
    });
  });
}
