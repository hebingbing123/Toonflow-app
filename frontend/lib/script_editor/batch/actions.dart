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
    } catch (e) {
      if (mounted) {
        _applyBatchWorkbenchState(
          () => _statusLine = describeUserVisibleApiErrorResolved(context, e),
        );
      }
    } finally {
      if (mounted) _applyBatchWorkbenchState(() => _busyMutation = false);
      widget.onMutationEnd();
    }
  }

  Future<void> _batchGenerate() async {
    final productionMap = _productionById();
    final selected = _sortedSelection();
    final effectiveSelected = selected.isEmpty
        ? _readyStoryboardIds()
        : selected;
    final suffix = _ctrls.promptSuffixCtrl.text.trim();
    final negativePrompt = _ctrls.negativePromptCtrl.text.trim();
    final items = <BatchGenerateImageItem>[];
    for (final numericId in effectiveSelected) {
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
          model: _ctrls.modelCtrl.text.trim().isEmpty
              ? null
              : _ctrls.modelCtrl.text.trim(),
          resolution: _ctrls.resolutionCtrl.text.trim().isEmpty
              ? null
              : _ctrls.resolutionCtrl.text.trim(),
        ),
      );
    }
    if (items.isEmpty) {
      final loc = resolveAppLocalizationsForErrors(context);
      throw FormatException(loc.scriptEditorStoryboardBatchNoPromptsError);
    }
    final response = await postStoryboardBatchGenerateImageV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      items: items,
      model: _ctrls.modelCtrl.text.trim().isEmpty
          ? null
          : _ctrls.modelCtrl.text.trim(),
      resolution: _ctrls.resolutionCtrl.text.trim().isEmpty
          ? null
          : _ctrls.resolutionCtrl.text.trim(),
    );
    await _refreshProduction();
    if (mounted) {
      final l10n = resolveAppLocalizationsForErrors(context);
      _applyBatchWorkbenchState(() {
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          l10n,
          actionSummary: selected.isEmpty
              ? l10n.scriptEditorStoryboardBatchGenerateAutoSelected(
                  effectiveSelected.length,
                  response.total,
                  response.enqueued.length,
                )
              : l10n.scriptEditorStoryboardBatchGenerateSubmitted(
                  response.total,
                  response.enqueued.length,
                ),
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  void _selectReadyStoryboards() {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        l10n,
        actionSummary: l10n.scriptEditorStoryboardBatchSelectAllReady,
        diagnosis: _currentDiagnosis(),
      );
    });
  }

  void _clearSelection() {
    final l10n = resolveAppLocalizationsForErrors(context);
    _applyBatchWorkbenchState(() {
      _selectedIds.clear();
      _clearSelectionScopedOutputs();
      _statusLine = buildStoryboardBatchWorkbenchFollowUp(
        l10n,
        actionSummary: l10n.scriptEditorStoryboardBatchClearSelection,
        diagnosis: _currentDiagnosis(),
      );
    });
  }

  Future<void> _loadCurrentPreview(int storyboardId) async {
    final preview = await postStoryboardPreviewImageV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: storyboardId,
    );
    if (mounted) {
      final l10n = resolveAppLocalizationsForErrors(context);
      _applyBatchWorkbenchState(() {
        _previewUrl = preview.imageUrl;
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          l10n,
          actionSummary: preview.imageUrl == null
              ? l10n.scriptEditorStoryboardBatchNoPreview
              : l10n.scriptEditorStoryboardBatchPreviewLoaded(storyboardId),
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  Future<void> _loadDownloadUrl(int storyboardId) async {
    final preview = await postStoryboardDownPreviewImageV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      storyboardId: storyboardId,
    );
    if (mounted) {
      final l10n = resolveAppLocalizationsForErrors(context);
      _applyBatchWorkbenchState(() {
        _downloadUrl = preview.previewUrl;
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          l10n,
          actionSummary: preview.previewUrl == null
              ? preview.message
              : l10n.scriptEditorStoryboardBatchDownloadReady(storyboardId),
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }

  Future<void> _exportSelectedZip(List<int> selected) async {
    final zip = await fetchProductionExportImageZipV1(
      widget.token,
      projectUuid: widget.projectId,
      scriptId: widget.scriptNumericId,
      shotId: selected
          .map((id) => <String, dynamic>{'id': '$id'})
          .toList(growable: false),
    );
    final summary = buildStoryboardExportBundleSummary(
      selectedIds: selected,
      boards: widget.boardsList,
      productionRows: _productionRows,
      zip: zip,
    );
    if (mounted) {
      final l10n = resolveAppLocalizationsForErrors(context);
      _applyBatchWorkbenchState(() {
        _exportSummary = summary;
        _statusLine = buildStoryboardBatchWorkbenchFollowUp(
          l10n,
          actionSummary: l10n.scriptEditorStoryboardBatchExportDone(
            summary.shotCount,
            summary.filename,
            summary.totalDurationLabel,
          ),
          diagnosis: _currentDiagnosis(),
        );
      });
    }
  }
}
