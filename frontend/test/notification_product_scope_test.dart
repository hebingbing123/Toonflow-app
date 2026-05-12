import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/notifications/product_scope.dart';
import 'package:openflow_app/rust_api.dart';

NotificationRecordV1 _notification({
  String? workspaceId,
  String? projectId,
  int? projectNumericId,
  Map<String, dynamic> payload = const <String, dynamic>{},
  String? linkPath,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return NotificationRecordV1(
    id: 1,
    userId: 'user-1',
    workspaceId: workspaceId,
    projectId: projectId,
    projectNumericId: projectNumericId,
    jobId: 'job-1',
    notificationType: 'job_failed',
    title: 'title',
    message: 'message',
    linkPath: linkPath,
    payload: payload,
    filePath: null,
    changedAt: null,
    readAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('resolveNotificationProductScope prefers explicit query params', () {
    final scope = resolveNotificationProductScope(
      _notification(
        workspaceId: 'workspace-record',
        projectId: 'project-record',
        projectNumericId: 7,
        payload: <String, dynamic>{
          'workspaceId': 'workspace-payload',
          'projectId': 'project-payload',
          'projectNumericId': 8,
          'scriptNumericId': 11,
        },
      ),
      Uri.parse(
        '/product/projects?workspaceId=workspace-query&projectUuid=project-query&projectNumericId=9&scriptNumericId=12',
      ),
    );

    expect(scope.workspaceId, 'workspace-query');
    expect(scope.projectUuid, 'project-query');
    expect(scope.projectNumericId, 9);
    expect(scope.scriptNumericId, 12);
  });

  test('resolveNotificationProductScope falls back to notification record', () {
    final scope = resolveNotificationProductScope(
      _notification(
        workspaceId: 'workspace-record',
        projectId: 'project-record',
        projectNumericId: 7,
      ),
      Uri.parse('/product/jobs?jobId=job-1'),
    );

    expect(scope.workspaceId, 'workspace-record');
    expect(scope.projectUuid, 'project-record');
    expect(scope.projectNumericId, 7);
    expect(scope.scriptNumericId, isNull);
  });

  test('resolveNotificationProductScope falls back to payload values', () {
    final scope = resolveNotificationProductScope(
      _notification(
        payload: <String, dynamic>{
          'workspaceId': 'workspace-payload',
          'projectId': 'project-payload',
          'projectNumericId': 15,
          'scriptNumericId': '21',
        },
      ),
      Uri.parse('/product/quality'),
    );

    expect(scope.workspaceId, 'workspace-payload');
    expect(scope.projectUuid, 'project-payload');
    expect(scope.projectNumericId, 15);
    expect(scope.scriptNumericId, 21);
    expect(scope.hasProjectScope, isTrue);
  });
}
