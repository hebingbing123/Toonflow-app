import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/design_system/studio_adaptive_theme.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/product_shell/studio_theme.dart';
import 'package:openflow_app/rust_api/settings/billing_webhook_events.dart';
import 'package:openflow_app/rust_api/settings/outbound_webhooks.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

Widget _routerApp(GoRouter router, {Size size = const Size(1440, 900)}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp.router(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: StudioTheme.build(),
      builder: (context, widget) => Theme(
        data: studioAdaptiveDesktopTheme(context),
        child: widget ?? const SizedBox(),
      ),
      routerConfig: router,
    ),
  );
}

HomePage _shellHome({
  ProductWorkspacePane? initialPane,
  OutboundWebhookListResponseV1? debugHelpHubWebhooks,
  OutboundWebhookCreatedResponseV1? debugHelpHubLatestCreatedWebhook,
  BillingWebhookEventsResponseV1? debugHelpHubBillingEventsPage,
  Map<String, OutboundWebhookDeliveryListResponseV1>?
  debugHelpHubWebhookDeliveries,
  Map<String, OutboundWebhookTestResponseV1>?
  debugHelpHubWebhookLastTestResults,
}) {
  return HomePage(
    shellMode: HomeShellMode.product,
    initialProductPane: initialPane,
    debugAuthenticatedAccessToken: 'test-token',
    debugSkipSessionContextSync: true,
    debugSkipAuthListenerAttach: true,
    debugHelpHubWebhooks: debugHelpHubWebhooks,
    debugHelpHubLatestCreatedWebhook: debugHelpHubLatestCreatedWebhook,
    debugHelpHubBillingEventsPage: debugHelpHubBillingEventsPage,
    debugHelpHubWebhookDeliveries: debugHelpHubWebhookDeliveries,
    debugHelpHubWebhookLastTestResults: debugHelpHubWebhookLastTestResults,
  );
}

OutboundWebhookListResponseV1 _debugWebhookList() {
  return const OutboundWebhookListResponseV1(
    items: [
      OutboundWebhookListItemV1(
        id: 'wh_alpha',
        url: 'https://hooks.example.com/a/really/long/webhook/path/alpha',
        createdAt: '2026-05-01T12:00:00Z',
        updatedAt: '2026-05-01T12:30:00Z',
        workspaceId: 'workspace-alpha',
        eventTypes: ['billing.invoice.paid', 'render.completed'],
      ),
      OutboundWebhookListItemV1(
        id: 'wh_beta',
        url: 'https://hooks.example.com/a/really/long/webhook/path/beta',
        createdAt: '2026-05-02T08:15:00Z',
        workspaceId: 'workspace-beta',
        eventTypes: ['publish.completed'],
        enabled: false,
      ),
    ],
  );
}

OutboundWebhookCreatedResponseV1 _debugLatestCreatedWebhook() {
  return const OutboundWebhookCreatedResponseV1(
    id: 'wh_alpha',
    url: 'https://hooks.example.com/a/really/long/webhook/path/alpha',
    secret: 'whsec_alpha_secret_value',
  );
}

BillingWebhookEventsResponseV1 _debugBillingEventsPage() {
  return BillingWebhookEventsResponseV1(
    items: [
      BillingWebhookEventItemV1(
        id: 101,
        providerEventId: 'evt_101',
        provider: 'stripe',
        rawEventId: 'raw_evt_101',
        eventType: 'invoice.paid',
        eventCreatedAt: DateTime.utc(2026, 5, 1, 12),
        isInformationalEvent: false,
        createdAt: DateTime.utc(2026, 5, 1, 12, 1),
      ),
      BillingWebhookEventItemV1(
        id: 102,
        providerEventId: 'evt_102',
        provider: 'stripe',
        rawEventId: 'raw_evt_102',
        eventType: 'customer.subscription.updated',
        eventCreatedAt: DateTime.utc(2026, 5, 1, 12, 30),
        isInformationalEvent: true,
        createdAt: DateTime.utc(2026, 5, 1, 12, 31),
      ),
    ],
    total: 3,
    limit: 25,
    offset: 0,
    hasMore: true,
    nextOffset: 2,
  );
}

Map<String, OutboundWebhookDeliveryListResponseV1> _debugWebhookDeliveries() {
  return const {
    'wh_alpha': OutboundWebhookDeliveryListResponseV1(
      items: [
        OutboundWebhookDeliveryItemV1(
          id: 'del_1',
          eventType: 'billing.invoice.paid',
          status: 'delivered',
          httpStatus: 200,
          error: null,
          retryCount: 0,
          createdAt: '2026-05-01T12:05:00Z',
          deliveredAt: '2026-05-01T12:05:01Z',
        ),
        OutboundWebhookDeliveryItemV1(
          id: 'del_2',
          eventType: 'render.completed',
          status: 'failed',
          httpStatus: 500,
          error: 'upstream timeout after retry',
          retryCount: 2,
          createdAt: '2026-05-01T12:06:00Z',
        ),
      ],
    ),
  };
}

Map<String, OutboundWebhookTestResponseV1> _debugWebhookLastTestResults() {
  return const {
    'wh_alpha': OutboundWebhookTestResponseV1(
      delivered: false,
      httpStatus: 502,
      error: 'bad gateway',
    ),
  };
}

GoRouter _utilityRouter(
  String initialLocation, {
  OutboundWebhookListResponseV1? debugHelpHubWebhooks,
  OutboundWebhookCreatedResponseV1? debugHelpHubLatestCreatedWebhook,
  BillingWebhookEventsResponseV1? debugHelpHubBillingEventsPage,
  Map<String, OutboundWebhookDeliveryListResponseV1>?
  debugHelpHubWebhookDeliveries,
  Map<String, OutboundWebhookTestResponseV1>?
  debugHelpHubWebhookLastTestResults,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => _shellHome(
          debugHelpHubWebhooks: debugHelpHubWebhooks,
          debugHelpHubLatestCreatedWebhook: debugHelpHubLatestCreatedWebhook,
          debugHelpHubBillingEventsPage: debugHelpHubBillingEventsPage,
          debugHelpHubWebhookDeliveries: debugHelpHubWebhookDeliveries,
          debugHelpHubWebhookLastTestResults:
              debugHelpHubWebhookLastTestResults,
        ),
      ),
      GoRoute(
        path: '/notifications',
        redirect: (context, state) => '/?pane=notifications',
      ),
      GoRoute(
        path: '/settings',
        redirect: (context, state) => '/?pane=settings',
      ),
      GoRoute(path: '/help', redirect: (context, state) => '/?pane=help'),
      GoRoute(
        path: '/settings/models',
        builder: (context, state) => _shellHome(
          initialPane: ProductWorkspacePane.platformConfig,
          debugHelpHubWebhooks: debugHelpHubWebhooks,
          debugHelpHubLatestCreatedWebhook: debugHelpHubLatestCreatedWebhook,
          debugHelpHubBillingEventsPage: debugHelpHubBillingEventsPage,
          debugHelpHubWebhookDeliveries: debugHelpHubWebhookDeliveries,
          debugHelpHubWebhookLastTestResults:
              debugHelpHubWebhookLastTestResults,
        ),
      ),
    ],
  );
}

void main() {
  testWidgets('notifications utility route redirects into shell pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/notifications');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsAtLeastNWidgets(1));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/?pane=notifications',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings utility route redirects into shell pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/settings');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsAtLeastNWidgets(1));
    expect(find.text('Account'), findsAtLeastNWidgets(1));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/?pane=settings',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('help utility route redirects into shell pane', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/help');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Help / docs'), findsAtLeastNWidgets(1));
    expect(router.routeInformationProvider.value.uri.toString(), '/?pane=help');
    expect(tester.takeException(), isNull);
  });

  testWidgets('help utility route stays stable on tighter desktop width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/help');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router, size: const Size(1280, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Help / docs'), findsAtLeastNWidgets(1));
    expect(router.routeInformationProvider.value.uri.toString(), '/?pane=help');
    expect(tester.takeException(), isNull);
  });

  testWidgets('help utility route stays stable on compact desktop width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/help');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router, size: const Size(1180, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Help / docs'), findsAtLeastNWidgets(1));
    expect(router.routeInformationProvider.value.uri.toString(), '/?pane=help');
    expect(tester.takeException(), isNull);
  });

  testWidgets('help utility route stays stable on narrow desktop width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/help');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router, size: const Size(1080, 900)));
    await tester.pumpAndSettle();

    expect(find.text('Help / docs'), findsAtLeastNWidgets(1));
    expect(router.routeInformationProvider.value.uri.toString(), '/?pane=help');
    expect(tester.takeException(), isNull);
  });

  testWidgets('help utility route stays stable on common laptop viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1366, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/help');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router, size: const Size(1366, 768)));
    await tester.pumpAndSettle();

    expect(find.text('Help / docs'), findsAtLeastNWidgets(1));
    expect(router.routeInformationProvider.value.uri.toString(), '/?pane=help');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'help utility route shows seeded webhook and billing audit cards on common laptop viewport',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = _utilityRouter(
        '/help',
        debugHelpHubWebhooks: _debugWebhookList(),
        debugHelpHubLatestCreatedWebhook: _debugLatestCreatedWebhook(),
        debugHelpHubBillingEventsPage: _debugBillingEventsPage(),
        debugHelpHubWebhookDeliveries: _debugWebhookDeliveries(),
        debugHelpHubWebhookLastTestResults: _debugWebhookLastTestResults(),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_routerApp(router, size: const Size(1366, 768)));
      await tester.pumpAndSettle();

      expect(find.text('Latest created webhook credentials'), findsOneWidget);
      expect(
        find.text('https://hooks.example.com/a/really/long/webhook/path/alpha'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Recent deliveries'), findsOneWidget);
      expect(
        find.textContaining('billing.invoice.paid'),
        findsAtLeastNWidgets(1),
      );
      expect(
        find.textContaining('upstream timeout after retry'),
        findsOneWidget,
      );
      expect(find.textContaining('HTTP 502'), findsOneWidget);
      expect(find.text('Current load summary'), findsOneWidget);
      expect(find.text('Copy audit snapshot'), findsOneWidget);
      expect(find.text('Copy provider_event_id'), findsAtLeastNWidgets(1));
      expect(find.text('Copy raw_event_id'), findsAtLeastNWidgets(1));
      expect(find.text('Filter by stripe'), findsAtLeastNWidgets(1));
      expect(
        find.text('Filter by customer.subscription.updated'),
        findsOneWidget,
      );
      expect(find.text('Only this event'), findsAtLeastNWidgets(1));
      expect(find.text('Load more'), findsOneWidget);
      expect(find.text('total=3 · loaded=2 · has_more=true'), findsOneWidget);
      expect(find.text('Delivery log'), findsAtLeastNWidgets(1));
      expect(find.text('Test delivery'), findsAtLeastNWidgets(1));
      expect(find.text('Delete'), findsAtLeastNWidgets(1));
      expect(find.text('Copy secret'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/?pane=help',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('settings models route opens platform config pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = _utilityRouter('/settings/models');
    addTearDown(router.dispose);

    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    expect(find.text('Platform configuration'), findsAtLeastNWidgets(1));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/settings/models',
    );
    expect(tester.takeException(), isNull);
  });
}
