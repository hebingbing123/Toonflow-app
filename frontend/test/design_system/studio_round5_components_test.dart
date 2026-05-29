import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/design_system/components/studio_tooltip.dart';
import 'package:openflow_app/design_system/components/studio_transfer_progress.dart';
import 'package:openflow_app/design_system/studio_motion.dart';
import 'package:openflow_app/design_system/studio_page_transitions.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('StudioTooltip wraps child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        home: const Scaffold(
          body: StudioTooltip(
            message: 'Help text',
            child: Text('Target'),
          ),
        ),
      ),
    );
    expect(find.text('Target'), findsOneWidget);
  });

  testWidgets('StudioTransferProgress shows percent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildStudioDarkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: StudioTransferProgress(
            label: 'Uploading clip.mp4',
            progress: 0.42,
          ),
        ),
      ),
    );
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Uploading clip.mp4'), findsOneWidget);
  });

  test('studioFadeTransitionPage uses StudioMotion durations', () {
    final page = studioFadeTransitionPage(
      key: const ValueKey<String>('fade'),
      child: const SizedBox.shrink(),
    );
    expect(page.transitionDuration, StudioMotionDurations.pageTransition);
  });

  test('studioProjectStudioTransitionPage uses slow duration', () {
    final page = studioProjectStudioTransitionPage(
      key: const ValueKey<String>('project'),
      child: const SizedBox.shrink(),
    );
    expect(page.transitionDuration, StudioMotionDurations.slow);
  });
}
