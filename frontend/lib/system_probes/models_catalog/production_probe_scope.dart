import '../../rust_api.dart';

typedef ProductionProbeFetchProjects =
    Future<List<ProjectRow>> Function(String token);

class ProductionProbeScope {
  const ProductionProbeScope({required this.projectId, required this.scriptId});

  final int projectId;
  final int scriptId;
}

Future<ProductionProbeScope> resolveProductionProbeScope({
  required String token,
  required String projectIdText,
  required String projectUuidText,
  required String scriptIdText,
  required ProductionProbeFetchProjects fetchProjects,
  int fallbackProjectId = 1,
  int fallbackScriptId = 1,
}) async {
  var projectId = _parsePositiveInt(projectIdText);
  if (projectId == null) {
    final projectUuid = _trimmedNonEmpty(projectUuidText);
    if (projectUuid != null) {
      final projects = await fetchProjects(token);
      for (final project in projects) {
        if (project.id == projectUuid) {
          projectId = project.numericId;
          break;
        }
      }
    }
  }
  return ProductionProbeScope(
    projectId: projectId ?? fallbackProjectId,
    scriptId: _parsePositiveInt(scriptIdText) ?? fallbackScriptId,
  );
}

int? _parsePositiveInt(String raw) {
  final value = int.tryParse(raw.trim());
  if (value == null || value <= 0) {
    return null;
  }
  return value;
}

String? _trimmedNonEmpty(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  return value;
}
