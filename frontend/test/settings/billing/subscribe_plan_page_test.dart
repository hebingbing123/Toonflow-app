import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/settings/billing/subscribe_plan_page.dart';

void main() {
  testWidgets('SubscribePlanPage shows title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SubscribePlanPage(
          accessToken: 'test-token',
          currentPlanTier: 'free',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Subscribe'), findsOneWidget);
  });
}
