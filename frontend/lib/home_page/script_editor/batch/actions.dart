part of '../../../home_page.dart';

/// Keeps batch storyboard mutations and external side effects out of the
/// dialog composition file so the batch subdomain can keep shrinking cleanly.
extension _StoryboardBatchWorkbenchActions
    on _StoryboardBatchWorkbenchDialogState {
  Future<void> _runMutation(Future<void> Function() action) async {
    widget.onMutationStart();
    _applyBatchWorkbenchState(() => _busyMutation = true);
    try {
      await action();
    } on RustApiException catch (e) {
      if (mounted) _applyBatchWorkbenchState(() => _statusLine = '$e');
    } catch (e) {
      if (mounted) _applyBatchWorkbenchState(() => _statusLine = '$e');
    } finally {
      if (mounted) _applyBatchWorkbenchState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  Future<void> _batchGenerate() async {
    final productionMap = _productionById();
    final selected = _sortedSelection();
    final suffix = _promptSuffixCtrl.text.trim();
    final negativePrompt = _negativePromptCtrl.text.trim();
    final items = <BatchGenerateImageItem>[];
    for (final numericId in selected) {
      final scriptRow = _findScriptRow(numericId);
      final prompt = resolveStoryboardGenerationPrompt(
        scriptStoryboard: scriptRow,
        productionStoryboard: productionMap[numericId],
      );
      if (prompt == null) continue;
      final combinedPrompt = suffix.isEmpty ? prompt : '$prompt\n$suffix';
      items.add(
        BatchGenerateImageItem(
          storyboardId: numericId,
          prompt: combinedPrompt,
          negativePrompt: negativePrompt.isEmpty ? null : negativePrompt,
          model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
          resolution: _resolutionCtrl.text.trim().isEmpty
              ? null
              : _resolutionCtrl.text.trim(),
        ),
      );
    }
    if (items.isEmpty) {
      throw const FormatException('所选分镜没有可用提示词，无法发起批量出图');
    }
    final response = await postStoryboardBatchGenerateImageV1(
      widget.token,
      projectId: widget.projectNumericId,
      scriptId: widget.scriptNumericId,
      items: items,
      model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
      resolution: _resolutionCtrl.text.trim().isEmpty
          ? null
          : _resolutionCtrl.text.trim(),
    );
    await _refreshProduction();
    if (mounted) {
      _applyBatchWorkbenchState(() {
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          actionSummary:
              '已为 ${response.total} 条分镜创建出图任务，队列 ${response.enqueued.length} 条。',
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  void _selectReadyStoryboards() {
    final productionMap = _productionById();
    _applyBatchWorkbenchState(() {
      _selectedIds
        ..clear()
        ..addAll(
          widget.boardsList
              .where(
                (row) =>
                    resolveStoryboardGenerationPrompt(
                      scriptStoryboard: row,
                      productionStoryboard: productionMap[row.numericId],
                    ) !=
                    null,
              )
              .map((row) => row.numericId),
        );
      _clearSelectionScopedOutputs();
      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
        actionSummary: '已选择全部可直接出图的分镜。',
        diagnosis: _currentDiagnosis(),
      );
    });
  }

  void _clearSelection() {
    _applyBatchWorkbenchState(() {
      _selectedIds.clear();
      _clearSelectionScopedOutputs();
      _exportLine = null;
      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
        actionSummary: '已清空选择。',
        diagnosis: _currentDiagnosis(),
      );
    });
  }

  Future<void> _loadCurrentPreview(int storyboardId) async {
    final preview = await postStoryboardPreviewImageV1(
      widget.token,
      storyboardId: storyboardId,
    );
    if (mounted) {
      _applyBatchWorkbenchState(() {
        _previewUrl = preview.imageUrl;
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          actionSummary: preview.imageUrl == null
              ? '当前分镜还没有预览图。'
              : '已读取分镜 #$storyboardId 的当前预览。',
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  Future<void> _loadDownloadUrl(int storyboardId) async {
    final preview = await postStoryboardDownPreviewImageV1(
      widget.token,
      storyboardId: storyboardId,
    );
    if (mounted) {
      _applyBatchWorkbenchState(() {
        _downloadUrl = preview.previewUrl;
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          actionSummary: preview.previewUrl == null
              ? preview.message
              : '已生成分镜 #$storyboardId 的下载链接。',
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  Future<void> _exportSelectedZip(List<int> selected) async {
    final zip = await fetchProductionExportImageZipV1(
      widget.token,
      shotId: selected
          .map((id) => <String, dynamic>{'id': '$id'})
          .toList(growable: false),
    );
    if (mounted) {
      _applyBatchWorkbenchState(() {
        _exportLine =
            '已导出 ${selected.length} 张分镜图片，文件 ${zip.filename ?? "storyboards.zip"}，大小 ${zip.bytes.length} bytes';
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          actionSummary: _exportLine!,
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }
}
