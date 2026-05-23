import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/ignore_layout_overflow.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/short_video_space/dialogs/confirmation_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/studio_golden_app.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

void main() {
  testWidgets('cancel export confirmation dialog renders', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      studioGoldenApp(
        child: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  showCancelExportConfirmation(context, showDontShowAgain: false);
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

    expect(find.byType(StudioAlertDialog), findsOneWidget);
    expect(find.text(zh.shortVideoSpaceDialogConfirmCancelExportTitle), findsOneWidget);
    expectNoBenignQueuedExceptions(tester);
  });
}
