import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_keyboard_shortcuts_panel.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('StudioKeyboardShortcutsPanel shows entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioKeyboardShortcutsPanel(
            title: 'Shortcuts',
            intro: 'Intro',
            entries: const [
              StudioKeyboardShortcutEntry(
                description: 'Open palette',
                keys: '⌘K',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shortcuts'), findsOneWidget);
    expect(find.text('Intro'), findsOneWidget);
    expect(find.text('Open palette'), findsOneWidget);
    expect(find.text('⌘K'), findsOneWidget);
  });
}
