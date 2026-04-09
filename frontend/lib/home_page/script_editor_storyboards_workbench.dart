part of '../home_page.dart';

extension _HomePageScriptEditorStoryboardsWorkbench on _HomePageState {
  Future<void> _openStoryboardBatchWorkbenchDialog({
    required BuildContext ctx,
    required String token,
    required int projectLegacyId,
    required int scriptLegacyId,
    required List<StoryboardRow> boardsList,
    required StateSetter setBoardsState,
    required List<bool> actionBusy,
  }) async {
    final promptSuffixCtrl = TextEditingController();
    final negativePromptCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final resolutionCtrl = TextEditingController();

    final selectedIds = <int>{};
    List<ProductionStoryboardItemV1> productionRows = const [];
    bool loadingProduction = false;
    bool busyMutation = false;
    String? statusLine;
    String? previewUrl;
    String? downloadUrl;
    String? exportLine;

    Map<int, ProductionStoryboardItemV1> productionById() => {
      for (final row in productionRows) row.id: row,
    };

    List<int> sortedSelection() {
      final values = selectedIds.toList()..sort();
      return values;
    }

    StoryboardRow? findScriptRow(int legacyId) {
      for (final row in boardsList) {
        if (row.legacyId == legacyId) {
          return row;
        }
      }
      return null;
    }

    Future<void> refreshProduction(StateSetter setState) async {
      setState(() {
        loadingProduction = true;
        statusLine = null;
      });
      try {
        final response = await postProductionGetStoryboardDataV1(
          token,
          projectId: projectLegacyId,
          scriptId: scriptLegacyId,
        );
        final ids = boardsList.map((row) => row.legacyId).toSet();
        final filtered = response.data
            .where((row) => ids.contains(row.id))
            .toList(growable: false);
        setState(() {
          productionRows = filtered;
          selectedIds.removeWhere((legacyId) => !ids.contains(legacyId));
          if (selectedIds.isEmpty && boardsList.isNotEmpty) {
            selectedIds.add(boardsList.first.legacyId);
          }
          statusLine = filtered.isEmpty
              ? '制作视图尚无分镜记录，仍可按脚本分镜提示词发起出图。'
              : '已同步 ${filtered.length} 条制作分镜';
        });
      } on RustApiException catch (e) {
        setState(() => statusLine = '加载制作视图失败：$e');
      } catch (e) {
        setState(() => statusLine = '加载制作视图失败：$e');
      } finally {
        setState(() => loadingProduction = false);
      }
    }

    Future<void> runMutation(
      StateSetter setState,
      Future<void> Function() action,
    ) async {
      setBoardsState(() => actionBusy[0] = true);
      setState(() => busyMutation = true);
      try {
        await action();
      } on RustApiException catch (e) {
        setState(() => statusLine = '$e');
      } catch (e) {
        setState(() => statusLine = '$e');
      } finally {
        setState(() => busyMutation = false);
        if (ctx.mounted) {
          setBoardsState(() {});
          setBoardsState(() => actionBusy[0] = false);
        }
      }
    }

    String storyboardMetaLine(
      StoryboardRow row,
      ProductionStoryboardItemV1? productionRow,
    ) {
      final parts = <String>[
        if (row.sbIndex != null || productionRow?.sbIndex != null)
          '序号 ${row.sbIndex ?? productionRow?.sbIndex}',
        if ((row.state ?? productionRow?.state ?? '').trim().isNotEmpty)
          '状态 ${row.state ?? productionRow?.state}',
        if ((row.duration ?? productionRow?.duration ?? '').trim().isNotEmpty)
          '时长 ${row.duration ?? productionRow?.duration}',
        if ((row.filePath ?? productionRow?.url ?? '').trim().isNotEmpty)
          '已有画面',
      ];
      return parts.isEmpty ? '待补充分镜信息' : parts.join(' · ');
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              final productionMap = productionById();
              final selected = sortedSelection();
              final singleSelectedId = selected.length == 1
                  ? selected.first
                  : null;
              return AlertDialog(
                title: const Text('分镜出图工作台'),
                content: SizedBox(
                  width: 820,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '把批量出图、当前预览、下载链接与导出 ZIP 收口到剧本分镜区，不再只依赖 production probe。',
                        style: Theme.of(dialogCtx).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(dialogCtx).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: loadingProduction || busyMutation
                                ? null
                                : () => refreshProduction(setState),
                            child: Text(loadingProduction ? '同步中…' : '同步制作视图'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () {
                                    setState(() {
                                      selectedIds
                                        ..clear()
                                        ..addAll(
                                          boardsList
                                              .where(
                                                (row) =>
                                                    resolveStoryboardGenerationPrompt(
                                                      scriptStoryboard: row,
                                                      productionStoryboard:
                                                          productionMap[row
                                                              .legacyId],
                                                    ) !=
                                                    null,
                                              )
                                              .map((row) => row.legacyId),
                                        );
                                      statusLine = '已选择全部可直接出图的分镜';
                                    });
                                  },
                            child: const Text('全选可出图分镜'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () {
                                    setState(() {
                                      selectedIds.clear();
                                      previewUrl = null;
                                      downloadUrl = null;
                                      exportLine = null;
                                      statusLine = '已清空选择';
                                    });
                                  },
                            child: const Text('清空选择'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: promptSuffixCtrl,
                              decoration: const InputDecoration(
                                labelText: '追加提示词（可选）',
                                helperText: '会拼接到每条分镜原提示词末尾。',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: negativePromptCtrl,
                              decoration: const InputDecoration(
                                labelText: '负面提示词（可选）',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: modelCtrl,
                              decoration: const InputDecoration(
                                labelText: '模型（可选）',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: resolutionCtrl,
                              decoration: const InputDecoration(
                                labelText: '分辨率（可选）',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: busyMutation || selectedIds.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final productionMap = productionById();
                                    final suffix = promptSuffixCtrl.text.trim();
                                    final negativePrompt = negativePromptCtrl
                                        .text
                                        .trim();
                                    final items = <BatchGenerateImageItem>[];
                                    for (final legacyId in selected) {
                                      final scriptRow = findScriptRow(legacyId);
                                      final prompt =
                                          resolveStoryboardGenerationPrompt(
                                            scriptStoryboard: scriptRow,
                                            productionStoryboard:
                                                productionMap[legacyId],
                                          );
                                      if (prompt == null) {
                                        continue;
                                      }
                                      final combinedPrompt = suffix.isEmpty
                                          ? prompt
                                          : '$prompt\n$suffix';
                                      items.add(
                                        BatchGenerateImageItem(
                                          storyboardId: legacyId,
                                          prompt: combinedPrompt,
                                          negativePrompt: negativePrompt.isEmpty
                                              ? null
                                              : negativePrompt,
                                          model: modelCtrl.text.trim().isEmpty
                                              ? null
                                              : modelCtrl.text.trim(),
                                          resolution:
                                              resolutionCtrl.text.trim().isEmpty
                                              ? null
                                              : resolutionCtrl.text.trim(),
                                        ),
                                      );
                                    }
                                    if (items.isEmpty) {
                                      throw const FormatException(
                                        '所选分镜没有可用提示词，无法发起批量出图',
                                      );
                                    }
                                    final response =
                                        await postStoryboardBatchGenerateImageV1(
                                          token,
                                          projectId: projectLegacyId,
                                          scriptId: scriptLegacyId,
                                          items: items,
                                          model: modelCtrl.text.trim().isEmpty
                                              ? null
                                              : modelCtrl.text.trim(),
                                          resolution:
                                              resolutionCtrl.text.trim().isEmpty
                                              ? null
                                              : resolutionCtrl.text.trim(),
                                        );
                                    await refreshProduction(setState);
                                    statusLine =
                                        '已为 ${response.total} 条分镜创建出图任务，队列 ${response.enqueued.length} 条';
                                  }),
                            child: Text(busyMutation ? '处理中…' : '批量发起出图'),
                          ),
                          TextButton(
                            onPressed: busyMutation || singleSelectedId == null
                                ? null
                                : () => runMutation(setState, () async {
                                    final preview =
                                        await postStoryboardPreviewImageV1(
                                          token,
                                          storyboardId: singleSelectedId,
                                        );
                                    setState(() {
                                      previewUrl = preview.imageUrl;
                                      statusLine = preview.imageUrl == null
                                          ? '当前分镜还没有预览图'
                                          : '已读取分镜 #$singleSelectedId 的当前预览';
                                    });
                                  }),
                            child: const Text('读取当前预览'),
                          ),
                          TextButton(
                            onPressed: busyMutation || singleSelectedId == null
                                ? null
                                : () => runMutation(setState, () async {
                                    final preview =
                                        await postStoryboardDownPreviewImageV1(
                                          token,
                                          storyboardId: singleSelectedId,
                                        );
                                    setState(() {
                                      downloadUrl = preview.previewUrl;
                                      statusLine = preview.previewUrl == null
                                          ? preview.message
                                          : '已生成分镜 #$singleSelectedId 的下载链接';
                                    });
                                  }),
                            child: const Text('读取下载链接'),
                          ),
                          TextButton(
                            onPressed: busyMutation || selectedIds.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final zip =
                                        await fetchProductionExportImageZipV1(
                                          token,
                                          shotId: selected
                                              .map(
                                                (id) => <String, dynamic>{
                                                  'id': '$id',
                                                },
                                              )
                                              .toList(growable: false),
                                        );
                                    setState(() {
                                      exportLine =
                                          '已导出 ${selected.length} 张分镜图片，文件 ${zip.filename ?? "storyboards.zip"}，大小 ${zip.bytes.length} bytes';
                                      statusLine = exportLine;
                                    });
                                  }),
                            child: const Text('导出所选 ZIP'),
                          ),
                        ],
                      ),
                      if (statusLine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusLine!,
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                      ],
                      if (exportLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          exportLine!,
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: boardsList.length,
                                itemBuilder: (context, index) {
                                  final row = boardsList[index];
                                  final productionRow =
                                      productionMap[row.legacyId];
                                  final prompt =
                                      resolveStoryboardGenerationPrompt(
                                        scriptStoryboard: row,
                                        productionStoryboard: productionRow,
                                      );
                                  final checked = selectedIds.contains(
                                    row.legacyId,
                                  );
                                  return CheckboxListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: checked,
                                    onChanged: busyMutation
                                        ? null
                                        : (value) {
                                            setState(() {
                                              if (value == true) {
                                                selectedIds.add(row.legacyId);
                                              } else {
                                                selectedIds.remove(
                                                  row.legacyId,
                                                );
                                              }
                                            });
                                          },
                                    title: Text('#${row.legacyId}'),
                                    subtitle: Text(
                                      [
                                        storyboardMetaLine(row, productionRow),
                                        prompt ?? '无可用提示词',
                                      ].join('\n'),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(dialogCtx)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.4),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '预览与导出信息',
                                      style: Theme.of(
                                        dialogCtx,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      singleSelectedId == null
                                          ? '选中 1 条分镜后可读取当前预览与下载链接。'
                                          : '当前查看分镜 #$singleSelectedId',
                                      style: Theme.of(
                                        dialogCtx,
                                      ).textTheme.bodySmall,
                                    ),
                                    if (downloadUrl != null) ...[
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        '下载链接：$downloadUrl',
                                        style: Theme.of(
                                          dialogCtx,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: previewUrl == null
                                          ? Center(
                                              child: Text(
                                                '这里会显示当前分镜预览图。',
                                                style: Theme.of(dialogCtx)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: Theme.of(
                                                        dialogCtx,
                                                      ).colorScheme.outline,
                                                    ),
                                              ),
                                            )
                                          : ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Image.network(
                                                previewUrl!,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                errorBuilder: (_, _, _) =>
                                                    Center(
                                                      child: SelectableText(
                                                        previewUrl!,
                                                        style: Theme.of(
                                                          dialogCtx,
                                                        ).textTheme.bodySmall,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: busyMutation
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      promptSuffixCtrl.dispose();
      negativePromptCtrl.dispose();
      modelCtrl.dispose();
      resolutionCtrl.dispose();
    }
  }
}
