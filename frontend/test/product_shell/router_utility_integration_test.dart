import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openflow_app/rust_api/settings/billing_webhook_events.dart';
import 'package:openflow_app/rust_api/settings/outbound_webhooks.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

import '../support/help_hub_fixtures.dart';
import '../support/product_shell_test_app.dart';
import '../support/utility_shell_fixtures.dart';

GoRouter _utilityRouter(
  String initialLocation, {
  ProductWorkspacePane? initialPane,
  OutboundWebhookListResponseV1? debugHelpHubWebhooks,
  OutboundWebhookCreatedResponseV1? debugHelpHubLatestCreatedWebhook,
  BillingWebhookEventsResponseV1? debugHelpHubBillingEventsPage,
  Map<String, OutboundWebhookDeliveryListResponseV1>?
  debugHelpHubWebhookDeliveries,
  Map<String, OutboundWebhookTestResponseV1>?
  debugHelpHubWebhookLastTestResults,
}) {
  return buildProductShellTestRouter(
    initialLocation: initialLocation,
    initialPane: initialPane,
    debugHelpHubWebhooks: debugHelpHubWebhooks,
    debugHelpHubLatestCreatedWebhook: debugHelpHubLatestCreatedWebhook,
    debugHelpHubBillingEventsPage: debugHelpHubBillingEventsPage,
    debugHelpHubWebhookDeliveries: debugHelpHubWebhookDeliveries,
    debugHelpHubWebhookLastTestResults: debugHelpHubWebhookLastTestResults,
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

    await tester.pumpWidget(
      productShellRouterTestApp(router, locale: const Locale('en')),
    );
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

    await tester.pumpWidget(
      productShellRouterTestApp(router, locale: const Locale('en')),
    );
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

    await tester.pumpWidget(
      productShellRouterTestApp(router, locale: const Locale('en')),
    );
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

    await tester.pumpWidget(
      productShellRouterTestApp(
        router,
        size: const Size(1280, 900),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      productShellRouterTestApp(
        router,
        size: const Size(1180, 900),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      productShellRouterTestApp(
        router,
        size: const Size(1080, 900),
        locale: const Locale('en'),
      ),
    );
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

    await tester.pumpWidget(
      productShellRouterTestApp(
        router,
        size: const Size(1366, 768),
        locale: const Locale('en'),
      ),
    );
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
        debugHelpHubWebhooks: buildHelpHubWebhookList(),
        debugHelpHubLatestCreatedWebhook: buildHelpHubLatestCreatedWebhook(),
        debugHelpHubBillingEventsPage: buildHelpHubBillingEventsPage(),
        debugHelpHubWebhookDeliveries: buildHelpHubWebhookDeliveries(),
        debugHelpHubWebhookLastTestResults:
            buildHelpHubWebhookLastTestResults(),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        productShellRouterTestApp(
          router,
          size: const Size(1366, 768),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Outbound webhooks'));
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

      await tester.tap(find.text('Billing webhook audit'));
      await tester.pumpAndSettle();

      expect(find.text('Billing webhook audit'), findsWidgets);
      expect(find.text('Provider'), findsWidgets);
      expect(find.text('Sort'), findsWidgets);
      expect(find.text('Informational only'), findsOneWidget);
      expect(find.text('Stateful only'), findsOneWidget);
      expect(find.text('Event type'), findsWidgets);
      expect(find.text('Provider event ID'), findsWidgets);
      expect(find.text('Raw event ID'), findsWidgets);
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

    await tester.pumpWidget(
      productShellRouterTestApp(router, locale: const Locale('en')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform configuration'), findsAtLeastNWidgets(1));
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/settings/models',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('platform status route opens platform status pane', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = buildPlatformStatusTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      productShellRouterTestApp(router, locale: const Locale('en')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Platform status'), findsAtLeastNWidgets(1));
    expect(find.text('Refresh'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/platform-status',
    );
    expect(tester.takeException(), isNull);
  });
}
