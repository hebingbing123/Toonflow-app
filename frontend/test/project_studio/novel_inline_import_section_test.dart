import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/novel_inline_import_section.dart';
import 'package:openflow_app/rust_api.dart';

void main() {
  testWidgets('inline import shows intake sections and advanced workbench', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useBundledFonts: true),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioScriptNovelInlineImport(
            accessToken: '',
            project: const ProjectRow(
              id: '00000000-0000-0000-0000-000000000001',
              numericId: 1,
              projectAccessMode: 'inherited',
              projectAccessRole: 'owner',
            ),
            onReload: () async {},
            onOpenFullWorkbench: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Import novel'), findsOneWidget);
    expect(find.text('URL crawl'), findsOneWidget);
    expect(find.text('Full text (paste or file)'), findsOneWidget);
    expect(find.text('Advanced workbench'), findsOneWidget);
  });
}
