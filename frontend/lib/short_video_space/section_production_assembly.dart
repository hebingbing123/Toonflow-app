part of 'section.dart';

/// Assembly and clip desk operations for ShortVideoSpaceSection
extension _ShortVideoSpaceSectionProductionAssemblyExtension on _ShortVideoSpaceSectionState {
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
                if (mounted) {
                  setState(() {
                    _projectConfigLine =
                        '分镜 #${item.storyboardNumericId} 已暂停（清空当前视频）。';
                  });
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '暂停失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '暂停失败：$e';
                });
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
                await postWorkbenchSelectVideoV1(
                  token,
                  projectId: project.numericId,
                  scriptId: item.scriptNumericId,
                  storyboardId: item.storyboardNumericId,
                  videoUrl: seedUrl,
                );
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
                  setState(() {
                    _projectConfigLine =
                        '分镜 #${item.storyboardNumericId} 已写回当前视频版本。';
                  });
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '写回失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '写回失败：$e';
                });
              }
            }

            Future<void> persistReorder() async {
              final byScript = <int, List<int>>{};
              for (final item in ordered) {
                byScript.putIfAbsent(item.scriptNumericId, () => <int>[]).add(
                  item.storyboardNumericId,
                );
              }
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
                  setState(() {
                    _projectConfigLine =
                        '已持久化镜头重排顺序（按剧本写回时间线与分镜序号）。';
                  });
                }
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '重排持久化失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '重排持久化失败：$e';
                });
              }
            }

            Future<void> runAlignDuration(
              _AssemblyClipDeskOpEntry item,
              int durationSeconds,
            ) async {
              try {
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
                  setState(() {
                    _projectConfigLine =
                        '分镜 #${item.storyboardNumericId} 已对齐为 ${durationSeconds}s。';
                  });
                }
                setLocalState(() {});
                await _loadProjectOverview();
              } on RustApiException catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '时长对齐失败：${e.statusCode ?? '-'}';
                });
              } catch (e) {
                if (!mounted) return;
                setState(() {
                  _projectConfigLine = '时长对齐失败：$e';
                });
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: () => unawaited(persistReorder()),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('保存重排顺序'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              ordered = List<_AssemblyClipDeskOpEntry>.from(
                                initialOrdered,
                              );
                              setLocalState(() {});
                            },
                            icon: const Icon(Icons.undo_outlined),
                            label: const Text('撤销到打开时'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: ordered.length,
                        itemBuilder: (ctx, idx) {
                          final item = ordered[idx];
                          final paused = pausedStoryboardIds.contains(
                            item.storyboardNumericId,
                          );
                          final canMoveUp = idx > 0;
                          final canMoveDown = idx < ordered.length - 1;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '剧本 #${item.scriptNumericId} · 分镜 #${item.storyboardNumericId} · 顺序 ${idx + 1}',
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
                                  Text(
                                    '错位检查：${subtitleMismatchLine(item)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton(
                                        onPressed: canMoveUp
                                            ? () {
                                                final current = ordered[idx];
                                                ordered[idx] = ordered[idx - 1];
                                                ordered[idx - 1] = current;
                                                setLocalState(() {});
                                              }
                                            : null,
                                        child: const Text('上移'),
                                      ),
                                      OutlinedButton(
                                        onPressed: canMoveDown
                                            ? () {
                                                final current = ordered[idx];
                                                ordered[idx] = ordered[idx + 1];
                                                ordered[idx + 1] = current;
                                                setLocalState(() {});
                                              }
                                            : null,
                                        child: const Text('下移'),
                                      ),
                                      FilledButton.tonal(
                                        onPressed: () {
                                          if (paused) {
                                            unawaited(runEnableOrReplace(item));
                                          } else {
                                            unawaited(runDisable(item));
                                          }
                                        },
                                        child: Text(paused ? '启用' : '暂停'),
                                      ),
                                      OutlinedButton(
                                        onPressed: () async {
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
                                        onPressed: () async {
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
                      _projectConfigLine =
                          '已更新成片级默认：字幕 ${_subtitleStyle.trim().isEmpty ? "默认" : _subtitleStyle.trim()} · '
                          'BGM ${_bgmStrategy.trim().isEmpty ? "默认" : _bgmStrategy.trim()}';
                    });
                    await _loadProjectOverview();
                  } on RustApiException catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _projectConfigLine = '成片样式写回失败：${e.statusCode ?? '-'}';
                    });
                  } catch (e) {
                    if (!mounted) return;
                    setState(() {
                      _projectConfigLine = '成片样式写回失败：$e';
                    });
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
  });

  final int scriptNumericId;
  final int storyboardNumericId;
  final int? sbIndex;
  final String selectedMediaUrl;
  final String selectedMediaKind;
  final String durationText;
  final String subtitleText;

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
    );
  }
}
