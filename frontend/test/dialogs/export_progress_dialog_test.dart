import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/ix/studio_api_error_callout.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api/core.dart';
import 'package:openflow_app/short_video_space/section.dart';
import 'package:openflow_app/design_system/components/studio_dialog_shell.dart';

void main() {
  testWidgets('export progress error state shows retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioApiErrorCallout(
            error: RustApiException('export_failed', statusCode: 500),
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.byType(StudioApiErrorCallout), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('export progress session expired when access token is null', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: FilledButton(
                onPressed: () {
                  showStudioDialog<void>(
                    context: context,
                    builder: (_) => const ExportProgressDialog(
                      taskId: 'export-task-1',
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
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('导出进度'), findsOneWidget);
    expect(find.textContaining('获取进度失败'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
