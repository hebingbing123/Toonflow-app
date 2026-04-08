part of '../home_page.dart';

extension _HomePageProjectEditorDialogContent on _HomePageState {
  Widget _buildProjectEditorDialogContent({
    required BuildContext ctx,
    required StateSetter setDialogState,
    required String token,
    required ProjectRow p,
    required ProjectDetail detail,
    required TextEditingController nameCtrl,
    required TextEditingController introCtrl,
    required List<ScriptBrief> scriptList,
    required List<ProjectStats?> statsRef,
    required List<ListAssetsResponse?> assetsRef,
    required List<ListNovelsResponse?> novelsRef,
    required List<ListNovelEventsResponse?> novelEventsRef,
    required List<ListAssetsResponse?> assetsForScriptRef,
    required List<int?> assetsFilterScriptLegacyId,
    required List<bool> assetsLoading,
    required List<bool> assetsScriptFilterLoading,
    required List<bool> assetsBusy,
    required List<bool> novelsLoading,
    required List<bool> novelsBusy,
    required List<bool> novelEventsLoading,
    required List<bool> scriptProbeBusy,
    required List<bool> saving,
    required List<bool> generalLegacyBusy,
    required List<bool> tasksLegacyBusy,
    required List<bool> projectLegacyBusy,
    required Future<void> Function() reloadAssetsAndStats,
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
              style: Theme.of(
                ctx,
              ).textTheme.bodySmall?.copyWith(
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
    );
  }
}
