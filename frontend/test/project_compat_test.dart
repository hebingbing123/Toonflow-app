import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('projectUuidOrNull trims direct compat UUID inputs', () {
    expect(
      projectUuidOrNull(' 550e8400-e29b-41d4-a716-446655440123 '),
      '550e8400-e29b-41d4-a716-446655440123',
    );
    expect(projectUuidOrNull('   '), isNull);
    expect(projectUuidOrNull(null), isNull);
  });

  test('projectUuidFromCompatBody prefers explicit non-empty uuid', () {
    expect(
      projectUuidFromCompatBody(<String, dynamic>{
        'projectUuid': '550e8400-e29b-41d4-a716-446655440123',
      }),
      '550e8400-e29b-41d4-a716-446655440123',
    );
    expect(
      projectUuidFromCompatBody(<String, dynamic>{'projectUuid': '   '}),
      isNull,
    );
    expect(projectUuidFromCompatBody(<String, dynamic>{}), isNull);
  });
}
