import 'package:flutter/material.dart';

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
  if (error is RustApiException) {
    return formatRustApiExceptionForDisplay(rustApiLookupL10nFromPlatform(), error);
  }
  return '$error';
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

/// Shows a SnackBar for [RustApiException] or any error using [formatRustApiExceptionForDisplay].
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
