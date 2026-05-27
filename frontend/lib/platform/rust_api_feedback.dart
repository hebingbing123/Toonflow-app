import 'package:flutter/material.dart';

import '../demo/product_demo_mode.dart';
import '../design_system/ix/studio_toast.dart';
import '../design_system/ix/studio_toast_overlay.dart';
import '../l10n/app_localizations.dart';
import '../l10n/rust_api_error_format.dart';
import '../rust_api/core.dart';
import '../shell/studio_settings_hub_navigation.dart';

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
  return describeUserVisibleApiError(
    rustApiLookupL10nFromPlatform(),
    error,
  );
}

void reportRustApiError(
  Object error, {
  required void Function(String? error) onErrorChanged,
  bool showGlobalSnackBar = true,
}) {
  if (ProductDemoMode.shouldSuppressDemoApiError(error)) {
    return;
  }
  onErrorChanged(describeRustApiError(error));
  if (showGlobalSnackBar && error is RustApiException) {
    showRustApiErrorSnackBar(error);
  }
}

/// Same split as the common `on RustApiException` + `catch` pair: [RustApiException] goes through
/// [reportRustApiError] (global SnackBar by default); anything else uses [describeUserVisibleApiError]
/// with [l10n] when provided, otherwise English [lookupAppLocalizations] (stable in tests / headless).
void reportRustOrDescribeApiError(
  Object error, {
  required void Function(String? error) onErrorChanged,
  AppLocalizations? l10n,
  bool showGlobalSnackBar = true,
}) {
  if (ProductDemoMode.shouldSuppressDemoApiError(error)) {
    return;
  }
  if (error is RustApiException) {
    reportRustApiError(
      error,
      onErrorChanged: onErrorChanged,
      showGlobalSnackBar: showGlobalSnackBar,
    );
  } else {
    onErrorChanged(
      describeUserVisibleApiError(
        l10n ?? lookupAppLocalizations(const Locale('en')),
        error,
      ),
    );
  }
}

/// Shows a top-right toast using [describeRustApiError].
void showRustApiErrorSnackBar(Object error) {
  if (ProductDemoMode.shouldSuppressDemoApiError(error)) {
    return;
  }
  final messenger = kRustApiRootScaffoldMessengerKey.currentState;
  final context = messenger?.context;
  if (context == null || !context.mounted) {
    return;
  }
  final l10n =
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('en'));
  final text = describeRustApiError(error);
  final isRate = isRustApiQuotaOrRateError(error);
  showStudioToast(
    context,
    message: text,
    tone: isRate ? StudioToastTone.warning : StudioToastTone.error,
    duration: Duration(seconds: isRate ? 8 : 5),
    actionLabel: isRate ? l10n.billingUpgradePlan : null,
    onAction: isRate ? StudioSettingsHubNavigation.openSubscribe : null,
  );
}

/// When [error] is a [RustApiException], shows the root SnackBar; then calls [onMessage]
/// with [describeUserVisibleApiError] using [l10n] (for Rust and non-Rust errors alike).
void showRustApiSnackBarIfRustThenDescribeUserVisible(
  Object error, {
  required AppLocalizations l10n,
  required void Function(String message) onMessage,
}) {
  if (error is RustApiException) {
    showRustApiErrorSnackBar(error);
  }
  onMessage(describeUserVisibleApiError(l10n, error));
}
