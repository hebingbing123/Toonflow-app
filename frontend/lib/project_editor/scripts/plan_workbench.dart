part of '../../home_page.dart';

extension _HomePageProjectEditorScriptPlanWorkbench on _HomePageState {
  Future<void> _openProjectScriptPlanWorkbenchDialog({
    required BuildContext ctx,
    required String token,
    required ProjectRow project,
  }) async {
    final l10n = AppLocalizations.of(ctx)!;
    final storySkeletonCtrl = TextEditingController();
    final adaptationStrategyCtrl = TextEditingController();
    ScriptAgentPlanData? planData;
    List<NovelEventRow> eventRows = const <NovelEventRow>[];
    List<NovelRow> novelRows = const <NovelRow>[];
    List<ScriptDraftPacket> draftPackets = const <ScriptDraftPacket>[];
    List<StructuredRewriteGuidance> guidanceRows =
        const <StructuredRewriteGuidance>[];
    var localBusy = false;
    var infoLine = l10n.projectScriptPlanWorkbenchLoadingInitial;

    Future<void> loadPlan(StateSetter setLocalState) async {
      setLocalState(() {
        localBusy = true;
        infoLine = l10n.projectScriptPlanWorkbenchRefreshingPlan;
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
          infoLine = l10n.projectScriptPlanWorkbenchLoadedPlan(
            next.planId?.toString() ?? 'new',
            next.scriptRows.length,
          );
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setLocalState(() {
          infoLine = l10n.projectScriptPlanWorkbenchLoadFailed(describeUserVisibleApiError(l10n, e));
        });
      } finally {
        if (ctx.mounted) {
          setLocalState(() => localBusy = false);
        }
      }
    }

    void fillStorySkeletonSeed(StateSetter setLocalState) {
      final seed = buildStorySkeletonSeedFromEvents(
        l10n: l10n,
        events: eventRows,
        novels: novelRows,
      );
      setLocalState(() {
        storySkeletonCtrl.text = seed;
        infoLine = l10n.projectScriptPlanWorkbenchSkeletonDraftGenerated;
      });
    }

    void fillAdaptationStrategySeed(StateSetter setLocalState) {
      final seed = buildAdaptationStrategySeedFromEvents(
        l10n: l10n,
        events: eventRows,
        novels: novelRows,
      );
      setLocalState(() {
        adaptationStrategyCtrl.text = seed;
        infoLine = l10n.projectScriptPlanWorkbenchStrategyDraftGenerated;
      });
    }

    void generateDraftPackets(StateSetter setLocalState) {
      final nextDrafts = buildScriptDraftPackets(
        l10n: l10n,
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
            ? l10n.projectScriptPlanWorkbenchNoDraftsNoEvents
            : l10n.projectScriptPlanWorkbenchDraftsGenerated(nextDrafts.length);
      });
    }

    void generateGuidance(StateSetter setLocalState) {
      final nextGuidance = buildStructuredRewriteGuidance(
        l10n: l10n,
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
            ? l10n.projectScriptPlanWorkbenchNoGuidanceNoEvents
            : l10n.projectScriptPlanWorkbenchGuidanceGenerated(nextGuidance.length);
      });
    }

    Future<void> savePlan(StateSetter setLocalState) async {
      setLocalState(() {
        localBusy = true;
        infoLine = l10n.projectScriptPlanWorkbenchSavingPlan;
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
          throw Exception(l10n.projectScriptPlanWorkbenchSaveFailedHttp(status));
        }
        await loadPlan(setLocalState);
        if (!ctx.mounted) return;
        setLocalState(() {
          infoLine = l10n.projectScriptPlanWorkbenchPlanSaved;
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setLocalState(() {
          localBusy = false;
          infoLine = l10n.projectScriptPlanWorkbenchSaveFailed(describeUserVisibleApiError(l10n, e));
        });
      }
    }

    Future<void> writeDraftPackets(StateSetter setLocalState) async {
      if (draftPackets.isEmpty) {
        setLocalState(() {
          infoLine = l10n.projectScriptPlanWorkbenchNeedDraftsFirst;
        });
        return;
      }
      setLocalState(() {
        localBusy = true;
        infoLine = l10n.projectScriptPlanWorkbenchWritingDrafts;
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
          throw Exception(l10n.projectScriptPlanWorkbenchWriteFailedHttp(status));
        }
        await loadPlan(setLocalState);
        if (!ctx.mounted) return;
        setLocalState(() {
          draftPackets = buildScriptDraftPackets(
            l10n: l10n,
            events: eventRows,
            novels: novelRows,
            storySkeleton: storySkeletonCtrl.text,
            adaptationStrategy: adaptationStrategyCtrl.text,
            existingScripts:
                planData?.scriptRows ?? const <ScriptAgentPlanScriptRow>[],
          );
          guidanceRows = buildStructuredRewriteGuidance(
            l10n: l10n,
            events: eventRows,
            novels: novelRows,
            storySkeleton: storySkeletonCtrl.text,
            adaptationStrategy: adaptationStrategyCtrl.text,
            existingScripts:
                planData?.scriptRows ?? const <ScriptAgentPlanScriptRow>[],
          );
          infoLine = l10n.projectScriptPlanWorkbenchDraftsWritten(draftPackets.length);
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setLocalState(() {
          localBusy = false;
          infoLine = l10n.projectScriptPlanWorkbenchWriteDraftsFailed(describeUserVisibleApiError(l10n, e));
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
                    l10n: l10n,
                    events: eventRows,
                    novels: novelRows,
                  ),
                  draftSummaryLine: summarizeScriptDraftPackets(
                    l10n,
                    draftPackets,
                  ),
                  draftPackets: draftPackets,
                  guidanceSummaryLine: summarizeStructuredRewriteGuidance(
                    l10n,
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
