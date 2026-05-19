import '../l10n/app_localizations.dart';
import '../rust_api.dart';

ProjectRow? scopedProjectFromProjects(
  List<ProjectRow>? projects, {
  int? projectNumericId,
  String? projectUuid,
}) {
  if (projects == null || projects.isEmpty) {
    return null;
  }
  if (projectNumericId != null) {
    for (final project in projects) {
      if (project.numericId == projectNumericId) {
        return project;
      }
    }
  }
  final normalizedUuid = projectUuid?.trim();
  if (normalizedUuid == null || normalizedUuid.isEmpty) {
    return null;
  }
  for (final project in projects) {
    if (project.id == normalizedUuid) {
      return project;
    }
  }
  return null;
}

String? productWorkspaceProjectLabel({
  required AppLocalizations l10n,
  required List<ProjectRow>? projects,
  int? projectNumericId,
  String? projectUuid,
}) {
  final project = scopedProjectFromProjects(
    projects,
    projectNumericId: projectNumericId,
    projectUuid: projectUuid,
  );
  if (project != null) {
    final trimmedName = project.name?.trim();
    final name = trimmedName != null && trimmedName.isNotEmpty
        ? trimmedName
        : l10n.agentMemoryUnnamedProject;
    return l10n.productScopeProjectWithName(project.numericId, name);
  }
  if (projectNumericId != null) {
    return l10n.projectsUnnamedProject(projectNumericId);
  }
  final normalizedUuid = projectUuid?.trim();
  if (normalizedUuid != null && normalizedUuid.isNotEmpty) {
    return l10n.productScopeProjectUuidScoped(normalizedUuid);
  }
  return null;
}
