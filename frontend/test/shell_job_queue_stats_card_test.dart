import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/l10n/studio_code_labels.dart';
import 'package:openflow_app/rust_api.dart';
import 'package:openflow_app/shell/job_queue_stats_card.dart';

void main() {
  Finder findTextSpan(String text) {
    return find.byWidgetPredicate(
      (widget) => widget is RichText && widget.text.toPlainText() == text,
    );
  }

  testWidgets('JobQueueStatsCard shows localized title and refresh label', (
    tester,
  ) async {
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

  testWidgets('JobQueueStatsCard renders structured stats after refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: JobQueueStatsCard(
            loadStats: () async => JobQueueStatsV1(
              pending: 7,
              pendingClaimable: 4,
              running: 2,
              dead: 1,
              failedLast24h: 3,
              oldestClaimableQueuedAgeSecs: 88,
              pendingByKind: <String, int>{'render': 5, 'export': 2},
            ),
          ),
        ),
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(JobQueueStatsCard)),
    )!;

    await tester.tap(find.text(l10n.helpHubRefresh));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      findTextSpan('${studioJobQueueMetricLabel(l10n, 'pending')} 7'),
      findsOneWidget,
    );
    expect(
      findTextSpan('${studioJobQueueMetricLabel(l10n, 'claimable')} 4'),
      findsOneWidget,
    );
    expect(
      find.text(studioJobQueueMetricLabel(l10n, 'pending_by_kind')),
      findsOneWidget,
    );
    expect(
      findTextSpan('${studioJobKindLabel(l10n, 'render')} 5'),
      findsOneWidget,
    );
    expect(
      findTextSpan('${studioJobKindLabel(l10n, 'export')} 2'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
