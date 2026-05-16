import '../l10n/app_localizations.dart';
import '../rust_api/settings/billing_webhook_events.dart';

/// Placeholder stored in error strings when the user must sign in; resolve in UI with [AppLocalizations.platformConfigPleaseSignIn].
const String kProductShellSignInErrorPlaceholder = '__product_shell_sign_in__';

int countWebhookActivity(Iterable<String> actions, String action) {
  return actions.where((entry) => entry == action).length;
}

String buildWebhookInventorySummary(
  AppLocalizations l10n, {
  required int total,
  required int filtered,
  required int sessionTestOkCount,
  required int sessionTestFailedCount,
  String? latestWebhookId,
}) {
  final latestPart = latestWebhookId == null
      ? ''
      : l10n.opsWhInventoryLatestPart(latestWebhookId);
  return l10n.opsWhInventoryLine(
    total,
    filtered,
    sessionTestOkCount,
    sessionTestFailedCount,
    latestPart,
  );
}

String? describeOutboundWebhookEmptyState(
  AppLocalizations l10n, {
  required int total,
  required int filtered,
}) {
  if (total == 0) {
    return l10n.opsWhEmptyNone;
  }
  if (filtered == 0) {
    return l10n.opsWhEmptyFiltered;
  }
  return null;
}

String? describeBillingWebhookEmptyState(
  AppLocalizations l10n, {
  required bool hasPage,
  required int loaded,
  required bool isLoading,
  required String? error,
}) {
  if (!hasPage || loaded > 0 || isLoading || error != null) {
    return null;
  }
  return l10n.billingEmptyQuery;
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
  AppLocalizations l10n,
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
    l10n.billingSnapLoaded(list.length),
    l10n.billingSnapInformational(informational),
    l10n.billingSnapStateful(stateful),
    l10n.billingSnapProviders(
      providerCounts.map((e) => '${e.key}:${e.value}').join(', '),
    ),
    l10n.billingSnapEventTypes(
      typeCounts.take(8).map((e) => '${e.key}:${e.value}').join(', '),
    ),
  ].join('\n');
}
