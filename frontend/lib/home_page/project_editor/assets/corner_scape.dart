part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsCornerScapeWorkbench on _HomePageState {
  Future<void> _openCornerScapeWorkbenchDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> assetsBusy,
    int? preferredAssetNumericId,
  }) async {
    final typesCtrl = TextEditingController(text: 'role,clip,props');
    List<CornerScapeAssetItem> assets = const [];
    int? selectedAssetNumericId;
    String? selectedHistoryImageId;
    Uint8List? selectedPreviewBytes;
    bool loading = false;
    bool loadingPreview = false;
    bool initialLoadTriggered = false;
    String? summaryLine;

    void syncSummaryLine(StateSetter setState) {
      setState(() {
        summaryLine = summarizeCornerScapeSelection(
          assets,
          activeTypes: parseCornerScapeTypesInput(typesCtrl.text),
          selectedAssetNumericId: selectedAssetNumericId,
          selectedHistoryImageId: selectedHistoryImageId,
        );
      });
    }

    CornerScapeAssetItem? selectedAsset() {
      if (selectedAssetNumericId == null) return null;
      for (final item in assets) {
        if (item.numericId == selectedAssetNumericId) {
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
        syncSummaryLine(setState);
        return;
      }
      setState(() {
        loadingPreview = true;
        selectedPreviewBytes = null;
      });
      final bytes = await fetchCornerScapeHistoryImagePreviewBytes(
        token,
        p.id,
        asset.numericId,
        image,
      );
      setState(() {
        loadingPreview = false;
        selectedPreviewBytes = bytes;
      });
      syncSummaryLine(setState);
    }

    Future<void> refreshAssets(StateSetter setState) async {
      final activeTypes = parseCornerScapeTypesInput(typesCtrl.text);
      setDialogState(() => assetsBusy[0] = true);
      setState(() {
        loading = true;
        summaryLine = activeTypes == null
            ? '正在加载全部类型的历史图资产…'
            : '正在加载类型 ${activeTypes.join(", ")} 的历史图资产…';
        selectedPreviewBytes = null;
      });
      try {
        final response = await fetchCornerScapeAssetsByProjectId(
          token,
          p.id,
          types: activeTypes,
        );
        selectedAssetNumericId = response.items.isEmpty
            ? null
            : chooseInitialAssetNumericId(
                response.items
                    .map(
                      (item) => AssetRow(
                        id: item.id,
                        numericId: item.numericId,
                        name: item.name,
                        assetType: item.assetType,
                      ),
                    )
                    .toList(growable: false),
                preferredNumericId:
                    selectedAssetNumericId ?? preferredAssetNumericId,
              );
        selectedHistoryImageId = chooseInitialCornerScapeHistoryImageId(
          response.items,
          selectedAssetNumericId: selectedAssetNumericId,
          preferredHistoryImageId: selectedHistoryImageId,
        );
        setState(() {
          assets = response.items;
          summaryLine = summarizeCornerScapeSelection(
            response.items,
            activeTypes: activeTypes,
            selectedAssetNumericId: selectedAssetNumericId,
            selectedHistoryImageId: selectedHistoryImageId,
          );
        });
        await loadPreview(setState);
      } on RustApiException catch (e) {
        setState(() {
          summaryLine = '加载失败：$e';
          selectedAssetNumericId = null;
          selectedHistoryImageId = null;
          selectedPreviewBytes = null;
        });
      } catch (e) {
        setState(() {
          summaryLine = '加载失败：$e';
          selectedAssetNumericId = null;
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
              if (!initialLoadTriggered) {
                initialLoadTriggered = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!dialogCtx.mounted) return;
                  await refreshAssets(setState);
                });
              }
              return _buildCornerScapeWorkbenchDialog(
                ctx: dialogCtx,
                typesCtrl: typesCtrl,
                assetsBusy: assetsBusy,
                assets: assets,
                selectedAssetNumericId: selectedAssetNumericId,
                selectedHistoryImageId: selectedHistoryImageId,
                selectedPreviewBytes: selectedPreviewBytes,
                loading: loading,
                loadingPreview: loadingPreview,
                summaryLine: summaryLine,
                selectedAsset: selectedAsset(),
                selectedImage: selectedHistoryImage(),
                setState: setState,
                refreshAssets: refreshAssets,
                loadPreview: loadPreview,
                syncSummaryLine: syncSummaryLine,
                onAssetSelected: (assetNumericId) {
                  setState(() {
                    selectedAssetNumericId = assetNumericId;
                    selectedHistoryImageId =
                        chooseInitialCornerScapeHistoryImageId(
                          assets,
                          selectedAssetNumericId: assetNumericId,
                          preferredHistoryImageId: selectedHistoryImageId,
                        );
                    selectedPreviewBytes = null;
                  });
                },
                onHistoryImageSelected: (historyImageId) {
                  setState(() {
                    selectedHistoryImageId = historyImageId;
                    selectedPreviewBytes = null;
                  });
                },
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
