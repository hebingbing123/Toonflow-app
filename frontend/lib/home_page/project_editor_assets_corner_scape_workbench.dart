part of '../home_page.dart';

extension _HomePageProjectEditorAssetsCornerScapeWorkbench on _HomePageState {
  Future<void> _openCornerScapeWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
  }) async {
    final typesCtrl = TextEditingController(text: 'role,clip,props');
    List<CornerScapeAssetItem> assets = const [];
    int? selectedAssetLegacyId;
    String? selectedHistoryImageId;
    Uint8List? selectedPreviewBytes;
    bool loading = false;
    bool loadingPreview = false;
    String? summaryLine;

    List<String>? parseTypes() {
      final raw = typesCtrl.text
          .split(',')
          .map((segment) => segment.trim())
          .where((segment) => segment.isNotEmpty)
          .toSet()
          .toList();
      if (raw.isEmpty) return null;
      return raw;
    }

    CornerScapeAssetItem? selectedAsset() {
      if (selectedAssetLegacyId == null) return null;
      for (final item in assets) {
        if (item.legacyId == selectedAssetLegacyId) {
          return item;
        }
      }
      return null;
    }

    CornerScapeHistoryImage? selectedHistoryImage() {
      final asset = selectedAsset();
      if (asset == null || selectedHistoryImageId == null) return null;
      for (final image in asset.historyImages) {
        if (image.id == selectedHistoryImageId) {
          return image;
        }
      }
      return null;
    }

    Future<void> loadPreview(StateSetter setState) async {
      final asset = selectedAsset();
      final image = selectedHistoryImage();
      if (asset == null || image == null) {
        setState(() => selectedPreviewBytes = null);
        return;
      }
      setState(() {
        loadingPreview = true;
        selectedPreviewBytes = null;
      });
      final bytes = await fetchCornerScapeHistoryImagePreviewBytes(
        token,
        p.legacyId,
        asset.legacyId,
        image,
      );
      setState(() {
        loadingPreview = false;
        selectedPreviewBytes = bytes;
      });
    }

    Future<void> refreshAssets(StateSetter setState) async {
      setDialogState(() => assetsBusy[0] = true);
      setState(() {
        loading = true;
        summaryLine = null;
        selectedPreviewBytes = null;
      });
      try {
        final response = await fetchCornerScapeAssetsByLegacyId(
          token,
          p.legacyId,
          types: parseTypes(),
        );
        selectedAssetLegacyId = response.items.isEmpty
            ? null
            : response.items.first.legacyId;
        selectedHistoryImageId =
            response.items.isEmpty || response.items.first.historyImages.isEmpty
            ? null
            : response.items.first.historyImages.first.id;
        final totalHist = response.items.fold<int>(
          0,
          (sum, item) => sum + item.historyImages.length,
        );
        setState(() {
          assets = response.items;
          summaryLine = '已加载 ${response.items.length} 条资产，历史图 $totalHist 张';
        });
        await loadPreview(setState);
      } on RustApiException catch (e) {
        setState(() {
          summaryLine = '加载失败：$e';
          selectedAssetLegacyId = null;
          selectedHistoryImageId = null;
          selectedPreviewBytes = null;
        });
      } catch (e) {
        setState(() {
          summaryLine = '加载失败：$e';
          selectedAssetLegacyId = null;
          selectedHistoryImageId = null;
          selectedPreviewBytes = null;
        });
      } finally {
        setState(() => loading = false);
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
              final selected = selectedAsset();
              final selectedImage = selectedHistoryImage();
              return AlertDialog(
                title: const Text('资产历史图工作台'),
                content: SizedBox(
                  width: 760,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: typesCtrl,
                        decoration: const InputDecoration(
                          labelText: '类型过滤（可选）',
                          helperText: '逗号分隔，例如 role,clip,props；留空表示全部',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton(
                            onPressed: assetsBusy[0] || loading
                                ? null
                                : () => refreshAssets(setState),
                            child: Text(loading ? '加载中…' : '查询历史图资产'),
                          ),
                          TextButton(
                            onPressed: loading
                                ? null
                                : () {
                                    typesCtrl.clear();
                                    setState(() {
                                      summaryLine = '已清空过滤类型，点击“查询历史图资产”重新加载';
                                    });
                                  },
                            child: const Text('清空类型过滤'),
                          ),
                        ],
                      ),
                      if (summaryLine != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          summaryLine!,
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (assets.isEmpty)
                        Text(
                          '暂无数据，点击“查询历史图资产”开始。',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            itemCount: assets.length,
                            itemBuilder: (context, index) {
                              final item = assets[index];
                              final selectedFlag =
                                  item.legacyId == selectedAssetLegacyId;
                              return ListTile(
                                dense: true,
                                selected: selectedFlag,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '#${item.legacyId} ${item.name}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${item.assetType} · history_images=${item.historyImages.length}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () async {
                                  setState(() {
                                    selectedAssetLegacyId = item.legacyId;
                                    selectedHistoryImageId =
                                        item.historyImages.isEmpty
                                        ? null
                                        : item.historyImages.first.id;
                                    selectedPreviewBytes = null;
                                  });
                                  await loadPreview(setState);
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (selected != null &&
                            selected.historyImages.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: selectedHistoryImageId,
                            decoration: const InputDecoration(
                              labelText: '历史图片',
                            ),
                            items: selected.historyImages
                                .map(
                                  (img) => DropdownMenuItem<String>(
                                    value: img.id,
                                    child: Text(
                                      '#${img.sortIndex} · ${img.state ?? "-"} · ${img.id.substring(0, img.id.length >= 8 ? 8 : img.id.length)}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              if (value == null) return;
                              setState(() {
                                selectedHistoryImageId = value;
                                selectedPreviewBytes = null;
                              });
                              await loadPreview(setState);
                            },
                          )
                        else if (selected != null)
                          Text(
                            '该资产暂无历史图片',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                        if (selectedImage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '当前图片：sort=${selectedImage.sortIndex} · state=${selectedImage.state ?? "-"}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (loadingPreview)
                          const SizedBox(
                            height: 140,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (selectedPreviewBytes != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              selectedPreviewBytes!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          )
                        else
                          Text(
                            '当前图片没有可用预览（可能仅存路径占位或远程资源暂不可达）',
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      typesCtrl.dispose();
    }
  }
}
