import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_cost_estimate_chip.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('shows BYOK chip when platform billing exempt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioCostEstimateChip(
            estimate: const BillingEstimateResponse(
              modelId: '1:gpt-4o-mini',
              taskKind: 'text_completion',
              quantity: 1,
              pricingUnit: 'per_1k_tokens',
              credits: 4,
              cnyCents: 60,
              quotaImpactJobs: 1,
              warnings: <String>[],
              platformBillingExempt: true,
              quotaUsagePercentAfter: 25,
              dailyJobQuota: 20,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('API key'), findsOneWidget);
    expect(find.textContaining('25%'), findsOneWidget);
  });
}
