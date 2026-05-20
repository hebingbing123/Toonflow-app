import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/project/creator_journey_api.dart';

void main() {
  test('CreatorJourneySummary.fromJson parses summary payload', () {
    final summary = CreatorJourneySummary.fromJson(<String, dynamic>{
      'topEvents': <Map<String, dynamic>>[
        <String, dynamic>{'name': 'step_selected', 'count': 3},
        <String, dynamic>{'name': 'review_pack_view', 'count': 1},
      ],
      'stepSelections': <Map<String, dynamic>>[
        <String, dynamic>{'step': 'script', 'count': 2},
      ],
      'retryEventCount': 4,
      'totalEvents': 8,
    });

    expect(summary.totalEvents, 8);
    expect(summary.retryEventCount, 4);
    expect(summary.topEvents, hasLength(2));
    expect(summary.topEvents.first.name, 'step_selected');
    expect(summary.stepSelections.single.step, 'script');
  });
}
