import 'package:flutter/widgets.dart';

import '../rust_api/core.dart';
import 'app_localizations.dart';

/// Localized “retry after” text for rate limits and backoff hints.
String formatRetryAfterMsForDisplay(AppLocalizations l10n, int retryAfterMs) {
  if (retryAfterMs <= 0) {
    return l10n.rustApiClientRetryAfterTryLater;
  }
  final totalSeconds = (retryAfterMs / 1000).ceil();
  if (totalSeconds < 60) {
    return l10n.rustApiClientRetryAfterSeconds(totalSeconds);
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  if (minutes < 60) {
    return seconds == 0
        ? l10n.rustApiClientRetryAfterMinutes(minutes)
        : l10n.rustApiClientRetryAfterMinutesSeconds(minutes, seconds);
  }
  final hours = minutes ~/ 60;
  final remainMinutes = minutes % 60;
  return remainMinutes == 0
      ? l10n.rustApiClientRetryAfterHours(hours)
      : l10n.rustApiClientRetryAfterHoursMinutes(hours, remainMinutes);
}

/// User-facing summary for [RustApiException] (client checks, JSON errors, HTTP status).
String formatRustApiExceptionForDisplay(
  AppLocalizations l10n,
  RustApiException error,
) {
  final details = RustApiErrorDetails.tryParse(error.message);
  if (details != null) {
    if (details.code == 'concurrent_limit_exceeded') {
      return l10n.rustApiClientConcurrentLimitExceeded;
    }
    if (error.statusCode == 429 || details.code == 'quota_exceeded') {
      final waitMs = details.retryAfterMs ?? error.retryAfterMsHint;
      final waitText = waitMs == null
          ? l10n.rustApiClientRetryAfterTryLater
          : formatRetryAfterMsForDisplay(l10n, waitMs);
      return l10n.rustApiClientQuotaOrRateWithWait(waitText);
    }
    return details.message;
  }
  if (error.statusCode == 429) {
    final waitMs = error.retryAfterMsHint;
    final waitText = waitMs == null
        ? l10n.rustApiClientRetryAfterTryLater
        : formatRetryAfterMsForDisplay(l10n, waitMs);
    return l10n.rustApiClientTooFrequentWithWait(waitText);
  }
  if (error.statusCode == 404) {
    return l10n.rustApiClientRecordNotFound;
  }
  if (error.statusCode == 499) {
    return l10n.rustApiClientRequestCancelled;
  }
  final trimmed = error.message.trim();
  if (trimmed.isNotEmpty &&
      !trimmed.startsWith('{') &&
      !trimmed.startsWith('[')) {
    return trimmed;
  }
  return l10n.rustApiClientUnknownError(error.toString());
}

/// When no [BuildContext] is available (e.g. global snackbars), follow platform locale.
AppLocalizations rustApiLookupL10nFromPlatform() {
  final loc = WidgetsBinding.instance.platformDispatcher.locale;
  final code = loc.languageCode == 'zh' ? 'zh' : 'en';
  return lookupAppLocalizations(Locale(code));
}
