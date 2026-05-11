import '../project/index.dart' as project_api;

Future<String> resolveNovelProjectUuid(
  String accessToken, {
  String? projectUuid,
  int? projectNumericId,
}) async {
  final explicitUuid = projectUuid?.trim();
  if (explicitUuid != null && explicitUuid.isNotEmpty) {
    return explicitUuid;
  }
  if (projectNumericId != null && projectNumericId > 0) {
    return project_api.projectIdForNumericId(accessToken, projectNumericId);
  }
  throw ArgumentError('projectUuid or positive projectNumericId is required');
}
