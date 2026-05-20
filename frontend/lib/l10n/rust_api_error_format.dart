import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

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
    if (details.code == 'subscription_expired') {
      return l10n.billingErrorSubscriptionExpired;
    }
    if (details.code == 'payment_failed') {
      return l10n.billingErrorPaymentFailed;
    }
    if (details.code == 'subscription_past_due') {
      return l10n.billingErrorSubscriptionPastDue;
    }
    if (details.code.startsWith('billing_')) {
      return l10n.rustApiClientUnknownError(error.toString());
    }
    if (error.statusCode == 429 || details.code == 'quota_exceeded') {
      final waitMs = details.retryAfterMs ?? error.retryAfterMsHint;
      final waitText = waitMs == null
          ? l10n.rustApiClientRetryAfterTryLater
          : formatRetryAfterMsForDisplay(l10n, waitMs);
      return l10n.rustApiClientQuotaOrRateWithWait(waitText);
    }
    return _compactGenericErrorMessage(l10n, details.message);
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
  if ((error.statusCode ?? 0) >= 500) {
    return l10n.rustApiClientUnknownError(l10n.rustApiClientRetryAfterTryLater);
  }
  final trimmed = error.message.trim();
  if (trimmed.isNotEmpty &&
      !trimmed.startsWith('{') &&
      !trimmed.startsWith('[')) {
    return _compactGenericErrorMessage(l10n, trimmed);
  }
  return l10n.rustApiClientUnknownError(error.toString());
}

/// User-visible message for API failures and other thrown values (e.g. [SnackBar]).
String describeUserVisibleApiError(AppLocalizations l10n, Object error) {
  if (error is RustApiException) {
    return formatRustApiExceptionForDisplay(l10n, error);
  }
  if (error is http.ClientException) {
    return l10n.rustApiClientUnknownError(
      _compactGenericErrorMessage(l10n, error.message),
    );
  }
  return l10n.rustApiClientUnknownError(
    _compactGenericErrorMessage(l10n, error.toString()),
  );
}

/// Same as [describeUserVisibleApiError], but resolves [AppLocalizations] from
/// [context] when handling the error.
///
/// Prefer in async **`catch`** (after **`await`**) instead of reusing an
/// [AppLocalizations] captured earlier or relying on [AppLocalizations.of]!.
String describeUserVisibleApiErrorResolved(
  BuildContext context,
  Object error,
) {
  return describeUserVisibleApiError(
    resolveAppLocalizationsForErrors(context),
    error,
  );
}

String compactUserVisibleApiErrorText(AppLocalizations l10n, String raw) {
  final localizedPrefixes = <String>[
    l10n.rustApiClientUnknownError('').trimRight(),
  ];
  for (final prefix in localizedPrefixes) {
    if (raw.startsWith(prefix)) {
      final detail = raw.substring(prefix.length).trimLeft();
      final separator = prefix.endsWith('：') ? '' : ' ';
      return '$prefix$separator${_compactGenericErrorMessage(l10n, detail)}'
          .trimRight();
    }
  }
  return _compactGenericErrorMessage(l10n, raw);
}

String _compactGenericErrorMessage(AppLocalizations l10n, String raw) {
  var compact = raw.trim();
  compact = compact.replaceFirst(RegExp(r'^(?:[A-Za-z]+)?Exception:\s*'), '');
  compact = compact.replaceFirst(RegExp(r'^Bad state:\s*'), '');
  compact = compact.replaceAll(RegExp(r',\s*uri=https?://\S+'), '');
  compact = compact.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (RegExp(
    r'error occurred while decoding column \d+: unexpected null',
    caseSensitive: false,
  ).hasMatch(compact)) {
    return l10n.rustApiClientRetryAfterTryLater;
  }
  if (compact.endsWith(',')) {
    compact = compact.substring(0, compact.length - 1).trim();
  }
  return compact.isEmpty ? l10n.rustApiClientRetryAfterTryLater : compact;
}

/// [AppLocalizations] from [context] when delegates are present; otherwise English lookup.
///
/// Prefer over [AppLocalizations.of]! in async error paths so tests and edge contexts
/// without a full localization subtree do not throw; aligns with controller
/// `_l10n ?? lookupAppLocalizations(const Locale('en'))` resolution.
AppLocalizations resolveAppLocalizationsForErrors(BuildContext context) {
  return AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('en'));
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
    Locale loc;
    try {
      loc = WidgetsBinding.instance.platformDispatcher.locale;
    } catch (_) {
      // Unit tests / headless contexts may run before binding init; default en.
      loc = const Locale('en');
    }
    code = loc.languageCode == 'zh' ? 'zh' : 'en';
  }
  return lookupAppLocalizations(Locale(code));
}
