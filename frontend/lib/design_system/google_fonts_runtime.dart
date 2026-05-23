// ignore_for_file: implementation_imports, invalid_use_of_visible_for_testing_member

import 'dart:async';

import 'package:google_fonts/src/google_fonts_base.dart' as google_fonts_base;
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

const Set<String> _kGoogleFontsHosts = <String>{
  'fonts.gstatic.com',
  'fonts.googleapis.com',
};

/// Disables runtime Google Fonts HTTP fetch; product UI uses bundled TTFs in
/// `assets/fonts/` via [buildStudioDarkTheme].
void configureGoogleFontsRuntime({
  String proxyBaseUrl = kGoogleFontsProxyBaseUrl,
}) {
  GoogleFonts.config.allowRuntimeFetching = false;
  final proxyBaseUri = resolveGoogleFontsProxyBaseUri(proxyBaseUrl);
  google_fonts_base.httpClient = proxyBaseUri == null
      ? http.Client()
      : GoogleFontsProxyHttpClient(
          inner: http.Client(),
          proxyBaseUri: proxyBaseUri,
        );
}

Uri? resolveGoogleFontsProxyBaseUri(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    throw ArgumentError.value(
      raw,
      'proxyBaseUrl',
      'Expected an absolute URL such as https://fonts-proxy.example',
    );
  }
  return parsed;
}

Uri rewriteGoogleFontsUri(
  Uri original, {
  required Uri proxyBaseUri,
}) {
  if (!_kGoogleFontsHosts.contains(original.host)) {
    return original;
  }

  final normalizedBasePath = _normalizeBasePath(proxyBaseUri.path);
  final rewrittenPath = _joinProxyPath(normalizedBasePath, original.path);
  return proxyBaseUri.replace(
    path: rewrittenPath,
    query: original.hasQuery ? original.query : null,
    fragment: original.fragment.isEmpty ? null : original.fragment,
  );
}

String _normalizeBasePath(String path) {
  if (path.isEmpty || path == '/') {
    return '';
  }
  return path.endsWith('/') ? path.substring(0, path.length - 1) : path;
}

String _joinProxyPath(String basePath, String originalPath) {
  if (basePath.isEmpty) {
    return originalPath;
  }
  final normalizedOriginal = originalPath.startsWith('/')
      ? originalPath
      : '/$originalPath';
  return '$basePath$normalizedOriginal';
}

class GoogleFontsProxyHttpClient extends http.BaseClient {
  GoogleFontsProxyHttpClient({
    required http.Client inner,
    required this.proxyBaseUri,
  }) : _inner = inner;

  final http.Client _inner;
  final Uri proxyBaseUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bodyBytes = await request.finalize().toBytes();
    final rewrittenRequest = http.Request(
      request.method,
      rewriteGoogleFontsUri(request.url, proxyBaseUri: proxyBaseUri),
    )
      ..followRedirects = request.followRedirects
      ..headers.addAll(request.headers)
      ..maxRedirects = request.maxRedirects
      ..persistentConnection = request.persistentConnection
      ..bodyBytes = bodyBytes;
    return _inner.send(rewrittenRequest);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
