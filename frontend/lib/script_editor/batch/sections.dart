part of '../../../home_page.dart';

/// Keeps batch storyboard control sections beside the batch domain so the main
/// dialog file stays focused on selection state and overall composition.
extension _StoryboardBatchWorkbenchSections
    on _StoryboardBatchWorkbenchDialogState {
  Widget _buildBatchWorkbenchTopActions() {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: _loadingProduction || _busyMutation
              ? null
              : _refreshProduction,
          child: Text(
            _loadingProduction
                ? l10n.scriptEditorStoryboardBatchSyncing
                : l10n.scriptEditorStoryboardBatchRecommendSyncProduction,
          ),
        ),
        TextButton(
          onPressed: _busyMutation ? null : _selectReadyStoryboards,
          child: Text(l10n.scriptEditorStoryboardBatchRecommendSelectReady),
        ),
        TextButton(
          onPressed: _busyMutation ? null : _clearSelection,
          child: Text(l10n.scriptEditorStoryboardBatchClearSelectionButton),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchPromptSection() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrls.promptSuffixCtrl,
            decoration: InputDecoration(
              labelText: l10n.scriptEditorStoryboardBatchPromptSuffixLabel,
              helperText: l10n.scriptEditorStoryboardBatchPromptSuffixHelper,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _ctrls.negativePromptCtrl,
            decoration: InputDecoration(
              labelText: l10n.scriptEditorStoryboardBatchNegativePromptLabel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchModelSection() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrls.modelCtrl,
            decoration: InputDecoration(
              labelText: l10n.scriptEditorStoryboardBatchModelLabel,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: _ctrls.resolutionCtrl,
            decoration: InputDecoration(
              labelText: l10n.scriptEditorStoryboardBatchResolutionLabel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchMutationActions({
    required List<int> selected,
    required int? singleSelectedId,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final canQuickGenerate =
        _selectedIds.isNotEmpty || _readyStoryboardIds().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: _busyMutation || !canQuickGenerate
                  ? null
                  : () => _runMutation(_batchGenerate),
              child: Text(
                _busyMutation
                    ? l10n.scriptEditorStoryboardsBusy
                    : l10n.scriptEditorStoryboardBatchRecommendGenerateSelected,
              ),
            ),
            TextButton(
              onPressed: _busyMutation || singleSelectedId == null
                  ? null
                  : () =>
                        _runMutation(() => _loadCurrentPreview(singleSelectedId)),
              child: Text(l10n.scriptEditorStoryboardBatchRecommendPreviewSelected),
            ),
            TextButton(
              onPressed: _busyMutation || singleSelectedId == null
                  ? null
                  : () =>
                        _runMutation(() => _loadDownloadUrl(singleSelectedId)),
              child: Text(l10n.scriptEditorStoryboardBatchReadDownloadLink),
            ),
            TextButton(
              onPressed: _busyMutation || _selectedIds.isEmpty
                  ? null
                  : () => _runMutation(() => _exportSelectedZip(selected)),
              child: Text(l10n.scriptEditorStoryboardBatchRecommendExportSelected),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.scriptEditorStoryboardBatchQuickGenerateHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildBatchWorkbenchBoardsList({
    required Map<int, ProductionStoryboardItemV1> productionMap,
  }) {
    final l10n = AppLocalizations.of(context)!;
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
              _storyboardMetaLine(l10n, row, productionRow),
              prompt ?? l10n.scriptEditorStoryboardBatchNoResolvablePrompt,
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
    final l10n = AppLocalizations.of(context)!;
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
          Text(
            l10n.scriptEditorStoryboardBatchPreviewExportHeading,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            singleSelectedId == null
                ? l10n.scriptEditorStoryboardBatchSelectOneForPreview
                : l10n.scriptEditorStoryboardBatchViewingShot(singleSelectedId),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (exportEstimate != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.scriptEditorStoryboardBatchExportEstimateHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.scriptEditorStoryboardBatchExportEstimateContent(
                exportEstimate.shotCount,
                exportEstimate.sidecarLabel,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.scriptEditorStoryboardBatchExportEstimateEntries(
                exportEstimate.estimatedEntryCount,
                exportEstimate.totalDurationLabel,
              ),
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
            Text(
              exportEstimate.audioDeliveryLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.voiceoverJsonLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.assemblyPlanLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_downloadUrl != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              l10n.scriptEditorStoryboardBatchDownloadLinkLine(_downloadUrl!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_exportSummary != null) ...[
            const SizedBox(height: 12),
            Text(
              l10n.scriptEditorStoryboardBatchLastExportHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.scriptEditorStoryboardBatchExportFileLine(
                _exportSummary!.filename,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.scriptEditorStoryboardBatchExportContentLine(
                _exportSummary!.shotCount,
                _exportSummary!.sidecarLabel,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.scriptEditorStoryboardBatchExportDetailWithSize(
                _exportSummary!.estimatedEntryCount,
                _exportSummary!.totalDurationLabel,
                formatBinarySize(_exportSummary!.byteLength ?? 0),
              ),
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
              _exportSummary!.audioDeliveryLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.voiceoverJsonLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.assemblyPlanLabel,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.scriptEditorStoryboardBatchExportShotIds(
                _exportSummary!.shotIds.join(', '),
              ),
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
                      l10n.scriptEditorStoryboardBatchPreviewPlaceholder,
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
