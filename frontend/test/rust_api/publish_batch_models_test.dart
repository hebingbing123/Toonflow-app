import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/platform/studio_optimistic_publish_draft.dart';
import 'package:openflow_app/rust_api/project/publish_models.dart';

PublishDraftRow _draft({required String id, String? scheduledAt}) {
  return PublishDraftRow(
    id: id,
    projectId: 'project',
    title: 'Draft',
    description: '',
    tags: const <String>[],
    draftStatus: 'editing',
    scheduledAt: scheduledAt,
  );
}

void main() {
  test('PublishBatchArchiveResponse parses archived + failed from OpenAPI', () {
    final response = PublishBatchArchiveResponse.fromJson(<String, dynamic>{
      'archived': 2,
      'failed': <Map<String, dynamic>>[
        <String, dynamic>{
          'draft_id': '00000000-0000-0000-0000-000000000099',
          'reason': 'Draft not found',
        },
      ],
    });
    expect(response.archivedCount, 2);
    expect(response.failed, hasLength(1));
    expect(response.failed.first.draftId, contains('99'));
    expect(response.failed.first.reason, 'Draft not found');
  });

  test('PublishBatchPublishResponse parses enqueued + failed from OpenAPI', () {
    final response = PublishBatchPublishResponse.fromJson(<String, dynamic>{
      'enqueued': 3,
      'failed': <Map<String, dynamic>>[
        <String, dynamic>{
          'draft_id': '00000000-0000-0000-0000-0000000000aa',
          'reason': 'Draft not found',
        },
      ],
    });
    expect(response.enqueued, 3);
    expect(response.successCount, 3);
    expect(response.failedCount, 1);
    expect(response.failed.single.draftId, contains('aa'));
  });

  test('studioPublishDraftRowWithScheduledAt updates schedule only', () {
    final row = _draft(id: 'd1');
    final next = studioPublishDraftRowWithScheduledAt(
      row,
      '2026-05-29T12:00:00.000Z',
    );
    expect(next.scheduledAt, '2026-05-29T12:00:00.000Z');
    expect(next.id, row.id);
  });
}
