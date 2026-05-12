// ignore_for_file: invalid_use_of_protected_member, unused_element

part of 'section.dart';

/// Undo/Redo operations for ShortVideoSpaceSection
///
/// **Validates: Requirements 18, 19**
extension _ShortVideoSpaceSectionUndoRedoExtension
    on _ShortVideoSpaceSectionState {
  /// Performs undo operation (Ctrl+Z / Cmd+Z)
  ///
  /// Restores the state to before the last operation and moves the operation
  /// to the redo stack. Returns true if undo was successful.
  Future<bool> _performUndo() async {
    if (!_operationHistory.canUndo) {
      return false;
    }

    final l10n = AppLocalizations.of(context);
    try {
      final success = await _operationHistory.undo();
      if (success) {
        // Refresh the assembly data after undo
        await _loadProjectOverview();
        if (!mounted) {
          return success;
        }

        // Show feedback
        final operation = _operationHistory.peekRedo();
        final description =
            operation?.getDescription() ??
            (l10n?.shortVideoSpaceUndoRedoOperationDefault ?? 'Operation');
        _showOperationFeedback(
          l10n?.shortVideoSpaceUndoSucceeded(description) ??
              'Undone: $description',
          isSuccess: true,
        );

        // Update UI state
        setState(() {});
      }
      return success;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      _showOperationFeedback(
        l10n?.shortVideoSpaceUndoFailed('$e') ?? 'Undo failed: $e',
        isSuccess: false,
      );
      return false;
    }
  }

  /// Performs redo operation (Ctrl+Shift+Z / Cmd+Shift+Z)
  ///
  /// Restores the state to after the last undone operation and moves the
  /// operation back to the undo stack. Returns true if redo was successful.
  Future<bool> _performRedo() async {
    if (!_operationHistory.canRedo) {
      return false;
    }

    final l10n = AppLocalizations.of(context);
    try {
      final success = await _operationHistory.redo();
      if (success) {
        // Refresh the assembly data after redo
        await _loadProjectOverview();
        if (!mounted) {
          return success;
        }

        // Show feedback
        final operation = _operationHistory.peekUndo();
        final description =
            operation?.getDescription() ??
            (l10n?.shortVideoSpaceUndoRedoOperationDefault ?? 'Operation');
        _showOperationFeedback(
          l10n?.shortVideoSpaceRedoSucceeded(description) ??
              'Redone: $description',
          isSuccess: true,
        );

        // Update UI state
        setState(() {});
      }
      return success;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      _showOperationFeedback(
        l10n?.shortVideoSpaceRedoFailed('$e') ?? 'Redo failed: $e',
        isSuccess: false,
      );
      return false;
    }
  }

  /// Handles keyboard shortcuts for undo/redo
  ///
  /// - Ctrl+Z / Cmd+Z: Undo
  /// - Ctrl+Shift+Z / Cmd+Shift+Z: Redo
  Future<void> _handleUndoRedoKeyEvent(KeyEvent event) async {
    if (event is! KeyDownEvent) {
      return;
    }

    final isControlPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    // Ctrl+Z / Cmd+Z: Undo
    if (isControlPressed &&
        !isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      await _performUndo();
    }
    // Ctrl+Shift+Z / Cmd+Shift+Z: Redo
    else if (isControlPressed &&
        isShiftPressed &&
        event.logicalKey == LogicalKeyboardKey.keyZ) {
      await _performRedo();
    }
  }

  /// Records an enable shot operation in history
  void _recordEnableOperation({
    required int scriptId,
    required int storyboardId,
    required String videoUrl,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'enable',
      timestamp: DateTime.now(),
      beforeState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'enabled': false,
      },
      afterState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'enabled': true,
        'videoUrl': videoUrl,
      },
      undo: () async {
        await postWorkbenchDeleteVideoV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
        );
      },
      redo: () async {
        await postWorkbenchSelectVideoV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: videoUrl,
        );
      },
      description: 'Enable shot #$storyboardId',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a disable shot operation in history
  void _recordDisableOperation({
    required int scriptId,
    required int storyboardId,
    required String previousVideoUrl,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'disable',
      timestamp: DateTime.now(),
      beforeState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'enabled': true,
        'videoUrl': previousVideoUrl,
      },
      afterState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'enabled': false,
      },
      undo: () async {
        await postWorkbenchSelectVideoV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: previousVideoUrl,
        );
      },
      redo: () async {
        await postWorkbenchDeleteVideoV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
        );
      },
      description: 'Disable shot #$storyboardId',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a duration update operation in history
  void _recordDurationOperation({
    required int scriptId,
    required int storyboardId,
    required int previousDuration,
    required int newDuration,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'duration',
      timestamp: DateTime.now(),
      beforeState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'duration': previousDuration,
      },
      afterState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'duration': newDuration,
      },
      undo: () async {
        await postStoryboardUpdateDurationV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
          duration: previousDuration,
        );
      },
      redo: () async {
        await postStoryboardUpdateDurationV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
          duration: newDuration,
        );
      },
      description: 'Set shot #$storyboardId duration to ${newDuration}s',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a video replacement operation in history
  void _recordReplaceOperation({
    required int scriptId,
    required int storyboardId,
    required String previousVideoUrl,
    required String newVideoUrl,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'replace',
      timestamp: DateTime.now(),
      beforeState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'videoUrl': previousVideoUrl,
      },
      afterState: {
        'scriptId': scriptId,
        'storyboardId': storyboardId,
        'videoUrl': newVideoUrl,
      },
      undo: () async {
        await postWorkbenchSelectVideoV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: previousVideoUrl,
        );
      },
      redo: () async {
        await postWorkbenchSelectVideoV1(
          token,
          projectUuid: _selectedProject!.id,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: newVideoUrl,
        );
      },
      description: 'Replace shot #$storyboardId video',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a batch enable operation in history
  void _recordBatchEnableOperation({
    required int scriptId,
    required List<Map<String, dynamic>> operations,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty || operations.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'batch_enable',
      timestamp: DateTime.now(),
      beforeState: {'scriptId': scriptId, 'operations': operations},
      afterState: {'scriptId': scriptId, 'operations': operations},
      undo: () async {
        // Disable all shots that were enabled
        for (final op in operations) {
          await postWorkbenchDeleteVideoV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
          );
        }
      },
      redo: () async {
        // Re-enable all shots
        for (final op in operations) {
          await postWorkbenchSelectVideoV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            videoUrl: op['videoUrl'] as String,
          );
        }
      },
      description: 'Batch enable ${operations.length} shot(s)',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a batch disable operation in history
  void _recordBatchDisableOperation({
    required int scriptId,
    required List<Map<String, dynamic>> operations,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty || operations.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'batch_disable',
      timestamp: DateTime.now(),
      beforeState: {'scriptId': scriptId, 'operations': operations},
      afterState: {'scriptId': scriptId, 'operations': operations},
      undo: () async {
        // Re-enable all shots that were disabled
        for (final op in operations) {
          await postWorkbenchSelectVideoV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            videoUrl: op['previousVideoUrl'] as String,
          );
        }
      },
      redo: () async {
        // Re-disable all shots
        for (final op in operations) {
          await postWorkbenchDeleteVideoV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
          );
        }
      },
      description: 'Batch disable ${operations.length} shot(s)',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a batch duration update operation in history
  void _recordBatchDurationOperation({
    required int scriptId,
    required List<Map<String, dynamic>> operations,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty || operations.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'batch_duration',
      timestamp: DateTime.now(),
      beforeState: {'scriptId': scriptId, 'operations': operations},
      afterState: {'scriptId': scriptId, 'operations': operations},
      undo: () async {
        // Restore previous durations
        for (final op in operations) {
          await postStoryboardUpdateDurationV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            duration: op['previousDuration'] as int,
          );
        }
      },
      redo: () async {
        // Re-apply new durations
        for (final op in operations) {
          await postStoryboardUpdateDurationV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            duration: op['newDuration'] as int,
          );
        }
      },
      description: 'Batch align duration for ${operations.length} shot(s)',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Records a batch replace operation in history
  void _recordBatchReplaceOperation({
    required int scriptId,
    required List<Map<String, dynamic>> operations,
  }) {
    final token = widget.accessToken;
    if (token == null || token.isEmpty || operations.isEmpty) {
      return;
    }

    final operation = Operation(
      type: 'batch_replace',
      timestamp: DateTime.now(),
      beforeState: {'scriptId': scriptId, 'operations': operations},
      afterState: {'scriptId': scriptId, 'operations': operations},
      undo: () async {
        // Restore previous video URLs
        for (final op in operations) {
          await postWorkbenchSelectVideoV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            videoUrl: op['previousVideoUrl'] as String,
          );
        }
      },
      redo: () async {
        // Re-apply new video URLs
        for (final op in operations) {
          await postWorkbenchSelectVideoV1(
            token,
            projectUuid: _selectedProject!.id,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            videoUrl: op['newVideoUrl'] as String,
          );
        }
      },
      description: 'Batch replace video for ${operations.length} shot(s)',
    );

    _operationHistory.recordOperation(operation);
  }

  /// Builds undo/redo toolbar buttons
  Widget _buildUndoRedoToolbar() {
    final canUndo = _operationHistory.canUndo;
    final canRedo = _operationHistory.canRedo;
    final undoDescription = _operationHistory.peekUndo()?.getDescription();
    final redoDescription = _operationHistory.peekRedo()?.getDescription();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: canUndo
              ? 'Undo: $undoDescription (Ctrl+Z / Cmd+Z)'
              : 'Nothing to undo',
          child: IconButton(
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? () => _performUndo() : null,
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: canRedo
              ? 'Redo: $redoDescription (Ctrl+Shift+Z / Cmd+Shift+Z)'
              : 'Nothing to redo',
          child: IconButton(
            icon: const Icon(Icons.redo),
            onPressed: canRedo ? () => _performRedo() : null,
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: 'View operation history',
          child: IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showOperationHistoryDialog(),
          ),
        ),
      ],
    );
  }

  /// Shows the operation history dialog
  Future<void> _showOperationHistoryDialog() async {
    final summary = _operationHistory.getSummary();
    final historyList = _operationHistory.getHistoryList();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Operation history'),
          content: SizedBox(
            width: 600,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.undo,
                            size: 16,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text('Undo stack: ${summary['undoCount']}'),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.redo,
                            size: 16,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text('Redo stack: ${summary['redoCount']}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'History limit: ${summary['maxHistorySize']} entries',
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // History list section
                if (historyList.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_outlined,
                            size: 48,
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No operations yet',
                            style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Operations (newest first)',
                          style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: historyList.length,
                            itemBuilder: (ctx, idx) {
                              // Show from newest to oldest
                              final operation =
                                  historyList[historyList.length - 1 - idx];
                              final isLatest = idx == 0;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: isLatest ? 2 : 0,
                                color: isLatest
                                    ? Theme.of(ctx).colorScheme.primaryContainer
                                    : null,
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: isLatest
                                        ? Theme.of(ctx).colorScheme.primary
                                        : Theme.of(
                                            ctx,
                                          ).colorScheme.surfaceContainerHighest,
                                    child: Text(
                                      '${historyList.length - idx}',
                                      style: TextStyle(
                                        color: isLatest
                                            ? Theme.of(
                                                ctx,
                                              ).colorScheme.onPrimary
                                            : Theme.of(
                                                ctx,
                                              ).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    operation.getDescription(),
                                    style: TextStyle(
                                      fontWeight: isLatest
                                          ? FontWeight.bold
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatOperationTimestamp(
                                      operation.timestamp,
                                    ),
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  ),
                                  trailing: isLatest
                                      ? Chip(
                                          label: const Text('Latest'),
                                          backgroundColor: Theme.of(
                                            ctx,
                                          ).colorScheme.primary,
                                          labelStyle: TextStyle(
                                            color: Theme.of(
                                              ctx,
                                            ).colorScheme.onPrimary,
                                            fontSize: 11,
                                          ),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            if (historyList.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  _operationHistory.clearHistory();
                  Navigator.of(ctx).pop();
                  _showOperationFeedback(
                    'Operation history cleared',
                    isSuccess: true,
                  );
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear history'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  /// Formats operation timestamp for display
  String _formatOperationTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
