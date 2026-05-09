import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/rust_api/settings/billing_webhook_events.dart';
import 'package:openflow_app/shell/help_hub_support.dart';

BillingWebhookEventItemV1 billingEvent({
  required int id,
  required String providerEventId,
  String? provider,
  String? rawEventId,
  String? eventType,
  DateTime? eventCreatedAt,
  required bool informational,
  DateTime? createdAt,
}) {
  return BillingWebhookEventItemV1(
    id: id,
    providerEventId: providerEventId,
    provider: provider,
    rawEventId: rawEventId,
    eventType: eventType,
    eventCreatedAt: eventCreatedAt,
    isInformationalEvent: informational,
    createdAt: createdAt ?? DateTime.utc(2026, 5, 1),
  );
}

void main() {
  test('countWebhookActivity counts only matching actions', () {
    expect(
      countWebhookActivity(
        const ['created', 'test_success', 'test_failed', 'test_success'],
        'test_success',
      ),
      2,
    );
    expect(countWebhookActivity(const ['created'], 'test_failed'), 0);
  });

  test('buildWebhookInventorySummary includes latest id when present', () {
    expect(
      buildWebhookInventorySummary(
        total: 4,
        filtered: 2,
        sessionTestOkCount: 1,
        sessionTestFailedCount: 3,
        latestWebhookId: 'wh_123',
      ),
      'total=4 · filtered=2 · session test ok=1 · session test failed=3 · latest=wh_123',
    );
  });

  test('buildWebhookInventorySummary omits latest id when absent', () {
    expect(
      buildWebhookInventorySummary(
        total: 0,
        filtered: 0,
        sessionTestOkCount: 0,
        sessionTestFailedCount: 0,
      ),
      'total=0 · filtered=0 · session test ok=0 · session test failed=0',
    );
  });

  test('describeOutboundWebhookEmptyState distinguishes zero and filtered out', () {
    expect(
      describeOutboundWebhookEmptyState(total: 0, filtered: 0),
      '当前还没有配置任何出站 Webhook。可直接在上方创建，并在此处测试投递与删除。',
    );
    expect(
      describeOutboundWebhookEmptyState(total: 2, filtered: 0),
      '当前筛选没有命中任何 Webhook，请调整 URL / id / createdAt 搜索关键字。',
    );
    expect(describeOutboundWebhookEmptyState(total: 2, filtered: 1), isNull);
  });

  test('describeBillingWebhookEmptyState only shows for loaded-empty successful page', () {
    expect(
      describeBillingWebhookEmptyState(
        hasPage: true,
        loaded: 0,
        isLoading: false,
        error: null,
      ),
      '当前查询没有命中任何 billing webhook 审计事件，可调整 provider、event id、时间窗或 informational 条件后重试。',
    );
    expect(
      describeBillingWebhookEmptyState(
        hasPage: false,
        loaded: 0,
        isLoading: false,
        error: null,
      ),
      isNull,
    );
    expect(
      describeBillingWebhookEmptyState(
        hasPage: true,
        loaded: 1,
        isLoading: false,
        error: null,
      ),
      isNull,
    );
    expect(
      describeBillingWebhookEmptyState(
        hasPage: true,
        loaded: 0,
        isLoading: true,
        error: null,
      ),
      isNull,
    );
    expect(
      describeBillingWebhookEmptyState(
        hasPage: true,
        loaded: 0,
        isLoading: false,
        error: 'boom',
      ),
      isNull,
    );
  });

  test('billing event counters normalize unknown provider and type', () {
    final items = <BillingWebhookEventItemV1>[
      billingEvent(
        id: 1,
        providerEventId: 'evt_1',
        provider: 'stripe',
        eventType: 'invoice.paid',
        informational: false,
      ),
      billingEvent(
        id: 2,
        providerEventId: 'evt_2',
        provider: ' ',
        eventType: null,
        informational: true,
      ),
      billingEvent(
        id: 3,
        providerEventId: 'evt_3',
        provider: 'stripe',
        eventType: 'invoice.paid',
        informational: false,
      ),
    ];

    expect(countBillingEventsByProvider(items), {'stripe': 2, 'unknown': 1});
    expect(countBillingEventsByType(items), {'invoice.paid': 2, 'unknown': 1});
  });

  test('buildBillingEventsSnapshotSummary emits provider and type rollups', () {
    final items = <BillingWebhookEventItemV1>[
      billingEvent(
        id: 1,
        providerEventId: 'evt_1',
        provider: 'stripe',
        eventType: 'invoice.paid',
        informational: false,
      ),
      billingEvent(
        id: 2,
        providerEventId: 'evt_2',
        provider: 'alipay',
        eventType: 'trade.success',
        informational: true,
      ),
      billingEvent(
        id: 3,
        providerEventId: 'evt_3',
        provider: 'stripe',
        eventType: 'invoice.paid',
        informational: false,
      ),
    ];

    final summary = buildBillingEventsSnapshotSummary(items);
    expect(summary, contains('loaded=3'));
    expect(summary, contains('informational=1'));
    expect(summary, contains('stateful=2'));
    expect(summary, contains('providers=stripe:2, alipay:1'));
    expect(summary, contains('event_types=invoice.paid:2, trade.success:1'));
  });
}
