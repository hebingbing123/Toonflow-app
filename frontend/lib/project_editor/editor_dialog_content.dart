part of '../../home_page.dart';

extension _HomePageProjectEditorDialogContent on _HomePageState {
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
}
