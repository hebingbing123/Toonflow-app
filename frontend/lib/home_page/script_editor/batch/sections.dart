part of '../../../home_page.dart';

/// Keeps batch storyboard control sections beside the batch domain so the main
/// dialog file stays focused on selection state and overall composition.
extension _StoryboardBatchWorkbenchSections
    on _StoryboardBatchWorkbenchDialogState {
  Widget _buildBatchWorkbenchTopActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: _loadingProduction || _busyMutation
              ? null
              : _refreshProduction,
          child: Text(_loadingProduction ? '同步中…' : '同步制作视图'),
        ),
        TextButton(
          onPressed: _busyMutation ? null : _selectReadyStoryboards,
          child: const Text('全选可出图分镜'),
        ),
        TextButton(
          onPressed: _busyMutation ? null : _clearSelection,
          child: const Text('清空选择'),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchPromptSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _promptSuffixCtrl,
            decoration: const InputDecoration(
              labelText: '追加提示词（可选）',
              helperText: '会拼接到每条分镜原提示词末尾。',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _negativePromptCtrl,
            decoration: const InputDecoration(labelText: '负面提示词（可选）'),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchModelSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _modelCtrl,
            decoration: const InputDecoration(labelText: '模型（可选）'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _resolutionCtrl,
            decoration: const InputDecoration(labelText: '分辨率（可选）'),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchMutationActions({
    required List<int> selected,
    required int? singleSelectedId,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: _busyMutation || _selectedIds.isEmpty
              ? null
              : () => _runMutation(_batchGenerate),
          child: Text(_busyMutation ? '处理中…' : '批量发起出图'),
        ),
        TextButton(
          onPressed: _busyMutation || singleSelectedId == null
              ? null
              : () => _runMutation(() => _loadCurrentPreview(singleSelectedId)),
          child: const Text('读取当前预览'),
        ),
        TextButton(
          onPressed: _busyMutation || singleSelectedId == null
              ? null
              : () => _runMutation(() => _loadDownloadUrl(singleSelectedId)),
          child: const Text('读取下载链接'),
        ),
        TextButton(
          onPressed: _busyMutation || _selectedIds.isEmpty
              ? null
              : () => _runMutation(() => _exportSelectedZip(selected)),
          child: const Text('导出所选 ZIP'),
        ),
      ],
    );
  }
}
