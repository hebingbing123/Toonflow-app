import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/settings/studio_ui.dart';

void main() {
  test('StudioUiPrefsV1 parses pinnedProjectIds from OpenAPI camelCase', () {
    final prefs = StudioUiPrefsV1.fromJson(<String, dynamic>{
      'pinnedProjectIds': <String>[
        '00000000-0000-0000-0000-000000000001',
      ],
    });
    expect(prefs.pinnedProjectIds, hasLength(1));
    expect(prefs.toJson()['pinnedProjectIds'], hasLength(1));
  });
}
