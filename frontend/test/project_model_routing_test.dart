import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('ProjectRow parses project-level model routing fields', () {
    final row = ProjectRow.fromJson(<String, dynamic>{
      'id': '550e8400-e29b-41d4-a716-446655440123',
      'workspace_id': '550e8400-e29b-41d4-a716-446655440124',
      'numeric_id': 12,
      'name': 'Route test',
      'project_type': 'short-drama',
      'text_model': '1:gpt-4.1-mini',
      'multimodal_model': '1:gpt-4o',
      'image_model': '1:gpt-image-1',
      'video_model': 'runway-gen-4',
      'voice_model': 'gpt-4o-mini-tts',
      'voice_profile': '{"voice":"alloy"}',
      'project_access_mode': 'inherited',
      'project_access_role': 'project_owner',
    });

    expect(row.textModel, '1:gpt-4.1-mini');
    expect(row.multimodalModel, '1:gpt-4o');
    expect(row.imageModel, '1:gpt-image-1');
    expect(row.videoModel, 'runway-gen-4');
    expect(row.voiceModel, 'gpt-4o-mini-tts');
    expect(row.voiceProfile, '{"voice":"alloy"}');
  });
}
