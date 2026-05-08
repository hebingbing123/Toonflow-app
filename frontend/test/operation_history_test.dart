import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/state/operation_history.dart';

void main() {
  group('Operation', () {
    test('creates operation with all required fields', () {
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime(2024, 1, 1),
        beforeState: {'enabled': false},
        afterState: {'enabled': true},
        undo: () async {},
        redo: () async {},
      );

      expect(operation.type, 'enable');
      expect(operation.timestamp, DateTime(2024, 1, 1));
      expect(operation.beforeState, {'enabled': false});
      expect(operation.afterState, {'enabled': true});
      expect(operation.description, isNull);
    });

    test('creates operation with custom description', () {
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime(2024, 1, 1),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
        description: '自定义描述',
      );

      expect(operation.description, '自定义描述');
      expect(operation.getDescription(), '自定义描述');
    });

    test('copyWith creates new operation with overridden fields', () {
      final original = Operation(
        type: 'enable',
        timestamp: DateTime(2024, 1, 1),
        beforeState: {'enabled': false},
        afterState: {'enabled': true},
        undo: () async {},
        redo: () async {},
      );

      final copied = original.copyWith(
        type: 'disable',
        description: '新描述',
      );

      expect(copied.type, 'disable');
      expect(copied.timestamp, DateTime(2024, 1, 1));
      expect(copied.description, '新描述');
      expect(copied.beforeState, {'enabled': false});
    });

    test('getDescription returns custom description when provided', () {
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
        description: '自定义操作',
      );

      expect(operation.getDescription(), '自定义操作');
    });

    test('getDescription returns default description for known types', () {
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
        'unknown': '编辑操作',
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

        expect(operation.getDescription(), entry.value,
            reason: 'Type ${entry.key} should return "${entry.value}"');
      }
    });
  });

  group('OperationHistory - Basic Operations', () {
    late OperationHistory history;

    setUp(() {
      history = OperationHistory();
    });

    test('initializes with empty stacks', () {
      expect(history.canUndo, false);
      expect(history.canRedo, false);
      expect(history.undoCount, 0);
      expect(history.redoCount, 0);
    });

    test('initializes with custom max history size', () {
      final customHistory = OperationHistory(maxHistorySize: 100);
      expect(customHistory.maxHistorySize, 100);
    });

    test('recordOperation adds operation to undo stack', () {
      final operation = _createTestOperation('enable');
      history.recordOperation(operation);

      expect(history.canUndo, true);
      expect(history.undoCount, 1);
      expect(history.canRedo, false);
    });

    test('recordOperation clears redo stack', () async {
      final op1 = _createTestOperation('enable');
      final op2 = _createTestOperation('disable');

      history.recordOperation(op1);
      await history.undo();
      expect(history.canRedo, true);

      history.recordOperation(op2);
      expect(history.canRedo, false);
      expect(history.redoCount, 0);
    });

    test('peekUndo returns last operation without removing it', () {
      final operation = _createTestOperation('enable');
      history.recordOperation(operation);

      final peeked = history.peekUndo();
      expect(peeked, isNotNull);
      expect(peeked!.type, 'enable');
      expect(history.undoCount, 1); // Still in stack
    });

    test('peekRedo returns null when redo stack is empty', () {
      expect(history.peekRedo(), isNull);
    });

    test('getHistoryList returns all operations in chronological order', () {
      final op1 = _createTestOperation('enable');
      final op2 = _createTestOperation('disable');
      final op3 = _createTestOperation('reorder');

      history.recordOperation(op1);
      history.recordOperation(op2);
      history.recordOperation(op3);

      final historyList = history.getHistoryList();
      expect(historyList.length, 3);
      expect(historyList[0].type, 'enable');
      expect(historyList[1].type, 'disable');
      expect(historyList[2].type, 'reorder');
    });

    test('clearHistory removes all operations', () {
      history.recordOperation(_createTestOperation('enable'));
      history.recordOperation(_createTestOperation('disable'));

      history.clearHistory();

      expect(history.canUndo, false);
      expect(history.canRedo, false);
      expect(history.undoCount, 0);
      expect(history.redoCount, 0);
    });
  });

  group('OperationHistory - Undo/Redo Logic', () {
    late OperationHistory history;

    setUp(() {
      history = OperationHistory();
    });

    test('undo returns false when undo stack is empty', () async {
      final result = await history.undo();
      expect(result, false);
    });

    test('redo returns false when redo stack is empty', () async {
      final result = await history.redo();
      expect(result, false);
    });

    test('undo executes undo function and moves operation to redo stack',
        () async {
      var undoCalled = false;
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          undoCalled = true;
        },
        redo: () async {},
      );

      history.recordOperation(operation);
      final result = await history.undo();

      expect(result, true);
      expect(undoCalled, true);
      expect(history.canUndo, false);
      expect(history.canRedo, true);
      expect(history.redoCount, 1);
    });

    test('redo executes redo function and moves operation to undo stack',
        () async {
      var redoCalled = false;
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {
          redoCalled = true;
        },
      );

      history.recordOperation(operation);
      await history.undo();

      final result = await history.redo();

      expect(result, true);
      expect(redoCalled, true);
      expect(history.canUndo, true);
      expect(history.canRedo, false);
      expect(history.undoCount, 1);
    });

    test('undo then redo restores original state', () async {
      var state = 'initial';
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {'state': 'initial'},
        afterState: {'state': 'modified'},
        undo: () async {
          state = 'initial';
        },
        redo: () async {
          state = 'modified';
        },
      );

      state = 'modified';
      history.recordOperation(operation);

      await history.undo();
      expect(state, 'initial');

      await history.redo();
      expect(state, 'modified');
    });

    test('multiple undo operations work in reverse order', () async {
      final operations = <String>[];
      final op1 = Operation(
        type: 'op1',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          operations.add('undo_op1');
        },
        redo: () async {},
      );
      final op2 = Operation(
        type: 'op2',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          operations.add('undo_op2');
        },
        redo: () async {},
      );

      history.recordOperation(op1);
      history.recordOperation(op2);

      await history.undo();
      await history.undo();

      expect(operations, ['undo_op2', 'undo_op1']);
    });

    test('undo failure keeps operation in undo stack', () async {
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

      await expectLater(history.undo(), throwsException);
      expect(history.canUndo, true);
      expect(history.undoCount, 1);
    });

    test('redo failure keeps operation in redo stack', () async {
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

      await expectLater(history.redo(), throwsException);
      expect(history.canRedo, true);
      expect(history.redoCount, 1);
    });
  });

  group('OperationHistory - History Stack Management', () {
    test('enforces max history size limit', () {
      final history = OperationHistory(maxHistorySize: 3);

      history.recordOperation(_createTestOperation('op1'));
      history.recordOperation(_createTestOperation('op2'));
      history.recordOperation(_createTestOperation('op3'));
      history.recordOperation(_createTestOperation('op4'));

      expect(history.undoCount, 3);
      final historyList = history.getHistoryList();
      expect(historyList[0].type, 'op2'); // op1 was removed
      expect(historyList[1].type, 'op3');
      expect(historyList[2].type, 'op4');
    });

    test('removes oldest operation when exceeding max size', () {
      final history = OperationHistory(maxHistorySize: 2);

      final op1 = _createTestOperation('first');
      final op2 = _createTestOperation('second');
      final op3 = _createTestOperation('third');

      history.recordOperation(op1);
      history.recordOperation(op2);
      history.recordOperation(op3);

      final historyList = history.getHistoryList();
      expect(historyList.length, 2);
      expect(historyList[0].type, 'second');
      expect(historyList[1].type, 'third');
    });

    test('default max history size is 50', () {
      final history = OperationHistory();
      expect(history.maxHistorySize, 50);
    });

    test('can store up to max history size operations', () {
      final history = OperationHistory(maxHistorySize: 50);

      for (var i = 0; i < 50; i++) {
        history.recordOperation(_createTestOperation('op$i'));
      }

      expect(history.undoCount, 50);
    });

    test('adding 51st operation removes the oldest', () {
      final history = OperationHistory(maxHistorySize: 50);

      for (var i = 0; i < 51; i++) {
        history.recordOperation(_createTestOperation('op$i'));
      }

      expect(history.undoCount, 50);
      final historyList = history.getHistoryList();
      expect(historyList.first.type, 'op1'); // op0 was removed
      expect(historyList.last.type, 'op50');
    });
  });

  group('OperationHistory - getSummary', () {
    test('returns correct summary for empty history', () {
      final history = OperationHistory();
      final summary = history.getSummary();

      expect(summary['canUndo'], false);
      expect(summary['canRedo'], false);
      expect(summary['undoCount'], 0);
      expect(summary['redoCount'], 0);
      expect(summary['maxHistorySize'], 50);
      expect(summary['lastUndoOperation'], isNull);
      expect(summary['lastRedoOperation'], isNull);
    });

    test('returns correct summary with operations', () {
      final history = OperationHistory();
      history.recordOperation(_createTestOperation('enable'));

      final summary = history.getSummary();

      expect(summary['canUndo'], true);
      expect(summary['canRedo'], false);
      expect(summary['undoCount'], 1);
      expect(summary['redoCount'], 0);
      expect(summary['lastUndoOperation'], '启用镜头');
      expect(summary['lastRedoOperation'], isNull);
    });

    test('returns correct summary after undo', () async {
      final history = OperationHistory();
      history.recordOperation(_createTestOperation('enable'));
      await history.undo();

      final summary = history.getSummary();

      expect(summary['canUndo'], false);
      expect(summary['canRedo'], true);
      expect(summary['undoCount'], 0);
      expect(summary['redoCount'], 1);
      expect(summary['lastUndoOperation'], isNull);
      expect(summary['lastRedoOperation'], '启用镜头');
    });
  });

  group('OperationHistory - Complex Scenarios', () {
    test('handles alternating undo and redo operations', () async {
      final history = OperationHistory();
      var counter = 0;

      final operation = Operation(
        type: 'counter',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          counter--;
        },
        redo: () async {
          counter++;
        },
      );

      counter = 1;
      history.recordOperation(operation);

      await history.undo();
      expect(counter, 0);

      await history.redo();
      expect(counter, 1);

      await history.undo();
      expect(counter, 0);

      await history.redo();
      expect(counter, 1);
    });

    test('handles multiple operations with state tracking', () async {
      final history = OperationHistory();
      final states = <String>[];

      final op1 = Operation(
        type: 'add_a',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          states.removeLast();
        },
        redo: () async {
          states.add('A');
        },
      );

      final op2 = Operation(
        type: 'add_b',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {
          states.removeLast();
        },
        redo: () async {
          states.add('B');
        },
      );

      states.add('A');
      history.recordOperation(op1);
      states.add('B');
      history.recordOperation(op2);

      expect(states, ['A', 'B']);

      await history.undo();
      expect(states, ['A']);

      await history.undo();
      expect(states, isEmpty);

      await history.redo();
      expect(states, ['A']);

      await history.redo();
      expect(states, ['A', 'B']);
    });

    test('new operation after undo clears redo stack', () async {
      final history = OperationHistory();

      history.recordOperation(_createTestOperation('op1'));
      history.recordOperation(_createTestOperation('op2'));
      await history.undo();

      expect(history.canRedo, true);
      expect(history.redoCount, 1);

      history.recordOperation(_createTestOperation('op3'));

      expect(history.canRedo, false);
      expect(history.redoCount, 0);
      expect(history.undoCount, 2);
    });

    test('undoStack and redoStack return unmodifiable lists', () {
      final history = OperationHistory();
      history.recordOperation(_createTestOperation('op1'));

      final undoStack = history.undoStack;
      expect(() => undoStack.add(_createTestOperation('op2')),
          throwsUnsupportedError);

      final redoStack = history.redoStack;
      expect(() => redoStack.add(_createTestOperation('op3')),
          throwsUnsupportedError);
    });
  });

  group('OperationHistory - Edge Cases', () {
    test('handles empty description gracefully', () {
      final operation = Operation(
        type: 'enable',
        timestamp: DateTime.now(),
        beforeState: {},
        afterState: {},
        undo: () async {},
        redo: () async {},
        description: '',
      );

      expect(operation.getDescription(), '启用镜头');
    });

    test('handles very large history size', () {
      final history = OperationHistory(maxHistorySize: 10000);

      for (var i = 0; i < 100; i++) {
        history.recordOperation(_createTestOperation('op$i'));
      }

      expect(history.undoCount, 100);
    });

    test('peekUndo returns null for empty stack', () {
      final history = OperationHistory();
      expect(history.peekUndo(), isNull);
    });

    test('peekRedo returns correct operation after undo', () async {
      final history = OperationHistory();
      final operation = _createTestOperation('enable');
      history.recordOperation(operation);
      await history.undo();

      final peeked = history.peekRedo();
      expect(peeked, isNotNull);
      expect(peeked!.type, 'enable');
    });

    test('handles rapid recordOperation calls', () {
      final history = OperationHistory();

      for (var i = 0; i < 1000; i++) {
        history.recordOperation(_createTestOperation('op$i'));
      }

      expect(history.undoCount, 50); // Limited by maxHistorySize
    });
  });
}

/// Helper function to create a test operation
Operation _createTestOperation(String type) {
  return Operation(
    type: type,
    timestamp: DateTime.now(),
    beforeState: {},
    afterState: {},
    undo: () async {},
    redo: () async {},
  );
}
