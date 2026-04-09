part of '../home_page.dart';

extension _HomePageProjectEditorAssetsImagesProbe on _HomePageState {
  Widget _buildProjectAssetsImagesCompatibilitySection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '资产图片 / legacy 轮询检查',
          style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
            color: Theme.of(ctx).colorScheme.outline,
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed:
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final r = await fetchCornerScapeAssetsByLegacyId(
                          token,
                          p.legacyId,
                        );
                        Uint8List? cornerThumb;
                        if (r.items.isNotEmpty &&
                            r.items.first.historyImages.isNotEmpty) {
                          final a = r.items.first;
                          cornerThumb =
                              await fetchCornerScapeHistoryImagePreviewBytes(
                                token,
                                p.legacyId,
                                a.legacyId,
                                a.historyImages.first,
                              );
                        }
                        if (!ctx.mounted) return;
                        final h0 = r.items.isEmpty
                            ? 0
                            : r.items.first.historyImages.length;
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
                                  const SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Text(
                                    'POST …/assets/corner-scape：'
                                    '${r.items.length} 条'
                                    '${r.items.isEmpty ? "" : "，首条 history_images=$h0"}'
                                    '${cornerThumb == null ? "" : "（预览）"}',
                                  ),
                                ),
                              ],
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
              child: const Text('POST corner-scape'),
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
                        final row = await createProjectAssetImage(
                          token,
                          p.legacyId,
                          first.legacyId,
                          filePath: 'probe/hist_$ts.png',
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/${first.legacyId}/images：${row.id.substring(0, 8)}…',
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
              child: const Text('POST 首条资产图片'),
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
                        final list = await fetchProjectAssetImagesByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                        );
                        if (list.items.isEmpty) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'GET …/images：0 条，可先点「POST 首条资产图片」',
                              ),
                            ),
                          );
                          return;
                        }
                        final img = list.items.first;
                        final one = await fetchProjectAssetImageByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                          img.id,
                        );
                        var fileSuffix = '';
                        try {
                          final bytes =
                              await fetchProjectAssetImageFileByLegacyIds(
                                token,
                                p.legacyId,
                                first.legacyId,
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
                              'GET …/images/$idShort：sort=${one.sortIndex} '
                              'state=${one.state ?? "-"}$fileSuffix',
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
              child: const Text('GET 资产图片(单条)'),
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
                        final r = await postLegacyAssetsGetImage(
                          token,
                          first.legacyId,
                        );
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/get-image：tempAssets=${r.tempAssets.length} '
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
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final ts = DateTime.now().millisecondsSinceEpoch;
                        final r = await postLegacyAssetsUploadClip(
                          token,
                          projectLegacyId: p.legacyId,
                          base64Data: 'data:image/png;base64,AA==',
                          name: 'probe clip $ts',
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/upload-clip：${r.message}',
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
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final r = await postLegacyAssetsGetMaterialData(
                          token,
                          p.legacyId,
                        );
                        if (!ctx.mounted) return;
                        final firstClip = r.data.isEmpty ? null : r.data.first;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/get-material-data：'
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
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final r = await postLegacyAssetsBatchGenerationData(
                          token,
                          projectLegacyId: p.legacyId,
                          assetType: 'role',
                          page: 1,
                          limit: 3,
                        );
                        if (!ctx.mounted) return;
                        final first = r.data.isEmpty ? null : r.data.first;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/batch-generation-data：'
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
                  assetsBusy[0] ||
                      assetsLoading[0] ||
                      assetsScriptFilterLoading[0]
                  ? null
                  : () async {
                      setDialogState(() => assetsBusy[0] = true);
                      try {
                        final r = await postLegacyAssetsGetAssetsApi(
                          token,
                          projectLegacyId: p.legacyId,
                          assetType: 'role',
                          page: 1,
                          limit: 3,
                        );
                        if (!ctx.mounted) return;
                        final first = r.data.isEmpty ? null : r.data.first;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST …/assets/get-assets-api：'
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
                        final rows = await postLegacyAssetsPollingImageAssets(
                          token,
                          <int>[first.legacyId],
                        );
                        if (!ctx.mounted) return;
                        final one = rows.isEmpty ? null : rows.first;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              one == null
                                  ? 'POST …/assets/polling-image-assets：0 rows'
                                  : 'POST …/assets/polling-image-assets：'
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
                        final rows = await postLegacyAssetsPollingPromptAssets(
                          token,
                          <int>[first.legacyId],
                        );
                        if (!ctx.mounted) return;
                        final one = rows.isEmpty ? null : rows.first;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              one == null
                                  ? 'POST …/assets/polling-prompt-assets：0 rows'
                                  : 'POST …/assets/polling-prompt-assets：'
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
                        final row = await createProjectAssetImage(
                          token,
                          p.legacyId,
                          first.legacyId,
                          filePath: 'probe/patch_del_$ts.png',
                        );
                        final patched = await patchProjectAssetImageByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                          row.id,
                          {'state': '已完成', 'sort_index': row.sortIndex + 1},
                        );
                        await deleteProjectAssetImageByLegacyIds(
                          token,
                          p.legacyId,
                          first.legacyId,
                          row.id,
                        );
                        if (!ctx.mounted) return;
                        await reloadAssetsAndStats();
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'POST→PATCH→DEL 资产图片：sort ${row.sortIndex}→${patched.sortIndex} '
                              'state=${patched.state ?? "-"} 已删',
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
              child: const Text('POST→PATCH→DEL 图'),
            ),
          ],
        ),
      ],
    );
  }
}
