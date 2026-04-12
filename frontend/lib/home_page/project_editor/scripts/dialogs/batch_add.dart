part of '../../../../home_page.dart';

extension _HomePageProjectEditorScriptsBatchAddDialog on _HomePageState {
  /// 处理批量新增剧本弹窗，避免 scripts section 混入过多表单细节。
  Future<void> _openBatchAddScriptsDialog({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<String?> scriptTaskLine,
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
      final rows = buildBatchAddScriptItems(
        count: count,
        startingIndex: scriptList.length + 1,
        prefix: prefix,
        scriptData: scriptDataCtrl.text,
      );

      setDialogState(() => saving[0] = true);
      final created = await postScriptsBatchAddByProjectId(
        token,
        projectId: p.id,
        data: rows,
      );
      if (!ctx.mounted) return;
      scriptList.addAll(
        created.scripts.map(
          (s) => ScriptBrief(
            numericId: s.numericId,
            name: s.name,
            extractState: s.extractState,
          ),
        ),
      );
      try {
        statsRef[0] = await fetchProjectStatsByProjectId(token, p.id);
      } catch (_) {}
      if (!ctx.mounted) return;
      final nextDiagnosis = diagnoseScriptBatchWorkbench(
        selectedIds: scriptList.map((script) => script.numericId),
        scripts: scriptList,
        previewRows: const [],
      );
      setDialogState(() => saving[0] = false);
      setDialogState(() {
        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
          actionSummary: '已批量创建 ${created.inserted} 条剧本。',
          diagnosis: nextDiagnosis,
        );
      });
      ScaffoldMessenger.of(
        ctx,
      ).showSnackBar(SnackBar(content: Text('已批量创建 ${created.inserted} 条剧本')));
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
}
