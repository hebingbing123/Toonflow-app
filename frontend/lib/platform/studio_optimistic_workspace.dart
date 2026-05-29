import '../rust_api/workspaces/workspaces.dart';

WorkspaceListItem studioWorkspaceListItemWithArchive(
  WorkspaceListItem row, {
  required bool archived,
}) {
  final workspace = row.workspace;
  return WorkspaceListItem(
    workspace: WorkspaceResponse(
      id: workspace.id,
      ownerUserId: workspace.ownerUserId,
      name: workspace.name,
      workspaceType: workspace.workspaceType,
      metadata: workspace.metadata,
      archivedAt: archived ? DateTime.now().toUtc() : null,
      createdAt: workspace.createdAt,
      updatedAt: workspace.updatedAt,
    ),
    role: row.role,
  );
}

List<WorkspaceListItem> studioReplaceWorkspaceInList(
  List<WorkspaceListItem> items,
  WorkspaceListItem updated,
) {
  final next = List<WorkspaceListItem>.from(items);
  final index = next.indexWhere(
    (row) => row.workspace.id == updated.workspace.id,
  );
  if (index >= 0) {
    next[index] = updated;
  }
  return next;
}
