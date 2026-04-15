import 'package:flutter/material.dart';

import '../../rust_api.dart';

typedef ProjectsAccessTokenProvider = String? Function();
typedef ProjectsErrorSink = void Function(String? error);

class ProjectsController extends ChangeNotifier {
  ProjectsController({
    required ProjectsAccessTokenProvider accessTokenProvider,
    required ProjectsErrorSink onErrorChanged,
  }) : _accessTokenProvider = accessTokenProvider,
       _onErrorChanged = onErrorChanged;

  final ProjectsAccessTokenProvider _accessTokenProvider;
  final ProjectsErrorSink _onErrorChanged;

  bool loadingProjects = false;
  bool loadingProjectsSummary = false;
  bool loadingArtStyles = false;
  bool creatingProject = false;
  bool loadingAgentMemory = false;
  List<ProjectRow>? projects;
  List<ArtStyleRow>? artStyles;
  String? projectsSummaryLine;
  String? artStylesLine;
  String? agentMemoryBody;

  String? get _accessToken => _accessTokenProvider();

  void _setError(String? error) {
    _onErrorChanged(error);
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
    notifyListeners();
  }

  Future<bool> createEmptyProject() async {
    final token = _accessToken;
    if (token == null) return false;
    creatingProject = true;
    _setError(null);
    notifyListeners();
    try {
      await createProject(token);
      await loadProjects();
      return true;
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
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
      _setError(
        'Load projects first (agent memory needs a project numeric ID).',
      );
      return;
    }
    final numericId = currentProjects.first.numericId;
    loadingAgentMemory = true;
    agentMemoryBody = null;
    _setError(null);
    notifyListeners();
    try {
      final rows = await queryAgentMemory(
        token,
        projectId: numericId,
        agentType: 'scriptAgent',
      );
      var appendBit = '';
      try {
        final id = await appendAgentMemory(
          token,
          projectId: numericId,
          agentType: 'scriptAgent',
          content: '[flutter probe] ${DateTime.now().toIso8601String()}',
        );
        final short = id.length > 8 ? '${id.substring(0, 8)}…' : id;
        appendBit = ' · append id=$short';
      } on RustApiException catch (e) {
        appendBit = ' · append -> ${e.statusCode}';
      }
      agentMemoryBody =
          '${rows.length} message(s) for project $numericId$appendBit';
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingAgentMemory = false;
      notifyListeners();
    }
  }

  Future<void> loadProjects() async {
    final token = _accessToken;
    if (token == null) return;
    loadingProjects = true;
    projects = null;
    _setError(null);
    notifyListeners();
    try {
      projects = await fetchProjects(token);
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingProjects = false;
      notifyListeners();
    }
  }

  Future<void> loadProjectsSummary() async {
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
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingProjectsSummary = false;
      notifyListeners();
    }
  }

  Future<void> loadArtStyles() async {
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
    } on RustApiException catch (e) {
      _setError(e.toString());
    } catch (e) {
      _setError(e.toString());
    } finally {
      loadingArtStyles = false;
      notifyListeners();
    }
  }
}
