import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/project_studio/novel_crawl_auth_section.dart';

void main() {
  testWidgets('crawl auth section shows title after load attempt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(useGoogleFonts: false),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StudioNovelCrawlAuthSection(
            accessToken: 'test-token',
            projectId: '00000000-0000-0000-0000-000000000001',
            onOverrideChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.studioNovelCrawlAuthSectionTitle), findsOneWidget);
  });
}
