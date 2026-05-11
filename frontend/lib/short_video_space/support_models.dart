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
