import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/shell/job_queue_stats_card.dart';

void main() {
  testWidgets('JobQueueStatsCard shows localized title and refresh label',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(body: JobQueueStatsCard()),
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(JobQueueStatsCard)),
    )!;

    expect(find.text(l10n.shellJobQueueStatsTitle), findsOneWidget);
    expect(find.text(l10n.helpHubRefresh), findsOneWidget);
  });
}
