import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('assembly JSON missing effective block falls back like resolve_tts_voice', () {
    final asm = ProjectShortVideoAssembly.fromJson({
      'schema_version': 1,
      'project_defaults': {
        'voice_profile': 'nova',
        'subtitle_style': null,
        'bgm_strategy': null,
      },
      'scripts': <dynamic>[],
    });
    expect(asm.effectiveShortVideoDefaults.ttsVoice, 'nova');
  });

  test('assembly fallback uses alloy when voice_profile empty', () {
    final asm = ProjectShortVideoAssembly.fromJson({
      'schema_version': 1,
      'project_defaults': {
        'voice_profile': '   ',
        'subtitle_style': null,
        'bgm_strategy': null,
      },
      'scripts': <dynamic>[],
    });
    expect(asm.effectiveShortVideoDefaults.ttsVoice, 'alloy');
  });
}
