import '../rust_api/settings/billing_webhook_events.dart';

int countWebhookActivity(Iterable<String> actions, String action) {
  return actions.where((entry) => entry == action).length;
}

String buildWebhookInventorySummary({
  required int total,
  required int filtered,
  required int sessionTestOkCount,
  required int sessionTestFailedCount,
  String? latestWebhookId,
}) {
  return [
    'total=$total',
    'filtered=$filtered',
    'session test ok=$sessionTestOkCount',
    'session test failed=$sessionTestFailedCount',
    if (latestWebhookId != null) 'latest=$latestWebhookId',
  ].join(' · ');
}

String? describeOutboundWebhookEmptyState({
  required int total,
  required int filtered,
}) {
  if (total == 0) {
    return '当前还没有配置任何出站 Webhook。可直接在上方创建，并在此处测试投递与删除。';
  }
  if (filtered == 0) {
    return '当前筛选没有命中任何 Webhook，请调整 URL / id / createdAt 搜索关键字。';
  }
  return null;
}

String? describeBillingWebhookEmptyState({
  required bool hasPage,
  required int loaded,
  required bool isLoading,
  required String? error,
}) {
  if (!hasPage || loaded > 0 || isLoading || error != null) {
    return null;
  }
  return '当前查询没有命中任何 billing webhook 审计事件，可调整 provider、event id、时间窗或 informational 条件后重试。';
}

Map<String, int> countBillingEventsByProvider(
  Iterable<BillingWebhookEventItemV1> items,
) {
  final counts = <String, int>{};
  for (final item in items) {
    final normalized = item.provider?.trim() ?? '';
    final key = normalized.isEmpty ? 'unknown' : normalized;
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

Map<String, int> countBillingEventsByType(
  Iterable<BillingWebhookEventItemV1> items,
) {
  final counts = <String, int>{};
  for (final item in items) {
    final normalized = item.eventType?.trim() ?? '';
    final key = normalized.isEmpty ? 'unknown' : normalized;
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

String buildBillingEventsSnapshotSummary(
  Iterable<BillingWebhookEventItemV1> items,
) {
  final list = items.toList(growable: false);
  final providerCounts = countBillingEventsByProvider(list).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final typeCounts = countBillingEventsByType(list).entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final informational = list.where((e) => e.isInformationalEvent).length;
  final stateful = list.length - informational;
  return [
    'loaded=${list.length}',
    'informational=$informational',
    'stateful=$stateful',
    'providers=${providerCounts.map((e) => '${e.key}:${e.value}').join(', ')}',
    'event_types=${typeCounts.take(8).map((e) => '${e.key}:${e.value}').join(', ')}',
  ].join('\n');
}
