import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/platform/studio_optimistic_publish_draft.dart';
import 'package:openflow_app/rust_api/project/publish_models.dart';

PublishDraftRow _draft() {
  return PublishDraftRow(
    id: 'd1',
    projectId: 'p1',
    title: 'T',
    description: '',
    tags: const <String>[],
    draftStatus: 'ready',
  );
}

void main() {
  test('studioPublishDraftRowWithStatus updates draftStatus', () {
    final next = studioPublishDraftRowWithStatus(_draft(), 'publishing');
    expect(next.draftStatus, 'publishing');
  });
}
