import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/production/project_scope.dart';
import 'package:openflow_app/rust_api/production/storyboard/project_scope.dart';
import 'package:openflow_app/rust_api/production/workbench/storyboard_media_op.dart';
import 'package:openflow_app/rust_api/production/workbench/video_selection.dart';

void main() {
  test('buildStoryboardProjectScopeBodyV1 prefers projectUuid', () {
    final body = buildStoryboardProjectScopeBodyV1(
      base: <String, dynamic>{'scriptId': 7, 'storyboardId': 13},
      projectId: 42,
      projectUuid: '550e8400-e29b-41d4-a716-446655440000',
    );

    expect(body['projectUuid'], '550e8400-e29b-41d4-a716-446655440000');
    expect(body.containsKey('projectId'), isFalse);
    expect(body['scriptId'], 7);
    expect(body['storyboardId'], 13);
  });

  test('buildStoryboardProjectScopeBodyV1 falls back to numeric projectId', () {
    final body = buildStoryboardProjectScopeBodyV1(
      base: <String, dynamic>{'scriptId': 7},
      projectId: 42,
    );

    expect(body['projectId'], 42);
    expect(body.containsKey('projectUuid'), isFalse);
  });

  test('buildStoryboardProjectScopeBodyV1 rejects empty scope', () {
    expect(
      () => buildStoryboardProjectScopeBodyV1(
        base: const <String, dynamic>{'scriptId': 7},
      ),
      throwsArgumentError,
    );
  });

  test('buildStoryboardMediaOpBodyV1 prefers projectUuid', () {
    final body = buildStoryboardMediaOpBodyV1(
      base: const <String, dynamic>{'op': 'selectVideo', 'scriptId': 7},
      projectId: 42,
      projectUuid: '550e8400-e29b-41d4-a716-446655440000',
    );

    expect(body['projectUuid'], '550e8400-e29b-41d4-a716-446655440000');
    expect(body.containsKey('projectId'), isFalse);
    expect(body['op'], 'selectVideo');
  });

  test('buildWorkbenchVideoSelectionBodyV1 prefers projectUuid', () {
    final body = buildWorkbenchVideoSelectionBodyV1(
      base: const <String, dynamic>{'scriptId': 7, 'storyboardId': 13},
      projectId: 42,
      projectUuid: '550e8400-e29b-41d4-a716-446655440000',
    );

    expect(body['projectUuid'], '550e8400-e29b-41d4-a716-446655440000');
    expect(body.containsKey('projectId'), isFalse);
    expect(body['storyboardId'], 13);
  });

  test('buildProductionProjectScopeBodyV1 prefers projectUuid', () {
    final body = buildProductionProjectScopeBodyV1(
      base: const <String, dynamic>{'episodesId': 9},
      projectId: 42,
      projectUuid: '550e8400-e29b-41d4-a716-446655440000',
    );

    expect(body['projectUuid'], '550e8400-e29b-41d4-a716-446655440000');
    expect(body.containsKey('projectId'), isFalse);
    expect(body['episodesId'], 9);
  });
}
