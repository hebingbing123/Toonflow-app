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

  test('assembly parses candidate_quality_summary when present', () {
    final asm = ProjectShortVideoAssembly.fromJson({
      'schema_version': 1,
      'project_defaults': {
        'voice_profile': null,
        'subtitle_style': null,
        'bgm_strategy': null,
      },
      'candidate_quality_summary': {
        'schema_version': 1,
        'project_bad_case_total': 2,
        'assembly_shot_review_total': 5,
        'assembly_shot_bad_case_count': 1,
        'assembly_shots_with_bad_case': 1,
        'assembly_late_stage_bad_case_count': 1,
        'bad_cases_by_stage': [
          {'stage': 'video_prompt', 'bad_case_count': 1},
        ],
      },
      'scripts': <dynamic>[],
    });
    expect(asm.candidateQualitySummary.projectBadCaseTotal, 2);
    expect(asm.candidateQualitySummary.badCasesByStage.first.stage, 'video_prompt');
  });
}
