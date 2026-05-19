import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/studio/default_project_scope.dart';

void main() {
  const projects = <ProjectRow>[
    ProjectRow(
      id: 'project-uuid-7',
      numericId: 7,
      name: 'First',
      projectAccessMode: 'inherited',
      projectAccessRole: 'member',
    ),
    ProjectRow(
      id: 'project-uuid-9',
      numericId: 9,
      name: 'Second',
      projectAccessMode: 'inherited',
      projectAccessRole: 'member',
    ),
  ];

  test('resolveDefaultProductScopedProject prefers recent continue row', () {
    expect(
      resolveDefaultProductScopedProject(
        projects: projects,
        recentProjectIds: const <String>['project-uuid-9', 'missing'],
      )?.numericId,
      9,
    );
  });

  test('resolveDefaultProductScopedProject falls back to first project', () {
    expect(
      resolveDefaultProductScopedProject(
        projects: projects,
        recentProjectIds: const <String>['missing'],
      )?.numericId,
      7,
    );
    expect(
      resolveDefaultProductScopedProject(projects: projects)?.numericId,
      7,
    );
  });

  test('resolveDefaultProductScopedProject returns null for empty list', () {
    expect(
      resolveDefaultProductScopedProject(projects: const <ProjectRow>[]),
      isNull,
    );
  });
}
