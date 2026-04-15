part of '../../home_page.dart';

extension _HomePageProjectEditor on _HomePageState {
  Future<void> _openProjectDetail(ProjectRow p) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final nameCtrl = TextEditingController(text: p.name ?? '');
    final introCtrl = TextEditingController(text: p.intro ?? '');
    try {
      final detail = await fetchProjectByProjectId(token, p.id);
      if (!mounted) return;
      nameCtrl.text = detail.project.name ?? '';
      introCtrl.text = detail.project.intro ?? '';
      final scriptList = List<ScriptBrief>.from(detail.scripts);
      ProjectStats? statsSnap;
      try {
        statsSnap = await fetchProjectStatsByProjectId(token, p.id);
      } catch (_) {
        statsSnap = null;
      }
      ListAssetsResponse? assetsSnap;
      try {
        assetsSnap = await fetchProjectAssetsByProjectId(token, p.id);
      } catch (_) {
        assetsSnap = null;
      }
      ListNovelsResponse? novelsSnap;
      try {
        novelsSnap = await fetchProjectNovelsByProjectId(token, p.id);
      } catch (_) {
        novelsSnap = null;
      }
      if (!mounted) return;
      final dialogState = _ProjectEditorDialogState(
        initialStats: statsSnap,
        initialAssets: assetsSnap,
        initialNovels: novelsSnap,
      );
      await showDialog<void>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text(
                  detail.project.name ?? 'project #${detail.project.numericId}',
                ),
                content: _buildProjectEditorDialogContent(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  detail: detail,
                  dialogState: dialogState,
                  nameCtrl: nameCtrl,
                  introCtrl: introCtrl,
                  scriptList: scriptList,
                ),
                actions: _buildProjectEditorDialogActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  dialogState: dialogState,
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

class _ProjectEditorDialogState {
  _ProjectEditorDialogState({
    ProjectStats? initialStats,
    ListAssetsResponse? initialAssets,
    ListNovelsResponse? initialNovels,
  }) : statsRef = <ProjectStats?>[initialStats],
       assetsRef = <ListAssetsResponse?>[initialAssets],
       novelsRef = <ListNovelsResponse?>[initialNovels];

  final List<ProjectStats?> statsRef;
  final List<ListAssetsResponse?> assetsRef;
  final List<ListNovelsResponse?> novelsRef;
  final List<ListNovelEventsResponse?> novelEventsRef =
      <ListNovelEventsResponse?>[null];
  final List<ListAssetsResponse?> assetsForScriptRef = <ListAssetsResponse?>[
    null,
  ];
  final List<int?> assetsFilterScriptNumericId = <int?>[null];
  final List<bool> assetsLoading = <bool>[false];
  final List<bool> assetsScriptFilterLoading = <bool>[false];
  final List<bool> assetsBusy = <bool>[false];
  final List<bool> novelsLoading = <bool>[false];
  final List<bool> novelsBusy = <bool>[false];
  final List<bool> novelEventsLoading = <bool>[false];
  final List<bool> scriptProbeBusy = <bool>[false];
  final List<bool> scriptTaskBusy = <bool>[false];
  final List<String?> scriptTaskLine = <String?>[null];
  final List<bool> saving = <bool>[false];
  final List<bool> generalProbeBusy = <bool>[false];
  final List<bool> tasksProbeBusy = <bool>[false];
  final List<bool> projectProbeBusy = <bool>[false];

  Future<void> reloadAssetsAndStats(
    String token,
    String projectId,
    int projectNumericId,
  ) async {
    assert(projectNumericId > 0);
    try {
      assetsRef[0] = await fetchProjectAssetsByProjectId(token, projectId);
    } catch (_) {
      assetsRef[0] = null;
    }

    final scriptNumericId = assetsFilterScriptNumericId[0];
    if (scriptNumericId != null) {
      try {
        assetsForScriptRef[0] = await fetchProjectAssetsByProjectId(
          token,
          projectId,
          scriptNumericId: scriptNumericId,
        );
      } catch (_) {
        assetsForScriptRef[0] = null;
      }
    }

    try {
      statsRef[0] = await fetchProjectStatsByProjectId(token, projectId);
    } catch (_) {}

    try {
      novelsRef[0] = await fetchProjectNovelsByProjectId(token, projectId);
    } catch (_) {
      novelsRef[0] = null;
    }

    try {
      novelEventsRef[0] = await fetchProjectNovelEventsByProjectId(
        token,
        projectId,
      );
    } catch (_) {
      novelEventsRef[0] = null;
    }
  }
}

extension _HomePageProjectEditorDialog on _HomePageState {
  Widget _buildProjectEditorBasicsSection({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required _ProjectEditorDialogState dialogState,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Name (empty = clear)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: introCtrl,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Intro (empty = clear)'),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('兼容性检查'),
          subtitle: Text(
            '旧 general / project / tasks 接口回归入口，默认折叠',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  ..._buildProjectGeneralProbeActions(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    token: token,
                    p: p,
                    detail: detail,
                    introCtrl: introCtrl,
                    generalProbeBusy: dialogState.generalProbeBusy,
                    tasksProbeBusy: dialogState.tasksProbeBusy,
                    projectProbeBusy: dialogState.projectProbeBusy,
                  ),
                  ..._buildProjectProjectProbeActions(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    token: token,
                    detail: detail,
                    generalProbeBusy: dialogState.generalProbeBusy,
                    tasksProbeBusy: dialogState.tasksProbeBusy,
                    projectProbeBusy: dialogState.projectProbeBusy,
                  ),
                  ..._buildProjectTasksProbeActions(
                    ctx: ctx,
                    setDialogState: setDialogState,
                    token: token,
                    p: p,
                    generalProbeBusy: dialogState.generalProbeBusy,
                    tasksProbeBusy: dialogState.tasksProbeBusy,
                    projectProbeBusy: dialogState.projectProbeBusy,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (dialogState.statsRef[0] != null)
          Text(
            'GET …/stats：剧本 ${dialogState.statsRef[0]!.scriptCount} · 分镜 '
            '${dialogState.statsRef[0]!.storyboardCount} · 小说 ${dialogState.statsRef[0]!.novelCount} · 角色/视频 '
            '${dialogState.statsRef[0]!.roleCount}/${dialogState.statsRef[0]!.videoCount}（视频占位）',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          Text(
            'GET …/stats 未加载',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.outline,
            ),
          ),
      ],
    );
  }

  Widget _buildProjectEditorDialogContent({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required _ProjectEditorDialogState dialogState,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required List<ScriptBrief> scriptList,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildProjectEditorBasicsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            detail: detail,
            nameCtrl: nameCtrl,
            introCtrl: introCtrl,
            dialogState: dialogState,
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('小说与事件', style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 8),
              buildProjectNovelsWorkbenchSection(
                ctx: ctx,
                novels: dialogState.novelsRef[0]?.items ?? const <NovelRow>[],
                novelsLoading: dialogState.novelsLoading,
                novelsBusy: dialogState.novelsBusy,
                assetsBusy: dialogState.assetsBusy,
                assetsLoading: dialogState.assetsLoading,
                assetsScriptFilterLoading:
                    dialogState.assetsScriptFilterLoading,
                openWorkbench: () => openNovelWorkbenchDialog(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  project: p,
                  novelsRef: dialogState.novelsRef,
                  novelsBusy: dialogState.novelsBusy,
                  reloadAssetsAndStats: () => dialogState.reloadAssetsAndStats(
                    token,
                    p.id,
                    p.numericId,
                  ),
                  parseNumericIdList: parseNumericIdList,
                  buildSearchSection: _buildNovelWorkbenchSearchSection,
                  buildCreateSection: _buildNovelWorkbenchCreateSection,
                  buildEditSection: _buildNovelWorkbenchEditSection,
                  buildDeleteSection: _buildNovelWorkbenchDeleteSection,
                  buildSnapshotSection: _buildNovelWorkbenchSnapshotSection,
                ),
                refreshNovels: () async {
                  setDialogState(() => dialogState.novelsLoading[0] = true);
                  try {
                    await dialogState.reloadAssetsAndStats(
                      token,
                      p.id,
                      p.numericId,
                    );
                  } finally {
                    if (ctx.mounted) {
                      setDialogState(
                        () => dialogState.novelsLoading[0] = false,
                      );
                    }
                  }
                },
                generateEvents: () async {
                  setDialogState(() => dialogState.novelsBusy[0] = true);
                  try {
                    final ids =
                        (dialogState.novelsRef[0]?.items ?? const <NovelRow>[])
                            .take(3)
                            .map((e) => e.numericId)
                            .toList();
                    final message = await postNovelEventsGenerateEvents(
                      token,
                      projectNumericId: p.numericId,
                      novelIds: ids,
                    );
                    if (!ctx.mounted) return;
                    await dialogState.reloadAssetsAndStats(
                      token,
                      p.id,
                      p.numericId,
                    );
                    if (!ctx.mounted) return;
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('已为章节 ${ids.join(', ')} 触发事件生成：$message'),
                      ),
                    );
                  } on RustApiException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  } finally {
                    if (ctx.mounted) {
                      setDialogState(() => dialogState.novelsBusy[0] = false);
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              buildProjectNovelEventsWorkbenchSection(
                ctx: ctx,
                events:
                    dialogState.novelEventsRef[0]?.items ??
                    const <NovelEventRow>[],
                novelsLoading: dialogState.novelsLoading,
                novelsBusy: dialogState.novelsBusy,
                novelEventsLoading: dialogState.novelEventsLoading,
                assetsBusy: dialogState.assetsBusy,
                assetsLoading: dialogState.assetsLoading,
                assetsScriptFilterLoading:
                    dialogState.assetsScriptFilterLoading,
                openWorkbench: () => openNovelEventsWorkbenchDialog(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  project: p,
                  novelsRef: dialogState.novelsRef,
                  novelEventsRef: dialogState.novelEventsRef,
                  novelsBusy: dialogState.novelsBusy,
                  novelEventsLoading: dialogState.novelEventsLoading,
                  parseNumericIdList: parseNumericIdList,
                  chapterIndexesToNumericIds: chapterIndexesToNumericIds,
                ),
                refreshEvents: () async {
                  setDialogState(
                    () => dialogState.novelEventsLoading[0] = true,
                  );
                  try {
                    dialogState.novelEventsRef[0] =
                        await fetchProjectNovelEventsByProjectId(token, p.id);
                  } on RustApiException catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(
                        ctx,
                      ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  } finally {
                    if (ctx.mounted) {
                      setDialogState(
                        () => dialogState.novelEventsLoading[0] = false,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
              _buildProjectNovelsCompatibilitySection(
                ctx: ctx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                novelsRef: dialogState.novelsRef,
                novelEventsRef: dialogState.novelEventsRef,
                novelsLoading: dialogState.novelsLoading,
                novelsBusy: dialogState.novelsBusy,
                novelEventsLoading: dialogState.novelEventsLoading,
                assetsBusy: dialogState.assetsBusy,
                assetsLoading: dialogState.assetsLoading,
                assetsScriptFilterLoading:
                    dialogState.assetsScriptFilterLoading,
              ),
            ],
          ),
          const SizedBox(height: 12),
          buildProjectAssetsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            project: p,
            scriptList: scriptList,
            assetsRef: dialogState.assetsRef,
            assetsForScriptRef: dialogState.assetsForScriptRef,
            assetsFilterScriptNumericId:
                dialogState.assetsFilterScriptNumericId,
            assetsLoading: dialogState.assetsLoading,
            assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
            assetsBusy: dialogState.assetsBusy,
            reloadAssetsAndStats: () =>
                dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
            buildImagesSection: () =>
                _buildProjectAssetsImagesCompatibilitySection(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: dialogState.assetsRef,
                  assetsLoading: dialogState.assetsLoading,
                  assetsScriptFilterLoading:
                      dialogState.assetsScriptFilterLoading,
                  assetsBusy: dialogState.assetsBusy,
                  reloadAssetsAndStats: () => dialogState.reloadAssetsAndStats(
                    token,
                    p.id,
                    p.numericId,
                  ),
                ),
            buildPrimaryActions: () => _buildProjectAssetsPrimaryActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              assetsRef: dialogState.assetsRef,
              assetsFilterScriptNumericId:
                  dialogState.assetsFilterScriptNumericId,
              assetsLoading: dialogState.assetsLoading,
              assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
              assetsBusy: dialogState.assetsBusy,
              reloadAssetsAndStats: () =>
                  dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
            ),
            buildRelationActions: () => _buildProjectAssetsRelationActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              scriptList: scriptList,
              assetsRef: dialogState.assetsRef,
              assetsLoading: dialogState.assetsLoading,
              assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
              assetsBusy: dialogState.assetsBusy,
              reloadAssetsAndStats: () =>
                  dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
            ),
            buildQueryActions: () =>
                _buildProjectAssetsQueryCompatibilityActions(
                  ctx: ctx,
                  setDialogState: setDialogState,
                  token: token,
                  p: p,
                  assetsRef: dialogState.assetsRef,
                  assetsFilterScriptNumericId:
                      dialogState.assetsFilterScriptNumericId,
                  assetsLoading: dialogState.assetsLoading,
                  assetsScriptFilterLoading:
                      dialogState.assetsScriptFilterLoading,
                  assetsBusy: dialogState.assetsBusy,
                  reloadAssetsAndStats: () => dialogState.reloadAssetsAndStats(
                    token,
                    p.id,
                    p.numericId,
                  ),
                ),
            openWorkbench: () => openProjectAssetsWorkbenchDialog(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              project: p,
              scriptList: scriptList,
              assetsRef: dialogState.assetsRef,
              assetsForScriptRef: dialogState.assetsForScriptRef,
              assetsFilterScriptNumericId:
                  dialogState.assetsFilterScriptNumericId,
              assetsBusy: dialogState.assetsBusy,
              reloadAssetsAndStats: () =>
                  dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              onCreateAsset: (dialogCtx) => _openCreateAssetDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                assetsBusy: dialogState.assetsBusy,
                reloadAssetsAndStats: () =>
                    dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              ),
              onEditAsset: (dialogCtx) => _openEditAssetDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                assetsRef: dialogState.assetsRef,
                assetsBusy: dialogState.assetsBusy,
                reloadAssetsAndStats: () =>
                    dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              ),
              onDeleteAsset: (dialogCtx) => _openDeleteAssetDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                assetsRef: dialogState.assetsRef,
                assetsBusy: dialogState.assetsBusy,
                reloadAssetsAndStats: () =>
                    dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              ),
              onFilterAssets: (dialogCtx) => _openAssetFilterDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                p: p,
                scriptList: scriptList,
                assetsRef: dialogState.assetsRef,
                assetsForScriptRef: dialogState.assetsForScriptRef,
                assetsFilterScriptNumericId:
                    dialogState.assetsFilterScriptNumericId,
                assetsBusy: dialogState.assetsBusy,
              ),
              onLinkAsset: (dialogCtx) => openProjectAssetLinkDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                project: p,
                scriptList: scriptList,
                assetsRef: dialogState.assetsRef,
                assetsBusy: dialogState.assetsBusy,
                reloadAssetsAndStats: () =>
                    dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
                unlink: false,
              ),
              onUnlinkAsset: (dialogCtx) => openProjectAssetLinkDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                project: p,
                scriptList: scriptList,
                assetsRef: dialogState.assetsRef,
                assetsBusy: dialogState.assetsBusy,
                reloadAssetsAndStats: () =>
                    dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
                unlink: true,
              ),
              onUploadEditImage: (dialogCtx) =>
                  openProjectAssetEditImageUploadDialog(
                    ctx: dialogCtx,
                    setDialogState: setDialogState,
                    token: token,
                    project: p,
                    scriptList: scriptList,
                    assetsBusy: dialogState.assetsBusy,
                  ),
              onUploadClip: (dialogCtx) => openProjectAssetClipUploadDialog(
                ctx: dialogCtx,
                setDialogState: setDialogState,
                token: token,
                project: p,
                assetsBusy: dialogState.assetsBusy,
                reloadAssetsAndStats: () =>
                    dialogState.reloadAssetsAndStats(token, p.id, p.numericId),
              ),
              onOpenGenerationWorkbench: (dialogCtx, preferredAssetNumericId) =>
                  openAssetGenerationWorkbenchDialog(
                    ctx: dialogCtx,
                    setDialogState: setDialogState,
                    token: token,
                    project: p,
                    scriptList: scriptList,
                    assetsRef: dialogState.assetsRef,
                    assetsForScriptRef: dialogState.assetsForScriptRef,
                    assetsFilterScriptNumericId:
                        dialogState.assetsFilterScriptNumericId,
                    assetsBusy: dialogState.assetsBusy,
                    reloadAssetsAndStats: () => dialogState
                        .reloadAssetsAndStats(token, p.id, p.numericId),
                    preferredAssetNumericId: preferredAssetNumericId,
                  ),
              onOpenHistoryWorkbench: (dialogCtx, preferredAssetNumericId) =>
                  openCornerScapeWorkbenchDialog(
                    ctx: dialogCtx,
                    setDialogState: setDialogState,
                    token: token,
                    project: p,
                    assetsBusy: dialogState.assetsBusy,
                    preferredAssetNumericId: preferredAssetNumericId,
                  ),
              onOpenImagesWorkbench: (dialogCtx, preferredAssetNumericId) =>
                  openAssetImagesWorkbenchDialog(
                    ctx: dialogCtx,
                    setDialogState: setDialogState,
                    token: token,
                    project: p,
                    assetsRef: dialogState.assetsRef,
                    assetsBusy: dialogState.assetsBusy,
                    reloadAssetsAndStats: () => dialogState
                        .reloadAssetsAndStats(token, p.id, p.numericId),
                    preferredAssetNumericId: preferredAssetNumericId,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          buildProjectScriptsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            project: p,
            saving: dialogState.saving,
            scriptTaskBusy: dialogState.scriptTaskBusy,
            scriptTaskLine: dialogState.scriptTaskLine,
            scriptList: scriptList,
            statsRef: dialogState.statsRef,
            probeActions: _buildProjectScriptsProbeActions(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              saving: dialogState.saving,
              scriptProbeBusy: dialogState.scriptProbeBusy,
              scriptList: scriptList,
            ),
            openWorkbench: () => openProjectScriptsWorkbenchDialog(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              project: p,
              saving: dialogState.saving,
              scriptTaskBusy: dialogState.scriptTaskBusy,
              scriptTaskLine: dialogState.scriptTaskLine,
              scriptList: scriptList,
              statsRef: dialogState.statsRef,
            ),
            openBatchAddDialog: () => _openBatchAddScriptsDialog(
              ctx: ctx,
              setDialogState: setDialogState,
              token: token,
              p: p,
              saving: dialogState.saving,
              scriptTaskLine: dialogState.scriptTaskLine,
              scriptList: scriptList,
              statsRef: dialogState.statsRef,
            ),
            openScriptEditor: (script) => _openScriptEditor(
              token,
              script.numericId,
              projectId: p.id,
              projectNumericId: p.numericId,
              onScriptTreeMutated: () async {
                final refreshed = await fetchProjectByProjectId(token, p.id);
                if (!ctx.mounted) return;
                setDialogState(() {
                  scriptList
                    ..clear()
                    ..addAll(refreshed.scripts);
                });
                await dialogState.reloadAssetsAndStats(
                  token,
                  p.id,
                  p.numericId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildProjectEditorDialogActions({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required _ProjectEditorDialogState dialogState,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
  }) {
    return [
      TextButton(
        onPressed: dialogState.saving[0] ? null : () => Navigator.of(ctx).pop(),
        child: const Text('Close'),
      ),
      TextButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (c) => AlertDialog(
                    title: const Text('删除项目？'),
                    content: Text(
                      '将删除项目 #${p.numericId} 及关联剧本/分镜（数据库级联），且清除该项目的 agent 记忆。',
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
                setDialogState(() => dialogState.saving[0] = true);
                try {
                  await deleteProjectByProjectId(token, p.id);
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _loadProjects();
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('项目已删除')));
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
        child: const Text('DELETE'),
      ),
      FilledButton(
        onPressed: dialogState.saving[0]
            ? null
            : () async {
                setDialogState(() => dialogState.saving[0] = true);
                try {
                  await updateProjectByProjectId(token, p.id, {
                    'name': nameCtrl.text.isEmpty ? null : nameCtrl.text,
                    'intro': introCtrl.text.isEmpty ? null : introCtrl.text,
                  });
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _loadProjects();
                } on RustApiException catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    setDialogState(() => dialogState.saving[0] = false);
                    ScaffoldMessenger.of(
                      ctx,
                    ).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
        child: Text(dialogState.saving[0] ? '保存中…' : 'PATCH 保存'),
      ),
    ];
  }
}
