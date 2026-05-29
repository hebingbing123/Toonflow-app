part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

extension _ShortVideoSpaceSectionProductionAssemblyClipDesk on _ShortVideoSpaceSectionState {
  Future<void> _openAssemblyClipDeskOps() async {
    final token = widget.accessToken;
    final project = _selectedProject;
    final assembly = _shortVideoAssembly;
    if (token == null || token.isEmpty || project == null || assembly == null) {
      return;
    }
    final entries = <_AssemblyClipDeskOpEntry>[
      for (final group in assembly.scripts)
        for (final shot in group.shots)
          _AssemblyClipDeskOpEntry(
            scriptNumericId: group.scriptNumericId,
            storyboardId: shot.storyboardId,
            storyboardNumericId: shot.storyboardNumericId,
            sbIndex: shot.sbIndex,
            selectedMediaUrl: (shot.selectedMediaUrl ?? '').trim(),
            selectedMediaKind: shot.selectedMediaKind,
            durationText: (shot.duration ?? '').trim(),
            subtitleText: (shot.subtitleText ?? '').trim(),
            voiceoverScriptReady: shot.voiceoverScriptReady,
            voiceoverAssetReady: shot.voiceoverAssetReady,
            voiceoverState: shot.voiceoverState ?? '',
            voiceoverAudioUrl: (shot.voiceoverAudioUrl ?? '').trim(),
            voiceoverError: (shot.voiceoverError ?? '').trim(),
          ),
    ];
    if (entries.isEmpty) {
      return;
    }
    var ordered = List<_AssemblyClipDeskOpEntry>.from(entries);
    final initialOrdered = List<_AssemblyClipDeskOpEntry>.from(entries);
    final pausedStoryboardIds = <int>{
      for (final item in entries)
        if (item.selectedMediaUrl.isEmpty) item.storyboardNumericId,
    };
    var filterState = FilterState.empty();
    var filterPresets = <FilterPreset>[]; // Filter presets storage
    var operationInProgress = false;
    var selectedStoryboardIds = <int>{}; // Batch selection state
    if (!mounted) return;
    await showStudioDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            final l10n = resolveAppLocalizationsForErrors(ctx);
            Future<void> runDisable(_AssemblyClipDeskOpEntry item) async {
              try {
                await postWorkbenchDeleteVideoV1(
                  token,
                  projectUuid: project.id,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                );
                pausedStoryboardIds.add(item.storyboardNumericId);

                // Record operation for undo/redo
                _recordDisableOperation(
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  previousVideoUrl: item.selectedMediaUrl,
                );

                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyShotDisabled(
                      item.storyboardNumericId,
                    ),
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyDisableFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              }
            }

            Future<void> runEnableOrReplace(
              _AssemblyClipDeskOpEntry item, {
              String? replacementUrl,
            }) async {
              final seedUrl = (replacementUrl ?? item.selectedMediaUrl).trim();
              if (seedUrl.isEmpty) {
                ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
                  SnackBar(
                    content: Text(
                      l10n.shortVideoSpaceProductionAssemblyNoVideoUrl,
                    ),
                  ),
                );
                return;
              }
              try {
                // Store previous URL for undo/redo
                final previousUrl = item.selectedMediaUrl;
                final isReplace =
                    replacementUrl != null && previousUrl.isNotEmpty;

                await postWorkbenchSelectVideoV1(
                  token,
                  projectUuid: project.id,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  videoUrl: seedUrl,
                );

                // Record operation for undo/redo
                if (isReplace) {
                  _recordReplaceOperation(
                    scriptId: item.scriptNumericId,
                    storyboardId: item.storyboardNumericId,
                    previousVideoUrl: previousUrl,
                    newVideoUrl: seedUrl,
                  );
                } else {
                  _recordEnableOperation(
                    scriptId: item.scriptNumericId,
                    storyboardId: item.storyboardNumericId,
                    videoUrl: seedUrl,
                  );
                }

                pausedStoryboardIds.remove(item.storyboardNumericId);
                if (replacementUrl != null) {
                  final idx = ordered.indexWhere(
                    (entry) =>
                        entry.storyboardNumericId == item.storyboardNumericId,
                  );
                  if (idx >= 0) {
                    ordered[idx] = ordered[idx].copyWith(
                      selectedMediaUrl: seedUrl,
                    );
                  }
                }
                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyShotWriteBack(
                      item.storyboardNumericId,
                    ),
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyWriteBackFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              }
            }

            Future<void> persistReorder() async {
              final byScript = <int, List<int>>{};
              for (final item in ordered) {
                byScript
                    .putIfAbsent(item.scriptNumericId, () => <int>[])
                    .add(item.storyboardNumericId);
              }
              setLocalState(() {
                operationInProgress = true;
              });
              try {
                for (final entry in byScript.entries) {
                  final scriptNumericId = entry.key;
                  final orderedStoryboardIds = entry.value;
                  final flowData = await fallbackOnRustApiException(
                    () => fetchProductionFlowDataV1(
                      token,
                      projectUuid: project.id,
                      episodesId: scriptNumericId,
                    ),
                    <String, dynamic>{},
                  );
                  flowData['storyboard'] = orderedStoryboardIds
                      .map((id) => <String, dynamic>{'id': id})
                      .toList(growable: false);
                  final code = await postProductionSaveFlowDataV1(
                    token,
                    projectUuid: project.id,
                    episodesId: scriptNumericId,
                    data: flowData,
                  );
                  if (code != 200) {
                    throw RustApiException(
                      'save flow failed',
                      statusCode: code,
                    );
                  }
                }
                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyReorderPersisted,
                    isSuccess: true,
                  );
                }
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyReorderFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              } finally {
                setLocalState(() {
                  operationInProgress = false;
                });
              }
            }

            Future<void> runAlignDuration(
              _AssemblyClipDeskOpEntry item,
              int durationSeconds,
            ) async {
              try {
                // Store previous duration for undo/redo
                final previousDuration =
                    int.tryParse(
                      item.durationText.replaceAll(RegExp(r'[^0-9]'), ''),
                    ) ??
                    0;

                final status = await postStoryboardUpdateDurationV1(
                  token,
                  projectUuid: project.id,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  duration: durationSeconds,
                );
                if (status != 200) {
                  throw RustApiException(
                    'update storyboard duration failed',
                    statusCode: status,
                  );
                }

                // Record operation for undo/redo
                _recordDurationOperation(
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  previousDuration: previousDuration,
                  newDuration: durationSeconds,
                );

                final idx = ordered.indexWhere(
                  (entry) =>
                      entry.storyboardNumericId == item.storyboardNumericId,
                );
                if (idx >= 0) {
                  ordered[idx] = ordered[idx].copyWith(
                    durationText: '${durationSeconds}s',
                  );
                }
                if (mounted) {
                  _showOperationFeedback(
                    l10n.shortVideoSpaceProductionAssemblyShotAligned(
                      item.storyboardNumericId,
                      durationSeconds,
                    ),
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                _invalidateProductionSnapshots();
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  l10n.shortVideoSpaceProductionAssemblyAlignFailed(
                    describeUserVisibleApiErrorResolved(context, e),
                  ),
                  isSuccess: false,
                );
              }
            }

            final filters = _AssemblyClipDeskFilterKit(
              filterState: filterState,
              pausedStoryboardIds: pausedStoryboardIds,
              l10n: l10n,
              context: ctx,
              ordered: ordered,
            );

            final currentTotalDuration = filters.calculateCurrentTotalDuration();
            final currentTotalFormatted = _AssemblyClipDeskFilterKit.formatDurationHHMMSS(
              currentTotalDuration,
            );
            final visibleEntries = filters.buildVisibleEntries();

            return StudioAlertDialog(
              title: Text(l10n.shortVideoSpaceProductionAssemblyBasicOpsTitle),
              content: SizedBox(
                width: studioConstrainedDialogWidth(context, maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.shortVideoSpaceProductionAssemblyBasicOpsDescription,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    Text(
                      l10n.shortVideoSpaceProductionAssemblyBasicOpsNote,
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    // 显示成片总时长
                    Container(
                      padding: const EdgeInsets.all(StudioSpacing.xs),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          ctx,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          StudioSpacing.radiusDense,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: StudioIconSize.md,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: StudioSpacing.xs),
                          Text(
                            l10n.shortVideoSpaceProductionAssemblyTotalDuration(
                              currentTotalDuration,
                              currentTotalFormatted,
                            ),
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    FilterPanel(
                      initialFilter: filterState,
                      onFilterChanged: (nextFilter) {
                        setLocalState(() {
                          filterState = nextFilter;
                        });
                      },
                      presets: filterPresets,
                      onPresetsChanged: (newPresets) {
                        setLocalState(() {
                          filterPresets = newPresets;
                        });
                      },
                      onSearchFocusNodeCreated: (focusNode) {
                        _setSearchFocusNode(focusNode);
                      },
                    ),
                    const SizedBox(height: StudioSpacing.xs),
                    // Batch operation toolbar
                    if (visibleEntries.isNotEmpty)
                      BatchOperationToolbar(
                        totalCount: visibleEntries.length,
                        selectedIds: selectedStoryboardIds,
                        onSelectionChanged: (newSelection) {
                          setLocalState(() {
                            selectedStoryboardIds = newSelection;
                          });
                        },
                        onSelectAll: () {
                          setLocalState(() {
                            selectedStoryboardIds = visibleEntries
                                .map((e) => e.storyboardNumericId)
                                .toSet();
                          });
                        },
                        onDeselectAll: () {
                          setLocalState(() {
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchEnable: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchEnableShots(
                            selectedStoryboardIds: selectedStoryboardIds,
                            allEntries: ordered,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                            dialogContext: ctx,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchDisable: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchDisableShots(
                            selectedStoryboardIds: selectedStoryboardIds,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                            dialogContext: ctx,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchUpdateDuration: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchUpdateDuration(
                            selectedStoryboardIds: selectedStoryboardIds,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchReplace: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchReplaceVideos(
                            selectedStoryboardIds: selectedStoryboardIds,
                            allEntries: ordered,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                            refreshData: _refreshProductionOverview,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        onBatchGenerateVoiceover: () async {
                          setLocalState(() {
                            operationInProgress = true;
                          });
                          await _batchGenerateVoiceover(
                            selectedStoryboardIds: selectedStoryboardIds,
                            allEntries: ordered,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                          );
                          setLocalState(() {
                            operationInProgress = false;
                            selectedStoryboardIds.clear();
                          });
                        },
                        isOperationInProgress: operationInProgress,
                      ),
                    const SizedBox(height: StudioSpacing.xs),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: StudioDenseActionRow(
                        children: [
                          StudioDebouncedAction(
                            enabled: !operationInProgress,
                            onPressed: operationInProgress
                                ? null
                                : () async => persistReorder(),
                            builder: (context, onPressed) => FilledButton.tonalIcon(
                              style: studioFormIconLabeledButtonStyle(context),
                              onPressed: onPressed,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                l10n.shortVideoSpaceProductionAssemblySaveReorder,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            style: studioFormOutlinedIconLabeledButtonStyle(context),
                            onPressed: operationInProgress
                                ? null
                                : () {
                                    ordered =
                                        List<_AssemblyClipDeskOpEntry>.from(
                                          initialOrdered,
                                        );
                                    setLocalState(() {});
                                  },
                            icon: const Icon(Icons.undo_outlined),
                            label: Text(
                              l10n.shortVideoSpaceProductionAssemblyUndoToOpen,
                            ),
                          ),
                          StudioDebouncedAction(
                            enabled: !operationInProgress,
                            onPressed: operationInProgress
                                ? null
                                : () async => _openTtsTaskCenterDialog(
                                      context: ctx,
                                      token: token,
                                      projectId: project.id,
                                      entries: ordered,
                                    ),
                            builder: (context, onPressed) => OutlinedButton.icon(
                              style: studioFormOutlinedIconLabeledButtonStyle(
                                context,
                              ),
                              onPressed: onPressed,
                              icon: const Icon(Icons.record_voice_over_outlined),
                              label: Text(
                                l10n.shortVideoSpaceProductionAssemblyVoiceoverTasks,
                              ),
                            ),
                          ),
                          // Undo/Redo buttons
                          _buildUndoRedoToolbar(),
                        ],
                      ),
                    ),
                    const SizedBox(height: StudioLayoutSpacing.inlineGap),
                    Flexible(
                      child: visibleEntries.isEmpty
                          ? Center(
                              child: Text(
                                l10n.shortVideoSpaceProductionAssemblyNoShotsFiltered,
                                style: Theme.of(ctx).textTheme.bodyMedium,
                              ),
                            )
                          : _buildVirtualScrollList(
                              visibleEntries: visibleEntries,
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
                              parseDurationSeconds:
                                  _AssemblyClipDeskFilterKit.parseDurationSeconds,
                              subtitleMismatchLine: filters.subtitleMismatchLine,
                              buildHighlightedText: filters.buildHighlightedText,
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l10n.shortVideoSpaceProductionAssemblyClose),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
