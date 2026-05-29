import 'package:flutter/foundation.dart';

/// Active workspace id propagated to API calls (`X-Workspace-Id`).
class StudioWorkspaceScope extends ChangeNotifier {
  StudioWorkspaceScope._();
  static final StudioWorkspaceScope instance = StudioWorkspaceScope._();

  String? _workspaceId;
  int _generation = 0;

  String? get workspaceId => _workspaceId;
  int get generation => _generation;

  void setWorkspaceId(String? id) {
    final trimmed = id?.trim();
    if (trimmed == _workspaceId || (trimmed?.isEmpty ?? true) && _workspaceId == null) {
      return;
    }
    _workspaceId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _generation++;
    notifyListeners();
  }
}

Map<String, String> studioWorkspaceScopeHeaders() {
  final id = StudioWorkspaceScope.instance.workspaceId;
  if (id == null || id.isEmpty) {
    return const <String, String>{};
  }
  return <String, String>{'X-Workspace-Id': id};
}

Map<String, String> studioAuthorizedHeaders(String accessToken) {
  return <String, String>{
    'Authorization': 'Bearer $accessToken',
    ...studioWorkspaceScopeHeaders(),
  };
}
