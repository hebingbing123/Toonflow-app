import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/debug/debug.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';

void main() {
  tearDown(DebugErrorOverlayController.instance.resetForTest);

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: StudioTheme.build(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('shows overlay when controller reports an error', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DebugErrorOverlayHost(
          child: Scaffold(body: Center(child: Text('app'))),
        ),
      ),
    );

    expect(find.byType(DebugOverlayWidget), findsNothing);

    DebugErrorOverlayController.instance.report(
      FlutterErrorDetails(exception: StateError('async failure')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(DebugOverlayWidget), findsOneWidget);
    expect(find.text('StateError'), findsOneWidget);
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('hides overlay after controller clear', (tester) async {
    await tester.pumpWidget(
      wrap(
        const DebugErrorOverlayHost(
          child: SizedBox(),
        ),
      ),
    );

    DebugErrorOverlayController.instance.report(
      FlutterErrorDetails(exception: Exception('gone')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(DebugOverlayWidget), findsOneWidget);

    DebugErrorOverlayController.instance.clear();
    await tester.pump();
    expect(find.byType(DebugOverlayWidget), findsNothing);
  });
}
