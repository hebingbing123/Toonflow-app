part of '../home_page.dart';

extension _HomePageProjectEditorScripts on _HomePageState {
  Future<void> _openBatchAddScriptsDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) async {
    final countCtrl = TextEditingController(text: '3');
    final namePrefixCtrl = TextEditingController(text: '新剧本');
    final scriptDataCtrl = TextEditingController(text: '剧情梗概待补充。');
    try {
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogCtx) {
          return AlertDialog(
            title: const Text('批量新增剧本'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '数量（1-20）',
                      helperText: '单次最多创建 20 条，避免误操作。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: namePrefixCtrl,
                    decoration: const InputDecoration(labelText: '名称前缀'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: scriptDataCtrl,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: '剧本默认内容'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('创建'),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !ctx.mounted) return;

      final count = int.tryParse(countCtrl.text.trim());
      if (count == null || count < 1 || count > 20) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(const SnackBar(content: Text('数量必须是 1-20 的整数')));
        return;
      }

      final prefix = namePrefixCtrl.text.trim().isEmpty
          ? '新剧本'
          : namePrefixCtrl.text.trim();
      final scriptData = scriptDataCtrl.text;
      final base = scriptList.length;
      final rows = List<BatchAddScriptItemV1>.generate(
        count,
        (i) => BatchAddScriptItemV1(
          scriptName: '$prefix ${base + i + 1}',
          scriptData: scriptData,
        ),
      );

      setDialogState(() => saving[0] = true);
      final created = await postScriptsBatchAdd(
        token,
        projectId: p.legacyId,
        data: rows,
      );
      if (!ctx.mounted) return;
      scriptList.addAll(
        created.scripts.map(
          (s) => ScriptBrief(
            legacyId: s.legacyId,
            name: s.name,
            extractState: s.extractState,
          ),
        ),
      );
      try {
        statsRef[0] = await fetchProjectStatsByLegacyId(token, p.legacyId);
      } catch (_) {}
      if (!ctx.mounted) return;
      setDialogState(() => saving[0] = false);
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text('已批量创建 ${created.inserted} 条剧本')),
      );
    } on RustApiException catch (e) {
      if (ctx.mounted) {
        setDialogState(() => saving[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } catch (e) {
      if (ctx.mounted) {
        setDialogState(() => saving[0] = false);
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      countCtrl.dispose();
      namePrefixCtrl.dispose();
      scriptDataCtrl.dispose();
    }
  }

  Widget _buildProjectScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${scriptList.length} script(s)'),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          children: [
            TextButton(
              onPressed: saving[0]
                  ? null
                  : () => _openBatchAddScriptsDialog(
                      ctx: ctx,
                      setDialogState: setDialogState,
                      token: token,
                      p: p,
                      saving: saving,
                      scriptList: scriptList,
                      statsRef: statsRef,
                    ),
              child: const Text('批量新增剧本'),
            ),
            ..._buildProjectScriptsProbeActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              saving: saving,
              scriptProbeBusy: scriptProbeBusy,
              scriptList: scriptList,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving[0]
                ? null
                : () async {
                    setDialogState(() => saving[0] = true);
                    try {
                      final s = await createScriptUnderProjectLegacy(
                        token,
                        p.legacyId,
                      );
                      if (!ctx.mounted) return;
                      scriptList.add(
                        ScriptBrief(
                          legacyId: s.legacyId,
                          name: s.name,
                          extractState: s.extractState,
                        ),
                      );
                      try {
                        statsRef[0] = await fetchProjectStatsByLegacyId(
                          token,
                          p.legacyId,
                        );
                      } catch (_) {}
                      if (!ctx.mounted) return;
                      setDialogState(() => saving[0] = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('已创建剧本 legacy #${s.legacyId}')),
                      );
                    } on RustApiException catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() => saving[0] = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        setDialogState(() => saving[0] = false);
                        ScaffoldMessenger.of(
                          ctx,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                      }
                    }
                  },
            child: const Text('POST 空剧本'),
          ),
        ),
        const SizedBox(height: 8),
        ...scriptList.map(
          (s) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              '#${s.legacyId} ${s.name ?? ""}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            trailing: const Icon(Icons.edit_outlined, size: 18),
            onTap: saving[0]
                ? null
                : () => _openScriptEditor(
                    token,
                    s.legacyId,
                    onScriptTreeMutated: () async {
                      final d = await fetchProjectByLegacyId(token, p.legacyId);
                      if (!ctx.mounted) return;
                      scriptList
                        ..clear()
                        ..addAll(d.scripts);
                      try {
                        statsRef[0] = await fetchProjectStatsByLegacyId(
                          token,
                          p.legacyId,
                        );
                      } catch (_) {}
                      setDialogState(() {});
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
