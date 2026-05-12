part of '../../home_page.dart';

extension _HomePageStoryboardEditor on _HomePageState {
  Future<void> _openStoryboardEditor(
    String token,
    int storyNumericId, {
    required String projectId,
    required int scriptNumericId,
    Future<void> Function()? onStoryboardTreeMutated,
  }) async {
    final promptCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final videoCtrl = TextEditingController();
    final sbIdxCtrl = TextEditingController();
    final sgiCtrl = TextEditingController();
    try {
      final row = await fetchStoryboardByProjectAndNumericId(
        token,
        projectId,
        storyNumericId,
      );
      if (!mounted) return;
      promptCtrl.text = row.prompt ?? '';
      stateCtrl.text = row.state ?? '';
      videoCtrl.text = row.videoDesc ?? '';
      sbIdxCtrl.text = row.sbIndex?.toString() ?? '';
      sgiCtrl.text = row.shouldGenerateImage?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          final saving = <bool>[false];

          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final viewportWidth = MediaQuery.sizeOf(ctx).width;
              final dialogWidth = viewportWidth.isFinite
                  ? viewportWidth.clamp(320.0, 720.0)
                  : 720.0;
              return AlertDialog(
                title: Text('Storyboard #${row.numericId}'),
                content: SizedBox(
                  width: dialogWidth,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StoryboardWorkbenchPanel(
                          token: token,
                          projectId: projectId,
                          storyNumericId: storyNumericId,
                          scriptNumericId: scriptNumericId,
                          scriptStoryboard: row,
                          readPromptText: () => promptCtrl.text,
                          readVideoDescriptionText: () => videoCtrl.text,
                          videoDescriptionCtrl: videoCtrl,
                          onStoryboardMutated: onStoryboardTreeMutated,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: promptCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: '分镜提示词（留空则清空）',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(
                            labelText: '状态（留空则清空）',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: videoCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '视频描述（留空则清空）',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: sbIdxCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '分镜序号（留空则清空）',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: sgiCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '是否需要出图（留空则清空）',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving[0] ? null : () => Navigator.of(ctx).pop(),
                    child: const Text('关闭'),
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
                                  '将删除 storyboard #${row.numericId}。',
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
                              await deleteStoryboardByProjectAndNumericId(
                                token,
                                projectId,
                                storyNumericId,
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
                    child: const Text('删除分镜'),
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
                                    const SnackBar(content: Text('分镜序号必须是整数')),
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
                                      content: Text('是否需要出图必须是整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateStoryboardByProjectAndNumericId(
                                token,
                                projectId,
                                storyNumericId,
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
                    child: Text(saving[0] ? '保存中…' : '保存修改'),
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
