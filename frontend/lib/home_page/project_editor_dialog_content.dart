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
          _buildProjectNovelsSection(
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
          _buildProjectAssetsSection(
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
