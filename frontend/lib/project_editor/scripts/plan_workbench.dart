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
    List<NovelEventRow> eventRows = const <NovelEventRow>[];
    List<NovelRow> novelRows = const <NovelRow>[];
    List<ScriptDraftPacket> draftPackets = const <ScriptDraftPacket>[];
    List<StructuredRewriteGuidance> guidanceRows =
        const <StructuredRewriteGuidance>[];
    var localBusy = false;
    var infoLine = '正在读取当前项目的故事骨架与改编策略…';

    Future<void> loadPlan(StateSetter setLocalState) async {
      setLocalState(() {
        localBusy = true;
        infoLine = '正在刷新骨架与改编策略…';
      });
      try {
        final results = await Future.wait<Object>([
          fetchScriptAgentPlanDataV1(token, projectId: project.numericId),
          fetchProjectNovelEventsByProjectId(token, project.id),
          fetchProjectNovelsByProjectId(token, project.id),
        ]);
        final next = results[0] as ScriptAgentPlanData;
        final nextEvents = results[1] as ListNovelEventsResponse;
        final nextNovels = results[2] as ListNovelsResponse;
        if (!ctx.mounted) return;
        eventRows = nextEvents.items;
        novelRows = nextNovels.items;
        setLocalState(() {
          planData = next;
          storySkeletonCtrl.text = next.storySkeleton;
          adaptationStrategyCtrl.text = next.adaptationStrategy;
          draftPackets = const <ScriptDraftPacket>[];
          guidanceRows = const <StructuredRewriteGuidance>[];
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

    void fillStorySkeletonSeed(StateSetter setLocalState) {
      final seed = buildStorySkeletonSeedFromEvents(
        events: eventRows,
        novels: novelRows,
      );
      setLocalState(() {
        storySkeletonCtrl.text = seed;
        infoLine = '已用当前事件与章节生成骨架草稿。';
      });
    }

    void fillAdaptationStrategySeed(StateSetter setLocalState) {
      final seed = buildAdaptationStrategySeedFromEvents(
        events: eventRows,
        novels: novelRows,
      );
      setLocalState(() {
        adaptationStrategyCtrl.text = seed;
        infoLine = '已用当前事件与章节生成改编策略草稿。';
      });
    }

    void generateDraftPackets(StateSetter setLocalState) {
      final nextDrafts = buildScriptDraftPackets(
        events: eventRows,
        novels: novelRows,
        storySkeleton: storySkeletonCtrl.text,
        adaptationStrategy: adaptationStrategyCtrl.text,
        existingScripts: planData?.scriptRows ?? const <ScriptAgentPlanScriptRow>[],
      );
      setLocalState(() {
        draftPackets = nextDrafts;
        guidanceRows = const <StructuredRewriteGuidance>[];
        infoLine = nextDrafts.isEmpty
            ? '当前缺少可用事件或章节，暂时无法生成剧本初稿。'
            : '已根据当前事件、章节和计划生成 ${nextDrafts.length} 份剧本初稿包。';
      });
    }

    void generateGuidance(StateSetter setLocalState) {
      final nextGuidance = buildStructuredRewriteGuidance(
        events: eventRows,
        novels: novelRows,
        storySkeleton: storySkeletonCtrl.text,
        adaptationStrategy: adaptationStrategyCtrl.text,
        existingScripts:
            planData?.scriptRows ?? const <ScriptAgentPlanScriptRow>[],
      );
      setLocalState(() {
        guidanceRows = nextGuidance;
        infoLine = nextGuidance.isEmpty
            ? '当前缺少可用事件或章节，暂时无法生成结构化改写 guidance。'
            : '已生成 ${nextGuidance.length} 份结构化改写 guidance，可直接供后续 script 子代理或人工改稿消费。';
      });
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

    Future<void> writeDraftPackets(StateSetter setLocalState) async {
      if (draftPackets.isEmpty) {
        setLocalState(() {
          infoLine = '请先生成剧本初稿包。';
        });
        return;
      }
      setLocalState(() {
        localBusy = true;
        infoLine = '正在把剧本初稿写入当前项目…';
      });
      try {
        final status = await postScriptAgentSetPlanDataV1(
          token,
          projectId: project.numericId,
          storySkeleton: storySkeletonCtrl.text.trim(),
          adaptationStrategy: adaptationStrategyCtrl.text.trim(),
          script: draftPackets
              .map(
                (draft) => <String, dynamic>{
                  'name': draft.name,
                  'content': draft.content,
                },
              )
              .toList(growable: false),
        );
        if (status != 200) {
          throw Exception('写入失败，HTTP $status');
        }
        await loadPlan(setLocalState);
        if (!ctx.mounted) return;
        setLocalState(() {
          draftPackets = buildScriptDraftPackets(
            events: eventRows,
            novels: novelRows,
            storySkeleton: storySkeletonCtrl.text,
            adaptationStrategy: adaptationStrategyCtrl.text,
            existingScripts:
                planData?.scriptRows ?? const <ScriptAgentPlanScriptRow>[],
          );
          guidanceRows = buildStructuredRewriteGuidance(
            events: eventRows,
            novels: novelRows,
            storySkeleton: storySkeletonCtrl.text,
            adaptationStrategy: adaptationStrategyCtrl.text,
            existingScripts:
                planData?.scriptRows ?? const <ScriptAgentPlanScriptRow>[],
          );
          infoLine = '已写入 ${draftPackets.length} 份剧本初稿；同名剧本已覆盖更新，缺失剧本已自动创建。';
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setLocalState(() {
          localBusy = false;
          infoLine = '写入剧本初稿失败：$e';
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
                  eventSummaryLine: summarizePlanEventCoverage(
                    events: eventRows,
                    novels: novelRows,
                  ),
                  draftSummaryLine: summarizeScriptDraftPackets(draftPackets),
                  draftPackets: draftPackets,
                  guidanceSummaryLine: summarizeStructuredRewriteGuidance(
                    guidanceRows,
                  ),
                  guidanceRows: guidanceRows,
                ),
                callbacks: ProjectScriptPlanWorkbenchViewCallbacks(
                  onReload: () => loadPlan(setLocalState),
                  onSave: () => savePlan(setLocalState),
                  onFillStorySkeletonSeed: () =>
                      fillStorySkeletonSeed(setLocalState),
                  onFillAdaptationStrategySeed: () =>
                      fillAdaptationStrategySeed(setLocalState),
                  onGenerateDraftPackets: () =>
                      generateDraftPackets(setLocalState),
                  onWriteDraftPackets: () => writeDraftPackets(setLocalState),
                  onGenerateGuidance: () => generateGuidance(setLocalState),
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
