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
                        'POST …/workbench/image-bundle：tempAssets=${r.tempAssets.length} '
                        'imageId=${r.imageId ?? "null"}',
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
        child: const Text('POST get-image'),
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
                        'POST …/workbench/upload-clip：${r.message}',
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
        child: const Text('POST upload-clip'),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/workbench/material-data：'
                        'clips=${r.data.length} videos=${r.video.length}'
                        '${firstClip == null ? "" : " first=${firstClip.name}"}',
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
        child: const Text('POST get-material-data'),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/workbench/batch-generation-data：'
                        'rows=${r.data.length}/${r.total}'
                        '${first == null ? "" : " first=${first.name}(${first.assetType})"}',
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
        child: const Text('POST batch-generation-data'),
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
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'POST …/workbench/nested：'
                        'parents=${r.data.length}/${r.total}'
                        '${first == null ? "" : " firstChildren=${first.sonAssets.length}"}',
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
        child: const Text('POST get-assets-api'),
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
                            ? 'POST …/workbench/polling-image-assets：0 rows'
                            : 'POST …/workbench/polling-image-assets：'
                                  'state=${one.state ?? "-"} '
                                  'filePath=${one.filePath ?? "-"}',
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
        child: const Text('POST polling-image-assets'),
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
                            ? 'POST …/workbench/polling-prompt-assets：0 rows'
                            : 'POST …/workbench/polling-prompt-assets：'
                                  'promptState=${one.promptState} '
                                  'type=${one.assetType}',
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
        child: const Text('POST polling-prompt-assets'),
      ),
    ];
  }
}
