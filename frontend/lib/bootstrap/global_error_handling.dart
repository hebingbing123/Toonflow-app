import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design_system/debug/debug.dart';

/// Test hook for verifying [developer.log] is still invoked.
@visibleForTesting
typedef GlobalErrorLogCallback = void Function(
  String message, {
  required String name,
  Object? error,
  StackTrace? stackTrace,
  int level,
});

@visibleForTesting
GlobalErrorLogCallback? debugGlobalErrorLogCallback;

void _logGlobalError(
  String message, {
  required String name,
  Object? error,
  StackTrace? stackTrace,
  int level = 1000,
}) {
  final testHook = debugGlobalErrorLogCallback;
  if (testHook != null) {
    testHook(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: level,
    );
    return;
  }
  developer.log(
    message,
    name: name,
    error: error,
    stackTrace: stackTrace,
    level: level,
  );
}

/// Builds the widget shown for framework / async errors.
///
/// [enableDebugOverlay] mirrors [!kReleaseMode] in [configureGlobalErrorHandling].
@visibleForTesting
Widget buildGlobalErrorDisplayWidget(
  FlutterErrorDetails details, {
  required bool enableDebugOverlay,
}) {
  if (!enableDebugOverlay) {
    return const SizedBox.shrink();
  }
  return DebugOverlayWidget(
    snapshot: DebugErrorSnapshot.fromDetails(details),
  );
}

/// Installs global Flutter / platform error handlers (HEALTH-010).
///
/// Call once per entrypoint after [WidgetsFlutterBinding.ensureInitialized].
void configureGlobalErrorHandling({String logName = 'openflow.global'}) {
  final enableDebugOverlay = !kReleaseMode;

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    _logGlobalError(
      details.exceptionAsString(),
      name: logName,
      error: details.exception,
      stackTrace: details.stack,
    );
    if (enableDebugOverlay) {
      DebugErrorOverlayController.instance.report(details);
    }
    previousFlutterOnError?.call(details);
    if (previousFlutterOnError == null) {
      FlutterError.presentError(details);
    }
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (enableDebugOverlay) {
      DebugErrorOverlayController.instance.report(details);
    }
    return buildGlobalErrorDisplayWidget(
      details,
      enableDebugOverlay: enableDebugOverlay,
    );
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logGlobalError(
      error.toString(),
      name: logName,
      error: error,
      stackTrace: stack,
    );

    if (enableDebugOverlay) {
      final details = FlutterErrorDetails(exception: error, stack: stack);
      DebugErrorOverlayController.instance.report(details);
      ErrorWidget.builder(details);
    }

    return previousPlatformOnError?.call(error, stack) ?? true;
  };
}
