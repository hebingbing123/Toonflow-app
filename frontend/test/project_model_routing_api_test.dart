import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('ProjectModelRoutingResponse parses effective entries', () {
    final row = ProjectModelRoutingResponse.fromJson(<String, dynamic>{
      'project_id': '550e8400-e29b-41d4-a716-446655440123',
      'defaults': <String, dynamic>{
        'text_model': '1:gpt-4.1-mini',
      },
      'steps': <String, dynamic>{
        'script': <String, dynamic>{'text': '1:gpt-4o-mini'},
      },
      'effective': <Map<String, dynamic>>[
        <String, dynamic>{
          'step': 'script',
          'slot': 'text',
          'model_id': '1:gpt-4o-mini',
          'source': 'step_override',
        },
      ],
    });

    expect(row.effectiveModelFor(step: 'script', slot: 'text'), '1:gpt-4o-mini');
    expect(row.steps['script']?['text'], '1:gpt-4o-mini');
  });

  test('ProjectModelRoutingResponse omits null and blank step slots', () {
    final row = ProjectModelRoutingResponse.fromJson(<String, dynamic>{
      'project_id': '550e8400-e29b-41d4-a716-446655440123',
      'defaults': <String, dynamic>{},
      'steps': <String, dynamic>{
        'script': <String, dynamic>{
          'text': '1:gpt-4o-mini',
          'image': null,
          'video': '  ',
        },
        'assets': <String, dynamic>{'image': ''},
      },
      'effective': const <Map<String, dynamic>>[],
    });

    expect(row.steps['script'], <String, String>{'text': '1:gpt-4o-mini'});
    expect(row.steps.containsKey('assets'), isFalse);
  });
}
