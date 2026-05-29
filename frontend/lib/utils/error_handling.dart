import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../l10n/rust_api_error_format.dart';
import '../rust_api/core.dart';

/// High-level error categories for UI routing (banner vs callout vs toast).
enum StudioErrorCategory {
  network,
  auth,
  validation,
  server,
  unknown,
}

/// Classifies [error] for presentation and retry policy.
StudioErrorCategory classifyStudioError(Object error) {
  if (studioLooksLikeConnectivityError(error)) {
    return StudioErrorCategory.network;
  }
  if (error is RustApiException) {
    final status = error.statusCode;
    if (status == 401 || status == 403) {
      return StudioErrorCategory.auth;
    }
    if (status == 400 || status == 422) {
      return StudioErrorCategory.validation;
    }
    if (status != null && status >= 500) {
      return StudioErrorCategory.server;
    }
  }
  if (error is http.ClientException) {
    return StudioErrorCategory.network;
  }
  return StudioErrorCategory.unknown;
}

/// Whether the user can reasonably retry after [error].
bool studioErrorIsRetryable(Object error) {
  final category = classifyStudioError(error);
  return category == StudioErrorCategory.network ||
      category == StudioErrorCategory.server;
}

/// User-visible message; never exposes stack traces or exception types.
String formatStudioUserError(BuildContext context, Object error) =>
    describeUserVisibleApiErrorResolved(context, error);
