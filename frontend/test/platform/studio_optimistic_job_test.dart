import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/notifications/optimistic_read.dart';
import 'package:openflow_app/platform/studio_optimistic_job.dart';
import 'package:openflow_app/rust_api.dart';

JobRow _job({required String id, required String status}) {
  return JobRow(
    numericTaskId: 1,
    id: id,
    ownerUserId: 'u',
    kind: 'export',
    status: status,
    payload: const <String, dynamic>{},
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  test('studioJobRowWithStatus updates status only', () {
    final row = _job(id: 'a', status: 'queued');
    final next = studioJobRowWithStatus(row, 'cancelled');
    expect(next.status, 'cancelled');
    expect(next.id, row.id);
  });

  test('studioReplaceJobInList replaces matching id', () {
    final rows = <JobRow>[_job(id: 'a', status: 'queued')];
    final updated = studioReplaceJobInList(
      rows,
      _job(id: 'a', status: 'cancelled'),
    );
    expect(updated.single.status, 'cancelled');
  });

  test('studioNotificationsMarkAllRead clears unread', () {
    final item = NotificationRecordV1(
      id: 1,
      userId: 'u',
      workspaceId: null,
      projectId: null,
      projectNumericId: null,
      jobId: null,
      notificationType: 'test',
      title: 't',
      message: 'm',
      linkPath: null,
      payload: const <String, dynamic>{},
      filePath: null,
      changedAt: null,
      readAt: null,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final next = studioNotificationsMarkAllRead([item]);
    expect(next.single.isUnread, isFalse);
  });
}
