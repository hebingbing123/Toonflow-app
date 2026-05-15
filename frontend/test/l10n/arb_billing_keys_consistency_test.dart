// Feature: billing-i18n-production, Property 8: ARB key 集合一致性不变量
// Validates: Requirements 8.4

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('app_en.arb and app_zh.arb share identical billing* key sets', () {
    final repoRoot = Directory.current.path.endsWith('frontend')
        ? Directory.current.parent
        : Directory.current;
    final enPath = '${repoRoot.path}/frontend/lib/l10n/app_en.arb';
    final zhPath = '${repoRoot.path}/frontend/lib/l10n/app_zh.arb';

    Set<String> billingKeys(String path) {
      final raw =
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      return raw.keys
          .where((k) => k.startsWith('billing') && !k.startsWith('@'))
          .toSet();
    }

    final enKeys = billingKeys(enPath);
    final zhKeys = billingKeys(zhPath);

    expect(
      enKeys.difference(zhKeys),
      isEmpty,
      reason: 'keys only in app_en.arb: ${enKeys.difference(zhKeys)}',
    );
    expect(
      zhKeys.difference(enKeys),
      isEmpty,
      reason: 'keys only in app_zh.arb: ${zhKeys.difference(enKeys)}',
    );
  });
}
