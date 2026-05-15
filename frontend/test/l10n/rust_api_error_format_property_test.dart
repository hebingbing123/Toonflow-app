// Feature: billing-i18n-production, Property 6: 计费错误码 Flutter 本地化
// Validates: Requirements 5.2, 5.3, 5.4

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const billingErrorCodes = <String, int>{
    'subscription_expired': 403,
    'payment_failed': 403,
    'subscription_past_due': 403,
  };

  RustApiException billingError(String code, int statusCode) {
    return RustApiException(
      jsonEncode(<String, dynamic>{
        'code': code,
        'message': 'server message for $code',
        'status': statusCode,
      }),
      statusCode: statusCode,
    );
  }

  group(
    'Property 6: billing error codes localize in formatRustApiExceptionForDisplay',
    () {
      test(
        'known codes differ from raw code string (200 random server messages)',
        () {
          final l10n = lookupAppLocalizations(const Locale('en'));
          final rng = Random(11);
          for (var i = 0; i < 200; i++) {
            for (final entry in billingErrorCodes.entries) {
              final code = entry.key;
              final status = entry.value;
              final serverMsg = 'billing-${rng.nextInt(1 << 20)}';
              final ex = RustApiException(
                jsonEncode(<String, dynamic>{
                  'code': code,
                  'message': serverMsg,
                  'status': status,
                }),
                statusCode: status,
              );
              final display = formatRustApiExceptionForDisplay(l10n, ex);
              expect(display, isNot(code));
              expect(display, isNot(serverMsg));
              expect(display, isNotEmpty);
            }
          }
        },
      );

      test('en and zh locales return different copy for each billing code', () {
        final en = lookupAppLocalizations(const Locale('en'));
        final zh = lookupAppLocalizations(const Locale('zh'));
        for (final entry in billingErrorCodes.entries) {
          final ex = billingError(entry.key, entry.value);
          final enMsg = formatRustApiExceptionForDisplay(en, ex);
          final zhMsg = formatRustApiExceptionForDisplay(zh, ex);
          expect(
            enMsg,
            isNot(zhMsg),
            reason: 'locale copy should differ for ${entry.key}',
          );
          expect(enMsg, isNot(entry.key));
          expect(zhMsg, isNot(entry.key));
        }
      });

      test('unknown billing_* code falls back to generic unknown error', () {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final ex = RustApiException(
          jsonEncode(<String, dynamic>{
            'code': 'billing_custom_unknown',
            'message': 'raw',
          }),
          statusCode: 400,
        );
        final display = formatRustApiExceptionForDisplay(l10n, ex);
        expect(display, isNot('billing_custom_unknown'));
        expect(display, contains('RustApiException'));
      });
    },
  );
}
