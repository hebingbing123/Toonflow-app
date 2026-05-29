import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/short_video_space/layout/short_video_responsive_shell.dart';
import 'package:openflow_app/short_video_space/layout/short_video_desktop_shell.dart';
import 'package:openflow_app/short_video_space/layout/short_video_mobile_shell.dart';

void main() {
  Widget wrap(Widget child, {double width = 1280}) {
    return MaterialApp(
      theme: buildStudioLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 900)),
        child: Scaffold(body: child),
      ),
    );
  }

  testWidgets('desktop shell renders three columns at 1280', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 1280,
          height: 800,
          child: ShortVideoDesktopShell(
            videoRatio: '9:16',
            masterPane: const Text('master'),
            detailPane: const Text('detail'),
            threePane: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('master'), findsOneWidget);
    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('responsive shell uses mobile shell under 600', (tester) async {
    await tester.pumpWidget(
      wrap(
        SizedBox(
          width: 400,
          height: 800,
          child: ShortVideoResponsiveShell(
            videoRatio: '9:16',
            masterPane: const Text('master'),
            detailPane: const Text('detail body'),
            mobileDock: const Text('dock'),
          ),
        ),
        width: 400,
      ),
    );
    await tester.pump();
    expect(find.byType(ShortVideoMobileShell), findsOneWidget);
    expect(find.text('detail body'), findsOneWidget);
    expect(find.text('dock'), findsOneWidget);
  });
}
