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
          _buildProjectEditorNovelsAndEventsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            dialogState: dialogState,
          ),
          const SizedBox(height: 12),
          _buildProjectEditorAssetsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            dialogState: dialogState,
            scriptList: scriptList,
          ),
          const SizedBox(height: 12),
          _buildProjectEditorScriptsSection(
            ctx: ctx,
            setDialogState: setDialogState,
            token: token,
            p: p,
            dialogState: dialogState,
            scriptList: scriptList,
          ),
        ],
      ),
    );
  }
}
