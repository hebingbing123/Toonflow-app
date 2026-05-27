import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/bootstrap/global_error_handling.dart';

void main() {
  test('configureGlobalErrorHandling installs FlutterError.onError', () {
    final previous = FlutterError.onError;
    addTearDown(() => FlutterError.onError = previous);

    configureGlobalErrorHandling(logName: 'test.global');

    expect(FlutterError.onError, isNotNull);
    expect(FlutterError.onError, isNot(previous));
  });

  test('configureGlobalErrorHandling chains FlutterError.onError', () {
    var previousCalled = false;
    final previous = FlutterError.onError;
    FlutterError.onError = (_) {
      previousCalled = true;
    };
    addTearDown(() => FlutterError.onError = previous);

    configureGlobalErrorHandling(logName: 'test.flutter.chain');
    FlutterError.onError!(
      FlutterErrorDetails(exception: Exception('widget build failed')),
    );

    expect(previousCalled, isTrue);
  });

  test('configureGlobalErrorHandling chains PlatformDispatcher.onError', () {
    var previousCalled = false;
    final previous = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      previousCalled = true;
      return true;
    };
    addTearDown(() => PlatformDispatcher.instance.onError = previous);

    configureGlobalErrorHandling(logName: 'test.platform.chain');
    final handled = PlatformDispatcher.instance.onError!(
      Exception('async gap'),
      StackTrace.current,
    );

    expect(previousCalled, isTrue);
    expect(handled, isTrue);
  });
}
