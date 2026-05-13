part of '../../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesWorkbenchProbeActions
    on _HomePageState {
  List<Widget> _buildProjectAssetsImagesWorkbenchProbeActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<ListAssetsResponse?> assetsRef,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required Future<void> Function() reloadAssetsAndStats,
  }) {
    final l10n = AppLocalizations.of(ctx)!;
    return [
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final first = assetsRef[0]!.items.first;
                try {
                  final r = await postWorkbenchAssetsGetImage(
                    token,
                    p.id,
                    first.numericId,
                  );
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeWbGetImageSnack(
                          r.tempAssets.length,
                          r.imageId?.toString() ?? 'null',
                        ),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbGetImageButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final ts = DateTime.now().millisecondsSinceEpoch;
                  final r = await postWorkbenchAssetsUploadClip(
                    token,
                    projectId: p.id,
                    base64Data: 'data:image/png;base64,AA==',
                    name: 'probe clip $ts',
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeWbUploadClipSnack(r.message),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbUploadClipButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final r = await postWorkbenchAssetsGetMaterialData(
                    token,
                    p.id,
                  );
                  if (!ctx.mounted) return;
                  final firstClip = r.data.isEmpty ? null : r.data.first;
                  final suffix = firstClip == null
                      ? ''
                      : l10n.projectEditorAssetsProbeWbMaterialDataFirstClipSuffix(
                          firstClip.name,
                        );
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeWbMaterialDataSnack(
                          r.data.length,
                          r.video.length,
                          suffix,
                        ),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbMaterialDataButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final r = await postWorkbenchAssetsBatchGenerationData(
                    token,
                    projectId: p.id,
                    assetType: 'role',
                    page: 1,
                    limit: 3,
                  );
                  if (!ctx.mounted) return;
                  final first = r.data.isEmpty ? null : r.data.first;
                  final suffix = first == null
                      ? ''
                      : l10n.projectEditorAssetsProbeWbBatchGenFirstSuffix(
                          first.name,
                          first.assetType,
                        );
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeWbBatchGenSnack(
                          r.data.length,
                          r.total,
                          suffix,
                        ),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbBatchGenDataButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final r = await postWorkbenchAssetsGetAssetsApi(
                    token,
                    projectId: p.id,
                    assetType: 'role',
                    page: 1,
                    limit: 3,
                  );
                  if (!ctx.mounted) return;
                  final first = r.data.isEmpty ? null : r.data.first;
                  final suffix = first == null
                      ? ''
                      : l10n.projectEditorAssetsProbeWbNestedFirstSuffix(
                          first.sonAssets.length,
                        );
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeWbNestedSnack(
                          r.data.length,
                          r.total,
                          suffix,
                        ),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbGetAssetsApiButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final first = assetsRef[0]!.items.first;
                try {
                  final rows = await postWorkbenchAssetsPollingImageAssets(
                    token,
                    p.id,
                    <int>[first.numericId],
                  );
                  if (!ctx.mounted) return;
                  final one = rows.isEmpty ? null : rows.first;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        one == null
                            ? l10n.projectEditorAssetsProbeWbPollingImageZeroSnack
                            : l10n.projectEditorAssetsProbeWbPollingImageRowSnack(
                                one.state ?? '-',
                                one.filePath ?? '-',
                              ),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbPollingImageButton),
      ),
      TextButton(
        onPressed:
            assetsBusy[0] ||
                assetsLoading[0] ||
                assetsScriptFilterLoading[0] ||
                assetsRef[0] == null ||
                assetsRef[0]!.items.isEmpty
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                final first = assetsRef[0]!.items.first;
                try {
                  final rows = await postWorkbenchAssetsPollingPromptAssets(
                    token,
                    p.id,
                    <int>[first.numericId],
                  );
                  if (!ctx.mounted) return;
                  final one = rows.isEmpty ? null : rows.first;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        one == null
                            ? l10n.projectEditorAssetsProbeWbPollingPromptZeroSnack
                            : l10n.projectEditorAssetsProbeWbPollingPromptRowSnack(
                                one.promptState,
                                one.assetType,
                              ),
                      ),
                    ),
                  );
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeWbPollingPromptButton),
      ),
    ];
  }
}
