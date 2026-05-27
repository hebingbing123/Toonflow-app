import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/billing_l10n_helpers.dart';

void main() {
  group('billing_l10n_helpers', () {
    testWidgets('subscriptionStatusLabel maps known values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(
                subscriptionStatusLabel(l10n, 'active'),
                l10n.billingSubscriptionStatusActive,
              );
              expect(
                subscriptionStatusLabel(l10n, 'past_due'),
                l10n.billingSubscriptionStatusPastDue,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('null subscription status uses not-set label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(
                subscriptionStatusLabel(l10n, null),
                l10n.billingSubscriptionStatusNotSet,
              );
              expect(
                subscriptionStatusLabel(l10n, '  '),
                l10n.billingSubscriptionStatusNotSet,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('unknown subscription status uses generic label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final label = subscriptionStatusLabel(l10n, 'not_a_real_status');
              expect(label, l10n.billingSubscriptionStatusUnknown);
              expect(label, isNot('not_a_real_status'));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('unknown sentinel statuses map to not-set label', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              for (final status in <String>['unknown', 'none', 'inactive']) {
                expect(
                  subscriptionStatusLabel(l10n, status),
                  l10n.billingSubscriptionStatusNotSet,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('planTierDisplayName localizes tiers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              expect(
                planTierDisplayName(l10n, 'free'),
                l10n.billingPlanTierFree,
              );
              expect(planTierDisplayName(l10n, 'pro'), l10n.billingPlanTierPro);
              expect(
                planTierDisplayName(l10n, 'mystery'),
                l10n.billingPlanTierUnknown,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('billingNotificationTypeLabel differs from raw type', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              const type = 'billing_payment_failed';
              final label = billingNotificationTypeLabel(l10n, type);
              expect(label, isNot(type));
              expect(label, l10n.billingNotificationPaymentFailed);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('quotaExceededMessage differs for free vs pro', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              final freeMsg = quotaExceededMessage(l10n, 'free');
              final proMsg = quotaExceededMessage(l10n, 'pro');
              expect(freeMsg, isNot(proMsg));
              expect(freeMsg, contains(l10n.billingPlanTierFree));
              expect(proMsg, contains(l10n.billingPlanTierPro));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });
}
