import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openflow_app/rust_api/core.dart';
import 'package:openflow_app/utils/error_handling.dart';

void main() {
  test('classifyStudioError detects network errors', () {
    expect(
      classifyStudioError(http.ClientException('offline')),
      StudioErrorCategory.network,
    );
  });

  test('classifyStudioError detects auth errors', () {
    expect(
      classifyStudioError(RustApiException('denied', statusCode: 403)),
      StudioErrorCategory.auth,
    );
  });

  test('studioErrorIsRetryable for server errors', () {
    expect(
      studioErrorIsRetryable(RustApiException('fail', statusCode: 503)),
      isTrue,
    );
    expect(
      studioErrorIsRetryable(RustApiException('denied', statusCode: 403)),
      isFalse,
    );
  });
}
