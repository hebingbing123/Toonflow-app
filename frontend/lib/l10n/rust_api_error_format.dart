import 'package:flutter/widgets.dart';

import '../locale/app_locale_notifier.dart';
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

/// User-visible message for API failures and other thrown values (e.g. [SnackBar]).
String describeUserVisibleApiError(AppLocalizations l10n, Object error) {
  if (error is RustApiException) {
    return formatRustApiExceptionForDisplay(l10n, error);
  }
  return l10n.rustApiClientUnknownError(error.toString());
}

/// When no [BuildContext] is available (e.g. global snackbars, controllers).
///
/// Uses [AppLocaleNotifier] when the user pinned `en` or `zh`; otherwise
/// follows the platform dispatcher (same idea as `locale: null` + resolution).
AppLocalizations rustApiLookupL10nFromPlatform() {
  final explicit = AppLocaleNotifier.instance.localeOrNull;
  final String code;
  if (explicit != null) {
    code = explicit.languageCode == 'zh' ? 'zh' : 'en';
  } else {
    final loc = WidgetsBinding.instance.platformDispatcher.locale;
    code = loc.languageCode == 'zh' ? 'zh' : 'en';
  }
  return lookupAppLocalizations(Locale(code));
}
