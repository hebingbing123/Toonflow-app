part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionAssemblyWidgets on _ShortVideoSpaceSectionState {
  /// Build virtual scroll list with FlutterListView for efficient rendering
  ///
  /// **Validates: Requirements 29**
  ///
  /// Automatically enables virtual scrolling when item count > 100
  Widget _buildVirtualScrollList({
    required List<_AssemblyClipDeskOpEntry> visibleEntries,
    required List<_AssemblyClipDeskOpEntry> ordered,
    required Set<int> pausedStoryboardIds,
    required Set<int> selectedStoryboardIds,
    required bool operationInProgress,
    required FilterState filterState,
    required BuildContext ctx,
    required AppLocalizations l10n,
    required void Function(void Function()) setLocalState,
    required Future<void> Function(_AssemblyClipDeskOpEntry) runDisable,
    required Future<void> Function(
      _AssemblyClipDeskOpEntry, {
      String? replacementUrl,
    })
    runEnableOrReplace,
    required Future<void> Function(_AssemblyClipDeskOpEntry, int)
    runAlignDuration,
    required int? Function(String) parseDurationSeconds,
    required String Function(_AssemblyClipDeskOpEntry) subtitleMismatchLine,
    required Widget Function(String, String, {TextStyle? style})
    buildHighlightedText,
  }) {
    // Use virtual scrolling when item count > 100 for performance
    final useVirtualScrolling = visibleEntries.length > 100;

    if (useVirtualScrolling) {
      // Use FlutterListView for virtual scrolling
      return FlutterListView(
        delegate: FlutterListViewDelegate(
          (context, idx) {
            final item = visibleEntries[idx];
            return studioStaggeredItem(
              idx,
              entranceKey: visibleEntries.length,
              child: _buildShotCard(
                item: item,
                ordered: ordered,
                pausedStoryboardIds: pausedStoryboardIds,
                selectedStoryboardIds: selectedStoryboardIds,
                operationInProgress: operationInProgress,
                filterState: filterState,
                ctx: ctx,
                l10n: l10n,
                setLocalState: setLocalState,
                runDisable: runDisable,
                runEnableOrReplace: runEnableOrReplace,
                runAlignDuration: runAlignDuration,
                parseDurationSeconds: parseDurationSeconds,
                subtitleMismatchLine: subtitleMismatchLine,
                buildHighlightedText: buildHighlightedText,
              ),
            );
          },
          childCount: visibleEntries.length,
          // Configure cache extent for better performance
          // This determines how many pixels of content to cache outside the viewport
          onItemKey: (idx) =>
              visibleEntries[idx].storyboardNumericId.toString(),
        ),
      );
    } else {
      // Use standard ListView.builder for smaller lists
      return ListView.builder(
        itemCount: visibleEntries.length,
        itemBuilder: (context, idx) {
          final item = visibleEntries[idx];
          return studioStaggeredItem(
            idx,
            entranceKey: visibleEntries.length,
            child: _buildShotCard(
              item: item,
              ordered: ordered,
              pausedStoryboardIds: pausedStoryboardIds,
              selectedStoryboardIds: selectedStoryboardIds,
              operationInProgress: operationInProgress,
              filterState: filterState,
              ctx: ctx,
              l10n: l10n,
              setLocalState: setLocalState,
              runDisable: runDisable,
              runEnableOrReplace: runEnableOrReplace,
              runAlignDuration: runAlignDuration,
              parseDurationSeconds: parseDurationSeconds,
              subtitleMismatchLine: subtitleMismatchLine,
              buildHighlightedText: buildHighlightedText,
            ),
          );
        },
      );
    }
  }

  /// Build a single shot card widget
  Widget _buildShotCard({
    required _AssemblyClipDeskOpEntry item,
    required List<_AssemblyClipDeskOpEntry> ordered,
    required Set<int> pausedStoryboardIds,
    required Set<int> selectedStoryboardIds,
    required bool operationInProgress,
    required FilterState filterState,
    required BuildContext ctx,
    required AppLocalizations l10n,
    required void Function(void Function()) setLocalState,
    required Future<void> Function(_AssemblyClipDeskOpEntry) runDisable,
    required Future<void> Function(
      _AssemblyClipDeskOpEntry, {
      String? replacementUrl,
    })
    runEnableOrReplace,
    required Future<void> Function(_AssemblyClipDeskOpEntry, int)
    runAlignDuration,
    required int? Function(String) parseDurationSeconds,
    required String Function(_AssemblyClipDeskOpEntry) subtitleMismatchLine,
    required Widget Function(String, String, {TextStyle? style})
    buildHighlightedText,
  }) {
    final actualIndex = ordered.indexOf(item);
    final paused = pausedStoryboardIds.contains(item.storyboardNumericId);
    final canMoveUp = actualIndex > 0;
    final canMoveDown = actualIndex < ordered.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: StudioSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(StudioSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox for batch selection
            Checkbox(
              value: selectedStoryboardIds.contains(item.storyboardNumericId),
              onChanged: operationInProgress
                  ? null
                  : (checked) {
                      setLocalState(() {
                        if (checked == true) {
                          selectedStoryboardIds.add(item.storyboardNumericId);
                        } else {
                          selectedStoryboardIds.remove(
                            item.storyboardNumericId,
                          );
                        }
                      });
                    },
            ),
            const SizedBox(width: StudioSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.shortVideoSpaceProductionAssemblyScriptShotOrder(
                      item.scriptNumericId,
                      item.storyboardNumericId,
                      actualIndex + 1,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    paused
                        ? l10n.shortVideoSpaceProductionAssemblyStatusPaused
                        : l10n.shortVideoSpaceProductionAssemblyStatusEnabled(
                            item.selectedMediaKind,
                          ),
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Row(
                    children: [
                      Text(l10n.shortVideoSpaceProductionAssemblyDurationLabel),
                      buildHighlightedText(
                        item.durationText.isEmpty
                            ? l10n.shortVideoSpaceProductionAssemblyDurationNotSet
                            : item.durationText,
                        filterState.searchKeyword,
                      ),
                      Text(l10n.shortVideoSpaceProductionAssemblySubtitleLabel),
                      Flexible(
                        child: buildHighlightedText(
                          item.subtitleText.isEmpty
                              ? l10n.shortVideoSpaceProductionAssemblySubtitleEmpty
                              : item.subtitleText,
                          filterState.searchInSubtitles
                              ? filterState.searchKeyword
                              : '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  // 配音状态展示
                  Text(
                    '${item.voiceoverScriptReady ? l10n.shortVideoSpaceProductionAssemblyVoiceoverScriptReady : l10n.shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady} · '
                    '${item.voiceoverAssetReady ? l10n.shortVideoSpaceProductionAssemblyVoiceoverAssetReady : l10n.shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady}',
                  ),
                  if (item.voiceoverState.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Row(
                      children: [
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyVoiceoverStatusLabel,
                        ),
                        buildHighlightedText(
                          item.voiceoverState,
                          filterState.searchInVoiceover
                              ? filterState.searchKeyword
                              : '',
                        ),
                      ],
                    ),
                  ],
                  if (item.voiceoverAudioUrl.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Row(
                      children: [
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyVoiceoverAudioLabel,
                        ),
                        Flexible(
                          child: buildHighlightedText(
                            item.voiceoverAudioUrl,
                            filterState.searchInVoiceover
                                ? filterState.searchKeyword
                                : '',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (item.voiceoverState == 'failed' &&
                      item.voiceoverError.isNotEmpty) ...[
                    const SizedBox(height: StudioSpacing.xs),
                    Row(
                      children: [
                        Text(
                          l10n.shortVideoSpaceProductionAssemblyVoiceoverErrorLabel,
                        ),
                        Flexible(
                          child: buildHighlightedText(
                            item.voiceoverError,
                            filterState.searchInVoiceover
                                ? filterState.searchKeyword
                                : '',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    '${l10n.shortVideoSpaceProductionAssemblyMismatchCheckLabel}${subtitleMismatchLine(item)}',
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  StudioDenseActionRow(
                    children: [
                      OutlinedButton(
                        style: studioFormSecondaryButtonStyle(context),
                        onPressed: (canMoveUp && !operationInProgress)
                            ? () {
                                final current = ordered[actualIndex];
                                ordered[actualIndex] = ordered[actualIndex - 1];
                                ordered[actualIndex - 1] = current;
                                setLocalState(() {});
                              }
                            : null,
                        child: Text(
                          l10n.shortVideoSpaceProductionAssemblyMoveUp,
                        ),
                      ),
                      OutlinedButton(
                        style: studioFormSecondaryButtonStyle(context),
                        onPressed: (canMoveDown && !operationInProgress)
                            ? () {
                                final current = ordered[actualIndex];
                                ordered[actualIndex] = ordered[actualIndex + 1];
                                ordered[actualIndex + 1] = current;
                                setLocalState(() {});
                              }
                            : null,
                        child: Text(
                          l10n.shortVideoSpaceProductionAssemblyMoveDown,
                        ),
                      ),
                      StudioDebouncedAction(
                        enabled: !operationInProgress,
                        onPressed: operationInProgress
                            ? null
                            : () async {
                                if (paused) {
                                  await runEnableOrReplace(item);
                                } else {
                                  await runDisable(item);
                                }
                              },
                        builder: (context, onPressed) => FilledButton.tonal(
                          style: studioFormTonalButtonStyle(context),
                          onPressed: onPressed,
                          child: Text(
                            paused
                                ? l10n.shortVideoSpaceProductionAssemblyEnable
                                : l10n.shortVideoSpaceProductionAssemblyPause,
                          ),
                        ),
                      ),
                      StudioDebouncedAction(
                        enabled: !operationInProgress,
                        onPressed: operationInProgress
                            ? null
                            : () async {
                                final ctrl = TextEditingController(
                                  text:
                                      parseDurationSeconds(
                                        item.durationText,
                                      )?.toString() ??
                                      '',
                                );
                                final picked = await showStudioDialog<int>(
                                  context: ctx,
                                  builder: (dCtx) => StudioAlertDialog(
                                    title: Text(
                                      l10n.shortVideoSpaceProductionAssemblySingleShotDurationTitle,
                                    ),
                                    content: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: l10n
                                            .shortVideoSpaceProductionAssemblySingleShotDurationLabel,
                                        hintText: l10n
                                            .shortVideoSpaceProductionAssemblySingleShotDurationHint,
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dCtx).pop(),
                                        child: Text(
                                          l10n.shortVideoSpaceProductionAssemblyCancel,
                                        ),
                                      ),
                                      FilledButton(
                                        style: studioFormPrimaryButtonStyle(context),
                                        onPressed: () {
                                          final sec = int.tryParse(
                                            ctrl.text.trim(),
                                          );
                                          Navigator.of(dCtx).pop(sec);
                                        },
                                        child: Text(
                                          l10n.shortVideoSpaceProductionAssemblyAlignAndWriteBack,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                ctrl.dispose();
                                if (picked == null ||
                                    picked <= 0 ||
                                    picked > 300) {
                                  return;
                                }
                                await runAlignDuration(item, picked);
                              },
                        builder: (context, onPressed) => OutlinedButton(
                          style: studioFormSecondaryButtonStyle(context),
                          onPressed: onPressed,
                          child: Text(
                            l10n.shortVideoSpaceProductionAssemblyAlignDuration,
                          ),
                        ),
                      ),
                      StudioDebouncedAction(
                        enabled: !operationInProgress,
                        onPressed: operationInProgress
                            ? null
                            : () async {
                                final nextUrl = await _promptReplacementVideoUrl(
                                  ctx,
                                  initialValue: item.selectedMediaUrl,
                                );
                                if ((nextUrl ?? '').trim().isEmpty) {
                                  return;
                                }
                                await runEnableOrReplace(
                                  item,
                                  replacementUrl: nextUrl,
                                );
                              },
                        builder: (context, onPressed) => OutlinedButton(
                          onPressed: onPressed,
                          child: Text(
                            l10n.shortVideoSpaceProductionAssemblyReplaceVersion,
                          ),
                        ),
                      ),
                      // Generate voiceover button
                      if (item.voiceoverScriptReady)
                        StudioDebouncedAction(
                          enabled: !operationInProgress,
                          onPressed: operationInProgress
                              ? null
                              : () async {
                                  await _generateSingleVoiceover(
                                    item: item,
                                    context: ctx,
                                    showFeedback: _showOperationFeedback,
                                  );
                                  setLocalState(() {});
                                },
                          builder: (context, onPressed) => FilledButton.icon(
                            style: studioFormIconLabeledButtonStyle(context),
                            onPressed: onPressed,
                            icon: const Icon(Icons.record_voice_over),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyGenerateVoiceover,
                            ),
                          ),
                        ),
                      // Preview voiceover audio button
                      if (item.voiceoverAudioUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: operationInProgress
                              ? null
                              : () {
                                  _showAudioPreviewDialog(
                                    context: ctx,
                                    audioUrl: item.voiceoverAudioUrl,
                                  );
                                },
                          icon: const Icon(Icons.play_circle_outline),
                          label: Text(
                            l10n.shortVideoSpaceProductionAssemblyPreviewVoiceover,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssemblyDefaultsEditor() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null) {
      return;
    }
    final subtitleCtrl = TextEditingController(text: _subtitleStyle);
    final bgmCtrl = TextEditingController(text: _bgmStrategy);
    try {
      if (!mounted) return;
      await showStudioDialog<void>(
        context: context,
        builder: (ctx) {
          final l10n = resolveAppLocalizationsForErrors(ctx);
          return StudioAlertDialog(
            title: Text(
              l10n.shortVideoSpaceProductionAssemblyAssemblyStyleTitle,
            ),
            content: SizedBox(
              width: studioConstrainedDialogWidth(context, maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subtitleCtrl,
                    decoration: InputDecoration(
                      labelText: l10n
                          .shortVideoSpaceProductionAssemblySubtitleStyleLabel,
                      hintText: l10n
                          .shortVideoSpaceProductionAssemblySubtitleStyleHint,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.sm),
                  TextField(
                    controller: bgmCtrl,
                    decoration: InputDecoration(
                      labelText: l10n
                          .shortVideoSpaceProductionAssemblyBgmStrategyLabel,
                      hintText:
                          l10n.shortVideoSpaceProductionAssemblyBgmStrategyHint,
                    ),
                  ),
                  const SizedBox(height: StudioSpacing.xs),
                  Text(
                    l10n.shortVideoSpaceProductionAssemblyStyleNote,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.shortVideoSpaceProductionAssemblyCancel),
              ),
              FilledButton(
                style: studioFormPrimaryButtonStyle(ctx),
                onPressed: () async {
                  final nextSubtitle = subtitleCtrl.text.trim();
                  final nextBgm = bgmCtrl.text.trim();
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  final rootL10n = resolveAppLocalizationsForErrors(context);
                  try {
                    final updated = await updateProjectByProjectId(
                      token,
                      project.id,
                      <String, dynamic>{
                        'subtitleStyle': nextSubtitle.isEmpty
                            ? null
                            : nextSubtitle,
                        'bgmStrategy': nextBgm.isEmpty ? null : nextBgm,
                      },
                    );
                    if (!mounted) return;
                    setState(() {
                      _subtitleStyle = updated.subtitleStyle ?? '';
                      _bgmStrategy = updated.bgmStrategy ?? '';
                      _projects = _projects
                          .map((row) => row.id == updated.id ? updated : row)
                          .toList(growable: false);
                    });
                    final subtitleDisplay = _subtitleStyle.trim().isEmpty
                        ? rootL10n.shortVideoSpaceProductionAssemblyStyleDefault
                        : _subtitleStyle.trim();
                    final bgmDisplay = _bgmStrategy.trim().isEmpty
                        ? rootL10n.shortVideoSpaceProductionAssemblyStyleDefault
                        : _bgmStrategy.trim();
                    _showOperationFeedback(
                      rootL10n.shortVideoSpaceProductionAssemblyStyleUpdated(
                        subtitleDisplay,
                        bgmDisplay,
                      ),
                      isSuccess: true,
                    );
                    _invalidateProductionSnapshots();
                  } catch (e) {
                    if (!mounted) return;
                    _showOperationFeedback(
                      rootL10n
                          .shortVideoSpaceProductionAssemblyStyleWriteBackFailed(
                            describeUserVisibleApiErrorResolved(context, e),
                          ),
                      isSuccess: false,
                    );
                  }
                },
                child: Text(
                  l10n.shortVideoSpaceProductionAssemblySaveAndRefresh,
                ),
              ),
            ],
          );
        },
      );
    } finally {
      subtitleCtrl.dispose();
      bgmCtrl.dispose();
    }
  }
}
