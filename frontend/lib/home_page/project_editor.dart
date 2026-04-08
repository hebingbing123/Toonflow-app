part of '../home_page.dart';

extension _HomePageProjectEditor on _HomePageState {
  Future<void> _openProjectDetail(ProjectRow p) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final nameCtrl = TextEditingController(text: p.name ?? '');
    final introCtrl = TextEditingController(text: p.intro ?? '');
    try {
      final detail = await fetchProjectByLegacyId(token, p.legacyId);
      if (!mounted) return;
      nameCtrl.text = detail.project.name ?? '';
      introCtrl.text = detail.project.intro ?? '';
      final scriptList = List<ScriptBrief>.from(detail.scripts);
      ProjectStats? statsSnap;
      try {
        statsSnap = await fetchProjectStatsByLegacyId(token, p.legacyId);
      } catch (_) {
        statsSnap = null;
      }
      ListAssetsResponse? assetsSnap;
      try {
        assetsSnap = await fetchProjectAssetsByLegacyId(token, p.legacyId);
      } catch (_) {
        assetsSnap = null;
      }
      ListNovelsResponse? novelsSnap;
      try {
        novelsSnap = await fetchProjectNovelsByLegacyId(token, p.legacyId);
      } catch (_) {
        novelsSnap = null;
      }
      if (!mounted) return;
      final statsRef = <ProjectStats?>[statsSnap];
      final assetsRef = <ListAssetsResponse?>[assetsSnap];
      final novelsRef = <ListNovelsResponse?>[novelsSnap];
      final novelEventsRef = <ListNovelEventsResponse?>[null];
      final assetsForScriptRef = <ListAssetsResponse?>[null];
      final assetsFilterScriptLegacyId = <int?>[null];
      final assetsLoading = <bool>[false];
      final assetsScriptFilterLoading = <bool>[false];
      final assetsBusy = <bool>[false];
      final novelsLoading = <bool>[false];
      final novelsBusy = <bool>[false];
      final novelEventsLoading = <bool>[false];
      final scriptProbeBusy = <bool>[false];
      final generalLegacyBusy = <bool>[false];
      final tasksLegacyBusy = <bool>[false];
      final projectLegacyBusy = <bool>[false];
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              final saving = <bool>[false];
              Future<void> reloadAssetsAndStats() async {
                try {
                  assetsRef[0] = await fetchProjectAssetsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  assetsRef[0] = null;
                }
                final sid = assetsFilterScriptLegacyId[0];
                if (sid != null) {
                  try {
                    assetsForScriptRef[0] = await fetchProjectAssetsByLegacyId(
                      token,
                      p.legacyId,
                      scriptLegacyId: sid,
                    );
                  } catch (_) {
                    assetsForScriptRef[0] = null;
                  }
                }
                try {
                  statsRef[0] = await fetchProjectStatsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {}
                try {
                  novelsRef[0] = await fetchProjectNovelsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  novelsRef[0] = null;
                }
                try {
                  novelEventsRef[0] = await fetchProjectNovelEventsByLegacyId(
                    token,
                    p.legacyId,
                  );
                } catch (_) {
                  novelEventsRef[0] = null;
                }
                if (ctx.mounted) {
                  setDialogState(() {});
                }
              }

              return AlertDialog(
                title: Text(
                  detail.project.name ?? 'legacy #${detail.project.legacyId}',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Name (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: introCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Intro (empty = clear)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildProjectLegacyProbeActions(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        detail: detail,
                        introCtrl: introCtrl,
                        generalLegacyBusy: generalLegacyBusy,
                        tasksLegacyBusy: tasksLegacyBusy,
                        projectLegacyBusy: projectLegacyBusy,
                      ),
                      const SizedBox(height: 12),
                      if (statsRef[0] != null)
                        Text(
                          'GET …/stats：剧本 ${statsRef[0]!.scriptCount} · 分镜 '
                          '${statsRef[0]!.storyboardCount} · 小说 ${statsRef[0]!.novelCount} · 角色/视频 '
                          '${statsRef[0]!.roleCount}/${statsRef[0]!.videoCount}（视频占位）',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        )
                      else
                        Text(
                          'GET …/stats 未加载',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                        ),
                      const SizedBox(height: 12),
                      _buildProjectNovelProbeSection(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        novelsRef: novelsRef,
                        novelEventsRef: novelEventsRef,
                        novelsLoading: novelsLoading,
                        novelsBusy: novelsBusy,
                        novelEventsLoading: novelEventsLoading,
                        assetsBusy: assetsBusy,
                        assetsLoading: assetsLoading,
                        assetsScriptFilterLoading: assetsScriptFilterLoading,
                        reloadAssetsAndStats: reloadAssetsAndStats,
                      ),
                      const SizedBox(height: 12),
                      _buildProjectAssetsProbeSection(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        scriptList: scriptList,
                        assetsRef: assetsRef,
                        assetsForScriptRef: assetsForScriptRef,
                        assetsFilterScriptLegacyId: assetsFilterScriptLegacyId,
                        assetsLoading: assetsLoading,
                        assetsScriptFilterLoading: assetsScriptFilterLoading,
                        assetsBusy: assetsBusy,
                        reloadAssetsAndStats: reloadAssetsAndStats,
                      ),
                      const SizedBox(height: 12),
                      _buildProjectScriptsSection(
                        ctx: ctx,
                        setDialogState: setDialogState,
                        token: token,
                        p: p,
                        saving: saving,
                        scriptProbeBusy: scriptProbeBusy,
                        scriptList: scriptList,
                        statsRef: statsRef,
                      ),
                    ],
                  ),
                ),
                actions: _buildProjectEditorDialogActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  saving: saving,
                  nameCtrl: nameCtrl,
                  introCtrl: introCtrl,
                ),
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
      introCtrl.dispose();
    }
  }
}
