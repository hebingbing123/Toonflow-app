part of '../../../home_page.dart';

/// Keeps batch storyboard control sections beside the batch domain so the main
/// dialog file stays focused on selection state and overall composition.
extension _StoryboardBatchWorkbenchSections
    on _StoryboardBatchWorkbenchDialogState {
  Widget _buildBatchWorkbenchTopActions() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioWorkbenchSection(
      title: l10n.scriptEditorStoryboardBatchDialogTitle,
      child: StudioFilterRow(
        wideLayout: StudioFilterWideLayout.toolbarRow,
        children: <Widget>[
          FilledButton.tonal(
            style: studioFormTonalButtonStyle(context),
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
      ),
    );
  }

  Widget _buildBatchWorkbenchPromptSection() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioWorkbenchSection(
      title: l10n.scriptEditorStoryboardBatchPromptSuffixLabel,
      child: StudioFilterRow(
        wideLayout: StudioFilterWideLayout.toolbarRow,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _ctrls.promptSuffixCtrl,
              decoration: InputDecoration(
                labelText: l10n.scriptEditorStoryboardBatchPromptSuffixLabel,
                helperText: l10n.scriptEditorStoryboardBatchPromptSuffixHelper,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrls.negativePromptCtrl,
              decoration: InputDecoration(
                labelText: l10n.scriptEditorStoryboardBatchNegativePromptLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchWorkbenchModelSection() {
    final l10n = resolveAppLocalizationsForErrors(context);
    return StudioWorkbenchSection(
      title: l10n.scriptEditorStoryboardBatchModelLabel,
      child: StudioFilterRow(
        wideLayout: StudioFilterWideLayout.toolbarRow,
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _ctrls.modelCtrl,
              decoration: InputDecoration(
                labelText: l10n.scriptEditorStoryboardBatchModelLabel,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _ctrls.resolutionCtrl,
              decoration: InputDecoration(
                labelText: l10n.scriptEditorStoryboardBatchResolutionLabel,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchWorkbenchMutationActions({
    required List<int> selected,
    required int? singleSelectedId,
  }) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final canQuickGenerate =
        _selectedIds.isNotEmpty || _readyStoryboardIds().isNotEmpty;
    return StudioWorkbenchSection(
      title: l10n.scriptEditorStoryboardBatchRecommendGenerateSelected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StudioFilterRow(
            wideLayout: StudioFilterWideLayout.toolbarRow,
            children: <Widget>[
              FilledButton(
                style: studioFormPrimaryButtonStyle(context),
                onPressed: _busyMutation || !canQuickGenerate
                    ? null
                    : () => _runMutation(_batchGenerate),
                child: Text(
                  _busyMutation
                      ? l10n.scriptEditorStoryboardsBusy
                      : l10n
                            .scriptEditorStoryboardBatchRecommendGenerateSelected,
                ),
              ),
              TextButton(
                onPressed: _busyMutation || singleSelectedId == null
                    ? null
                    : () => _runMutation(
                        () => _loadCurrentPreview(singleSelectedId),
                      ),
                child: Text(
                  l10n.scriptEditorStoryboardBatchRecommendPreviewSelected,
                ),
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
                child: Text(
                  l10n.scriptEditorStoryboardBatchRecommendExportSelected,
                ),
              ),
            ],
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            l10n.scriptEditorStoryboardBatchQuickGenerateHint,
            style: studioHintStyle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchWorkbenchBoardsList({
    required Map<int, ProductionStoryboardItemV1> productionMap,
  }) {
    final l10n = resolveAppLocalizationsForErrors(context);
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
        return studioStaggeredItem(
          index,
          entranceKey: widget.boardsList.length,
          child: StudioCheckboxListRow(
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
          title: Text(l10n.l10nBatch_46f00a087b(row.numericId)),
          subtitle: Text(
            [
              _storyboardMetaLine(l10n, row, productionRow),
              prompt ?? l10n.scriptEditorStoryboardBatchNoResolvablePrompt,
            ].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        );
      },
    );
  }

  Widget _buildBatchWorkbenchPreviewPanel({
    required BuildContext context,
    required int? singleSelectedId,
  }) {
    final l10n = resolveAppLocalizationsForErrors(context);
    final exportEstimate = _currentExportEstimate();
    return Container(
      padding: const EdgeInsets.all(StudioSpacing.radiusComfort),
      decoration: studioRecessedPanelDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.scriptEditorStoryboardBatchPreviewExportHeading,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: StudioSpacing.xs),
          Text(
            singleSelectedId == null
                ? l10n.scriptEditorStoryboardBatchSelectOneForPreview
                : l10n.scriptEditorStoryboardBatchViewingShot(singleSelectedId),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (exportEstimate != null) ...[
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.scriptEditorStoryboardBatchExportEstimateHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.scriptEditorStoryboardBatchExportEstimateContent(
                exportEstimate.shotCount,
                exportEstimate.sidecarLabel(l10n),
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
              exportEstimate.subtitleCoverageLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.voiceoverCoverageLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.audioDeliveryLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.voiceoverJsonLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              exportEstimate.assemblyPlanLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_downloadUrl != null) ...[
            const SizedBox(height: StudioSpacing.xs),
            SelectableText(
              l10n.scriptEditorStoryboardBatchDownloadLinkLine(_downloadUrl!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_exportSummary != null) ...[
            const SizedBox(height: StudioSpacing.sm),
            Text(
              l10n.scriptEditorStoryboardBatchLastExportHeading,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: StudioSpacing.xs),
            Text(
              l10n.scriptEditorStoryboardBatchExportFileLine(
                _exportSummary!.filename,
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.scriptEditorStoryboardBatchExportContentLine(
                _exportSummary!.shotCount,
                _exportSummary!.sidecarLabel(l10n),
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
              _exportSummary!.subtitleCoverageLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.voiceoverCoverageLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.audioDeliveryLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.voiceoverJsonLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              _exportSummary!.assemblyPlanLabel(l10n),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              l10n.scriptEditorStoryboardBatchExportShotIds(
                _exportSummary!.shotIds.join(', '),
              ),
              style: studioHintStyle(context),
            ),
          ],
          const SizedBox(height: StudioSpacing.sm),
          Expanded(
            child: _previewUrl == null
                ? Center(
                    child: Text(
                      l10n.scriptEditorStoryboardBatchPreviewPlaceholder,
                      style: studioHintStyle(context),
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(StudioSpacing.radiusButton),
                    child: StudioNetworkImage(
                      accessToken: widget.token,
                      url: _previewUrl!,
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
