import '../rust_api.dart';

/// Widget-test seed for [ProjectStudioScriptStepPanel] without HTTP.
class ProjectStudioScriptStepDebugContent {
  const ProjectStudioScriptStepDebugContent({
    this.novels,
    this.scripts = const <ScriptBrief>[],
    this.stats,
  });

  final ListNovelsResponse? novels;
  final List<ScriptBrief> scripts;
  final ProjectStats? stats;
}

typedef ProjectStudioScriptStepContentLoader =
    Future<ProjectStudioScriptStepDebugContent> Function(
      String accessToken,
      String projectUuid,
    );
