import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

bool isLayoutOverflowException(Object? error) {
  if (error == null) {
    return false;
  }
  final message = switch (error) {
    FlutterErrorDetails details => details.exceptionAsString(),
    FlutterError flutterError => flutterError.message,
    _ => error.toString(),
  }.toLowerCase();
  return message.contains('overflowed') ||
      message.contains('renderflex') ||
      message.contains('pixels on the right') ||
      message.contains('pixels on the bottom');
}

/// Fails on layout overflow; drains benign API/network noise from widget tests.
void expectNoLayoutOverflow(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    expect(
      isLayoutOverflowException(exception),
      isFalse,
      reason: exception.toString(),
    );
  }
}
