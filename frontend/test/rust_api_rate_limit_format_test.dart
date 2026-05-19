import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/rust_api_error_format.dart';
import 'package:openflow_app/rust_api/core.dart';

void main() {
  test(
    'formatRustApiExceptionForDisplay uses Retry-After header on 429 when body is plain',
    () {
      final l10nZh = lookupAppLocalizations(const Locale('zh'));
      final ex = RustApiException.fromHttpResponse(
        http.Response('', 429, headers: {'retry-after': '90'}),
      );
      final s = formatRustApiExceptionForDisplay(l10nZh, ex);
      expect(s, contains('请求过于频繁'));
      expect(s, contains('分'));
    },
  );

  test('ensureHttpStatus throws fromHttpResponse on mismatch', () {
    final res = http.Response('{}', 200);
    expect(() => ensureHttpStatus(res, 201), throwsA(isA<RustApiException>()));
  });

  test(
    'formatRustApiExceptionForDisplay prefers JSON retry_after_ms over header',
    () {
      final l10nZh = lookupAppLocalizations(const Locale('zh'));
      final ex = RustApiException.fromHttpResponse(
        http.Response(
          '{"code":"quota_exceeded","message":"too many","retry_after_ms":5000}',
          429,
          headers: {'retry-after': '120'},
        ),
      );
      final s = formatRustApiExceptionForDisplay(l10nZh, ex);
      expect(s, contains('配额或频率已用尽'));
      expect(s, contains('5'));
      expect(s, contains('秒'));
    },
  );

  test(
    'describeUserVisibleApiError trims verbose ClientException URI details',
    () {
      final l10nZh = lookupAppLocalizations(const Locale('zh'));
      final message = describeUserVisibleApiError(
        l10nZh,
        http.ClientException(
          'Failed to fetch',
          Uri.parse('http://127.0.0.1:8666/api/v1/settings/account/exports'),
        ),
      );
      expect(message, '出现问题：Failed to fetch');
      expect(message, isNot(contains('127.0.0.1:8666')));
      expect(message, isNot(contains('/settings/account/exports')));
    },
  );

  test(
    'compactUserVisibleApiErrorText trims URI details from stored error strings',
    () {
      final l10nZh = lookupAppLocalizations(const Locale('zh'));
      final message = compactUserVisibleApiErrorText(
        l10nZh,
        '出现问题：ClientException: Failed to fetch, uri=http://127.0.0.1:8666/api/v1/settings/account/exports',
      );
      expect(message, '出现问题：Failed to fetch');
      expect(message, isNot(contains('127.0.0.1:8666')));
      expect(message, isNot(contains('/settings/account/exports')));
    },
  );

  testWidgets(
    'resolveAppLocalizationsForErrors falls back to English without delegates',
    (WidgetTester tester) async {
      late AppLocalizations resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              resolved = resolveAppLocalizationsForErrors(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        resolved.rustApiClientRecordNotFound,
        en.rustApiClientRecordNotFound,
      );
    },
  );

  testWidgets(
    'resolveAppLocalizationsForErrors follows MaterialApp locale when delegates exist',
    (WidgetTester tester) async {
      late AppLocalizations resolved;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              resolved = resolveAppLocalizationsForErrors(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final zh = lookupAppLocalizations(const Locale('zh'));
      expect(
        resolved.rustApiClientRecordNotFound,
        zh.rustApiClientRecordNotFound,
      );
    },
  );
}
