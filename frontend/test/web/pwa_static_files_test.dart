import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final webDir = '${Directory.current.path}${Platform.pathSeparator}web';
  final indexHtml = File('$webDir${Platform.pathSeparator}index.html');
  final manifestFile = File('$webDir${Platform.pathSeparator}manifest.json');

  group('index.html PWA smoke', () {
    late String html;

    setUp(() {
      expect(indexHtml.existsSync(), isTrue, reason: 'web/index.html missing');
      html = indexHtml.readAsStringSync();
    });

    test('includes viewport meta', () {
      expect(
        html,
        contains(
          '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
        ),
      );
    });

    test('includes apple-mobile-web-app-capable meta', () {
      expect(
        html,
        contains('<meta name="apple-mobile-web-app-capable" content="yes">'),
      );
      expect(html, isNot(contains('name="mobile-web-app-capable"')));
    });

    test('registers flutter service worker on load', () {
      expect(html, contains("'serviceWorker' in navigator"));
      expect(
        html,
        contains(
          "navigator.serviceWorker.register('/flutter_service_worker.js')",
        ),
      );
      expect(html, contains('flutter_bootstrap.js'));
    });
  });

  group('manifest.json PWA smoke', () {
    late Map<String, dynamic> manifest;

    setUp(() {
      expect(manifestFile.existsSync(), isTrue);
      manifest =
          jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    });

    test('includes scope, lang, categories, and standalone display', () {
      expect(manifest['scope'], '/');
      expect(manifest['lang'], 'en');
      expect(manifest['categories'], ['productivity']);
      expect(manifest['display'], 'standalone');
    });

    test('includes all four icon entries', () {
      final icons = manifest['icons'] as List<dynamic>;
      expect(icons, hasLength(4));

      final srcs = icons
          .map((e) => (e as Map<String, dynamic>)['src'] as String)
          .toList();
      expect(srcs, containsAll(<String>[
        'icons/Icon-192.png',
        'icons/Icon-512.png',
        'icons/Icon-maskable-192.png',
        'icons/Icon-maskable-512.png',
      ]));
    });
  });
}
