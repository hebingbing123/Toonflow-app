import '../project_scope.dart';

Map<String, dynamic> buildStoryboardProjectScopeBodyV1({
  required Map<String, dynamic> base,
  int? projectId,
  String? projectUuid,
}) {
  return buildProductionProjectScopeBodyV1(
    base: base,
    projectId: projectId,
    projectUuid: projectUuid,
  );
}
