// ignore_for_file: invalid_use_of_protected_member

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
      ],
    );
  }
}
