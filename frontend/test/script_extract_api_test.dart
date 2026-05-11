import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('buildScriptAssetExtractBody prefers projectUuid over numeric id', () {
    expect(
      buildScriptAssetExtractBody(
        projectUuid: ' 550e8400-e29b-41d4-a716-446655440123 ',
        projectNumericId: 9,
        scriptNumericIds: const [3, 4],
        groupSize: 2,
      ),
      <String, dynamic>{
        'project_uuid': '550e8400-e29b-41d4-a716-446655440123',
        'script_numeric_ids': const [3, 4],
        'group_size': 2,
      },
    );
  });

  test('buildScriptAssetExtractBody falls back to legacy numeric id', () {
    expect(
      buildScriptAssetExtractBody(
        projectNumericId: 9,
        scriptNumericIds: const [7],
      ),
      <String, dynamic>{
        'project_numeric_id': 9,
        'script_numeric_ids': const [7],
      },
    );
  });
}
