import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../rust_api.dart';
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

  void syncSummaryLine(StateSetter setState, AppLocalizations l10n) {
    setState(() {
      summaryLine = summarizeCornerScapeSelection(
        assets,
        activeTypes: parseCornerScapeTypesInput(typesCtrl.text),
        selectedAssetNumericId: selectedAssetNumericId,
        selectedHistoryImageId: selectedHistoryImageId,
        l10n: l10n,
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
      session.syncSummaryLine(
        setState,
        resolveAppLocalizationsForErrors(ctx),
      );
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
    session.syncSummaryLine(setState, resolveAppLocalizationsForErrors(ctx));
  }

  Future<void> refreshAssets(StateSetter setState) async {
    final l10n = resolveAppLocalizationsForErrors(ctx);
    final activeTypes = parseCornerScapeTypesInput(session.typesCtrl.text);
    setDialogState(() => assetsBusy[0] = true);
    setState(() {
      session.loading = true;
      session.summaryLine = activeTypes == null
          ? l10n.projectEditorAssetsCornerScapeLoadingAll
          : l10n.projectEditorAssetsCornerScapeLoadingTypes(activeTypes.join(", "));
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
          l10n: l10n,
        );
      });
      await loadPreview(setState);
    } catch (e) {
      setState(() {
        session.summaryLine = l10n.projectEditorAssetsCornerScapeLoadFailed(
          describeUserVisibleApiError(l10n, e),
        );
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
    session.syncSummaryLine(setState, resolveAppLocalizationsForErrors(ctx));
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
    session.syncSummaryLine(setState, resolveAppLocalizationsForErrors(ctx));
    await loadPreview(setState);
  }
}
