Map<String, dynamic> buildProductionProjectScopeBodyV1({
  required Map<String, dynamic> base,
  int? projectId,
  String? projectUuid,
}) {
  final body = Map<String, dynamic>.from(base);
  final uuid = projectUuid?.trim();
  if (uuid != null && uuid.isNotEmpty) {
    body['projectUuid'] = uuid;
    return body;
  }
  if (projectId != null) {
    body['projectId'] = projectId;
    return body;
  }
  throw ArgumentError('projectUuid or projectId is required');
}
