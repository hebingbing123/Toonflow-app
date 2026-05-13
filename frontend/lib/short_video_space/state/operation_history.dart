/// Operation history management for undo/redo functionality
///
/// This class maintains in-memory stacks for undo and redo operations.
/// History is cleared on page refresh and is not persisted to backend.
///
/// **Validates: Requirements 17**
library;

import 'package:openflow_app/l10n/app_localizations.dart';

/// Represents a single reversible operation in the editing workflow
class Operation {
  /// Type of operation (e.g., 'enable', 'disable', 'reorder', 'duration', 'replace')
  final String type;

  /// Timestamp when the operation was performed
  final DateTime timestamp;

  /// State before the operation was applied
  final Map<String, dynamic> beforeState;

  /// State after the operation was applied
  final Map<String, dynamic> afterState;

  /// Function to undo this operation
  final Future<void> Function() undo;

  /// Function to redo this operation
  final Future<void> Function() redo;

  /// Optional description of the operation for display
  final String? description;

  Operation({
    required this.type,
    required this.timestamp,
    required this.beforeState,
    required this.afterState,
    required this.undo,
    required this.redo,
    this.description,
  });

  /// Creates a copy of this operation with optional field overrides
  Operation copyWith({
    String? type,
    DateTime? timestamp,
    Map<String, dynamic>? beforeState,
    Map<String, dynamic>? afterState,
    Future<void> Function()? undo,
    Future<void> Function()? redo,
    String? description,
  }) {
    return Operation(
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      beforeState: beforeState ?? this.beforeState,
      afterState: afterState ?? this.afterState,
      undo: undo ?? this.undo,
      redo: redo ?? this.redo,
      description: description ?? this.description,
    );
  }

  /// Returns a localized description for UI and tooltips.
  String localizedDescription(AppLocalizations l10n) {
    if (description != null && description!.trim().isNotEmpty) {
      return description!;
    }

    switch (type) {
      case 'enable':
        return l10n.shortVideoOpHistoryEnableShot;
      case 'disable':
        return l10n.shortVideoOpHistoryDisableShot;
      case 'reorder':
        return l10n.shortVideoOpHistoryReorderShots;
      case 'duration':
        return l10n.shortVideoOpHistoryAdjustDuration;
      case 'replace':
        return l10n.shortVideoOpHistoryReplaceVideo;
      case 'batch_enable':
        return l10n.shortVideoOpHistoryBatchEnable;
      case 'batch_disable':
        return l10n.shortVideoOpHistoryBatchDisable;
      case 'batch_duration':
        return l10n.shortVideoOpHistoryBatchDuration;
      case 'batch_replace':
        return l10n.shortVideoOpHistoryBatchReplace;
      default:
        return l10n.shortVideoOpHistoryEditOperation;
    }
  }
}

/// Manages operation history for undo/redo functionality
///
/// This class maintains two stacks:
/// - undoStack: operations that can be undone
/// - redoStack: operations that can be redone
///
/// The history is limited to [maxHistorySize] operations (default 50).
/// When the limit is reached, the oldest operation is removed.
class OperationHistory {
  /// Maximum number of operations to keep in history
  final int maxHistorySize;

  /// Stack of operations that can be undone
  final List<Operation> _undoStack = [];

  /// Stack of operations that can be redone
  final List<Operation> _redoStack = [];

  /// Creates an operation history manager with optional max size
  OperationHistory({this.maxHistorySize = 50});

  /// Returns true if there are operations that can be undone
  bool get canUndo => _undoStack.isNotEmpty;

  /// Returns true if there are operations that can be redone
  bool get canRedo => _redoStack.isNotEmpty;

  /// Returns the number of operations in the undo stack
  int get undoCount => _undoStack.length;

  /// Returns the number of operations in the redo stack
  int get redoCount => _redoStack.length;

  /// Returns a read-only view of the undo stack
  List<Operation> get undoStack => List.unmodifiable(_undoStack);

  /// Returns a read-only view of the redo stack
  List<Operation> get redoStack => List.unmodifiable(_redoStack);

  /// Records a new operation in the history
  ///
  /// This adds the operation to the undo stack and clears the redo stack.
  /// If the undo stack exceeds [maxHistorySize], the oldest operation is removed.
  void recordOperation(Operation operation) {
    // Add to undo stack
    _undoStack.add(operation);

    // Clear redo stack (new operation invalidates redo history)
    _redoStack.clear();

    // Enforce history size limit
    if (_undoStack.length > maxHistorySize) {
      _undoStack.removeAt(0);
    }
  }

  /// Undoes the most recent operation
  ///
  /// Returns true if the undo was successful, false if there's nothing to undo.
  /// The undone operation is moved to the redo stack.
  Future<bool> undo() async {
    if (!canUndo) {
      return false;
    }

    // Pop from undo stack
    final operation = _undoStack.removeLast();

    try {
      // Execute undo function
      await operation.undo();

      // Move to redo stack
      _redoStack.add(operation);

      return true;
    } catch (e) {
      // If undo fails, put the operation back on the undo stack
      _undoStack.add(operation);
      rethrow;
    }
  }

  /// Redoes the most recently undone operation
  ///
  /// Returns true if the redo was successful, false if there's nothing to redo.
  /// The redone operation is moved back to the undo stack.
  Future<bool> redo() async {
    if (!canRedo) {
      return false;
    }

    // Pop from redo stack
    final operation = _redoStack.removeLast();

    try {
      // Execute redo function
      await operation.redo();

      // Move back to undo stack
      _undoStack.add(operation);

      return true;
    } catch (e) {
      // If redo fails, put the operation back on the redo stack
      _redoStack.add(operation);
      rethrow;
    }
  }

  /// Clears all history (both undo and redo stacks)
  void clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  /// Returns the most recent operation that can be undone, or null if none
  Operation? peekUndo() {
    if (!canUndo) {
      return null;
    }
    return _undoStack.last;
  }

  /// Returns the most recent operation that can be redone, or null if none
  Operation? peekRedo() {
    if (!canRedo) {
      return null;
    }
    return _redoStack.last;
  }

  /// Returns a list of all operations in chronological order
  ///
  /// This includes both undo and redo stacks, useful for displaying
  /// operation history to the user.
  List<Operation> getHistoryList() {
    return List.unmodifiable(_undoStack);
  }

  /// Returns a summary of the current history state
  Map<String, dynamic> getSummary(AppLocalizations l10n) {
    return {
      'canUndo': canUndo,
      'canRedo': canRedo,
      'undoCount': undoCount,
      'redoCount': redoCount,
      'maxHistorySize': maxHistorySize,
      'lastUndoOperation': peekUndo()?.localizedDescription(l10n),
      'lastRedoOperation': peekRedo()?.localizedDescription(l10n),
    };
  }
}
