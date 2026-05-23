import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/api_keys/controller.dart';
import 'package:openflow_app/api_keys/section.dart';
import 'package:openflow_app/design_system/theme.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/rust_api.dart';

import '../support/studio_collapsible_filter_test_support.dart';

Widget _wrapApp({required Widget child}) {
  return MaterialApp(
    theme: buildStudioDarkTheme(useGoogleFonts: false),
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: ListView(children: [child])),
  );
}

ApiKeysController _buildController() {
  return ApiKeysController(
    accessTokenProvider: () => null,
    onErrorChanged: (_) {},
    l10nProvider: () => null,
  );
}

void main() {
  testWidgets('api keys section compacts actions on mobile layouts', (
    tester,
  ) async {
    final controller = _buildController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapApp(child: ApiKeysSection(controller: controller)),
    );
    await tester.pumpAndSettle();
    await expandStudioCollapsibleFilterPanel(tester);

    expect(find.text('API keys'), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);

    final createButton = find.byWidgetPredicate(
      (widget) => widget is FilledButton && widget.onPressed != null,
    );
    expect(createButton, findsOneWidget);
    expect(tester.getSize(createButton).width, greaterThan(260));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'api keys section keeps labeled refresh action on wider layouts',
    (tester) async {
      final controller = _buildController();
      addTearDown(controller.dispose);

      await tester.binding.setSurfaceSize(const Size(900, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpWithExpandedStudioFilters(
        tester,
        _wrapApp(child: ApiKeysSection(controller: controller)),
      );

      expect(find.text('Refresh'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('api keys section renders deleted audit history entries', (
    tester,
  ) async {
    final controller = _buildController();
    addTearDown(controller.dispose);

    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrapApp(child: ApiKeysSection(controller: controller)),
    );
    await tester.pumpAndSettle();

    controller.auditItems = const <ApiKeyAuditRecordV1>[
      ApiKeyAuditRecordV1(
        id: 'audit-1',
        apiKeyId: 'key-1',
        eventType: 'deleted',
        eventSummary: 'api key deleted: desktop integration',
        metadata: <String, dynamic>{
          'scope': 'read_write',
          'publicId': 'deadbeefcafe',
        },
        createdAt: '2025-06-20T12:00:00Z',
      ),
    ];
    controller.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('api key deleted: desktop integration'), findsOneWidget);
    expect(find.textContaining('deleted'), findsWidgets);
    expect(find.text('scope: read_write'), findsOneWidget);
    expect(find.text('publicId: deadbeefcafe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
