import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../rust_api/core.dart';

/// Root [ScaffoldMessenger] for API errors when no local [BuildContext] is in scope.
final GlobalKey<ScaffoldMessengerState> kRustApiRootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(
      debugLabel: 'rustApiRootScaffoldMessenger',
    );

bool isRustApiQuotaOrRateError(Object error) {
  if (error is! RustApiException) {
    return false;
  }
  final code = RustApiErrorDetails.tryParse(error.message)?.code;
  return error.statusCode == 429 ||
      code == 'quota_exceeded' ||
      code == 'concurrent_limit_exceeded';
}

String describeRustApiError(Object error) {
  return describeUserVisibleApiError(rustApiLookupL10nFromPlatform(), error);
}

void reportRustApiError(
  Object error, {
  required void Function(String? error) onErrorChanged,
  bool showGlobalSnackBar = true,
}) {
  onErrorChanged(describeRustApiError(error));
  if (showGlobalSnackBar && error is RustApiException) {
    showRustApiErrorSnackBar(error);
  }
}

/// Same split as the common `on RustApiException` + `catch` pair: [RustApiException] goes through
/// [reportRustApiError] (global SnackBar by default); anything else uses [describeUserVisibleApiError]
/// with [l10n] when provided, otherwise [rustApiLookupL10nFromPlatform].
void reportRustOrDescribeApiError(
  Object error, {
  required void Function(String? error) onErrorChanged,
  AppLocalizations? l10n,
  bool showGlobalSnackBar = true,
}) {
  if (error is RustApiException) {
    reportRustApiError(
      error,
      onErrorChanged: onErrorChanged,
      showGlobalSnackBar: showGlobalSnackBar,
    );
  } else {
    onErrorChanged(
      describeUserVisibleApiError(l10n ?? rustApiLookupL10nFromPlatform(), error),
    );
  }
}

/// Shows a SnackBar using [describeRustApiError] (delegates to [describeUserVisibleApiError]).
void showRustApiErrorSnackBar(Object error) {
  final messenger = kRustApiRootScaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }
  final text = describeRustApiError(error);
  final isRate = isRustApiQuotaOrRateError(error);
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: Duration(seconds: isRate ? 8 : 5),
    ),
  );
}
