import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  const projects = <TaskCenterProjectItem>[
    TaskCenterProjectItem(
      numericId: 9,
      name: '古风短剧',
      projectUuid: '550e8400-e29b-41d4-a716-446655440009',
    ),
    TaskCenterProjectItem(
      numericId: 12,
      name: '都市剧情',
      projectUuid: '550e8400-e29b-41d4-a716-446655440012',
    ),
  ];

  test('task center project selection keeps explicit numeric scope', () {
    final selection = resolveTaskCenterProjectSelection(
      projects: projects,
      projectIdText: '12',
      projectUuid: '550e8400-e29b-41d4-a716-446655440012',
    );

    expect(selection.projectId, 12);
    expect(selection.projectUuid, '550e8400-e29b-41d4-a716-446655440012');
    expect(selection.resolvedFromUuid, isFalse);
  });

  test('task center project selection resolves numeric scope from uuid', () {
    final selection = resolveTaskCenterProjectSelection(
      projects: projects,
      projectIdText: '',
      projectUuid: '550e8400-e29b-41d4-a716-446655440009',
    );

    expect(selection.projectId, 9);
    expect(selection.projectUuid, '550e8400-e29b-41d4-a716-446655440009');
    expect(selection.resolvedFromUuid, isTrue);
  });

  test('task center project selection preserves uuid-only scope when unresolved', () {
    final selection = resolveTaskCenterProjectSelection(
      projects: projects,
      projectIdText: '',
      projectUuid: '550e8400-e29b-41d4-a716-446655440099',
    );

    expect(selection.projectId, isNull);
    expect(selection.projectUuid, '550e8400-e29b-41d4-a716-446655440099');
    expect(selection.resolvedFromUuid, isTrue);
  });
}
