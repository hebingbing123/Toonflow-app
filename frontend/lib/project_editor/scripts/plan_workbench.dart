part of '../../home_page.dart';

extension _HomePageProjectEditorScriptPlanWorkbench on _HomePageState {
  Future<void> _openProjectScriptPlanWorkbenchDialog({
    required BuildContext ctx,
    required String token,
    required ProjectRow project,
  }) async {
    final storySkeletonCtrl = TextEditingController();
    final adaptationStrategyCtrl = TextEditingController();
    ScriptAgentPlanData? planData;
    var localBusy = false;
    var infoLine = '正在读取当前项目的故事骨架与改编策略…';

    Future<void> loadPlan(StateSetter setLocalState) async {
      setLocalState(() {
        localBusy = true;
        infoLine = '正在刷新骨架与改编策略…';
      });
      try {
        final next = await fetchScriptAgentPlanDataV1(
          token,
          projectId: project.numericId,
        );
        if (!ctx.mounted) return;
        setLocalState(() {
          planData = next;
          storySkeletonCtrl.text = next.storySkeleton;
          adaptationStrategyCtrl.text = next.adaptationStrategy;
          infoLine =
              '已载入 plan ${next.planId ?? 'new'}，当前挂载 ${next.scriptRows.length} 条剧本。';
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setLocalState(() {
          infoLine = '读取失败：$e';
        });
      } finally {
        if (ctx.mounted) {
          setLocalState(() => localBusy = false);
        }
      }
    }

    Future<void> savePlan(StateSetter setLocalState) async {
      setLocalState(() {
        localBusy = true;
        infoLine = '正在保存骨架与改编策略…';
      });
      try {
        final status = await postScriptAgentSetPlanDataV1(
          token,
          projectId: project.numericId,
          storySkeleton: storySkeletonCtrl.text.trim(),
          adaptationStrategy: adaptationStrategyCtrl.text.trim(),
          script: const <Map<String, dynamic>>[],
        );
        if (status != 200) {
          throw Exception('保存失败，HTTP $status');
        }
        await loadPlan(setLocalState);
        if (!ctx.mounted) return;
        setLocalState(() {
          infoLine = '已保存骨架与改编策略。';
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setLocalState(() {
          localBusy = false;
          infoLine = '保存失败：$e';
        });
      }
    }

    try {
      await showDialog<void>(
        context: ctx,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (dialogCtx, setLocalState) {
              if (planData == null && !localBusy) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (dialogCtx.mounted) {
                    loadPlan(setLocalState);
                  }
                });
              }
              return ProjectScriptPlanWorkbenchView(
                model: ProjectScriptPlanWorkbenchViewModel(
                  localBusy: localBusy,
                  infoLine: infoLine,
                  storySkeletonCtrl: storySkeletonCtrl,
                  adaptationStrategyCtrl: adaptationStrategyCtrl,
                  planData: planData,
                ),
                callbacks: ProjectScriptPlanWorkbenchViewCallbacks(
                  onReload: () => loadPlan(setLocalState),
                  onSave: () => savePlan(setLocalState),
                  onClose: () => Navigator.of(dialogCtx).pop(),
                ),
              );
            },
          );
        },
      );
    } finally {
      storySkeletonCtrl.dispose();
      adaptationStrategyCtrl.dispose();
    }
  }
}
