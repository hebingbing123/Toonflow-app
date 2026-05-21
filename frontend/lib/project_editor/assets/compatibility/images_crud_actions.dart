part of '../../../home_page.dart';

extension _HomePageProjectEditorAssetsImagesCrudProbeActions on _HomePageState {
  List<Widget> _buildProjectAssetsImagesCrudProbeActions({
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
    final l10n = resolveAppLocalizationsForErrors(ctx);
    return [
      TextButton(
        onPressed:
            assetsBusy[0] || assetsLoading[0] || assetsScriptFilterLoading[0]
            ? null
            : () async {
                setDialogState(() => assetsBusy[0] = true);
                try {
                  final r = await fetchCornerScapeAssetsByProjectId(
                    token,
                    p.id,
                  );
                  Uint8List? cornerThumb;
                  if (r.items.isNotEmpty &&
                      r.items.first.historyImages.isNotEmpty) {
                    final a = r.items.first;
                    cornerThumb =
                        await fetchCornerScapeHistoryImagePreviewBytes(
                          token,
                          p.id,
                          a.numericId,
                          a.historyImages.first,
                        );
                  }
                  if (!ctx.mounted) return;
                  final h0 = r.items.isEmpty
                      ? 0
                      : r.items.first.historyImages.length;
                  final cornerText = r.items.isEmpty
                      ? l10n.projectEditorAssetsProbeImagesCornerScapeSnackZero
                      : l10n.projectEditorAssetsProbeImagesCornerScapeSnack(
                          r.items.length,
                          h0,
                          cornerThumb == null
                              ? ''
                              : l10n.projectEditorAssetsProbeImagesCornerScapePreviewSuffix,
                        );
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 6),
                      content: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cornerThumb != null) ...[
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.memory(
                                  cornerThumb,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: StudioLayoutSpacing.inlineGap),
                          ],
                          Expanded(
                            child: Text(cornerText),
                          ),
                        ],
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeImagesCornerScapeButton),
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
                  final ts = DateTime.now().millisecondsSinceEpoch;
                  final row = await createProjectAssetImageForProject(
                    token,
                    p.id,
                    first.numericId,
                    filePath: 'probe/hist_$ts.png',
                  );
                  if (!ctx.mounted) return;
                  final idPrefix = row.id.length <= 8 ? row.id : row.id.substring(0, 8);
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeImagesPostFirstSnack(
                          first.numericId,
                          idPrefix,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeImagesPostFirstButton),
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
                  final list = await fetchProjectAssetImagesByProjectIds(
                    token,
                    p.id,
                    first.numericId,
                  );
                  if (list.items.isEmpty) {
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(l10n.projectEditorAssetsProbeImagesGetEmptySnack),
                      ),
                    );
                    return;
                  }
                  final img = list.items.first;
                  final one = await fetchProjectAssetImageByProjectIds(
                    token,
                    p.id,
                    first.numericId,
                    img.id,
                  );
                  var fileSuffix = '';
                  try {
                    final bytes = await fetchProjectAssetImageFileByProjectIds(
                      token,
                      p.id,
                      first.numericId,
                      one.id,
                    );
                    fileSuffix = ' …/file ${bytes.length}B';
                  } on RustApiException catch (fe) {
                    fileSuffix = ' …/file ${fe.statusCode ?? "?"}';
                  }
                  if (!ctx.mounted) return;
                  final idShort = one.id.length <= 8
                      ? one.id
                      : '${one.id.substring(0, 8)}…';
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeImagesGetOneSnack(
                          idShort,
                          one.sortIndex,
                          one.state ?? '-',
                          fileSuffix,
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeImagesGetOneButton),
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
                  final ts = DateTime.now().millisecondsSinceEpoch;
                  final row = await createProjectAssetImageForProject(
                    token,
                    p.id,
                    first.numericId,
                    filePath: 'probe/patch_del_$ts.png',
                  );
                  final patched = await patchProjectAssetImageByProjectIds(
                    token,
                    p.id,
                    first.numericId,
                    row.id,
                    {'state': '已完成', 'sort_index': row.sortIndex + 1},
                  );
                  await deleteProjectAssetImageByProjectIds(
                    token,
                    p.id,
                    first.numericId,
                    row.id,
                  );
                  if (!ctx.mounted) return;
                  await reloadAssetsAndStats();
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.projectEditorAssetsProbeImagesPatchDelSnack(
                          row.sortIndex,
                          patched.sortIndex,
                          patched.state ?? '-',
                        ),
                      ),
                    ),
                  );
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(describeUserVisibleApiErrorResolved(ctx, e))));
                  }
                } finally {
                  if (ctx.mounted) {
                    setDialogState(() => assetsBusy[0] = false);
                  }
                }
              },
        child: Text(l10n.projectEditorAssetsProbeImagesPatchDelButton),
      ),
    ];
  }
}
