import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/short_video_space/section.dart';

import '../support/studio_golden_app.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

void main() {
  testWidgets('export settings dialog renders format controls', (tester) async {
    final zh = AppLocalizationsZh();

    await tester.pumpWidget(
      studioGoldenApp(
        child: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                onPressed: () {
                  showStudioDialog<void>(
                    context: context,
                    builder: (_) => const ExportSettingsDialog(
                      estimatedDurationSeconds: 60,
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

    expect(find.byType(StudioAlertDialog), findsOneWidget);
    expect(find.text(zh.shortVideoExportSettingsTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
