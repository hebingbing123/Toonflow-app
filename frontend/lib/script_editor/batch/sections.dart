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
            controller: _ctrls.promptSuffixCtrl,
            decoration: const InputDecoration(
              labelText: '追加提示词（可选）',
              helperText: '会拼接到每条分镜原提示词末尾。',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _ctrls.negativePromptCtrl,
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
            controller: _ctrls.modelCtrl,
            decoration: const InputDecoration(labelText: '模型（可选）'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _ctrls.resolutionCtrl,
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

  Widget _buildBatchWorkbenchBoardsList({
    required Map<int, ProductionStoryboardItemV1> productionMap,
  }) {
    return ListView.builder(
      itemCount: widget.boardsList.length,
      itemBuilder: (context, index) {
        final row = widget.boardsList[index];
        final productionRow = productionMap[row.numericId];
        final prompt = resolveStoryboardGenerationPrompt(
          scriptStoryboard: row,
          productionStoryboard: productionRow,
        );
        final checked = _selectedIds.contains(row.numericId);
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: checked,
          onChanged: _busyMutation
              ? null
              : (value) {
                  _applyBatchWorkbenchState(() {
                    final previousSingleSelectedId = _selectedIds.length == 1
                        ? _selectedIds.first
                        : null;
                    if (value == true) {
                      _selectedIds.add(row.numericId);
                    } else {
                      _selectedIds.remove(row.numericId);
                    }
                    final nextSingleSelectedId = _selectedIds.length == 1
                        ? _selectedIds.first
                        : null;
                    if (previousSingleSelectedId != nextSingleSelectedId) {
                      _clearSelectionScopedOutputs();
                    }
                  });
                },
          title: Text('#${row.numericId}'),
          subtitle: Text(
            [
              _storyboardMetaLine(row, productionRow),
              prompt ?? '无可用提示词',
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }

  Widget _buildBatchWorkbenchPreviewPanel({
    required BuildContext context,
    required int? singleSelectedId,
  }) {
    final exportEstimate = _currentExportEstimate();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('预览与导出信息', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(
            singleSelectedId == null
                ? '选中 1 条分镜后可读取当前预览与下载链接。'
                : '当前查看分镜 #$singleSelectedId',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (exportEstimate != null) ...[
            const SizedBox(height: 12),
            Text('待导出包预估', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              '内容：${exportEstimate.shotCount} 张分镜图 + ${exportEstimate.sidecarLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '预计条目：${exportEstimate.estimatedEntryCount} 个 · 总时长 ${exportEstimate.totalDurationLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.subtitleCoverageLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.voiceoverCoverageLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_downloadUrl != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              '下载链接：$_downloadUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_exportSummary != null) ...[
            const SizedBox(height: 12),
            Text('最近导出包', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(
              '文件：${_exportSummary!.filename}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '内容：${_exportSummary!.shotCount} 张分镜图 + ${_exportSummary!.sidecarLabel}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '预计条目：${_exportSummary!.estimatedEntryCount} 个 · 总时长 ${_exportSummary!.totalDurationLabel} · 大小 ${formatBinarySize(_exportSummary!.byteLength ?? 0)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.subtitleCoverageLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.voiceoverCoverageLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '分镜 ID：${_exportSummary!.shotIds.join(", ")}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Expanded(
            child: _previewUrl == null
                ? Center(
                    child: Text(
                      '这里会显示当前分镜预览图。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _previewUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, _, _) => Center(
                        child: SelectableText(
                          _previewUrl!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
