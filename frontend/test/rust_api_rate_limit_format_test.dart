import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openflow_app/rust_api/core.dart';

void main() {
  test('formatRustApiException uses Retry-After header on 429 when body is plain', () {
    final ex = RustApiException.fromHttpResponse(
      http.Response('', 429, headers: {'retry-after': '90'}),
    );
    final s = formatRustApiException(ex);
    expect(s, contains('请求过于频繁'));
    expect(s, contains('分'));
  });

  test('ensureHttpStatus throws fromHttpResponse on mismatch', () {
    final res = http.Response('{}', 200);
    expect(() => ensureHttpStatus(res, 201), throwsA(isA<RustApiException>()));
  });

  test('formatRustApiException prefers JSON retry_after_ms over header', () {
    final ex = RustApiException.fromHttpResponse(
      http.Response(
        '{"code":"quota_exceeded","message":"too many","retry_after_ms":5000}',
        429,
        headers: {'retry-after': '120'},
      ),
    );
    final s = formatRustApiException(ex);
    expect(s, contains('配额或频率已用尽'));
    expect(s, contains('5'));
    expect(s, contains('秒'));
  });
}
