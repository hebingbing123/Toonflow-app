import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/storyboard_studio/storyboard_studio_page.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  testWidgets('storyboard studio renders desktop chrome and primary actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var openProductionCalls = 0;

    await tester.pumpWidget(
      _wrapApp(
        child: StoryboardStudioPage(
          projectNumericId: 7,
          onOpenProductionWorkspace: () {
            openProductionCalls += 1;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storyboard studio'), findsOneWidget);
    expect(find.text('Shots'), findsOneWidget);
    expect(find.text('Properties'), findsOneWidget);
    expect(find.text('Grid mode'), findsOneWidget);
    expect(find.text('Open production'), findsOneWidget);
    expect(find.text('Shot 1'), findsOneWidget);
    expect(find.text('Shot 6'), findsOneWidget);

    await tester.tap(find.text('Open production'));
    await tester.pump();
    await tester.tap(find.text('Shot 1'));
    await tester.pump();

    expect(openProductionCalls, 2);
    expect(tester.takeException(), isNull);
  });
}
