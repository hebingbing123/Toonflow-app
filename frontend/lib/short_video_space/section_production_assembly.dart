// ignore_for_file: invalid_use_of_protected_member

part of 'section.dart';

/// Assembly and clip desk operations for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionAssemblyExtension on _ShortVideoSpaceSectionState {
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
    var operationInProgress = false;
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
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: visibleEntries.length,
                        itemBuilder: (ctx, idx) {
                          final item = visibleEntries[idx];
                          final actualIndex = ordered.indexOf(item);
                          final paused = pausedStoryboardIds.contains(
                            item.storyboardNumericId,
                          );
                          final canMoveUp = actualIndex > 0;
                          final canMoveDown = actualIndex < ordered.length - 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
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
                                  Text(
                                    '时长：${item.durationText.isEmpty ? "未设定" : item.durationText} · '
                                    '字幕：${item.subtitleText.isEmpty ? "空" : "已填"}',
                                  ),
                                  const SizedBox(height: 2),
                                  // 配音状态展示
                                  Text(
                                    '配音文本：${item.voiceoverScriptReady ? "✓ 就绪" : "✗ 未就绪"} · '
                                    '配音资产：${item.voiceoverAssetReady ? "✓ 就绪" : "✗ 未就绪"}',
                                  ),
                                  if (item.voiceoverState.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '配音状态：${item.voiceoverState}',
                                    ),
                                  ],
                                  if (item.voiceoverAudioUrl.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '配音音频：${item.voiceoverAudioUrl}',
                                      style: Theme.of(ctx).textTheme.bodySmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (item.voiceoverState == 'failed' &&
                                      item.voiceoverError.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      '配音错误：${item.voiceoverError}',
                                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(ctx).colorScheme.error,
                                          ),
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
                                        onPressed: operationInProgress ? null : () {
                                          if (paused) {
                                            unawaited(runEnableOrReplace(item));
                                          } else {
                                            unawaited(runDisable(item));
                                          }
                                        },
                                        child: Text(paused ? '启用' : '暂停'),
                                      ),
                                      OutlinedButton(
                                        onPressed: operationInProgress ? null : () async {
                                          final ctrl = TextEditingController(
                                            text: parseDurationSeconds(
                                                      item.durationText,
                                                    )?.toString() ??
                                                '',
                                          );
                                          final picked = await showDialog<int>(
                                            context: ctx,
                                            builder: (dCtx) => AlertDialog(
                                              title: const Text('单镜头时长对齐'),
                                              content: TextField(
                                                controller: ctrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: const InputDecoration(
                                                  labelText: '时长（秒）',
                                                  hintText: '输入 1~300',
                                                ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.of(
                                                    dCtx,
                                                  ).pop(),
                                                  child: const Text('取消'),
                                                ),
                                                FilledButton(
                                                  onPressed: () {
                                                    final sec = int.tryParse(
                                                      ctrl.text.trim(),
                                                    );
                                                    Navigator.of(
                                                      dCtx,
                                                    ).pop(sec);
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
                                          unawaited(
                                            runAlignDuration(item, picked),
                                          );
                                        },
                                        child: const Text('时长对齐'),
                                      ),
                                      OutlinedButton(
                                        onPressed: operationInProgress ? null : () async {
                                          final nextUrl =
                                              await _promptReplacementVideoUrl(
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
                                    ],
                                  ),
                                ],
                              ),
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
