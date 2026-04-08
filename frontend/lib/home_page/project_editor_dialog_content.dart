part of '../home_page.dart';

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
            generalLegacyBusy: dialogState.generalLegacyBusy,
            tasksLegacyBusy: dialogState.tasksLegacyBusy,
            projectLegacyBusy: dialogState.projectLegacyBusy,
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
          const SizedBox(height: 12),
          _buildProjectNovelProbeSection(
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
            assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
            reloadAssetsAndStats: () =>
                dialogState.reloadAssetsAndStats(token, p.legacyId),
          ),
          const SizedBox(height: 12),
          _buildProjectAssetsProbeSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            scriptList: scriptList,
            assetsRef: dialogState.assetsRef,
            assetsForScriptRef: dialogState.assetsForScriptRef,
            assetsFilterScriptLegacyId: dialogState.assetsFilterScriptLegacyId,
            assetsLoading: dialogState.assetsLoading,
            assetsScriptFilterLoading: dialogState.assetsScriptFilterLoading,
            assetsBusy: dialogState.assetsBusy,
            reloadAssetsAndStats: () =>
                dialogState.reloadAssetsAndStats(token, p.legacyId),
          ),
          const SizedBox(height: 12),
          _buildProjectScriptsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            saving: dialogState.saving,
            scriptProbeBusy: dialogState.scriptProbeBusy,
            scriptList: scriptList,
            statsRef: dialogState.statsRef,
          ),
        ],
      ),
    );
  }
}
