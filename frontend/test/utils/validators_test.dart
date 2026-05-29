import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/utils/validators.dart';

void main() {
  test('StudioValidators.required', () {
    expect(StudioValidators.required(null), isNotNull);
    expect(StudioValidators.required('  '), isNotNull);
    expect(StudioValidators.required('ok'), isNull);
  });

  test('StudioValidators.email', () {
    expect(StudioValidators.email('bad'), isNotNull);
    expect(StudioValidators.email('a@b.co'), isNull);
  });
}
