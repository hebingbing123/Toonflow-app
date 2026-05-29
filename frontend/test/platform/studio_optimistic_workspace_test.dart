import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/notifications/optimistic_templates.dart';
import 'package:openflow_app/platform/studio_optimistic_workspace.dart';
import 'package:openflow_app/rust_api.dart';

WorkspaceListItem _workspaceRow({required String id, bool archived = false}) {
  final stamp = DateTime.utc(2026);
  return WorkspaceListItem(
    workspace: WorkspaceResponse(
      id: id,
      ownerUserId: 'owner',
      name: 'Workspace',
      workspaceType: 'team',
      metadata: const <String, dynamic>{},
      archivedAt: archived ? stamp : null,
      createdAt: stamp,
      updatedAt: stamp,
    ),
    role: 'owner',
  );
}

ContentComplianceClearedTemplateItemV1 _template({required String id}) {
  return ContentComplianceClearedTemplateItemV1(
    id: id,
    label: 'Label',
    description: 'Description',
    policy: const ContentComplianceClearedTemplatePolicyV1(
      globalMinutes: 60,
      stageMinutes: <String, int>{},
    ),
    kind: 'custom',
    canEdit: true,
    canDelete: true,
  );
}

void main() {
  test('studioWorkspaceListItemWithArchive toggles archivedAt', () {
    final row = _workspaceRow(id: 'ws-1');
    final archived = studioWorkspaceListItemWithArchive(row, archived: true);
    expect(archived.workspace.archivedAt, isNotNull);
    final restored = studioWorkspaceListItemWithArchive(archived, archived: false);
    expect(restored.workspace.archivedAt, isNull);
  });

  test('studioReplaceWorkspaceInList replaces matching workspace id', () {
    final rows = <WorkspaceListItem>[
      _workspaceRow(id: 'a'),
      _workspaceRow(id: 'b'),
    ];
    final updated = studioReplaceWorkspaceInList(
      rows,
      studioWorkspaceListItemWithArchive(rows.first, archived: true),
    );
    expect(updated.first.workspace.archivedAt, isNotNull);
    expect(updated.last.workspace.archivedAt, isNull);
  });

  test('studioRemoveComplianceTemplateById removes matching template', () {
    final templates = <ContentComplianceClearedTemplateItemV1>[
      _template(id: 'keep'),
      _template(id: 'drop'),
    ];
    final next = studioRemoveComplianceTemplateById(templates, 'drop');
    expect(next.map((row) => row.id), ['keep']);
  });
}
