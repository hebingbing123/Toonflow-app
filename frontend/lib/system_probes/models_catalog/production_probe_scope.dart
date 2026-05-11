import '../../rust_api.dart';

typedef ProductionProbeFetchProjects =
    Future<List<ProjectRow>> Function(String token);
typedef ProductionProbeFetchAssets =
    Future<ListAssetsResponse> Function(
      String token,
      String projectUuid, {
      int? scriptNumericId,
    });
typedef ProductionProbeFetchStoryboards =
    Future<List<StoryboardRow>> Function(
      String token,
      String projectUuid,
      int scriptNumericId,
    );

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

class ProductionProbeResourceScope {
  const ProductionProbeResourceScope({
    required this.projectUuid,
    required this.assetId,
    required this.storyboardId,
  });

  final String? projectUuid;
  final int assetId;
  final int storyboardId;
}

Future<ProductionProbeResourceScope> resolveProductionProbeResourceScope({
  required String token,
  required ProductionProbeScope scope,
  required String projectUuidText,
  required ProductionProbeFetchProjects fetchProjects,
  required ProductionProbeFetchAssets fetchAssets,
  required ProductionProbeFetchStoryboards fetchStoryboards,
  int fallbackAssetId = 1,
  int fallbackStoryboardId = 1,
}) async {
  final projectUuid = await _resolveProjectUuid(
    token: token,
    scope: scope,
    projectUuidText: projectUuidText,
    fetchProjects: fetchProjects,
  );
  if (projectUuid == null) {
    return ProductionProbeResourceScope(
      projectUuid: null,
      assetId: fallbackAssetId,
      storyboardId: fallbackStoryboardId,
    );
  }

  final assetId = await _resolveAssetId(
    token: token,
    projectUuid: projectUuid,
    scriptId: scope.scriptId,
    fetchAssets: fetchAssets,
    fallbackAssetId: fallbackAssetId,
  );
  final storyboardId = await _resolveStoryboardId(
    token: token,
    projectUuid: projectUuid,
    scriptId: scope.scriptId,
    fetchStoryboards: fetchStoryboards,
    fallbackStoryboardId: fallbackStoryboardId,
  );

  return ProductionProbeResourceScope(
    projectUuid: projectUuid,
    assetId: assetId,
    storyboardId: storyboardId,
  );
}

Future<String?> _resolveProjectUuid({
  required String token,
  required ProductionProbeScope scope,
  required String projectUuidText,
  required ProductionProbeFetchProjects fetchProjects,
}) async {
  final explicitProjectUuid = _trimmedNonEmpty(projectUuidText);
  if (explicitProjectUuid != null) {
    return explicitProjectUuid;
  }
  try {
    final projects = await fetchProjects(token);
    for (final project in projects) {
      if (project.numericId == scope.projectId) {
        return project.id;
      }
    }
  } catch (_) {}
  return null;
}

Future<int> _resolveAssetId({
  required String token,
  required String projectUuid,
  required int scriptId,
  required ProductionProbeFetchAssets fetchAssets,
  required int fallbackAssetId,
}) async {
  try {
    final scopedAssets = await fetchAssets(
      token,
      projectUuid,
      scriptNumericId: scriptId,
    );
    final scopedAssetId = _firstAssetId(scopedAssets);
    if (scopedAssetId != null) {
      return scopedAssetId;
    }
  } catch (_) {}
  try {
    final projectAssets = await fetchAssets(token, projectUuid);
    final projectAssetId = _firstAssetId(projectAssets);
    if (projectAssetId != null) {
      return projectAssetId;
    }
  } catch (_) {}
  return fallbackAssetId;
}

Future<int> _resolveStoryboardId({
  required String token,
  required String projectUuid,
  required int scriptId,
  required ProductionProbeFetchStoryboards fetchStoryboards,
  required int fallbackStoryboardId,
}) async {
  try {
    final storyboards = await fetchStoryboards(token, projectUuid, scriptId);
    final storyboardId = _firstStoryboardId(storyboards);
    if (storyboardId != null) {
      return storyboardId;
    }
  } catch (_) {}
  return fallbackStoryboardId;
}

int? _firstAssetId(ListAssetsResponse response) {
  if (response.items.isEmpty) {
    return null;
  }
  return response.items.first.numericId;
}

int? _firstStoryboardId(List<StoryboardRow> storyboards) {
  if (storyboards.isEmpty) {
    return null;
  }
  return storyboards.first.numericId;
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
