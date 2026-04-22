import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/config.dart';

void main() {
  test('resolveRustApiUrl keeps absolute URLs unchanged', () {
    expect(
      resolveRustApiUrl('https://cdn.example.com/export.mp4'),
      'https://cdn.example.com/export.mp4',
    );
  });

  test('resolveRustApiUrl expands relative API paths against base URL', () {
    expect(
      resolveRustApiUrl('/api/v1/jobs/abc/file'),
      'http://127.0.0.1:8666/api/v1/jobs/abc/file',
    );
  });
}
