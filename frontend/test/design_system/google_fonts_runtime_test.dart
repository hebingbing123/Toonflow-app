import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/google_fonts_runtime.dart';

void main() {
  test('resolveGoogleFontsProxyBaseUri returns null for empty input', () {
    expect(resolveGoogleFontsProxyBaseUri('   '), isNull);
  });

  test('resolveGoogleFontsProxyBaseUri accepts absolute urls', () {
    final uri = resolveGoogleFontsProxyBaseUri(
      'https://fonts-proxy.example/mirror',
    );
    expect(uri, isNotNull);
    expect(uri!.host, 'fonts-proxy.example');
    expect(uri.path, '/mirror');
  });

  test('resolveGoogleFontsProxyBaseUri rejects relative urls', () {
    expect(
      () => resolveGoogleFontsProxyBaseUri('/mirror'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rewriteGoogleFontsUri keeps non-google urls unchanged', () {
    final original = Uri.parse('https://example.com/fonts/inter.ttf');
    final proxy = Uri.parse('https://fonts-proxy.example');

    expect(
      rewriteGoogleFontsUri(original, proxyBaseUri: proxy),
      same(original),
    );
  });

  test('rewriteGoogleFontsUri rewrites gstatic urls onto proxy host', () {
    final original = Uri.parse('https://fonts.gstatic.com/s/a/hash.ttf');
    final proxy = Uri.parse('https://fonts-proxy.example');

    expect(
      rewriteGoogleFontsUri(original, proxyBaseUri: proxy).toString(),
      'https://fonts-proxy.example/s/a/hash.ttf',
    );
  });

  test('rewriteGoogleFontsUri preserves proxy path prefix and query', () {
    final original = Uri.parse(
      'https://fonts.googleapis.com/css2?family=Inter:wght@400;700&display=swap',
    );
    final proxy = Uri.parse('https://fonts-proxy.example/google-fonts');

    expect(
      rewriteGoogleFontsUri(original, proxyBaseUri: proxy).toString(),
      'https://fonts-proxy.example/google-fonts/css2?family=Inter:wght@400;700&display=swap',
    );
  });
}
