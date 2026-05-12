import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/shell/product_scope_label.dart';

void main() {
  const projects = <ProjectRow>[
    ProjectRow(
      id: 'project-uuid-7',
      workspaceId: 'workspace-1',
      numericId: 7,
      name: 'Palace Episode',
      projectAccessMode: 'inherited',
      projectAccessRole: 'member',
    ),
    ProjectRow(
      id: 'project-uuid-9',
      workspaceId: 'workspace-1',
      numericId: 9,
      name: 'Second Project',
      projectAccessMode: 'inherited',
      projectAccessRole: 'member',
    ),
  ];

  test('product workspace label prefers numeric project scope when present', () {
    expect(
      productWorkspaceProjectLabel(
        projects: projects,
        projectNumericId: 7,
        projectUuid: 'project-uuid-9',
      ),
      'Project #7 · Palace Episode',
    );
  });

  test('product workspace label resolves project from uuid-only scope', () {
    expect(
      productWorkspaceProjectLabel(
        projects: projects,
        projectNumericId: null,
        projectUuid: ' project-uuid-9 ',
      ),
      'Project #9 · Second Project',
    );
  });

  test('product workspace label falls back to raw uuid when project list misses', () {
    expect(
      productWorkspaceProjectLabel(
        projects: projects,
        projectNumericId: null,
        projectUuid: 'project-uuid-missing',
      ),
      'Project UUID · project-uuid-missing',
    );
  });

  test('product workspace label falls back to numeric id when row missing', () {
    expect(
      productWorkspaceProjectLabel(
        projects: const <ProjectRow>[],
        projectNumericId: 42,
        projectUuid: null,
      ),
      'Project #42',
    );
  });
}
