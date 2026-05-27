import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_async_data_view.dart';
import 'package:openflow_app/design_system/components/studio_loading_placeholders.dart';
import 'package:openflow_app/design_system/components/studio_skeleton.dart';
import 'package:openflow_app/design_system/tokens.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

ThemeData _testTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(primary: StudioTokens.dark.primary),
    extensions: <ThemeExtension<dynamic>>[StudioTokens.dark],
  );
}

void main() {
  testWidgets('StudioPaneLoadingSkeleton supports density variants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: StudioPaneLoadingSkeleton(
            density: StudioPaneLoadingDensity.comfortable,
          ),
        ),
      ),
    );
    expect(find.byType(StudioSkeleton), findsNWidgets(3));
  });

  testWidgets('StudioListSkeleton renders shimmer placeholders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: StudioListSkeleton(itemCount: 2, scrollable: false),
        ),
      ),
    );
    expect(find.byType(StudioSkeleton), findsWidgets);
  });

  testWidgets('StudioAsyncDataView shows loadFailed with retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: _testTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioAsyncDataView(
            loading: false,
            error: 'network',
            onRetry: () => retried = true,
            child: const Text('data'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('data'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(retried, isTrue);
  });
}
