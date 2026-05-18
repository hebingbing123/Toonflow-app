import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_cost_confirm_sheet.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('cost confirm sheet proceed returns true', (tester) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await showStudioCostConfirmSheet(
                    context: context,
                    estimate: const BillingEstimateResponse(
                      modelId: '1:gpt-4o-mini',
                      taskKind: 'image_generation',
                      quantity: 1,
                      pricingUnit: 'per_image',
                      credits: 10,
                      cnyCents: 150,
                      quotaImpactJobs: 1,
                      warnings: <String>[],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm generation'), findsOneWidget);
    await tester.tap(find.text('Run'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}
