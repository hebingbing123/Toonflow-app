import 'package:openflow_app/rust_api/settings/billing_webhook_events.dart';
import 'package:openflow_app/rust_api/settings/outbound_webhooks.dart';

OutboundWebhookListResponseV1 buildHelpHubWebhookList() {
  return const OutboundWebhookListResponseV1(
    items: <OutboundWebhookListItemV1>[
      OutboundWebhookListItemV1(
        id: 'wh_alpha',
        url: 'https://hooks.example.com/a/really/long/webhook/path/alpha',
        createdAt: '2026-05-01T12:00:00Z',
        updatedAt: '2026-05-01T12:30:00Z',
        workspaceId: 'workspace-alpha',
        eventTypes: <String>['billing.invoice.paid', 'render.completed'],
      ),
      OutboundWebhookListItemV1(
        id: 'wh_beta',
        url: 'https://hooks.example.com/a/really/long/webhook/path/beta',
        createdAt: '2026-05-02T08:15:00Z',
        workspaceId: 'workspace-beta',
        eventTypes: <String>['publish.completed'],
        enabled: false,
      ),
    ],
  );
}

OutboundWebhookCreatedResponseV1 buildHelpHubLatestCreatedWebhook() {
  return const OutboundWebhookCreatedResponseV1(
    id: 'wh_alpha',
    url: 'https://hooks.example.com/a/really/long/webhook/path/alpha',
    secret: 'whsec_alpha_secret_value',
  );
}

BillingWebhookEventsResponseV1 buildHelpHubBillingEventsPage() {
  return BillingWebhookEventsResponseV1(
    items: <BillingWebhookEventItemV1>[
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

Map<String, OutboundWebhookDeliveryListResponseV1>
buildHelpHubWebhookDeliveries() {
  return const <String, OutboundWebhookDeliveryListResponseV1>{
    'wh_alpha': OutboundWebhookDeliveryListResponseV1(
      items: <OutboundWebhookDeliveryItemV1>[
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

Map<String, OutboundWebhookTestResponseV1> buildHelpHubWebhookLastTestResults() {
  return const <String, OutboundWebhookTestResponseV1>{
    'wh_alpha': OutboundWebhookTestResponseV1(
      delivered: false,
      httpStatus: 502,
      error: 'bad gateway',
    ),
  };
}
