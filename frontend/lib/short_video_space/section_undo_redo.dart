// ignore_for_file: invalid_use_of_protected_member, unused_element

part of 'section.dart';

/// Undo/Redo operations for ShortVideoSpaceSection
///
/// **Validates: Requirements 18, 19**
extension _ShortVideoSpaceSectionUndoRedoExtension on _ShortVideoSpaceSectionState {
  /// Performs undo operation (Ctrl+Z / Cmd+Z)
  ///
  /// Restores the state to before the last operation and moves the operation
  /// to the redo stack. Returns true if undo was successful.
  Future<bool> _performUndo() async {
    if (!_operationHistory.canUndo) {
      return false;
    }

    try {
      final success = await _operationHistory.undo();
      if (success) {
        // Refresh the assembly data after undo
        await _loadProjectOverview();
        
        // Show feedback
        final operation = _operationHistory.peekRedo();
        final description = operation?.getDescription() ?? '操作';
        _showOperationFeedback(
          '已撤销：$description',
          isSuccess: true,
        );
        
        // Update UI state
        setState(() {});
      }
      return success;
    } catch (e) {
      _showOperationFeedback(
        '撤销失败：$e',
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

    try {
      final success = await _operationHistory.redo();
      if (success) {
        // Refresh the assembly data after redo
        await _loadProjectOverview();
        
        // Show feedback
        final operation = _operationHistory.peekUndo();
        final description = operation?.getDescription() ?? '操作';
        _showOperationFeedback(
          '已重做：$description',
          isSuccess: true,
        );
        
        // Update UI state
        setState(() {});
      }
      return success;
    } catch (e) {
      _showOperationFeedback(
        '重做失败：$e',
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

    final isControlPressed = HardwareKeyboard.instance.isControlPressed ||
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
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
        );
      },
      redo: () async {
        await postWorkbenchSelectVideoV1(
          token,
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: videoUrl,
        );
      },
      description: '启用镜头 #$storyboardId',
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
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: previousVideoUrl,
        );
      },
      redo: () async {
        await postWorkbenchDeleteVideoV1(
          token,
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
        );
      },
      description: '禁用镜头 #$storyboardId',
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
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
          duration: previousDuration,
        );
      },
      redo: () async {
        await postStoryboardUpdateDurationV1(
          token,
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
          duration: newDuration,
        );
      },
      description: '调整镜头 #$storyboardId 时长为 ${newDuration}s',
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
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: previousVideoUrl,
        );
      },
      redo: () async {
        await postWorkbenchSelectVideoV1(
          token,
          projectId: _selectedProject!.numericId,
          scriptId: scriptId,
          storyboardId: storyboardId,
          videoUrl: newVideoUrl,
        );
      },
      description: '替换镜头 #$storyboardId 视频',
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
      beforeState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      afterState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      undo: () async {
        // Disable all shots that were enabled
        for (final op in operations) {
          await postWorkbenchDeleteVideoV1(
            token,
            projectId: _selectedProject!.numericId,
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
            projectId: _selectedProject!.numericId,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            videoUrl: op['videoUrl'] as String,
          );
        }
      },
      description: '批量启用 ${operations.length} 个镜头',
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
      beforeState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      afterState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      undo: () async {
        // Re-enable all shots that were disabled
        for (final op in operations) {
          await postWorkbenchSelectVideoV1(
            token,
            projectId: _selectedProject!.numericId,
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
            projectId: _selectedProject!.numericId,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
          );
        }
      },
      description: '批量禁用 ${operations.length} 个镜头',
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
      beforeState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      afterState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      undo: () async {
        // Restore previous durations
        for (final op in operations) {
          await postStoryboardUpdateDurationV1(
            token,
            projectId: _selectedProject!.numericId,
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
            projectId: _selectedProject!.numericId,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            duration: op['newDuration'] as int,
          );
        }
      },
      description: '批量时长对齐 ${operations.length} 个镜头',
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
      beforeState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      afterState: {
        'scriptId': scriptId,
        'operations': operations,
      },
      undo: () async {
        // Restore previous video URLs
        for (final op in operations) {
          await postWorkbenchSelectVideoV1(
            token,
            projectId: _selectedProject!.numericId,
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
            projectId: _selectedProject!.numericId,
            scriptId: scriptId,
            storyboardId: op['storyboardId'] as int,
            videoUrl: op['newVideoUrl'] as String,
          );
        }
      },
      description: '批量替换 ${operations.length} 个镜头视频',
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
              ? '撤销：$undoDescription (Ctrl+Z / Cmd+Z)'
              : '无可撤销操作',
          child: IconButton(
            icon: const Icon(Icons.undo),
            onPressed: canUndo ? () => _performUndo() : null,
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: canRedo
              ? '重做：$redoDescription (Ctrl+Shift+Z / Cmd+Shift+Z)'
              : '无可重做操作',
          child: IconButton(
            icon: const Icon(Icons.redo),
            onPressed: canRedo ? () => _performRedo() : null,
          ),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: '查看操作历史',
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
          title: const Text('操作历史'),
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
                        '历史记录摘要',
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
                          Text('可撤销操作：${summary['undoCount']}'),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.redo,
                            size: 16,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text('可重做操作：${summary['redoCount']}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '历史记录上限：${summary['maxHistorySize']} 条',
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
                            '暂无操作历史',
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
                          '操作记录（从新到旧）',
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
                              final operation = historyList[historyList.length - 1 - idx];
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
                                        : Theme.of(ctx).colorScheme.surfaceContainerHighest,
                                    child: Text(
                                      '${historyList.length - idx}',
                                      style: TextStyle(
                                        color: isLatest
                                            ? Theme.of(ctx).colorScheme.onPrimary
                                            : Theme.of(ctx).colorScheme.onSurfaceVariant,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    operation.getDescription(),
                                    style: TextStyle(
                                      fontWeight: isLatest ? FontWeight.bold : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    _formatOperationTimestamp(operation.timestamp),
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  ),
                                  trailing: isLatest
                                      ? Chip(
                                          label: const Text('最新'),
                                          backgroundColor:
                                              Theme.of(ctx).colorScheme.primary,
                                          labelStyle: TextStyle(
                                            color: Theme.of(ctx).colorScheme.onPrimary,
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
                    '已清空操作历史',
                    isSuccess: true,
                  );
                  setState(() {});
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('清空历史'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
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
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
