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
                  detail.project.name ?? 'legacy #${detail.project.legacyId}',
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
