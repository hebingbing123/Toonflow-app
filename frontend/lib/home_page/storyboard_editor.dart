part of '../home_page.dart';

extension _HomePageStoryboardEditor on _HomePageState {
  Future<void> _openStoryboardEditor(
    String token,
    int storyLegacyId, {
    Future<void> Function()? onStoryboardTreeMutated,
  }) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    try {
      final row = await fetchStoryboardByLegacyId(token, storyLegacyId);
      if (!mounted) return;
      promptCtrl.text = row.prompt ?? '';
      stateCtrl.text = row.state ?? '';
      videoCtrl.text = row.videoDesc ?? '';
      sbIdxCtrl.text = row.sbIndex?.toString() ?? '';
      sgiCtrl.text = row.shouldGenerateImage?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('Storyboard #${row.legacyId}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: promptCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'prompt (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: stateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'state (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: videoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'video_desc (empty = clear)',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sbIdxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'sb_index (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: sgiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'should_generate_image (empty = clear)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                  TextButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (c) => AlertDialog(
                                title: const Text('删除分镜？'),
                                content: Text(
                                  '将删除 storyboard #${row.legacyId}。',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(c).pop(false),
                                    child: const Text('取消'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(c).pop(true),
                                    child: const Text('删除'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !ctx.mounted) return;
                            setDialogState(() => saving[0] = true);
                            try {
                              await deleteStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('分镜已删除')),
                              );
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: const Text('DELETE'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? sbIdx;
                            final sbs = sbIdxCtrl.text.trim();
                            if (sbs.isNotEmpty) {
                              sbIdx = int.tryParse(sbs);
                              if (sbIdx == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('sb_index 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            int? sgi;
                            final sgis = sgiCtrl.text.trim();
                            if (sgis.isNotEmpty) {
                              sgi = int.tryParse(sgis);
                              if (sgi == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'should_generate_image 须为整数',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateStoryboardByLegacyId(
                                token,
                                storyLegacyId,
                                {
                                  'prompt': promptCtrl.text.isEmpty
                                      ? null
                                      : promptCtrl.text,
                                  'state': stateCtrl.text.isEmpty
                                      ? null
                                      : stateCtrl.text,
                                  'video_desc': videoCtrl.text.isEmpty
                                      ? null
                                      : videoCtrl.text,
                                  'sb_index': sbs.isEmpty ? null : sbIdx,
                                  'should_generate_image': sgis.isEmpty
                                      ? null
                                      : sgi,
                                },
                              );
                              if (!ctx.mounted) return;
                              await onStoryboardTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                            } on RustApiException catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => saving[0] = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              }
                            }
                          },
                    child: Text(saving[0] ? '保存中…' : 'PATCH 保存'),
                  ),
                ],
              );
            },
          );
        },
      );
    } on RustApiException catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } finally {
      promptCtrl.dispose();
      stateCtrl.dispose();
      videoCtrl.dispose();
      sbIdxCtrl.dispose();
      sgiCtrl.dispose();
    }
  }
}
