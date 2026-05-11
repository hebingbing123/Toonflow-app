import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/novels/project_scope.dart';

void main() {
  test('novel project scope prefers explicit uuid', () async {
    final resolved = await resolveNovelProjectUuid(
      'token',
      projectUuid: '550e8400-e29b-41d4-a716-446655440123',
      projectNumericId: 77,
    );

    expect(resolved, '550e8400-e29b-41d4-a716-446655440123');
  });

  test('novel project scope rejects missing identifiers', () async {
    expect(
      () => resolveNovelProjectUuid('token'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('novels compat callers may rely on uuid without numeric id', () async {
    final resolved = await resolveNovelProjectUuid(
      'token',
      projectUuid: '550e8400-e29b-41d4-a716-446655440123',
    );

    expect(resolved, '550e8400-e29b-41d4-a716-446655440123');
  });
}
