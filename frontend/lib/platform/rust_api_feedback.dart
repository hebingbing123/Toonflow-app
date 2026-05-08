import 'package:flutter/material.dart';

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
  return error.statusCode == 429 ||
      RustApiErrorDetails.tryParse(error.message)?.code == 'quota_exceeded';
}

String describeRustApiError(Object error) {
  if (error is RustApiException) {
    return formatRustApiException(error);
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

/// Shows a SnackBar for [RustApiException] or any error using [formatRustApiException].
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
