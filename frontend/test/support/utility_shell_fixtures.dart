import 'package:go_router/go_router.dart';
import 'package:openflow_app/home_page.dart';
import 'package:openflow_app/rust_api/settings/billing_webhook_events.dart';
import 'package:openflow_app/rust_api/settings/outbound_webhooks.dart';
import 'package:openflow_app/shell/home_shell_mode.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

import 'help_hub_fixtures.dart';

/// Product shell GoRouter for utility-pane widget tests (zh-friendly, debug auth).
GoRouter buildProductShellTestRouter({
  String initialLocation = '/',
  ProductWorkspacePane? initialPane,
  OutboundWebhookListResponseV1? debugHelpHubWebhooks,
  OutboundWebhookCreatedResponseV1? debugHelpHubLatestCreatedWebhook,
  BillingWebhookEventsResponseV1? debugHelpHubBillingEventsPage,
  Map<String, OutboundWebhookDeliveryListResponseV1>? debugHelpHubWebhookDeliveries,
  Map<String, OutboundWebhookTestResponseV1>? debugHelpHubWebhookLastTestResults,
}) {
  HomePage shellHome({ProductWorkspacePane? pane}) {
    return HomePage(
      shellMode: HomeShellMode.product,
      initialProductPane: pane ?? initialPane,
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

  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => shellHome()),
      GoRoute(
        path: '/notifications',
        redirect: (context, state) => '/?pane=notifications',
      ),
      GoRoute(path: '/help', redirect: (context, state) => '/?pane=help'),
      GoRoute(
        path: '/settings',
        redirect: (context, state) => '/?pane=settings',
      ),
      GoRoute(
        path: '/settings/models',
        builder: (context, state) =>
            shellHome(pane: ProductWorkspacePane.platformConfig),
      ),
      GoRoute(
        path: '/platform-status',
        builder: (context, state) =>
            shellHome(pane: ProductWorkspacePane.platformStatus),
      ),
    ],
  );
}

/// GoRouter that opens the platform status pane (non–shell-home path avoids pane resync).
GoRouter buildPlatformStatusTestRouter() {
  return buildProductShellTestRouter(
    initialLocation: '/platform-status',
    initialPane: ProductWorkspacePane.platformStatus,
  );
}

/// GoRouter that opens the platform config pane (mirrors integration gallery).
GoRouter buildPlatformConfigTestRouter() {
  return buildProductShellTestRouter(
    initialLocation: '/settings/models',
    initialPane: ProductWorkspacePane.platformConfig,
  );
}

/// GoRouter that opens Help Hub with debug webhook/billing seeds.
GoRouter buildHelpHubTestRouter() {
  return buildProductShellTestRouter(
    initialLocation: '/help',
    debugHelpHubWebhooks: buildHelpHubWebhookList(),
    debugHelpHubLatestCreatedWebhook: buildHelpHubLatestCreatedWebhook(),
    debugHelpHubBillingEventsPage: buildHelpHubBillingEventsPage(),
    debugHelpHubWebhookDeliveries: buildHelpHubWebhookDeliveries(),
    debugHelpHubWebhookLastTestResults: buildHelpHubWebhookLastTestResults(),
  );
}

/// GoRouter that opens the notifications utility pane.
GoRouter buildNotificationsUtilityTestRouter() {
  return buildProductShellTestRouter(initialLocation: '/notifications');
}
