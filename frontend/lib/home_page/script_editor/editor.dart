part of '../../home_page.dart';

extension _HomePageScriptEditor on _HomePageState {
  Future<void> _openScriptEditor(
    String token,
    int scriptLegacyId, {
    required int projectLegacyId,
    Future<void> Function()? onScriptTreeMutated,
  }) async {
    final nameCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    try {
      final script = await fetchScriptByLegacyId(token, scriptLegacyId);
      if (!mounted) return;
      nameCtrl.text = script.name ?? '';
      contentCtrl.text = script.content ?? '';
      stateCtrl.text = script.extractState?.toString() ?? '';
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              return AlertDialog(
                title: Text('剧本 #${script.legacyId}'),
                content: SizedBox(
                  width: 720,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ScriptWorkbenchPanel(
                          token: token,
                          projectLegacyId: projectLegacyId,
                          scriptLegacyId: scriptLegacyId,
                          onExtractStateSynced: (extractState) {
                            stateCtrl.text = extractState?.toString() ?? '';
                          },
                          onOpenEditImageWorkbench: () =>
                              _openScriptEditImageWorkbenchDialog(
                                token: token,
                                projectLegacyId: projectLegacyId,
                                scriptLegacyId: scriptLegacyId,
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: '名称（留空则清空）',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: contentCtrl,
                          minLines: 4,
                          maxLines: 12,
                          decoration: const InputDecoration(
                            labelText: '内容（留空则清空）',
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: stateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '提取状态（留空则清空）',
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: saving[0]
                                ? null
                                : () => _openScriptStoryboardsDialog(
                                    token: token,
                                    projectLegacyId: projectLegacyId,
                                    scriptLegacyId: scriptLegacyId,
                                  ),
                            child: const Text('分镜列表…'),
                          ),
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
                                title: const Text('删除剧本？'),
                                content: Text(
                                  '将删除 script #${script.legacyId} 及其分镜（数据库级联）。',
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
                              await deleteScriptByLegacyId(
                                token,
                                scriptLegacyId,
                              );
                              if (!ctx.mounted) return;
                              await onScriptTreeMutated?.call();
                              if (!ctx.mounted) return;
                              Navigator.of(ctx).pop();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('剧本已删除')),
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
                    child: const Text('删除剧本'),
                  ),
                  FilledButton(
                    onPressed: saving[0]
                        ? null
                        : () async {
                            setDialogState(() => saving[0] = true);
                            int? extractParsed;
                            final st = stateCtrl.text.trim();
                            if (st.isNotEmpty) {
                              extractParsed = int.tryParse(st);
                              if (extractParsed == null) {
                                if (ctx.mounted) {
                                  setDialogState(() => saving[0] = false);
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text('extract_state 须为整数'),
                                    ),
                                  );
                                }
                                return;
                              }
                            }
                            try {
                              await updateScriptByLegacyId(
                                token,
                                scriptLegacyId,
                                {
                                  'name': nameCtrl.text.isEmpty
                                      ? null
                                      : nameCtrl.text,
                                  'content': contentCtrl.text.isEmpty
                                      ? null
                                      : contentCtrl.text,
                                  'extract_state': st.isEmpty
                                      ? null
                                      : extractParsed,
                                },
                              );
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
      nameCtrl.dispose();
      contentCtrl.dispose();
      stateCtrl.dispose();
    }
  }
}
