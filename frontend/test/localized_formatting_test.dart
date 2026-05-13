import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/utils/localized_formatting.dart';

void main() {
  Future<void> pumpFormattingHarness(
    WidgetTester tester, {
    required Locale locale,
    required Widget child,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('LocalizedFormatting uses locale-aware time formats', (
    tester,
  ) async {
    final sample = DateTime(2024, 1, 15, 14, 30);

    await pumpFormattingHarness(
      tester,
      locale: const Locale('en'),
      child: Builder(
        builder: (context) =>
            Text(LocalizedFormatting.formatTime(context, sample)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2:30 PM'), findsOneWidget);

    await pumpFormattingHarness(
      tester,
      locale: const Locale('zh'),
      child: Builder(
        builder: (context) =>
            Text(LocalizedFormatting.formatTime(context, sample)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('LocalizedFormatting uses locale-aware short date times', (
    tester,
  ) async {
    final sample = DateTime(2024, 1, 15, 14, 30);

    await pumpFormattingHarness(
      tester,
      locale: const Locale('en'),
      child: Builder(
        builder: (context) =>
            Text(LocalizedFormatting.formatShortDateTime(context, sample)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('2:30 PM'), findsOneWidget);

    await pumpFormattingHarness(
      tester,
      locale: const Locale('zh'),
      child: Builder(
        builder: (context) =>
            Text(LocalizedFormatting.formatShortDateTime(context, sample)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('14:30'), findsOneWidget);
  });
}
