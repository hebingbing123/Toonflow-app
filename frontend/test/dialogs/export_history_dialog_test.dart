import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/short_video_space/section.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

import '../support/studio_golden_app.dart';

/// Phase-7 dialog smoke: session expired when [ExportHistoryDialog.accessToken] is null.
void main() {
  testWidgets('export_history session expired when access token is null', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      studioGoldenApp(
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  showStudioDialog<void>(
                    context: context,
                    builder: (_) => const ExportHistoryDialog(
                      projectId: 'project-123',
                      accessToken: null,
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
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('导出历史'), findsOneWidget);
    expect(find.textContaining('加载导出历史失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
