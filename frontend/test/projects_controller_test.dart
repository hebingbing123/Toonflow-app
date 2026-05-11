import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/projects/controller.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('agentMemoryProjectRefFromRow prefers non-empty project uuid', () {
    expect(
      agentMemoryProjectRefFromRow(
        const ProjectRow(
          id: ' project-uuid ',
          numericId: 42,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ),
      (projectUuid: 'project-uuid', projectId: null),
    );
  });

  test('agentMemoryProjectRefFromRow falls back to numeric id when uuid is empty', () {
    expect(
      agentMemoryProjectRefFromRow(
        const ProjectRow(
          id: '   ',
          numericId: 42,
          projectAccessMode: 'inherited',
          projectAccessRole: 'member',
        ),
      ),
      (projectUuid: null, projectId: 42),
    );
  });
}
