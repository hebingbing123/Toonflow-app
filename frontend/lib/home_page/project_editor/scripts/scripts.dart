part of '../../../home_page.dart';

extension _HomePageProjectEditorScripts on _HomePageState {
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
            legacyId: s.legacyId,
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
        selectedIds: scriptList.map((script) => script.legacyId),
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

  Widget _buildProjectScriptsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required List<bool> saving,
    required List<bool> scriptProbeBusy,
    required List<bool> scriptTaskBusy,
    required List<String?> scriptTaskLine,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
  }) {
    final outline = Theme.of(ctx).colorScheme.outline;
    final allScriptIds = scriptList
        .map((script) => script.legacyId)
        .toList(growable: false);
    final overviewDiagnosis = diagnoseScriptBatchWorkbench(
      selectedIds: allScriptIds,
      scripts: scriptList,
      previewRows: const [],
    );

    Future<void> runProjectScriptsExportAll() async {
      setDialogState(() {
        scriptTaskBusy[0] = true;
        scriptTaskLine[0] = null;
      });
      try {
        final zip = await exportScriptsZip(token, allScriptIds);
        if (!ctx.mounted) return;
        final nextDiagnosis = diagnoseScriptBatchWorkbench(
          selectedIds: allScriptIds,
          scripts: scriptList,
          previewRows: const [],
        );
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
            actionSummary:
                '已导出 ${scriptList.length} 条剧本，ZIP ${formatBinarySize(zip.length)}。',
            diagnosis: nextDiagnosis,
          );
        });
      } on RustApiException catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '导出失败：$e';
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '导出失败：$e';
          });
        }
      }
    }

    Future<void> runProjectScriptsPollAll() async {
      setDialogState(() {
        scriptTaskBusy[0] = true;
        scriptTaskLine[0] = null;
      });
      try {
        final rows = await pollScriptExtractState(token, allScriptIds);
        final synced = syncScriptExtractStates(scriptList, rows);
        scriptList
          ..clear()
          ..addAll(synced);
        final sample = rows.isEmpty
            ? '当前均为 idle 或已完成'
            : rows
                  .take(3)
                  .map((row) => '#${row.legacyId}:${row.extractState ?? 0}')
                  .join(' · ');
        if (!ctx.mounted) return;
        final nextDiagnosis = diagnoseScriptBatchWorkbench(
          selectedIds: allScriptIds,
          scripts: scriptList,
          previewRows: const [],
        );
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
            actionSummary: '已轮询 ${scriptList.length} 条剧本提取状态：$sample',
            diagnosis: nextDiagnosis,
          );
        });
      } on RustApiException catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '轮询提取状态失败：$e';
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '轮询提取状态失败：$e';
          });
        }
      }
    }

    Future<void> runProjectScriptsExtractAll() async {
      setDialogState(() {
        scriptTaskBusy[0] = true;
        scriptTaskLine[0] = null;
      });
      try {
        final accepted = await startScriptAssetExtract(
          token,
          projectNumericId: p.legacyId,
          scriptNumericIds: allScriptIds,
        );
        final rows = await pollScriptExtractState(token, allScriptIds);
        final synced = syncScriptExtractStates(scriptList, rows);
        scriptList
          ..clear()
          ..addAll(synced);
        if (!ctx.mounted) return;
        final nextDiagnosis = diagnoseScriptBatchWorkbench(
          selectedIds: allScriptIds,
          scripts: scriptList,
          previewRows: const [],
        );
        setDialogState(() {
          scriptTaskBusy[0] = false;
          scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
            actionSummary:
                '已提交 ${scriptList.length} 条剧本素材抽取：${accepted.status} · ${accepted.message}',
            diagnosis: nextDiagnosis,
          );
        });
      } on RustApiException catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '提交素材抽取失败：$e';
          });
        }
      } catch (e) {
        if (ctx.mounted) {
          setDialogState(() {
            scriptTaskBusy[0] = false;
            scriptTaskLine[0] = '提交素材抽取失败：$e';
          });
        }
      }
    }

    VoidCallback? overviewAction;
    String overviewActionLabel;
    switch (overviewDiagnosis.recommendedAction) {
      case ScriptBatchWorkbenchRecommendedAction.syncContext:
        overviewAction = saving[0] || scriptTaskBusy[0]
            ? null
            : () => _openProjectScriptsWorkbenchDialog(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                saving: saving,
                scriptTaskBusy: scriptTaskBusy,
                scriptTaskLine: scriptTaskLine,
                scriptList: scriptList,
                statsRef: statsRef,
              );
        overviewActionLabel = '打开工作台读取上下文';
      case ScriptBatchWorkbenchRecommendedAction.pollSelected:
        overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
            ? null
            : runProjectScriptsPollAll;
        overviewActionLabel = '轮询全部提取状态';
      case ScriptBatchWorkbenchRecommendedAction.startExtractSelected:
        overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
            ? null
            : runProjectScriptsExtractAll;
        overviewActionLabel = '提取全部剧本素材';
      case ScriptBatchWorkbenchRecommendedAction.exportSelectedZip:
        overviewAction = saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
            ? null
            : runProjectScriptsExportAll;
        overviewActionLabel = '导出全部剧本';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${scriptList.length} 条剧本',
          style: Theme.of(ctx).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          '在项目下管理剧本，并进入剧本详情维护内容与分镜。',
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: outline),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(
              ctx,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('剧本批量工作台', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '把项目级剧本上下文读取、批量导出、提取状态轮询、素材抽取和批量创建收口到同一工作台，不再只靠全量快捷按钮。',
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: saving[0] || scriptTaskBusy[0]
                    ? null
                    : () => _openProjectScriptsWorkbenchDialog(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        saving: saving,
                        scriptTaskBusy: scriptTaskBusy,
                        scriptTaskLine: scriptTaskLine,
                        scriptList: scriptList,
                        statsRef: statsRef,
                      ),
                child: const Text('打开剧本批量工作台'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(
              ctx,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前批量建议', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                overviewDiagnosis.summary,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                overviewDiagnosis.detail,
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: overviewAction,
                child: Text(overviewActionLabel),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                      scriptTaskLine: scriptTaskLine,
                      scriptList: scriptList,
                      statsRef: statsRef,
                    ),
              child: const Text('批量新增剧本'),
            ),
            TextButton(
              onPressed: saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
                  ? null
                  : runProjectScriptsExportAll,
              child: Text(scriptTaskBusy[0] ? '处理中…' : '导出全部剧本'),
            ),
            TextButton(
              onPressed: saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
                  ? null
                  : runProjectScriptsPollAll,
              child: const Text('轮询全部提取状态'),
            ),
            TextButton(
              onPressed: saving[0] || scriptTaskBusy[0] || scriptList.isEmpty
                  ? null
                  : runProjectScriptsExtractAll,
              child: const Text('提取全部剧本素材'),
            ),
          ],
        ),
        if (scriptTaskLine[0] != null) ...[
          const SizedBox(height: 4),
          Text(
            scriptTaskLine[0]!,
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: outline),
          ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: saving[0]
                ? null
                : () async {
                    setDialogState(() => saving[0] = true);
                    try {
                      final s = await createScriptUnderProject(
                        token,
                        p.id,
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
                        statsRef[0] = await fetchProjectStatsByProjectId(
                          token,
                          p.id,
                        );
                      } catch (_) {}
                      final nextDiagnosis = diagnoseScriptBatchWorkbench(
                        selectedIds: scriptList.map(
                          (script) => script.legacyId,
                        ),
                        scripts: scriptList,
                        previewRows: const [],
                      );
                      if (!ctx.mounted) return;
                      setDialogState(() {
                        saving[0] = false;
                        scriptTaskLine[0] = buildScriptBatchWorkbenchFollowUp(
                          actionSummary: '已创建剧本 legacy #${s.legacyId}。',
                          diagnosis: nextDiagnosis,
                        );
                      });
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
            child: const Text('新建空剧本'),
          ),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '保留旧剧本接口与导出/提取回归入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: outline),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
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
            ),
          ],
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
                    projectId: p.id,
                    projectLegacyId: p.legacyId,
                    onScriptTreeMutated: () async {
                      final d = await fetchProjectByProjectId(token, p.id);
                      if (!ctx.mounted) return;
                      scriptList
                        ..clear()
                        ..addAll(d.scripts);
                      try {
                        statsRef[0] = await fetchProjectStatsByProjectId(
                          token,
                          p.id,
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
