import 'package:flutter/material.dart';

import '../rust_api/core.dart';

/// Root [ScaffoldMessenger] for API errors when no local [BuildContext] is in scope.
final GlobalKey<ScaffoldMessengerState> kRustApiRootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>(
  debugLabel: 'rustApiRootScaffoldMessenger',
);

/// Shows a SnackBar for [RustApiException] or any error using [formatRustApiException].
void showRustApiErrorSnackBar(Object error) {
  final messenger = kRustApiRootScaffoldMessengerKey.currentState;
  if (messenger == null) {
    return;
  }
  final text = error is RustApiException
      ? formatRustApiException(error)
      : '$error';
  final isRate = error is RustApiException &&
      (error.statusCode == 429 ||
          RustApiErrorDetails.tryParse(error.message)?.code == 'quota_exceeded');
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      duration: Duration(seconds: isRate ? 8 : 5),
    ),
  );
}
