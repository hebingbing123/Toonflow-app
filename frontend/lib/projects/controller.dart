import 'package:flutter/material.dart';

import '../demo/product_demo_mode.dart';
import '../l10n/app_localizations.dart';
import '../../rust_api.dart';

typedef ProjectsAccessTokenProvider = String? Function();
typedef ProjectsErrorSink = void Function(String? error);
typedef ProjectsL10nProvider = AppLocalizations? Function();

({String? projectUuid, int? projectId}) agentMemoryProjectRefFromRow(
  ProjectRow row,
) {
  final projectUuid = row.id.trim();
  if (projectUuid.isNotEmpty) {
    return (projectUuid: projectUuid, projectId: null);
  }
  return (
    projectUuid: null,
    projectId: row.numericId > 0 ? row.numericId : null,
  );
}

class ProjectsController extends ChangeNotifier {
  ProjectsController({
    required ProjectsAccessTokenProvider accessTokenProvider,
    required ProjectsErrorSink onErrorChanged,
    required ProjectsL10nProvider l10nProvider,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged,
       _l10nProvider = l10nProvider;

  final ProjectsAccessTokenProvider _accessTokenProvider;
  final ProjectsErrorSink _onErrorChanged;
  final ProjectsL10nProvider _l10nProvider;

  bool loadingProjects = false;
  bool loadingProjectsSummary = false;
  bool loadingArtStyles = false;
  bool creatingProject = false;
  bool loadingAgentMemory = false;
  bool skipDemoApi = false;
  bool skipDemoMutations = false;
  List<ProjectRow>? projects;
  bool get projectsLoaded => projects != null;
  List<ArtStyleRow>? artStyles;
  String? projectsSummaryLine;
  String? artStylesLine;
  String? agentMemoryBody;

  String? get _accessToken => _accessTokenProvider();
  AppLocalizations? get _l10n => _l10nProvider();

  AppLocalizations get _l10nResolved =>
      _l10n ?? lookupAppLocalizations(const Locale('en'));

  void _setError(String? error) {
    _onErrorChanged(error);
  }

  /// Replaces one project row in the cached list and notifies listeners.
  void applyProjectRow(ProjectRow updated) {
    final list = projects;
    if (list == null) {
      return;
    }
    projects = <ProjectRow>[
      for (final row in list)
        if (row.id == updated.id) updated else row,
    ];
    notifyListeners();
  }

  void reset() {
    loadingProjects = false;
    loadingProjectsSummary = false;
    loadingArtStyles = false;
    creatingProject = false;
    loadingAgentMemory = false;
    projects = null;
    artStyles = null;
    projectsSummaryLine = null;
    artStylesLine = null;
    agentMemoryBody = null;
    skipDemoMutations = false;
    skipDemoApi = false;
    notifyListeners();
  }

  Future<bool> createEmptyProject() async {
    return createProjectWithFields();
  }

  Future<bool> createProjectWithFields([Map<String, dynamic>? fields]) async {
    if (skipDemoMutations) {
      _setError(_l10nResolved.productDemoModeMutationBlocked);
      return false;
    }
    final token = _accessToken;
    if (token == null) return false;
    creatingProject = true;
    _setError(null);
    notifyListeners();
    try {
      await createProject(token, fields: fields);
      await loadProjects();
      return true;
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      creatingProject = false;
      notifyListeners();
    }
    return false;
  }

  Future<void> probeAgentMemory() async {
    final token = _accessToken;
    if (token == null) return;
    final currentProjects = projects;
    if (currentProjects == null || currentProjects.isEmpty) {
      _setError(_l10nResolved.projectsProbeMemoryLoadProjectsFirst);
      return;
    }
    final first = currentProjects.first;
    loadingAgentMemory = true;
    agentMemoryBody = null;
    _setError(null);
    notifyListeners();
    try {
      final projectRef = agentMemoryProjectRefFromRow(first);
      final rows = await queryAgentMemory(
        token,
        projectUuid: projectRef.projectUuid,
        projectId: projectRef.projectId,
        agentType: 'scriptAgent',
      );
      var appendBit = '';
      try {
        final id = await appendAgentMemory(
          token,
          projectUuid: projectRef.projectUuid,
          projectId: projectRef.projectId,
          agentType: 'scriptAgent',
          content: '[flutter probe] ${DateTime.now().toIso8601String()}',
        );
        final short = id.length > 8 ? '${id.substring(0, 8)}…' : id;
        appendBit = ' · append id=$short';
      } on RustApiException catch (e) {
        appendBit = ' · append -> ${e.statusCode}';
      }
      agentMemoryBody =
          '${rows.length} message(s) for project ${first.id}$appendBit';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingAgentMemory = false;
      notifyListeners();
    }
  }

  Future<void> loadProjects() async {
    if (skipDemoApi || ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    final token = _accessToken;
    if (token == null) return;
    if (loadingProjects) return;
    loadingProjects = true;
    // Keep the last list visible while refreshing to avoid empty-state flicker.
    if (!projectsLoaded) {
      projects = null;
    }
    _setError(null);
    notifyListeners();
    try {
      projects = await fetchProjects(token);
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
      // Exit infinite skeleton when the first fetch fails (projects stays null).
      projects ??= const <ProjectRow>[];
    } finally {
      loadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> loadProjectsSummary() async {
    if (skipDemoApi || ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    final token = _accessToken;
    if (token == null) return;
    loadingProjectsSummary = true;
    projectsSummaryLine = null;
    _setError(null);
    notifyListeners();
    try {
      final summary = await fetchProjectsSummary(token);
      projectsSummaryLine =
          'projects=${summary.projectCount} scripts=${summary.scriptCount} storyboards=${summary.storyboardCount} novels=${summary.novelCount} roles=${summary.roleCount} art_styles=${summary.artStyleCount} assets=${summary.assetCount} videos=${summary.videoCount}';
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingProjectsSummary = false;
      notifyListeners();
    }
  }

  Future<void> loadArtStyles() async {
    if (skipDemoApi || ProductDemoMode.instance.shouldSkipLiveApi) {
      return;
    }
    final token = _accessToken;
    if (token == null) return;
    loadingArtStyles = true;
    artStyles = null;
    artStylesLine = null;
    _setError(null);
    notifyListeners();
    try {
      final response = await fetchArtStyles(token);
      var line =
          'total=${response.total} · ${response.items.take(5).map((style) => '#${style.numericId}:${style.name}').join(', ')}${response.items.length > 5 ? '…' : ''}';
      try {
        final probeName =
            '[flutter probe art-style] ${DateTime.now().toIso8601String()}';
        final created = await createArtStyle(token, name: probeName);
        await fetchArtStyleByNumericId(token, numericId: created.numericId);
        await patchArtStyleByNumericId(
          token,
          created.numericId,
          <String, dynamic>{'label': 'probe'},
        );
        await deleteArtStyleByNumericId(token, created.numericId);
        line += ' · create→get→patch→del ok (#${created.numericId})';
      } on RustApiException catch (e) {
        line += ' · crud -> ${e.statusCode}';
      }
      artStyles = response.items;
      artStylesLine = line;
    } catch (e) {
      reportRustOrDescribeApiError(
        e,
        onErrorChanged: _setError,
        l10n: _l10nResolved,
      );
    } finally {
      loadingArtStyles = false;
      notifyListeners();
    }
  }
}
