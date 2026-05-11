import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  test('buildNovelCrawlScheduleCreateBody omits numeric fallback when absent', () {
    expect(
      buildNovelCrawlScheduleCreateBody(
        urls: const ['https://example.com/ch1'],
        intakeStatus: 'admitted',
        intakeNote: 'note',
        runAtMs: 123,
        repeatIntervalMs: 456,
      ),
      <String, dynamic>{
        'urls': const ['https://example.com/ch1'],
        'intake_status': 'admitted',
        'intake_note': 'note',
        'run_at_ms': 123,
        'repeat_interval_ms': 456,
      },
    );
  });

  test('buildNovelCrawlScheduleCreateBody keeps numeric fallback when requested', () {
    expect(
      buildNovelCrawlScheduleCreateBody(
        urls: const ['https://example.com/ch1'],
        intakeStatus: 'admitted',
        projectNumericId: 42,
      ),
      <String, dynamic>{
        'urls': const ['https://example.com/ch1'],
        'intake_status': 'admitted',
        'intake_note': null,
        'run_at_ms': null,
        'repeat_interval_ms': null,
        'project_numeric_id': 42,
      },
    );
  });
}
