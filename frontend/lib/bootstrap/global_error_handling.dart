import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Installs global Flutter / platform error handlers (HEALTH-010).
///
/// Call once per entrypoint after [WidgetsFlutterBinding.ensureInitialized].
void configureGlobalErrorHandling({String logName = 'openflow.global'}) {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log(
      details.exceptionAsString(),
      name: logName,
      error: details.exception,
      stackTrace: details.stack,
      level: 1000,
    );
    previousFlutterOnError?.call(details);
    if (previousFlutterOnError == null) {
      FlutterError.presentError(details);
    }
  };

  final previousPlatformOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    developer.log(
      error.toString(),
      name: logName,
      error: error,
      stackTrace: stack,
      level: 1000,
    );
    return previousPlatformOnError?.call(error, stack) ?? false;
  };
}
