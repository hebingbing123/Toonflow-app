import '../l10n/app_localizations.dart';
import '../rust_api/settings/billing_webhook_events.dart';

/// Placeholder stored in error strings when the user must sign in; resolve in UI with [AppLocalizations.platformConfigPleaseSignIn].
const String kProductShellSignInErrorPlaceholder = '__product_shell_sign_in__';

int countWebhookActivity(Iterable<String> actions, String action) {
  return actions.where((entry) => entry == action).length;
}

/// Machine action slugs on webhook activity entries; localize for UI.
String webhookActivityActionLabel(AppLocalizations l10n, String action) {
  switch (action) {
    case 'created':
      return l10n.opsWhActivityActionCreated;
    case 'deleted':
      return l10n.opsWhActivityActionDeleted;
    case 'test_success':
      return l10n.opsWhActivityActionTestSuccess;
    case 'test_failed':
      return l10n.opsWhActivityActionTestFailed;
    default:
      return action;
  }
}

String webhookActivityTestSummary(
  AppLocalizations l10n, {
  required bool delivered,
  required int? httpStatus,
  required String? error,
}) {
  final status = httpStatus?.toString() ?? '-';
  if (delivered) {
    return l10n.opsWhActivitySummaryTestSuccess(status);
  }
  final trimmed = error?.trim();
  return l10n.opsWhActivitySummaryTestFailed(
    status,
    trimmed != null && trimmed.isNotEmpty
        ? trimmed
        : l10n.globalSearchUnknownError,
  );
}

String billingEventAggregationKey(AppLocalizations l10n, String? raw) {
  final normalized = raw?.trim() ?? '';
  if (normalized.isEmpty) {
    return l10n.globalSearchUnknownError;
  }
  return normalized;
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
  AppLocalizations l10n,
  Iterable<BillingWebhookEventItemV1> items,
) {
  final counts = <String, int>{};
  for (final item in items) {
    final key = billingEventAggregationKey(l10n, item.provider);
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

Map<String, int> countBillingEventsByType(
  AppLocalizations l10n,
  Iterable<BillingWebhookEventItemV1> items,
) {
  final counts = <String, int>{};
  for (final item in items) {
    final key = billingEventAggregationKey(l10n, item.eventType);
    counts.update(key, (value) => value + 1, ifAbsent: () => 1);
  }
  return counts;
}

String buildBillingEventsSnapshotSummary(
  AppLocalizations l10n,
  Iterable<BillingWebhookEventItemV1> items,
) {
  final list = items.toList(growable: false);
  final providerCounts = countBillingEventsByProvider(l10n, list).entries
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final typeCounts = countBillingEventsByType(l10n, list).entries.toList()
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
