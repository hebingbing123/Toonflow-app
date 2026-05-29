import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openflow_app/l10n/rust_api_error_format.dart';
import 'package:openflow_app/rust_api/core.dart';

void main() {
  test('studioLooksLikeConnectivityError detects client and gateway failures', () {
    expect(
      studioLooksLikeConnectivityError(http.ClientException('Socket failed')),
      isTrue,
    );
    expect(
      studioLooksLikeConnectivityError(
        RustApiException('gateway', statusCode: 503),
      ),
      isTrue,
    );
    expect(
      studioLooksLikeConnectivityError(
        RustApiException('nope', statusCode: 401),
      ),
      isFalse,
    );
  });
}
