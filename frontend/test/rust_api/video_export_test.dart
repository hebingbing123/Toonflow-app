import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/jobs/video_export.dart';

void main() {
  group('outputUrlFromJobResult', () {
    test('reads output_url', () {
      expect(
        outputUrlFromJobResult(<String, dynamic>{
          'output_url': 'https://cdn.example.com/a.mp4',
        }),
        'https://cdn.example.com/a.mp4',
      );
    });

    test('falls back to file_url then url', () {
      expect(
        outputUrlFromJobResult(<String, dynamic>{
          'file_url': 'https://cdn.example.com/b.mp4',
        }),
        'https://cdn.example.com/b.mp4',
      );
      expect(
        outputUrlFromJobResult(<String, dynamic>{'url': 'https://cdn.example.com/c.mp4'}),
        'https://cdn.example.com/c.mp4',
      );
    });

    test('returns null for empty result', () {
      expect(outputUrlFromJobResult(null), isNull);
      expect(outputUrlFromJobResult(<String, dynamic>{}), isNull);
    });

    test('resolves relative preview_url against API base', () {
      expect(
        playableUrlFromJobResult(<String, dynamic>{
          'preview_url': '/api/v1/jobs/job-1/file',
        }),
        contains('/api/v1/jobs/job-1/file'),
      );
    });
  });
}
