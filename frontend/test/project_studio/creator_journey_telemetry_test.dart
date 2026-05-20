import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/project_studio/creator_journey_telemetry.dart';
import 'package:openflow_app/rust_api/project/creator_journey_api.dart';

void main() {
  tearDown(() {
    CreatorJourneyTelemetry.debugSink = null;
    CreatorJourneyTelemetry.postOverride = null;
    CreatorJourneyTelemetry.clearProject(flush: false);
  });

  test('CreatorJourneyTelemetry forwards events to debugSink', () {
    final captured = <CreatorJourneyEvent>[];
    CreatorJourneyTelemetry.debugSink = captured.add;

    const event = CreatorJourneyEvent('step_selected', {'step': 'script'});
    CreatorJourneyTelemetry.record(event);

    expect(captured, <CreatorJourneyEvent>[event]);
  });

  test('bindProject enriches project_id and flushes via postOverride', () async {
    final posted = <List<CreatorJourneyEventPayload>>[];
    CreatorJourneyTelemetry.postOverride =
        (String token, String uuid, List<CreatorJourneyEventPayload> events) async {
      posted.add(events);
    };
    CreatorJourneyTelemetry.bindProject(
      accessToken: 'tok',
      projectUuid: 'uuid-1',
      projectNumericId: 42,
    );

    CreatorJourneyTelemetry.record(
      const CreatorJourneyEvent('next_cta', <String, Object?>{'step': 'script'}),
    );
    await CreatorJourneyTelemetry.flushNow();

    expect(posted, hasLength(1));
    expect(posted.first, hasLength(1));
    expect(posted.first.first.name, 'next_cta');
    expect(posted.first.first.properties['project_id'], 42);
    expect(posted.first.first.properties['step'], 'script');
  });
}
