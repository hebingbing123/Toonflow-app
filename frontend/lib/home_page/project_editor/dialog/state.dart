part of '../../../home_page.dart';

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
  final List<int?> assetsFilterScriptLegacyId = <int?>[null];
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
  final List<bool> generalLegacyBusy = <bool>[false];
  final List<bool> tasksLegacyBusy = <bool>[false];
  final List<bool> projectLegacyBusy = <bool>[false];

  Future<void> reloadAssetsAndStats(
    String token,
    String projectId,
    int projectLegacyId,
  ) async {
    try {
      assetsRef[0] = await fetchProjectAssetsByProjectId(token, projectId);
    } catch (_) {
      assetsRef[0] = null;
    }

    final scriptLegacyId = assetsFilterScriptLegacyId[0];
    if (scriptLegacyId != null) {
      try {
        assetsForScriptRef[0] = await fetchProjectAssetsByProjectId(
          token,
          projectId,
          scriptLegacyId: scriptLegacyId,
        );
      } catch (_) {
        assetsForScriptRef[0] = null;
      }
    }

    try {
      statsRef[0] = await fetchProjectStatsByProjectId(token, projectId);
    } catch (_) {}

    try {
      novelsRef[0] = await fetchProjectNovelsByLegacyId(token, projectLegacyId);
    } catch (_) {
      novelsRef[0] = null;
    }

    try {
      novelEventsRef[0] = await fetchProjectNovelEventsByLegacyId(
        token,
        projectLegacyId,
      );
    } catch (_) {
      novelEventsRef[0] = null;
    }
  }
}
