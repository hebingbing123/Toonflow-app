import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/jobs/product_scope.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('jobProductScopeFromRow prefers uuid and numeric project scope fields', () {
    final scope = jobProductScopeFromRow(
      const JobRow(
        numericTaskId: 1,
        id: 'job-1',
        ownerUserId: 'user-1',
        kind: 'assets.generate',
        status: 'queued',
        payload: <String, dynamic>{
          'project_uuid': 'project-uuid-1',
          'project_numeric_id': 7,
          'workspace_id': 'workspace-uuid-1',
          'script_numeric_id': 13,
          'script_uuid': 'script-uuid-1',
        },
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
      ),
    );

    expect(scope.projectUuid, 'project-uuid-1');
    expect(scope.projectNumericId, 7);
    expect(scope.workspaceId, 'workspace-uuid-1');
    expect(scope.scriptNumericId, 13);
    expect(scope.scriptUuid, 'script-uuid-1');
    expect(scope.hasProjectScope, isTrue);
  });

  test('jobProductScopeFromRow falls back to legacy script_id payload', () {
    final scope = jobProductScopeFromRow(
      const JobRow(
        numericTaskId: 2,
        id: 'job-2',
        ownerUserId: 'user-1',
        kind: 'video.generate',
        status: 'running',
        payload: <String, dynamic>{
          'project_numeric_id': '9',
          'script_id': 21,
        },
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
      ),
    );

    expect(scope.projectNumericId, 9);
    expect(scope.scriptNumericId, 21);
    expect(scope.projectUuid, isNull);
    expect(scope.hasProjectScope, isTrue);
  });

  test('jobProductScopeFromRow reports empty scope when project keys absent', () {
    final scope = jobProductScopeFromRow(
      const JobRow(
        numericTaskId: 3,
        id: 'job-3',
        ownerUserId: 'user-1',
        kind: 'personal.job',
        status: 'queued',
        payload: <String, dynamic>{'workspace_id': 'workspace-uuid-1'},
        createdAt: '2026-01-01T00:00:00Z',
        updatedAt: '2026-01-01T00:00:00Z',
      ),
    );

    expect(scope.projectNumericId, isNull);
    expect(scope.projectUuid, isNull);
    expect(scope.workspaceId, 'workspace-uuid-1');
    expect(scope.hasProjectScope, isFalse);
  });
}
