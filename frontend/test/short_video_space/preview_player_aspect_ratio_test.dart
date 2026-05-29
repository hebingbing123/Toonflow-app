import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/short_video_space/components/preview_player.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      theme: buildStudioLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('PreviewPlayer uses portrait aspect ratio for 9:16', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PreviewPlayer(
          videoUrl: 'https://example.com/video.mp4',
          videoRatio: '9:16',
        ),
      ),
    );
    await tester.pump();

    final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatios, isNotEmpty);
    expect(aspectRatios.first.aspectRatio, closeTo(9 / 16, 0.001));
  });

  testWidgets('PreviewPlayer uses landscape aspect ratio for 16:9', (tester) async {
    await tester.pumpWidget(
      wrap(
        const PreviewPlayer(
          videoUrl: 'https://example.com/video.mp4',
          videoRatio: '16:9',
        ),
      ),
    );
    await tester.pump();

    final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatios, isNotEmpty);
    expect(aspectRatios.first.aspectRatio, closeTo(16 / 9, 0.001));
  });
}
