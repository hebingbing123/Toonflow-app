import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api/settings/outbound_webhook_platform.dart';
import 'package:openflow_app/shell/outbound_webhook_event_chips.dart';

class _ChipsHarness extends StatefulWidget {
  const _ChipsHarness();

  @override
  State<_ChipsHarness> createState() => _ChipsHarnessState();
}

class _ChipsHarnessState extends State<_ChipsHarness> {
  late Set<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = Set<String>.from(kOutboundWebhookPlatformEventTypes);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(
        body: OutboundWebhookEventChips(
          selected: _sel,
          onSelectionChanged: (next) => setState(() => _sel = next),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('tapping Job完成 deselects job.completed', (tester) async {
    await tester.pumpWidget(const _ChipsHarness());
    final chipFinder = find.ancestor(
      of: find.text('作业完成'),
      matching: find.byType(FilterChip),
    );
    expect(tester.widget<FilterChip>(chipFinder).selected, isTrue);
    await tester.tap(find.text('作业完成'));
    await tester.pump();
    expect(tester.widget<FilterChip>(chipFinder).selected, isFalse);
  });

  testWidgets('enabled false leaves onSelected null', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: OutboundWebhookEventChips(
            selected: kOutboundWebhookPlatformEventTypes.toSet(),
            enabled: false,
            onSelectionChanged: (_) {},
          ),
        ),
      ),
    );
    final chipFinder = find.ancestor(
      of: find.text('作业完成'),
      matching: find.byType(FilterChip),
    );
    expect(tester.widget<FilterChip>(chipFinder).onSelected, isNull);
  });
}
