import '../rust_api.dart';

enum ShortVideoNextStepTarget {
  projects,
  scriptWorkspace,
  productionWorkspace,
  tasks,
  quality,
}

class ShortVideoNextStepPlan {
  const ShortVideoNextStepPlan({
    required this.title,
    required this.detail,
    required this.buttonLabel,
    required this.target,
  });

  final String title;
  final String detail;
  final String buttonLabel;
  final ShortVideoNextStepTarget target;
}

class ShortVideoProjectScope {
  const ShortVideoProjectScope({
    required this.projectNumericId,
    required this.projectUuid,
    this.workspaceId,
  });

  final int projectNumericId;
  final String projectUuid;
  final String? workspaceId;

  factory ShortVideoProjectScope.fromProject(ProjectRow project) {
    return ShortVideoProjectScope(
      projectNumericId: project.numericId,
      projectUuid: project.id,
      workspaceId: project.workspaceId,
    );
  }
}

String? resolveShortVideoSelectedProjectId(
  List<ProjectRow> projects, {
  String? currentProjectId,
  String? preferredProjectUuid,
  bool preferScopedProjectUuid = false,
}) {
  if (projects.isEmpty) {
    return null;
  }
  final normalizedCurrentId = currentProjectId?.trim();
  final normalizedPreferredUuid = preferredProjectUuid?.trim();

  ProjectRow? byId(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final project in projects) {
      if (project.id == value) {
        return project;
      }
    }
    return null;
  }

  final scopedMatch = byId(normalizedPreferredUuid);
  final currentMatch = byId(normalizedCurrentId);

  if (preferScopedProjectUuid) {
    return scopedMatch?.id ?? currentMatch?.id ?? projects.first.id;
  }
  return currentMatch?.id ?? scopedMatch?.id ?? projects.first.id;
}
