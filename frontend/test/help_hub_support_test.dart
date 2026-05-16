import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_en.dart';
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
  final l10n = AppLocalizationsEn();

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
        l10n,
        total: 4,
        filtered: 2,
        sessionTestOkCount: 1,
        sessionTestFailedCount: 3,
        latestWebhookId: 'wh_123',
      ),
      'Total 4 · Filtered 2 · Session tests OK 1 · Failed 3 · Latest: wh_123',
    );
  });

  test('buildWebhookInventorySummary omits latest id when absent', () {
    expect(
      buildWebhookInventorySummary(
        l10n,
        total: 0,
        filtered: 0,
        sessionTestOkCount: 0,
        sessionTestFailedCount: 0,
      ),
      'Total 0 · Filtered 0 · Session tests OK 0 · Failed 0',
    );
  });

  test('describeOutboundWebhookEmptyState distinguishes zero and filtered out', () {
    expect(
      describeOutboundWebhookEmptyState(l10n, total: 0, filtered: 0),
      l10n.opsWhEmptyNone,
    );
    expect(
      describeOutboundWebhookEmptyState(l10n, total: 2, filtered: 0),
      l10n.opsWhEmptyFiltered,
    );
    expect(
      describeOutboundWebhookEmptyState(l10n, total: 2, filtered: 1),
      isNull,
    );
  });

  test('describeBillingWebhookEmptyState only shows for loaded-empty successful page', () {
    expect(
      describeBillingWebhookEmptyState(
        l10n,
        hasPage: true,
        loaded: 0,
        isLoading: false,
        error: null,
      ),
      l10n.billingEmptyQuery,
    );
    expect(
      describeBillingWebhookEmptyState(
        l10n,
        hasPage: false,
        loaded: 0,
        isLoading: false,
        error: null,
      ),
      isNull,
    );
    expect(
      describeBillingWebhookEmptyState(
        l10n,
        hasPage: true,
        loaded: 1,
        isLoading: false,
        error: null,
      ),
      isNull,
    );
    expect(
      describeBillingWebhookEmptyState(
        l10n,
        hasPage: true,
        loaded: 0,
        isLoading: true,
        error: null,
      ),
      isNull,
    );
    expect(
      describeBillingWebhookEmptyState(
        l10n,
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

    final summary = buildBillingEventsSnapshotSummary(l10n, items);
    expect(summary, contains('Loaded: 3'));
    expect(summary, contains('Informational: 1'));
    expect(summary, contains('Stateful: 2'));
    expect(summary, contains('Providers: stripe:2, alipay:1'));
    expect(
      summary,
      contains('Event types: invoice.paid:2, trade.success:1'),
    );
  });
}
