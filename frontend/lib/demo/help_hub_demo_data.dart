import '../rust_api.dart';

OutboundWebhookListResponseV1 buildDemoHelpHubWebhookList() {
  return const OutboundWebhookListResponseV1(
    items: <OutboundWebhookListItemV1>[
      OutboundWebhookListItemV1(
        id: 'wh_demo_alpha',
        url: 'https://hooks.example.com/demo/render-ready',
        createdAt: '2026-05-01T12:00:00Z',
        updatedAt: '2026-05-01T12:30:00Z',
        workspaceId: 'workspace-demo',
        eventTypes: <String>['billing.invoice.paid', 'render.completed'],
      ),
      OutboundWebhookListItemV1(
        id: 'wh_demo_beta',
        url: 'https://hooks.example.com/demo/publish',
        createdAt: '2026-05-02T08:15:00Z',
        workspaceId: 'workspace-demo',
        eventTypes: <String>['publish.completed'],
        enabled: false,
      ),
    ],
  );
}

OutboundWebhookCreatedResponseV1 buildDemoHelpHubLatestCreatedWebhook() {
  return const OutboundWebhookCreatedResponseV1(
    id: 'wh_demo_alpha',
    url: 'https://hooks.example.com/demo/render-ready',
    secret: 'whsec_demo_secret_value',
  );
}

BillingWebhookEventsResponseV1 buildDemoHelpHubBillingEventsPage() {
  return BillingWebhookEventsResponseV1(
    items: <BillingWebhookEventItemV1>[
      BillingWebhookEventItemV1(
        id: 101,
        providerEventId: 'evt_demo_101',
        provider: 'stripe',
        rawEventId: 'raw_evt_demo_101',
        eventType: 'invoice.paid',
        eventCreatedAt: DateTime.utc(2026, 5, 1, 12),
        isInformationalEvent: false,
        createdAt: DateTime.utc(2026, 5, 1, 12, 1),
      ),
    ],
    total: 1,
    limit: 25,
    offset: 0,
    hasMore: false,
    nextOffset: null,
  );
}

Map<String, OutboundWebhookDeliveryListResponseV1>
buildDemoHelpHubWebhookDeliveries() {
  return const <String, OutboundWebhookDeliveryListResponseV1>{
    'wh_demo_alpha': OutboundWebhookDeliveryListResponseV1(
      items: <OutboundWebhookDeliveryItemV1>[
        OutboundWebhookDeliveryItemV1(
          id: 'del_demo_1',
          eventType: 'render.completed',
          status: 'delivered',
          httpStatus: 200,
          error: null,
          retryCount: 0,
          createdAt: '2026-05-01T12:05:00Z',
          deliveredAt: '2026-05-01T12:05:01Z',
        ),
      ],
    ),
  };
}

HelpHubConfigResponseV1 buildDemoHelpHubConfig() {
  const items = <HelpHubLinkItemV1>[
    HelpHubLinkItemV1(
      id: 'docs-getting-started',
      title: 'Getting started (demo)',
      url: 'https://docs.example.com/toonflow/getting-started',
    ),
    HelpHubLinkItemV1(
      id: 'docs-studio-sop',
      title: 'Studio SOP guide (demo)',
      url: 'https://docs.example.com/toonflow/studio-sop',
    ),
    HelpHubLinkItemV1(
      id: 'docs-billing-faq',
      title: 'Billing & webhooks FAQ (demo)',
      url: 'https://docs.example.com/toonflow/billing',
    ),
  ];
  return HelpHubConfigResponseV1(
    workspaceId: 'workspace-demo',
    canManageWorkspace: true,
    envItems: items,
    workspaceItems: items,
    userItems: const <HelpHubLinkItemV1>[],
    effectiveItems: items,
  );
}

Map<String, OutboundWebhookTestResponseV1> buildDemoHelpHubWebhookLastTestResults() {
  return const <String, OutboundWebhookTestResponseV1>{
    'wh_demo_alpha': OutboundWebhookTestResponseV1(
      delivered: true,
      httpStatus: 200,
      error: null,
    ),
  };
}
