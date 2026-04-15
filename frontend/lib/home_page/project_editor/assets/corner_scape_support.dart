import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../rust_api.dart';
import 'support.dart';

class CornerScapeWorkbenchSession {
  CornerScapeWorkbenchSession()
    : typesCtrl = TextEditingController(text: 'role,clip,props');

  final TextEditingController typesCtrl;
  List<CornerScapeAssetItem> assets = const [];
  int? selectedAssetNumericId;
  String? selectedHistoryImageId;
  Uint8List? selectedPreviewBytes;
  bool loading = false;
  bool loadingPreview = false;
  bool initialLoadTriggered = false;
  String? summaryLine;

  CornerScapeAssetItem? selectedAsset() {
    if (selectedAssetNumericId == null) {
      return null;
    }
    for (final item in assets) {
      if (item.numericId == selectedAssetNumericId) {
        return item;
      }
    }
    return null;
  }

  CornerScapeHistoryImage? selectedHistoryImage() {
    final asset = selectedAsset();
    if (asset == null || selectedHistoryImageId == null) {
      return null;
    }
    for (final image in asset.historyImages) {
      if (image.id == selectedHistoryImageId) {
        return image;
      }
    }
    return null;
  }

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

  void dispose() {
    typesCtrl.dispose();
  }
}

class CornerScapeWorkbenchController {
  const CornerScapeWorkbenchController({
    required this.ctx,
    required this.token,
    required this.project,
    required this.setDialogState,
    required this.assetsBusy,
    required this.preferredAssetNumericId,
    required this.session,
  });

  final BuildContext ctx;
  final String token;
  final ProjectRow project;
  final StateSetter setDialogState;
  final List<bool> assetsBusy;
  final int? preferredAssetNumericId;
  final CornerScapeWorkbenchSession session;

  Future<void> loadPreview(StateSetter setState) async {
    final asset = session.selectedAsset();
    final image = session.selectedHistoryImage();
    if (asset == null || image == null) {
      setState(() => session.selectedPreviewBytes = null);
      session.syncSummaryLine(setState);
      return;
    }
    setState(() {
      session.loadingPreview = true;
      session.selectedPreviewBytes = null;
    });
    final bytes = await fetchCornerScapeHistoryImagePreviewBytes(
      token,
      project.id,
      asset.numericId,
      image,
    );
    setState(() {
      session.loadingPreview = false;
      session.selectedPreviewBytes = bytes;
    });
    session.syncSummaryLine(setState);
  }

  Future<void> refreshAssets(StateSetter setState) async {
    final activeTypes = parseCornerScapeTypesInput(session.typesCtrl.text);
    setDialogState(() => assetsBusy[0] = true);
    setState(() {
      session.loading = true;
      session.summaryLine = activeTypes == null
          ? '正在加载全部类型的历史图资产…'
          : '正在加载类型 ${activeTypes.join(", ")} 的历史图资产…';
      session.selectedPreviewBytes = null;
    });
    try {
      final response = await fetchCornerScapeAssetsByProjectId(
        token,
        project.id,
        types: activeTypes,
      );
      session.selectedAssetNumericId = response.items.isEmpty
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
                  session.selectedAssetNumericId ?? preferredAssetNumericId,
            );
      session.selectedHistoryImageId = chooseInitialCornerScapeHistoryImageId(
        response.items,
        selectedAssetNumericId: session.selectedAssetNumericId,
        preferredHistoryImageId: session.selectedHistoryImageId,
      );
      setState(() {
        session.assets = response.items;
        session.summaryLine = summarizeCornerScapeSelection(
          response.items,
          activeTypes: activeTypes,
          selectedAssetNumericId: session.selectedAssetNumericId,
          selectedHistoryImageId: session.selectedHistoryImageId,
        );
      });
      await loadPreview(setState);
    } on RustApiException catch (e) {
      setState(() {
        session.summaryLine = '加载失败：$e';
        session.selectedAssetNumericId = null;
        session.selectedHistoryImageId = null;
        session.selectedPreviewBytes = null;
      });
    } catch (e) {
      setState(() {
        session.summaryLine = '加载失败：$e';
        session.selectedAssetNumericId = null;
        session.selectedHistoryImageId = null;
        session.selectedPreviewBytes = null;
      });
    } finally {
      setState(() => session.loading = false);
      if (ctx.mounted) {
        setDialogState(() => assetsBusy[0] = false);
      }
    }
  }

  Future<void> clearFilter(StateSetter setState) async {
    session.typesCtrl.clear();
    await refreshAssets(setState);
  }

  Future<void> presetType(StateSetter setState, String type) async {
    session.typesCtrl.text = type;
    await refreshAssets(setState);
  }

  Future<void> selectAsset(StateSetter setState, int? assetNumericId) async {
    setState(() {
      session.selectedAssetNumericId = assetNumericId;
      session.selectedHistoryImageId = chooseInitialCornerScapeHistoryImageId(
        session.assets,
        selectedAssetNumericId: assetNumericId,
        preferredHistoryImageId: session.selectedHistoryImageId,
      );
      session.selectedPreviewBytes = null;
    });
    session.syncSummaryLine(setState);
    await loadPreview(setState);
  }

  Future<void> selectHistoryImage(
    StateSetter setState,
    String? historyImageId,
  ) async {
    setState(() {
      session.selectedHistoryImageId = historyImageId;
      session.selectedPreviewBytes = null;
    });
    session.syncSummaryLine(setState);
    await loadPreview(setState);
  }
}
