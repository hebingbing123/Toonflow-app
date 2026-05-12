// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

/// Assembly and clip desk operations for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionAssemblyExtension on _ShortVideoSpaceSectionState {
  Future<void> _startExportFlow() async {
    final token = widget.accessToken?.trim();
    final project = _selectedProject;
    if (token == null || token.isEmpty || project == null || _exportActionBusy) {
      return;
    }

    final settings = await _openExportSettingsDialog(context: context);
    if (settings == null || !mounted) {
      return;
    }

    setState(() {
      _exportActionBusy = true;
    });
    try {
      final task = await postExportStartV1(
        token,
        CreateExportTaskRequestV1(
          projectId: project.id,
          format: settings.format,
          quality: ExportQualityV1(
            resolution: settings.resolution,
            bitrate: getBitrateValue(settings.bitrate),
            framerate: settings.framerate,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      final completed = await _openExportProgressDialog(
        context: context,
        taskId: task.id,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(completed ? '导出已完成。' : '导出未完成或已取消。'),
        ),
      );
      await _loadProjectOverview();
    } on RustApiException catch (e) {
      if (!mounted) {
        return;
      }
      reportRustApiError(e, onErrorChanged: (_) {});
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('导出启动失败：$e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportActionBusy = false;
        });
      }
    }
  }

  Future<void> _openExportHistoryFlow() async {
    if (_selectedProject == null || _exportActionBusy) {
      return;
    }
    await _openExportHistoryDialog(context: context);
  }

  /// Show operation feedback with auto-dismiss after 3 seconds
  void _showOperationFeedback(String message, {required bool isSuccess}) {
    setState(() {
      _projectConfigLine = message;
      _operationFeedbackIsSuccess = isSuccess;
    });
    
    // Auto-clear after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _projectConfigLine = null;
          _operationFeedbackIsSuccess = null;
        });
      }
    });
  }

  Future<String?> _promptReplacementVideoUrl(
    BuildContext context, {
    String initialValue = '',
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('替换当前视频版本'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: '视频 URL',
              hintText: 'https://...',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('写回当前版本'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  /// Show audio preview dialog for voiceover
  ///
  /// **Validates: Requirements 5**
  void _showAudioPreviewDialog({
    required BuildContext context,
    required String audioUrl,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AudioPreviewPlayer(
              audioUrl: audioUrl,
              autoPlay: false,
              onClose: () => Navigator.of(dialogContext).pop(),
            ),
          ),
        );
      },
    );
  }

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
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            Future<void> runDisable(_AssemblyClipDeskOpEntry item) async {
              try {
                await postWorkbenchDeleteVideoV1(
                  token,
                  projectId: project.numericId,
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
                    '分镜 #${item.storyboardNumericId} 已暂停（清空当前视频）。',
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '暂停失败：${e.statusCode ?? '-'}',
                  isSuccess: false,
                );
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '暂停失败：$e',
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
                  const SnackBar(content: Text('没有可用视频 URL，请先输入替换地址。')),
                );
                return;
              }
              try {
                // Store previous URL for undo/redo
                final previousUrl = item.selectedMediaUrl;
                final isReplace = replacementUrl != null && previousUrl.isNotEmpty;
                
                await postWorkbenchSelectVideoV1(
                  token,
                  projectId: project.numericId,
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
                    ordered[idx] = ordered[idx].copyWith(selectedMediaUrl: seedUrl);
                  }
                }
                if (mounted) {
                  _showOperationFeedback(
                    '分镜 #${item.storyboardNumericId} 已写回当前视频版本。',
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '写回失败：${e.statusCode ?? '-'}',
                  isSuccess: false,
                );
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '写回失败：$e',
                  isSuccess: false,
                );
              }
            }

            Future<void> persistReorder() async {
              final byScript = <int, List<int>>{};
              for (final item in ordered) {
                byScript.putIfAbsent(item.scriptNumericId, () => <int>[]).add(
                  item.storyboardNumericId,
                );
              }
              setLocalState(() {
                operationInProgress = true;
              });
              try {
                for (final entry in byScript.entries) {
                  final scriptNumericId = entry.key;
                  final orderedStoryboardIds = entry.value;
                  Map<String, dynamic> flowData;
                  try {
                    flowData = await fetchProductionFlowDataV1(
                      token,
                      projectId: project.numericId,
                      episodesId: scriptNumericId,
                    );
                  } on RustApiException {
                    flowData = <String, dynamic>{};
                  }
                  flowData['storyboard'] = orderedStoryboardIds
                      .map((id) => <String, dynamic>{'id': id})
                      .toList(growable: false);
                  final code = await postProductionSaveFlowDataV1(
                    token,
                    projectId: project.numericId,
                    episodesId: scriptNumericId,
                    data: flowData,
                  );
                  if (code != 200) {
                    throw RustApiException('save flow failed', statusCode: code);
                  }
                }
                if (mounted) {
                  _showOperationFeedback(
                    '已持久化镜头重排顺序（按剧本写回时间线与分镜序号）。',
                    isSuccess: true,
                  );
                }
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '重排持久化失败：${e.statusCode ?? '-'}',
                  isSuccess: false,
                );
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '重排持久化失败：$e',
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
                final previousDuration = int.tryParse(
                  item.durationText.replaceAll(RegExp(r'[^0-9]'), ''),
                ) ?? 0;
                
                final status = await postStoryboardUpdateDurationV1(
                  token,
                  projectId: project.numericId,
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
                    '分镜 #${item.storyboardNumericId} 已对齐为 ${durationSeconds}s。',
                    isSuccess: true,
                  );
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '时长对齐失败：${e.statusCode ?? '-'}',
                  isSuccess: false,
                );
              } catch (e) {
                if (!mounted) return;
                _showOperationFeedback(
                  '时长对齐失败：$e',
                  isSuccess: false,
                );
              }
            }

            int? parseDurationSeconds(String value) {
              final trimmed = value.trim().toLowerCase();
              if (trimmed.isEmpty) return null;
              final digits = RegExp(r'^(\d{1,3})\s*s?$').firstMatch(trimmed);
              if (digits == null) return null;
              return int.tryParse(digits.group(1)!);
            }

            String subtitleMismatchLine(_AssemblyClipDeskOpEntry item) {
              final durationSec = parseDurationSeconds(item.durationText);
              final hasSubtitle = item.subtitleText.isNotEmpty;
              if (hasSubtitle && durationSec == null) {
                return '字幕存在，但时长未显式（建议先对齐时长）。';
              }
              if (!hasSubtitle && (durationSec ?? 0) > 0) {
                return '时长已设定，但字幕为空（可能有字幕轨缺口）。';
              }
              if (hasSubtitle && (durationSec ?? 0) <= 0) {
                return '字幕存在，但时长异常（<=0）。';
              }
              return '字幕与时长未见明显错位。';
            }

            bool hasQualityIssue(_AssemblyClipDeskOpEntry item) {
              return item.voiceoverState == 'failed' ||
                  subtitleMismatchLine(item) != '字幕与时长未见明显错位。';
            }

            bool matchesSearch(_AssemblyClipDeskOpEntry item) {
              final keyword = filterState.searchKeyword.trim().toLowerCase();
              if (keyword.isEmpty) {
                return true;
              }
              final searchTargets = <String>[
                item.storyboardNumericId.toString(),
                item.scriptNumericId.toString(),
                item.selectedMediaUrl,
                if (filterState.searchInSubtitles) item.subtitleText,
                if (filterState.searchInVoiceover) ...[
                  item.voiceoverState,
                  item.voiceoverError,
                  item.voiceoverAudioUrl,
                ],
              ];
              return searchTargets.any(
                (value) => value.toLowerCase().contains(keyword),
              );
            }

            /// Build highlighted text widget for search results
            Widget buildHighlightedText(
              String text,
              String keyword, {
              TextStyle? style,
            }) {
              if (keyword.isEmpty || text.isEmpty) {
                return Text(text, style: style);
              }

              final lowerText = text.toLowerCase();
              final lowerKeyword = keyword.toLowerCase();
              final matches = <int>[];
              
              // Find all occurrences of the keyword
              var startIndex = 0;
              while (true) {
                final index = lowerText.indexOf(lowerKeyword, startIndex);
                if (index == -1) break;
                matches.add(index);
                startIndex = index + lowerKeyword.length;
              }

              if (matches.isEmpty) {
                return Text(text, style: style);
              }

              // Build text spans with highlighting
              final spans = <TextSpan>[];
              var currentIndex = 0;

              for (final matchIndex in matches) {
                // Add text before match
                if (matchIndex > currentIndex) {
                  spans.add(TextSpan(
                    text: text.substring(currentIndex, matchIndex),
                    style: style,
                  ));
                }

                // Add highlighted match
                spans.add(TextSpan(
                  text: text.substring(
                    matchIndex,
                    matchIndex + lowerKeyword.length,
                  ),
                  style: (style ?? const TextStyle()).copyWith(
                    backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                    color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ));

                currentIndex = matchIndex + lowerKeyword.length;
              }

              // Add remaining text
              if (currentIndex < text.length) {
                spans.add(TextSpan(
                  text: text.substring(currentIndex),
                  style: style,
                ));
              }

              return RichText(
                text: TextSpan(children: spans),
              );
            }

            bool matchesStatusFilters(_AssemblyClipDeskOpEntry item) {
              if (filterState.statusFilters.isEmpty) {
                return true;
              }
              final paused = pausedStoryboardIds.contains(item.storyboardNumericId);
              final durationSec = parseDurationSeconds(item.durationText);
              final hasSubtitle = item.subtitleText.isNotEmpty;
              final hasVoiceover = item.voiceoverScriptReady || item.voiceoverAssetReady;
              for (final filter in filterState.statusFilters) {
                switch (filter) {
                  case ShotStatusFilter.enabled:
                    if (!paused) return true;
                    break;
                  case ShotStatusFilter.disabled:
                    if (paused) return true;
                    break;
                  case ShotStatusFilter.hasVideo:
                    if (item.selectedMediaUrl.isNotEmpty) return true;
                    break;
                  case ShotStatusFilter.noVideo:
                    if (item.selectedMediaUrl.isEmpty) return true;
                    break;
                  case ShotStatusFilter.hasDuration:
                    if ((durationSec ?? 0) > 0) return true;
                    break;
                  case ShotStatusFilter.noDuration:
                    if ((durationSec ?? 0) <= 0) return true;
                    break;
                  case ShotStatusFilter.hasSubtitle:
                    if (hasSubtitle) return true;
                    break;
                  case ShotStatusFilter.noSubtitle:
                    if (!hasSubtitle) return true;
                    break;
                  case ShotStatusFilter.hasVoiceover:
                    if (hasVoiceover) return true;
                    break;
                  case ShotStatusFilter.noVoiceover:
                    if (!hasVoiceover) return true;
                    break;
                  case ShotStatusFilter.voiceoverFailed:
                    if (item.voiceoverState == 'failed') return true;
                    break;
                }
              }
              return false;
            }

            bool matchesQualityFilters(_AssemblyClipDeskOpEntry item) {
              if (filterState.qualityFilters.isEmpty) {
                return true;
              }
              final qualityIssue = hasQualityIssue(item);
              final postProductionReady =
                  item.selectedMediaUrl.isNotEmpty &&
                  parseDurationSeconds(item.durationText) != null;
              for (final filter in filterState.qualityFilters) {
                switch (filter) {
                  case QualityFilter.hasBadExample:
                    if (qualityIssue) return true;
                    break;
                  case QualityFilter.noBadExample:
                    if (!qualityIssue) return true;
                    break;
                  case QualityFilter.generationStage:
                    if (!postProductionReady) return true;
                    break;
                  case QualityFilter.postProductionStage:
                    if (postProductionReady) return true;
                    break;
                  case QualityFilter.hasDegradation:
                    if (qualityIssue || pausedStoryboardIds.contains(item.storyboardNumericId)) {
                      return true;
                    }
                    break;
                  case QualityFilter.noDegradation:
                    if (!qualityIssue &&
                        !pausedStoryboardIds.contains(item.storyboardNumericId)) {
                      return true;
                    }
                    break;
                }
              }
              return false;
            }

            List<_AssemblyClipDeskOpEntry> buildVisibleEntries() {
              return ordered.where((item) {
                return matchesSearch(item) &&
                    matchesStatusFilters(item) &&
                    matchesQualityFilters(item);
              }).toList(growable: false);
            }

            // 计算当前总时长（实时更新）
            int calculateCurrentTotalDuration() {
              var total = 0;
              for (final item in ordered) {
                // 排除已暂停镜头
                if (pausedStoryboardIds.contains(item.storyboardNumericId)) {
                  continue;
                }
                final durationSec = parseDurationSeconds(item.durationText);
                if (durationSec != null && durationSec > 0) {
                  total += durationSec;
                }
              }
              return total;
            }

            String formatDurationHHMMSS(int totalSeconds) {
              final hours = totalSeconds ~/ 3600;
              final minutes = (totalSeconds % 3600) ~/ 60;
              final seconds = totalSeconds % 60;
              return '${hours.toString().padLeft(2, '0')}:'
                  '${minutes.toString().padLeft(2, '0')}:'
                  '${seconds.toString().padLeft(2, '0')}';
            }

            final currentTotalDuration = calculateCurrentTotalDuration();
            final currentTotalFormatted = formatDurationHHMMSS(currentTotalDuration);
            final visibleEntries = buildVisibleEntries();

            return AlertDialog(
              title: const Text('镜头基础操作'),
              content: SizedBox(
                width: 760,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '支持基础重排（本次面板视图）、启停和替换当前视频版本。',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '启停 / 替换会直接写回 J 媒体槽位；重排仅用于本次排障视图。',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    // 显示成片总时长
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 20,
                            color: Theme.of(ctx).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '成片总时长：$currentTotalDuration秒 ($currentTotalFormatted)',
                            style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
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
                            projectId: project.numericId,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            showFeedback: _showOperationFeedback,
                            refreshData: _loadProjectOverview,
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
                            projectId: project.numericId,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            showFeedback: _showOperationFeedback,
                            refreshData: _loadProjectOverview,
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
                            projectId: project.numericId,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                            refreshData: _loadProjectOverview,
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
                            projectId: project.numericId,
                            projectUuid: project.id,
                            scriptId: ordered.first.scriptNumericId,
                            token: token,
                            context: ctx,
                            showFeedback: _showOperationFeedback,
                            refreshData: _loadProjectOverview,
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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: operationInProgress ? null : () => unawaited(persistReorder()),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('保存重排顺序'),
                          ),
                          OutlinedButton.icon(
                            onPressed: operationInProgress ? null : () {
                              ordered = List<_AssemblyClipDeskOpEntry>.from(
                                initialOrdered,
                              );
                              setLocalState(() {});
                            },
                            icon: const Icon(Icons.undo_outlined),
                            label: const Text('撤销到打开时'),
                          ),
                          OutlinedButton.icon(
                            onPressed: operationInProgress
                                ? null
                                : () => unawaited(
                                      _openTtsTaskCenterDialog(
                                        context: ctx,
                                        token: token,
                                        projectId: project.id,
                                        entries: ordered,
                                      ),
                                    ),
                            icon: const Icon(Icons.record_voice_over_outlined),
                            label: const Text('配音任务'),
                          ),
                          // Undo/Redo buttons
                          _buildUndoRedoToolbar(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: visibleEntries.isEmpty
                          ? Center(
                              child: Text(
                                '当前过滤条件下没有镜头，试试清空搜索或放宽条件。',
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
                              setLocalState: setLocalState,
                              runDisable: runDisable,
                              runEnableOrReplace: runEnableOrReplace,
                              runAlignDuration: runAlignDuration,
                              parseDurationSeconds: parseDurationSeconds,
                              subtitleMismatchLine: subtitleMismatchLine,
                              buildHighlightedText: buildHighlightedText,
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openTtsTaskCenterDialog({
    required BuildContext context,
    required String token,
    required String projectId,
    required List<_AssemblyClipDeskOpEntry> entries,
  }) async {
    final shotNumericById = <String, int>{
      for (final item in entries)
        if (item.storyboardId.trim().isNotEmpty)
          item.storyboardId: item.storyboardNumericId,
    };
    final scriptByShotNumeric = <int, int>{
      for (final item in entries) item.storyboardNumericId: item.scriptNumericId,
    };
    var tasks = const <TtsTaskV1>[];
    var loading = true;
    var requestBusy = false;
    var statusFilter = _ttsTaskCenterStatusFilter;
    var groupedByShot = _ttsTaskCenterGroupedByShot;
    var keyword = _ttsTaskCenterKeyword;
    String? errorMessage;
    StateSetter? updateDialogState;
    Timer? poller;

    Future<void> loadTasks() async {
      final setState = updateDialogState;
      if (setState == null) return;
      setState(() {
        loading = true;
      });
      try {
        final next = await getTtsTasksV1(
          token,
          projectId: projectId,
          status: statusFilter.isEmpty ? null : statusFilter,
          limit: 100,
          offset: 0,
        );
        setState(() {
          tasks = next;
          errorMessage = null;
          loading = false;
        });
      } on RustApiException catch (e) {
        setState(() {
          errorMessage = '加载失败：${e.statusCode ?? '-'}';
          loading = false;
        });
      } catch (e) {
        setState(() {
          errorMessage = '加载失败：$e';
          loading = false;
        });
      }
    }

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (ctx, setState) {
              updateDialogState = setState;
              poller ??= Timer.periodic(
                const Duration(seconds: 4),
                (_) => unawaited(loadTasks()),
              );
              if (tasks.isEmpty && loading && errorMessage == null) {
                unawaited(loadTasks());
              }
              final latestTaskByShotId = <String, TtsTaskV1>{};
              if (!loading && groupedByShot) {
                for (final task in tasks) {
                  final shotId = (task.shotId ?? '').trim();
                  if (shotId.isEmpty) continue;
                  final current = latestTaskByShotId[shotId];
                  if (current == null || current.updatedAt.isBefore(task.updatedAt)) {
                    latestTaskByShotId[shotId] = task;
                  }
                }
              }
              final visibleTasks = groupedByShot
                  ? latestTaskByShotId.values.toList(growable: false)
                  : tasks;
              bool matchesKeyword(TtsTaskV1 task) {
                final q = keyword.trim().toLowerCase();
                if (q.isEmpty) return true;
                final taskIdHit = task.taskId.toLowerCase().contains(q);
                final shotNumeric = task.shotId == null
                    ? null
                    : shotNumericById[task.shotId!];
                final scriptNumeric = shotNumeric == null
                    ? null
                    : scriptByShotNumeric[shotNumeric];
                final shotHit = shotNumeric?.toString().contains(q) == true;
                final scriptHit = scriptNumeric?.toString().contains(q) == true;
                return taskIdHit || shotHit || scriptHit;
              }
              final filteredTasks = visibleTasks
                  .where(matchesKeyword)
                  .toList(growable: false);
              final retryableFilteredTasks = filteredTasks
                  .where(
                    (task) =>
                        task.status == 'failed' &&
                        task.taskId.trim().isNotEmpty,
                  )
                  .toList(growable: false);
              return AlertDialog(
                title: const Text('配音任务中心'),
                content: SizedBox(
                  width: 760,
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DropdownButton<String>(
                            value: statusFilter,
                            items: const [
                              DropdownMenuItem(value: '', child: Text('全部状态')),
                              DropdownMenuItem(value: 'queued', child: Text('queued')),
                              DropdownMenuItem(value: 'running', child: Text('running')),
                              DropdownMenuItem(value: 'succeeded', child: Text('succeeded')),
                              DropdownMenuItem(value: 'failed', child: Text('failed')),
                              DropdownMenuItem(value: 'cancelled', child: Text('cancelled')),
                            ],
                            onChanged: requestBusy
                                ? null
                                : (next) {
                                    setState(() {
                                      statusFilter = next ?? '';
                                      _ttsTaskCenterStatusFilter = statusFilter;
                                    });
                                    unawaited(loadTasks());
                                  },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed:
                                (loading || requestBusy) ? null : () => unawaited(loadTasks()),
                            icon: const Icon(Icons.refresh_outlined),
                            label: const Text('刷新'),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            selected: groupedByShot,
                            label: const Text('按分镜聚合'),
                            onSelected: requestBusy
                                ? null
                                : (selected) {
                                    setState(() {
                                      groupedByShot = selected;
                                      _ttsTaskCenterGroupedByShot = groupedByShot;
                                    });
                                  },
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: (loading || requestBusy || retryableFilteredTasks.isEmpty)
                                ? null
                                : () async {
                                    final retrySettings =
                                        await _openVoiceoverSettingsDialog(
                                      context: ctx,
                                      initialSettings: _ttsRetrySettings,
                                    );
                                    if (retrySettings == null) {
                                      return;
                                    }
                                    _ttsRetrySettings = retrySettings;
                                    setState(() {
                                      requestBusy = true;
                                    });
                                    var succeeded = 0;
                                    var failed = 0;
                                    for (final task in retryableFilteredTasks) {
                                      try {
                                        await postTtsRetryV1(
                                          token,
                                          TtsRetryRequestV1(
                                            taskId: task.taskId,
                                            provider: retrySettings.provider,
                                            voiceId: retrySettings.voiceId,
                                            emotion: retrySettings.emotion,
                                            speed: retrySettings.speed,
                                          ),
                                        );
                                        succeeded += 1;
                                      } catch (_) {
                                        failed += 1;
                                      }
                                    }
                                    if (!mounted) return;
                                    _showOperationFeedback(
                                      '批量重试完成：成功 $succeeded，失败 $failed',
                                      isSuccess: failed == 0,
                                    );
                                    await loadTasks();
                                    setState(() {
                                      requestBusy = false;
                                    });
                                  },
                            icon: const Icon(Icons.replay_outlined),
                            label: Text('批量重试失败 (${retryableFilteredTasks.length})'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        enabled: !requestBusy,
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixIcon: Icon(Icons.search),
                          hintText: '筛选：任务ID / 剧本号 / 分镜号',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            keyword = value;
                            _ttsTaskCenterKeyword = keyword;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (errorMessage != null)
                        Text(
                          errorMessage!,
                          style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                        ),
                      const SizedBox(height: 8),
                      if (!loading && tasks.isNotEmpty)
                        Text(
                          '共 ${tasks.length} 条 · '
                          'queued ${tasks.where((t) => t.status == "queued").length} · '
                          'running ${tasks.where((t) => t.status == "running").length} · '
                          'succeeded ${tasks.where((t) => t.status == "succeeded").length} · '
                          'failed ${tasks.where((t) => t.status == "failed").length} · '
                          'cancelled ${tasks.where((t) => t.status == "cancelled").length} · '
                          '展示 ${filteredTasks.length}/${visibleTasks.length}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      if (!loading && tasks.isNotEmpty) const SizedBox(height: 8),
                      Expanded(
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : tasks.isEmpty
                                ? const Center(child: Text('暂无配音任务'))
                                : ListView.separated(
                                    itemCount: groupedByShot
                                        ? filteredTasks.length
                                        : filteredTasks.length,
                                    separatorBuilder: (context, _) =>
                                        const Divider(height: 1),
                                    itemBuilder: (_, index) {
                                      final task = filteredTasks[index];
                                      final shotNumeric = task.shotId == null
                                          ? null
                                          : shotNumericById[task.shotId!];
                                      final scriptNumeric = shotNumeric == null
                                          ? null
                                          : scriptByShotNumeric[shotNumeric];
                                      final canCancel = task.status == 'queued' ||
                                          task.status == 'running';
                                      final hasAudio = (task.audioUrl ?? '')
                                          .trim()
                                          .isNotEmpty;
                                      final canRetry = task.status == 'failed' &&
                                          task.taskId.trim().isNotEmpty;
                                      return ListTile(
                                        dense: true,
                                        title: Text(
                                          '${groupedByShot ? "最近任务" : "任务"} ${task.taskId.substring(0, 8)} · 状态 ${task.status}',
                                        ),
                                        subtitle: Text(
                                          '剧本 #${scriptNumeric ?? "-"} · 分镜 #${shotNumeric ?? "-"}'
                                          '${task.audioUrl != null && task.audioUrl!.isNotEmpty ? ' · 音频就绪' : ''}'
                                          '${task.error != null && task.error!.isNotEmpty ? ' · 错误: ${task.error}' : ''}',
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            if (hasAudio)
                                              IconButton(
                                                tooltip: '预览音频',
                                                onPressed: () {
                                                  _showAudioPreviewDialog(
                                                    context: ctx,
                                                    audioUrl: task.audioUrl!.trim(),
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.play_circle_outline,
                                                ),
                                              ),
                                            if (hasAudio)
                                              IconButton(
                                                tooltip: '复制音频链接',
                                                onPressed: () async {
                                                  await Clipboard.setData(
                                                    ClipboardData(
                                                      text: task.audioUrl!.trim(),
                                                    ),
                                                  );
                                                  if (!mounted) return;
                                                  _showOperationFeedback(
                                                    '已复制音频链接',
                                                    isSuccess: true,
                                                  );
                                                },
                                                icon: const Icon(Icons.link),
                                              ),
                                            if (canCancel)
                                              TextButton(
                                                onPressed: requestBusy
                                                    ? null
                                                    : () async {
                                                        setState(() {
                                                          requestBusy = true;
                                                        });
                                                        try {
                                                          await postTtsCancelV1(
                                                            token,
                                                            task.taskId,
                                                          );
                                                          if (!mounted) return;
                                                          _showOperationFeedback(
                                                            '已取消配音任务 ${task.taskId.substring(0, 8)}',
                                                            isSuccess: true,
                                                          );
                                                          await loadTasks();
                                                        } on RustApiException catch (e) {
                                                          if (!mounted) return;
                                                          _showOperationFeedback(
                                                            '取消失败：${e.statusCode ?? '-'}',
                                                            isSuccess: false,
                                                          );
                                                        } catch (e) {
                                                          if (!mounted) return;
                                                          _showOperationFeedback(
                                                            '取消失败：$e',
                                                            isSuccess: false,
                                                          );
                                                        } finally {
                                                          setState(() {
                                                            requestBusy = false;
                                                          });
                                                        }
                                                      },
                                                child: const Text('取消'),
                                              ),
                                            if (canRetry)
                                              TextButton(
                                                onPressed: requestBusy
                                                    ? null
                                                    : () async {
                                                        final retrySettings =
                                                            await _openVoiceoverSettingsDialog(
                                                          context: ctx,
                                                          initialSettings:
                                                              _ttsRetrySettings,
                                                        );
                                                        if (retrySettings == null) {
                                                          return;
                                                        }
                                                        _ttsRetrySettings =
                                                            retrySettings;
                                                        setState(() {
                                                          requestBusy = true;
                                                        });
                                                        try {
                                                          final response =
                                                              await postTtsRetryV1(
                                                            token,
                                                            TtsRetryRequestV1(
                                                              taskId: task.taskId,
                                                              provider: retrySettings.provider,
                                                              voiceId: retrySettings.voiceId,
                                                              emotion: retrySettings.emotion,
                                                              speed: retrySettings.speed,
                                                            ),
                                                          );
                                                          if (!mounted) return;
                                                          _showOperationFeedback(
                                                            '已重试，任务 ${response.taskId.substring(0, 8)} 已入队',
                                                            isSuccess: true,
                                                          );
                                                          await loadTasks();
                                                        } on RustApiException catch (e) {
                                                          if (!mounted) return;
                                                          _showOperationFeedback(
                                                            '重试失败：${e.statusCode ?? '-'}',
                                                            isSuccess: false,
                                                          );
                                                        } catch (e) {
                                                          if (!mounted) return;
                                                          _showOperationFeedback(
                                                            '重试失败：$e',
                                                            isSuccess: false,
                                                          );
                                                        } finally {
                                                          setState(() {
                                                            requestBusy = false;
                                                          });
                                                        }
                                                      },
                                                child: const Text('重试'),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      poller?.cancel();
    }
  }

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
    required void Function(void Function()) setLocalState,
    required Future<void> Function(_AssemblyClipDeskOpEntry) runDisable,
    required Future<void> Function(_AssemblyClipDeskOpEntry, {String? replacementUrl}) runEnableOrReplace,
    required Future<void> Function(_AssemblyClipDeskOpEntry, int) runAlignDuration,
    required int? Function(String) parseDurationSeconds,
    required String Function(_AssemblyClipDeskOpEntry) subtitleMismatchLine,
    required Widget Function(String, String, {TextStyle? style}) buildHighlightedText,
  }) {
    // Use virtual scrolling when item count > 100 for performance
    final useVirtualScrolling = visibleEntries.length > 100;

    if (useVirtualScrolling) {
      // Use FlutterListView for virtual scrolling
      return FlutterListView(
        delegate: FlutterListViewDelegate(
          (context, idx) {
            final item = visibleEntries[idx];
            return _buildShotCard(
              item: item,
              ordered: ordered,
              pausedStoryboardIds: pausedStoryboardIds,
              selectedStoryboardIds: selectedStoryboardIds,
              operationInProgress: operationInProgress,
              filterState: filterState,
              ctx: ctx,
              setLocalState: setLocalState,
              runDisable: runDisable,
              runEnableOrReplace: runEnableOrReplace,
              runAlignDuration: runAlignDuration,
              parseDurationSeconds: parseDurationSeconds,
              subtitleMismatchLine: subtitleMismatchLine,
              buildHighlightedText: buildHighlightedText,
            );
          },
          childCount: visibleEntries.length,
          // Configure cache extent for better performance
          // This determines how many pixels of content to cache outside the viewport
          onItemKey: (idx) => visibleEntries[idx].storyboardNumericId.toString(),
        ),
      );
    } else {
      // Use standard ListView.builder for smaller lists
      return ListView.builder(
        shrinkWrap: true,
        itemCount: visibleEntries.length,
        itemBuilder: (context, idx) {
          final item = visibleEntries[idx];
          return _buildShotCard(
            item: item,
            ordered: ordered,
            pausedStoryboardIds: pausedStoryboardIds,
            selectedStoryboardIds: selectedStoryboardIds,
            operationInProgress: operationInProgress,
            filterState: filterState,
            ctx: ctx,
            setLocalState: setLocalState,
            runDisable: runDisable,
            runEnableOrReplace: runEnableOrReplace,
            runAlignDuration: runAlignDuration,
            parseDurationSeconds: parseDurationSeconds,
            subtitleMismatchLine: subtitleMismatchLine,
            buildHighlightedText: buildHighlightedText,
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
    required void Function(void Function()) setLocalState,
    required Future<void> Function(_AssemblyClipDeskOpEntry) runDisable,
    required Future<void> Function(_AssemblyClipDeskOpEntry, {String? replacementUrl}) runEnableOrReplace,
    required Future<void> Function(_AssemblyClipDeskOpEntry, int) runAlignDuration,
    required int? Function(String) parseDurationSeconds,
    required String Function(_AssemblyClipDeskOpEntry) subtitleMismatchLine,
    required Widget Function(String, String, {TextStyle? style}) buildHighlightedText,
  }) {
    final actualIndex = ordered.indexOf(item);
    final paused = pausedStoryboardIds.contains(item.storyboardNumericId);
    final canMoveUp = actualIndex > 0;
    final canMoveDown = actualIndex < ordered.length - 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
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
                          selectedStoryboardIds.remove(item.storyboardNumericId);
                        }
                      });
                    },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '剧本 #${item.scriptNumericId} · 分镜 #${item.storyboardNumericId} · 顺序 ${actualIndex + 1}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    paused
                        ? '状态：暂停'
                        : '状态：启用（${item.selectedMediaKind}）',
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text('时长：'),
                      buildHighlightedText(
                        item.durationText.isEmpty ? "未设定" : item.durationText,
                        filterState.searchKeyword,
                      ),
                      const Text(' · 字幕：'),
                      Flexible(
                        child: buildHighlightedText(
                          item.subtitleText.isEmpty ? "空" : item.subtitleText,
                          filterState.searchInSubtitles
                              ? filterState.searchKeyword
                              : '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // 配音状态展示
                  Text(
                    '配音文本：${item.voiceoverScriptReady ? "✓ 就绪" : "✗ 未就绪"} · '
                    '配音资产：${item.voiceoverAssetReady ? "✓ 就绪" : "✗ 未就绪"}',
                  ),
                  if (item.voiceoverState.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text('配音状态：'),
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text('配音音频：'),
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Text('配音错误：'),
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
                  const SizedBox(height: 2),
                  Text(
                    '错位检查：${subtitleMismatchLine(item)}',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: (canMoveUp && !operationInProgress)
                            ? () {
                                final current = ordered[actualIndex];
                                ordered[actualIndex] = ordered[actualIndex - 1];
                                ordered[actualIndex - 1] = current;
                                setLocalState(() {});
                              }
                            : null,
                        child: const Text('上移'),
                      ),
                      OutlinedButton(
                        onPressed: (canMoveDown && !operationInProgress)
                            ? () {
                                final current = ordered[actualIndex];
                                ordered[actualIndex] = ordered[actualIndex + 1];
                                ordered[actualIndex + 1] = current;
                                setLocalState(() {});
                              }
                            : null,
                        child: const Text('下移'),
                      ),
                      FilledButton.tonal(
                        onPressed: operationInProgress
                            ? null
                            : () {
                                if (paused) {
                                  unawaited(runEnableOrReplace(item));
                                } else {
                                  unawaited(runDisable(item));
                                }
                              },
                        child: Text(paused ? '启用' : '暂停'),
                      ),
                      OutlinedButton(
                        onPressed: operationInProgress
                            ? null
                            : () async {
                                final ctrl = TextEditingController(
                                  text: parseDurationSeconds(item.durationText)
                                          ?.toString() ??
                                      '',
                                );
                                final picked = await showDialog<int>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('单镜头时长对齐'),
                                    content: TextField(
                                      controller: ctrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        labelText: '时长（秒）',
                                        hintText: '输入 1~300',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(dCtx).pop(),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () {
                                          final sec =
                                              int.tryParse(ctrl.text.trim());
                                          Navigator.of(dCtx).pop(sec);
                                        },
                                        child: const Text('对齐并写回'),
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
                                unawaited(runAlignDuration(item, picked));
                              },
                        child: const Text('时长对齐'),
                      ),
                      OutlinedButton(
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
                                unawaited(
                                  runEnableOrReplace(
                                    item,
                                    replacementUrl: nextUrl,
                                  ),
                                );
                              },
                        child: const Text('替换当前版本'),
                      ),
                      // Generate voiceover button
                      if (item.voiceoverScriptReady)
                        FilledButton.icon(
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
                          icon: const Icon(Icons.record_voice_over),
                          label: const Text('生成配音'),
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
                          label: const Text('预览配音'),
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
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('成片级样式调整'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: subtitleCtrl,
                    decoration: const InputDecoration(
                      labelText: '字幕样式 subtitle_style',
                      hintText: '例如 cinematic_cn_v2（留空则回退默认）',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bgmCtrl,
                    decoration: const InputDecoration(
                      labelText: 'BGM 策略 bgm_strategy',
                      hintText: '例如 pulse_light（留空则回退默认）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '保存后会写回 D7 默认配置，并刷新成片装配快照中的生效值。',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  final nextSubtitle = subtitleCtrl.text.trim();
                  final nextBgm = bgmCtrl.text.trim();
                  Navigator.of(ctx).pop();
                  try {
                    final updated = await updateProjectByProjectId(
                      token,
                      project.id,
                      <String, dynamic>{
                        'subtitleStyle': nextSubtitle.isEmpty ? null : nextSubtitle,
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
                    _showOperationFeedback(
                      '已更新成片级默认：字幕 ${_subtitleStyle.trim().isEmpty ? "默认" : _subtitleStyle.trim()} · '
                      'BGM ${_bgmStrategy.trim().isEmpty ? "默认" : _bgmStrategy.trim()}',
                      isSuccess: true,
                    );
                    await _loadProjectOverview();
                  } on RustApiException catch (e) {
                    if (!mounted) return;
                    _showOperationFeedback(
                      '成片样式写回失败：${e.statusCode ?? '-'}',
                      isSuccess: false,
                    );
                  } catch (e) {
                    if (!mounted) return;
                    _showOperationFeedback(
                      '成片样式写回失败：$e',
                      isSuccess: false,
                    );
                  }
                },
                child: const Text('保存并刷新'),
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

class _AssemblyClipDeskOpEntry {
  const _AssemblyClipDeskOpEntry({
    required this.scriptNumericId,
    required this.storyboardId,
    required this.storyboardNumericId,
    required this.sbIndex,
    required this.selectedMediaUrl,
    required this.selectedMediaKind,
    required this.durationText,
    required this.subtitleText,
    required this.voiceoverScriptReady,
    required this.voiceoverAssetReady,
    required this.voiceoverState,
    required this.voiceoverAudioUrl,
    required this.voiceoverError,
  });

  final int scriptNumericId;
  final String storyboardId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String selectedMediaUrl;
  final String selectedMediaKind;
  final String durationText;
  final String subtitleText;
  final bool voiceoverScriptReady;
  final bool voiceoverAssetReady;
  final String voiceoverState;
  final String voiceoverAudioUrl;
  final String voiceoverError;

  _AssemblyClipDeskOpEntry copyWith({
    String? selectedMediaUrl,
    String? durationText,
    String? subtitleText,
  }) {
    return _AssemblyClipDeskOpEntry(
      scriptNumericId: scriptNumericId,
      storyboardId: storyboardId,
      storyboardNumericId: storyboardNumericId,
      sbIndex: sbIndex,
      selectedMediaUrl: selectedMediaUrl ?? this.selectedMediaUrl,
      selectedMediaKind: selectedMediaKind,
      durationText: durationText ?? this.durationText,
      subtitleText: subtitleText ?? this.subtitleText,
      voiceoverScriptReady: voiceoverScriptReady,
      voiceoverAssetReady: voiceoverAssetReady,
      voiceoverState: voiceoverState,
      voiceoverAudioUrl: voiceoverAudioUrl,
      voiceoverError: voiceoverError,
    );
  }
}
