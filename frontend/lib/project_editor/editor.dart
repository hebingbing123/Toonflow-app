part of '../../home_page.dart';

extension _HomePageProjectEditor on _HomePageState {
  Future<void> _openProjectDetail(ProjectRow p) async {
    final token = _session?.accessToken;
    if (token == null) return;
    final l10n = resolveAppLocalizationsForErrors(context);
    final nameCtrl = TextEditingController(text: p.name ?? '');
    final introCtrl = TextEditingController(text: p.intro ?? '');
    final premiseCtrl = TextEditingController();
    final audienceCtrl = TextEditingController();
    final toneCtrl = TextEditingController();
    final hookCtrl = TextEditingController();
    final visualCtrl = TextEditingController();
    final brandNameCtrl = TextEditingController();
    final brandPromiseCtrl = TextEditingController();
    final visualMotifsCtrl = TextEditingController();
    final forbiddenCtrl = TextEditingController();
    final continuityCtrl = TextEditingController();
    try {
      final detail = await fetchProjectByProjectId(token, p.id);
      ProjectHome? homeSnap;
      try {
        homeSnap = await fetchProjectHomeByProjectId(token, p.id);
      } catch (_) {
        homeSnap = null;
      }
      _StylePackCatalog stylePackCatalog = const _StylePackCatalog(
        artPacks: <_StylePackOption>[],
        storyPacks: <_StylePackOption>[],
      );
      try {
        stylePackCatalog = await _loadProjectStylePackCatalog(token, l10n);
      } catch (_) {
        stylePackCatalog = const _StylePackCatalog(
          artPacks: <_StylePackOption>[],
          storyPacks: <_StylePackOption>[],
        );
      }
      if (!mounted) return;
      nameCtrl.text = detail.project.name ?? '';
      introCtrl.text = detail.project.intro ?? '';
      premiseCtrl.text = homeSnap?.projectBrief?.premise ?? '';
      audienceCtrl.text = homeSnap?.projectBrief?.targetAudience ?? '';
      toneCtrl.text = homeSnap?.projectBrief?.emotionalTone ?? '';
      hookCtrl.text = homeSnap?.projectBrief?.coreHook ?? '';
      visualCtrl.text = homeSnap?.projectBrief?.visualDirection ?? '';
      brandNameCtrl.text = homeSnap?.brandBible?.brandName ?? '';
      brandPromiseCtrl.text = homeSnap?.brandBible?.brandPromise ?? '';
      visualMotifsCtrl.text =
          (homeSnap?.brandBible?.visualMotifs ?? const <String>[]).join('\n');
      forbiddenCtrl.text =
          (homeSnap?.brandBible?.forbiddenElements ?? const <String>[]).join(
            '\n',
          );
      continuityCtrl.text =
          (homeSnap?.brandBible?.continuityRules ?? const <String>[]).join(
            '\n',
          );
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
        initialHome: homeSnap,
        initialStats: statsSnap,
        initialAssets: assetsSnap,
        initialNovels: novelsSnap,
        artStylePackOptions: stylePackCatalog.artPacks,
        storyStylePackOptions: stylePackCatalog.storyPacks,
        selectedArtStylePack: detail.project.artStylePack,
        selectedStoryStylePack: detail.project.storyStylePack,
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
                  premiseCtrl: premiseCtrl,
                  audienceCtrl: audienceCtrl,
                  toneCtrl: toneCtrl,
                  hookCtrl: hookCtrl,
                  visualCtrl: visualCtrl,
                  brandNameCtrl: brandNameCtrl,
                  brandPromiseCtrl: brandPromiseCtrl,
                  visualMotifsCtrl: visualMotifsCtrl,
                  forbiddenCtrl: forbiddenCtrl,
                  continuityCtrl: continuityCtrl,
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
                  premiseCtrl: premiseCtrl,
                  audienceCtrl: audienceCtrl,
                  toneCtrl: toneCtrl,
                  hookCtrl: hookCtrl,
                  visualCtrl: visualCtrl,
                  brandNameCtrl: brandNameCtrl,
                  brandPromiseCtrl: brandPromiseCtrl,
                  visualMotifsCtrl: visualMotifsCtrl,
                  forbiddenCtrl: forbiddenCtrl,
                  continuityCtrl: continuityCtrl,
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      _setErrorFromException(e);
    } finally {
      nameCtrl.dispose();
      introCtrl.dispose();
      premiseCtrl.dispose();
      audienceCtrl.dispose();
      toneCtrl.dispose();
      hookCtrl.dispose();
      visualCtrl.dispose();
      brandNameCtrl.dispose();
      brandPromiseCtrl.dispose();
      visualMotifsCtrl.dispose();
      forbiddenCtrl.dispose();
      continuityCtrl.dispose();
    }
  }
}

class _StylePackOption {
  const _StylePackOption({
    required this.path,
    required this.name,
    required this.description,
    required this.tag,
  });

  final String path;
  final String name;
  final String description;
  final String tag;
}

class _StylePackCatalog {
  const _StylePackCatalog({required this.artPacks, required this.storyPacks});

  final List<_StylePackOption> artPacks;
  final List<_StylePackOption> storyPacks;
}

class _ProjectEditorDialogState {
  _ProjectEditorDialogState({
    ProjectHome? initialHome,
    ProjectStats? initialStats,
    ListAssetsResponse? initialAssets,
    ListNovelsResponse? initialNovels,
    List<_StylePackOption> artStylePackOptions = const <_StylePackOption>[],
    List<_StylePackOption> storyStylePackOptions = const <_StylePackOption>[],
    String? selectedArtStylePack,
    String? selectedStoryStylePack,
  }) : homeRef = <ProjectHome?>[initialHome],
       statsRef = <ProjectStats?>[initialStats],
       assetsRef = <ListAssetsResponse?>[initialAssets],
       novelsRef = <ListNovelsResponse?>[initialNovels],
       artStylePackOptionsRef = <List<_StylePackOption>>[artStylePackOptions],
       storyStylePackOptionsRef = <List<_StylePackOption>>[
         storyStylePackOptions,
       ],
       selectedArtStylePackRef = <String?>[selectedArtStylePack],
       selectedStoryStylePackRef = <String?>[selectedStoryStylePack];

  final List<ProjectHome?> homeRef;
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
  final List<List<_StylePackOption>> artStylePackOptionsRef;
  final List<List<_StylePackOption>> storyStylePackOptionsRef;
  final List<String?> selectedArtStylePackRef;
  final List<String?> selectedStoryStylePackRef;

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

Future<_StylePackCatalog> _loadProjectStylePackCatalog(
  String token,
  AppLocalizations l10n,
) async {
  final visualManual = await fetchVisualManualV1(token);
  final directorManual = await postProjectQueryDirectorManual(token);

  final artPacks =
      visualManual.styles
          .map(
            (style) => _StylePackOption(
              path: style.stylePath,
              name: style.name,
              description: _stylePackDescriptionFromSlots(
                l10n,
                style.data.map((slot) => slot.data),
              ),
              tag: l10n.projectEditorStylePackTagArt,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  final storyPacks =
      directorManual.data
          .map(
            (style) => _StylePackOption(
              path: 'story_skills/${style.directorManual}',
              name: style.name,
              description: _stylePackDescriptionFromSlots(
                l10n,
                style.data.map((slot) => slot.data),
              ),
              tag: l10n.projectEditorStylePackTagStory,
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  return _StylePackCatalog(artPacks: artPacks, storyPacks: storyPacks);
}

String _stylePackDescriptionFromSlots(
  AppLocalizations l10n,
  Iterable<String> slots,
) {
  for (final raw in slots) {
    final lines = raw
        .split('\n')
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty &&
              !line.startsWith('#') &&
              !line.startsWith('|') &&
              !line.startsWith('```') &&
              !line.startsWith('- ') &&
              !line.startsWith('* '),
        );
    for (final line in lines) {
      return line.length <= 48 ? line : '${line.substring(0, 48)}...';
    }
  }
  return l10n.projectEditorStylePackNoDescriptionFallback;
}

// Project detail dialog widgets live in `editor_dialog_*.dart` parts to keep this file small.
