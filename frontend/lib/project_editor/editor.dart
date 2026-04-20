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

// Project detail dialog widgets were split into `editor_dialog.dart` to keep this file small.
