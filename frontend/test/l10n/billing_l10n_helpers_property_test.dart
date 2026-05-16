// Feature: billing-i18n-production, Property 3/4/5/7: billing l10n helper invariants
// Validates: Requirements 2.3, 3.2, 4.2, 6.1

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/billing_l10n_helpers.dart';

void main() {
  Future<AppLocalizations> loadL10n(Locale locale) async {
    return lookupAppLocalizations(locale);
  }

  group('Property 3: unknown enum values fall back to generic copy', () {
    test(
      'subscriptionStatusLabel and planTierDisplayName (200 cases)',
      () async {
        final l10n = await loadL10n(const Locale('en'));
        final rng = Random(7);
        const knownStatus = {
          'active',
          'past_due',
          'canceled',
          'trialing',
          'paused',
          'unpaid',
        };
        const knownTier = {'free', 'pro', 'enterprise'};

        for (var i = 0; i < 200; i++) {
          final status = 'x${rng.nextInt(99999)}';
          if (knownStatus.contains(status)) continue;
          final statusLabel = subscriptionStatusLabel(l10n, status);
          expect(statusLabel, l10n.billingSubscriptionStatusUnknown);
          expect(statusLabel, isNot(status));

          final tier = 'tier_${rng.nextInt(99999)}';
          if (knownTier.contains(tier)) continue;
          final tierLabel = planTierDisplayName(l10n, tier);
          expect(tierLabel, l10n.billingPlanTierUnknown);
          expect(tierLabel, isNot(tier));
        }
      },
    );
  });

  group('Property 4: billing notification labels are localized', () {
    test('known types differ from raw notificationType', () async {
      final l10n = await loadL10n(const Locale('en'));
      const types = [
        'billing_subscription_activated',
        'billing_subscription_past_due',
        'billing_subscription_canceled',
        'billing_payment_failed',
        'billing_subscription_expired',
        'billing_subscription_trialing',
      ];
      for (final type in types) {
        final label = billingNotificationTypeLabel(l10n, type);
        expect(label, isNot(type));
        expect(label, isNotEmpty);
      }
    });
  });

  group('Property 5: quotaExceededMessage is plan-aware', () {
    test('free and pro messages differ and include plan name', () async {
      final l10n = await loadL10n(const Locale('en'));
      final freeMsg = quotaExceededMessage(l10n, 'free');
      final proMsg = quotaExceededMessage(l10n, 'pro');
      expect(freeMsg, isNot(proMsg));
      expect(freeMsg, contains(l10n.billingPlanTierFree));
      expect(proMsg, contains(l10n.billingPlanTierPro));
    });
  });

  group('Property 7: planTierDisplayName differs across locales', () {
    test('known tiers differ between en and zh', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));
      for (final tier in ['free', 'pro', 'enterprise']) {
        final enName = planTierDisplayName(en, tier);
        final zhName = planTierDisplayName(zh, tier);
        expect(enName, isNot(zhName));
        expect(enName, isNot(tier));
        expect(zhName, isNot(tier));
      }
    });
  });
}
