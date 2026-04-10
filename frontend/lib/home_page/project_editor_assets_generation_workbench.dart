part of '../home_page.dart';

extension _HomePageProjectEditorAssetsGenerationWorkbench on _HomePageState {
  Future<void> _openAssetGenerationWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ScriptBrief> scriptList,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
    int? preferredAssetLegacyId,
  }) async {
    List<AssetRow> visibleAssets() {
      final filtered = assetsFilterScriptLegacyId[0] == null
          ? null
          : assetsForScriptRef[0];
      return (filtered ?? assetsRef[0])?.items ?? const <AssetRow>[];
    }

    final seededAssets = visibleAssets();
    if (seededAssets.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先加载资产列表再打开出图工作台')));
      return;
    }
    if (scriptList.isEmpty) {
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(const SnackBar(content: Text('请先创建剧本再发起资产出图')));
      return;
    }

    final modelCtrl = TextEditingController();
    final resolutionCtrl = TextEditingController();
    final imageUrlCtrl = TextEditingController();
    final batchNameCtrl = TextEditingController();
    final batchLimitCtrl = TextEditingController(text: '10');
    final initialFocusedAssetLegacyId = chooseInitialAssetLegacyId(
      seededAssets,
      preferredLegacyId: preferredAssetLegacyId,
    );
    final selectedIds = <int>{
      ...chooseVisibleAssetSelection(
        seededAssets,
        preferredLegacyId: initialFocusedAssetLegacyId,
      ),
    };
    int? focusedAssetLegacyId = initialFocusedAssetLegacyId;
    int selectedScriptLegacyId =
        assetsFilterScriptLegacyId[0] ?? scriptList.first.legacyId;
    String selectedType = '';
    bool initialLoadTriggered = false;
    bool loadingSummary = false;
    bool busyMutation = false;
    AssetsDataResponseV1? productionData;
    AssetsPollingImageResponseV1? pollingData;
    LegacyAssetMaterialDataResponse? materialData;
    LegacyAssetBatchGenerationDataResponse? batchData;
    List<LegacyAssetPollingPromptAssetsItem>? promptPollingData;
    String? statusLine;

    List<AssetRow> filteredVisibleAssets() {
      final assets = visibleAssets();
      if (selectedType.isEmpty) {
        return assets;
      }
      return assets
          .where((asset) => asset.assetType.trim() == selectedType)
          .toList(growable: false);
    }

    List<int> sortedSelection() => sortUniqueAssetLegacyIds(selectedIds);

    void applySelection(StateSetter setState, Iterable<int> ids, String label) {
      final next = sortUniqueAssetLegacyIds(ids);
      setState(() {
        selectedIds
          ..clear()
          ..addAll(next);
        focusedAssetLegacyId = next.isEmpty ? focusedAssetLegacyId : next.first;
        statusLine = next.isEmpty
            ? '$label：没有可选资产'
            : '$label：已选择 ${next.length} 条资产';
      });
    }

    Future<void> syncWorkbenchSnapshot(
      StateSetter setState, {
      required bool includeProductionSummary,
      String? lead,
    }) async {
      setState(() {
        loadingSummary = true;
        statusLine = lead == null ? null : '$lead，正在同步工作台摘要…';
      });
      try {
        final selected = sortedSelection();
        AssetsDataResponseV1? nextProductionData = productionData;
        if (includeProductionSummary) {
          nextProductionData = await postProductionAssetsGetAssetsDataV1(
            token,
            projectId: p.legacyId,
            assetType: selectedType.isEmpty ? null : selectedType,
          );
        }
        AssetsPollingImageResponseV1? nextPollingData;
        List<LegacyAssetPollingPromptAssetsItem>? nextPromptPollingData;
        if (selected.isNotEmpty) {
          nextPollingData = await postProductionAssetsPollingImageV1(
            token,
            projectId: p.legacyId,
            assetIds: selected,
          );
          nextPromptPollingData = await postLegacyAssetsPollingPromptAssets(
            token,
            selected,
          );
        }
        final currentVisibleAssets = filteredVisibleAssets();
        final nextSelection = chooseVisibleAssetSelection(
          currentVisibleAssets,
          preferredIds: selectedIds,
          preferredLegacyId: focusedAssetLegacyId,
        );
        setState(() {
          if (includeProductionSummary) {
            productionData = nextProductionData;
          }
          pollingData = nextPollingData;
          promptPollingData = nextPromptPollingData;
          selectedIds
            ..clear()
            ..addAll(nextSelection);
          focusedAssetLegacyId = selectedIds.isEmpty ? null : selectedIds.first;
          statusLine = summarizeAssetWorkbenchSnapshot(
            lead: lead,
            visibleAssets: currentVisibleAssets,
            selectedIds: selectedIds,
            productionData: productionData,
            pollingData: pollingData,
            promptPollingData: promptPollingData,
          );
        });
      } on RustApiException catch (e) {
        setState(() => statusLine = '同步工作台摘要失败：$e');
      } catch (e) {
        setState(() => statusLine = '同步工作台摘要失败：$e');
      } finally {
        setState(() => loadingSummary = false);
      }
    }

    Future<void> runMutation(
      StateSetter setState,
      Future<void> Function() action,
    ) async {
      setDialogState(() => assetsBusy[0] = true);
      setState(() => busyMutation = true);
      try {
        await action();
      } on RustApiException catch (e) {
        setState(() => statusLine = '$e');
      } on FormatException catch (e) {
        setState(() => statusLine = e.message);
      } catch (e) {
        setState(() => statusLine = '$e');
      } finally {
        setState(() => busyMutation = false);
        if (ctx.mounted) {
          setDialogState(() => assetsBusy[0] = false);
        }
      }
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setState) {
              if (!initialLoadTriggered) {
                initialLoadTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!dialogCtx.mounted) return;
                  await syncWorkbenchSnapshot(
                    setState,
                    includeProductionSummary: true,
                  );
                });
              }
              final visible = visibleAssets();
              final scopedAssets = filteredVisibleAssets();
              final typeSelections = collectAssetIdsByType(visible);
              final selected = sortedSelection();
              final selectedSingleAssetId = selected.length == 1
                  ? selected.first
                  : null;
              return AlertDialog(
                title: const Text('资产出图工作台'),
                content: SizedBox(
                  width: 860,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '把 production 资产摘要、批量出图、状态轮询、衍生图清理和封面 URL 更新收口到项目资产主流程，不再只依赖 system probe。',
                        style: Theme.of(dialogCtx).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(dialogCtx).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: selectedScriptLegacyId,
                              decoration: const InputDecoration(
                                labelText: '生成使用的剧本',
                                helperText: '批量出图会把所选资产投给这个剧本上下文',
                              ),
                              items: scriptList
                                  .map(
                                    (script) => DropdownMenuItem<int>(
                                      value: script.legacyId,
                                      child: Text(
                                        '#${script.legacyId} ${script.name ?? ""}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: busyMutation
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(
                                        () => selectedScriptLegacyId = value,
                                      );
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: selectedType,
                              decoration: const InputDecoration(
                                labelText: '资产类型筛选',
                                helperText: '同时影响 production 摘要读取和可见选择集',
                              ),
                              items: <DropdownMenuItem<String>>[
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('（全部类型）'),
                                ),
                                ...typeSelections.keys.map(
                                  (type) => DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type),
                                  ),
                                ),
                              ],
                              onChanged: busyMutation
                                  ? null
                                  : (value) async {
                                      final nextType = value ?? '';
                                      final nextVisibleAssets = nextType.isEmpty
                                          ? visible
                                          : visible
                                                .where(
                                                  (asset) =>
                                                      asset.assetType.trim() ==
                                                      nextType,
                                                )
                                                .toList(growable: false);
                                      final nextSelection =
                                          chooseVisibleAssetSelection(
                                            nextVisibleAssets,
                                            preferredIds: selectedIds,
                                            preferredLegacyId:
                                                focusedAssetLegacyId,
                                          );
                                      setState(() {
                                        selectedType = nextType;
                                        selectedIds
                                          ..clear()
                                          ..addAll(nextSelection);
                                        focusedAssetLegacyId =
                                            selectedIds.isEmpty
                                            ? null
                                            : selectedIds.first;
                                        statusLine = selectedType.isEmpty
                                            ? '正在切换到全部类型并同步工作台摘要…'
                                            : '正在切换到 $selectedType 并同步工作台摘要…';
                                      });
                                      await syncWorkbenchSnapshot(
                                        setState,
                                        includeProductionSummary: true,
                                      );
                                    },
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: batchNameCtrl,
                              decoration: const InputDecoration(
                                labelText: '批量候选名称过滤（可选）',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 140,
                            child: TextField(
                              controller: batchLimitCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '候选 limit',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: imageUrlCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: '更新封面 URL（单选时可用）',
                          helperText: '用于 production/assets/update-assets-url',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: loadingSummary || busyMutation
                                ? null
                                : () => syncWorkbenchSnapshot(
                                    setState,
                                    includeProductionSummary: true,
                                  ),
                            child: Text(loadingSummary ? '同步中…' : '同步当前工作台摘要'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () => runMutation(setState, () async {
                                    final response =
                                        await postLegacyAssetsGetMaterialData(
                                          token,
                                          p.legacyId,
                                        );
                                    setState(() {
                                      materialData = response;
                                      statusLine =
                                          summarizeLegacyAssetMaterialData(
                                            response,
                                          );
                                    });
                                  }),
                            child: const Text('读取素材上下文'),
                          ),
                          TextButton(
                            onPressed: busyMutation || visible.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final effectiveType = selectedType.isEmpty
                                        ? visible.first.assetType.trim()
                                        : selectedType;
                                    final limit =
                                        int.tryParse(
                                          batchLimitCtrl.text.trim(),
                                        ) ??
                                        10;
                                    if (effectiveType.isEmpty) {
                                      throw const FormatException(
                                        '批量候选读取需要有效资产类型',
                                      );
                                    }
                                    if (limit <= 0) {
                                      throw const FormatException(
                                        '候选 limit 需要大于 0',
                                      );
                                    }
                                    final response =
                                        await postLegacyAssetsBatchGenerationData(
                                          token,
                                          projectLegacyId: p.legacyId,
                                          assetType: effectiveType,
                                          name: batchNameCtrl.text.trim(),
                                          limit: limit,
                                        );
                                    setState(() {
                                      batchData = response;
                                      statusLine =
                                          '${summarizeLegacyBatchGenerationData(response)} · type=$effectiveType';
                                    });
                                  }),
                            child: const Text('读取批量候选'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () => applySelection(
                                    setState,
                                    scopedAssets.map((asset) => asset.legacyId),
                                    '已全选当前可见资产',
                                  ),
                            child: const Text('全选当前可见资产'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () => applySelection(
                                    setState,
                                    selectedType.isEmpty
                                        ? scopedAssets.map(
                                            (asset) => asset.legacyId,
                                          )
                                        : (typeSelections[selectedType] ??
                                              const <int>[]),
                                    selectedType.isEmpty
                                        ? '已按全部类型重建选择'
                                        : '已按 $selectedType 重建选择',
                                  ),
                            child: const Text('按类型重建选择'),
                          ),
                          TextButton(
                            onPressed: busyMutation
                                ? null
                                : () => applySelection(
                                    setState,
                                    const <int>[],
                                    '已清空选择',
                                  ),
                            child: const Text('清空选择'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: busyMutation || selected.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final response =
                                        await postProductionAssetsBatchGenerateAssetsImageV1(
                                          token,
                                          projectId: p.legacyId,
                                          scriptId: selectedScriptLegacyId,
                                          assetIds: selected,
                                          model: modelCtrl.text.trim().isEmpty
                                              ? null
                                              : modelCtrl.text.trim(),
                                          resolution:
                                              resolutionCtrl.text.trim().isEmpty
                                              ? null
                                              : resolutionCtrl.text.trim(),
                                        );
                                    await syncWorkbenchSnapshot(
                                      setState,
                                      includeProductionSummary: true,
                                      lead:
                                          '已为 ${response.total} 条资产创建出图任务，队列 ${response.enqueued.length} 条',
                                    );
                                  }),
                            child: Text(busyMutation ? '处理中…' : '批量发起资产出图'),
                          ),
                          TextButton(
                            onPressed: busyMutation || selected.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final response =
                                        await postProductionAssetsPollingImageV1(
                                          token,
                                          projectId: p.legacyId,
                                          assetIds: selected,
                                        );
                                    setState(() {
                                      pollingData = response;
                                      statusLine =
                                          summarizeAssetWorkbenchSnapshot(
                                            visibleAssets: scopedAssets,
                                            selectedIds: selectedIds,
                                            productionData: productionData,
                                            pollingData: pollingData,
                                            promptPollingData:
                                                promptPollingData,
                                          );
                                    });
                                  }),
                            child: const Text('轮询图片状态'),
                          ),
                          TextButton(
                            onPressed: busyMutation || selected.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final response =
                                        await postLegacyAssetsPollingPromptAssets(
                                          token,
                                          selected,
                                        );
                                    setState(() {
                                      promptPollingData = response;
                                      statusLine =
                                          summarizeAssetWorkbenchSnapshot(
                                            visibleAssets: scopedAssets,
                                            selectedIds: selectedIds,
                                            productionData: productionData,
                                            pollingData: pollingData,
                                            promptPollingData:
                                                promptPollingData,
                                          );
                                    });
                                  }),
                            child: const Text('轮询 prompt 状态'),
                          ),
                          TextButton(
                            onPressed: busyMutation || selected.isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final response =
                                        await postProductionAssetsDeleteAssetsDerivativeV1(
                                          token,
                                          projectId: p.legacyId,
                                          assetIds: selected,
                                        );
                                    await reloadAssetsAndStats();
                                    await syncWorkbenchSnapshot(
                                      setState,
                                      includeProductionSummary: true,
                                      lead:
                                          '已删除 ${response.deleted} 个衍生图记录，资产 ${response.assetIds.join(", ")}',
                                    );
                                  }),
                            child: const Text('清理衍生图'),
                          ),
                          TextButton(
                            onPressed:
                                busyMutation ||
                                    selectedSingleAssetId == null ||
                                    imageUrlCtrl.text.trim().isEmpty
                                ? null
                                : () => runMutation(setState, () async {
                                    final response =
                                        await postProductionAssetsUpdateAssetsUrlV1(
                                          token,
                                          projectId: p.legacyId,
                                          assetId: selectedSingleAssetId,
                                          imageUrl: imageUrlCtrl.text.trim(),
                                        );
                                    await reloadAssetsAndStats();
                                    await syncWorkbenchSnapshot(
                                      setState,
                                      includeProductionSummary: true,
                                      lead:
                                          '已更新资产 #${response.assetId} 封面 URL：${response.message}',
                                    );
                                  }),
                            child: const Text('更新封面 URL'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        assetsFilterScriptLegacyId[0] == null
                            ? '当前按项目全量资产操作；可在主视图先切换“按剧本筛选”再进入工作台。'
                            : '当前主视图已按剧本 #${assetsFilterScriptLegacyId[0]} 过滤资产，工作台默认沿用这批可见资产。',
                        style: Theme.of(dialogCtx).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(dialogCtx).colorScheme.outline,
                            ),
                      ),
                      if (statusLine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusLine!,
                          style: Theme.of(dialogCtx).textTheme.bodySmall,
                        ),
                      ],
                      if (productionData != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summarizeProductionAssetData(productionData!),
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                      ],
                      if (pollingData != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summarizeAssetPollingStatuses(pollingData!.statuses),
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                      ],
                      if (materialData != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summarizeLegacyAssetMaterialData(materialData!),
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                      ],
                      if (batchData != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summarizeLegacyBatchGenerationData(batchData!),
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                      ],
                      if (promptPollingData != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          summarizeLegacyPromptPolling(promptPollingData!),
                          style: Theme.of(dialogCtx).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(dialogCtx).colorScheme.outline,
                              ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 280,
                        child: ListView.builder(
                          itemCount: scopedAssets.length,
                          itemBuilder: (context, index) {
                            final asset = scopedAssets[index];
                            return CheckboxListTile(
                              dense: true,
                              value: selectedIds.contains(asset.legacyId),
                              onChanged: busyMutation
                                  ? null
                                  : (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          selectedIds.add(asset.legacyId);
                                          focusedAssetLegacyId = asset.legacyId;
                                          if (selectedIds.length == 1) {
                                            imageUrlCtrl.clear();
                                          }
                                        } else {
                                          selectedIds.remove(asset.legacyId);
                                          if (focusedAssetLegacyId ==
                                              asset.legacyId) {
                                            final remaining =
                                                sortUniqueAssetLegacyIds(
                                                  selectedIds,
                                                );
                                            focusedAssetLegacyId =
                                                remaining.isEmpty
                                                ? null
                                                : remaining.first;
                                          }
                                        }
                                      });
                                    },
                              title: Text('#${asset.legacyId} ${asset.name}'),
                              subtitle: Text(
                                [
                                  asset.assetType,
                                  asset.description?.trim().isNotEmpty == true
                                      ? asset.description!.trim()
                                      : '无描述',
                                ].join(' · '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          },
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
      modelCtrl.dispose();
      resolutionCtrl.dispose();
      imageUrlCtrl.dispose();
      batchNameCtrl.dispose();
      batchLimitCtrl.dispose();
    }
  }
}
