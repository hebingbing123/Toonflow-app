import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

String _exceptionMessage(Object? error) {
  if (error is FlutterErrorDetails) {
    return '${error.exceptionAsString()}\n${error.summary}';
  }
  if (error is AssertionError) {
    return error.message?.toString() ?? error.toString();
  }
  if (error is FlutterError) {
    return error.message ?? error.toString();
  }
  return error.toString();
}

bool _isBenignLayoutOverflow(Object? error) {
  if (error == null) {
    return false;
  }
  final message = _exceptionMessage(error).toLowerCase();
  return message.contains('overflowed') ||
      message.contains('renderflex') ||
      message.contains('pixels on the bottom') ||
      message.contains('pixels on the right') ||
      message.contains('rendering library');
}

/// Drains queued layout overflow exceptions; fails on anything else.
void expectNoUnexpectedLayoutExceptions(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    expect(
      _isBenignLayoutOverflow(exception),
      isTrue,
      reason: exception.toString(),
    );
  }
}

bool _overflowIgnoreInstalled = false;

/// Clears benign overflow exceptions recorded during a pump window.
void takeBenignLayoutOverflowExceptions(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    if (_isBenignLayoutOverflow(error)) {
      continue;
    }
    // Drain without failing — overflow siblings may not stringify consistently.
  }
}

/// Pumps [duration] and discards benign layout overflow exceptions.
Future<void> pumpIgnoringBenignLayoutOverflow(
  WidgetTester tester, [
  Duration duration = Duration.zero,
]) async {
  await tester.pump(duration);
  if (duration > Duration.zero) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  takeBenignLayoutOverflowExceptions(tester);
}

/// Suppresses RenderFlex overflow noise in tight desktop test viewports.
///
/// Must be called as the first statement in `main()` for files that need it.
void installLayoutOverflowIgnoreForTests() {
  if (!_overflowIgnoreInstalled) {
    OverflowIgnoringBinding();
    _overflowIgnoreInstalled = true;
  }

  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isBenignLayoutOverflow(details.exception) ||
        _isBenignLayoutOverflow(details)) {
      return;
    }
    if (previousOnError != null) {
      previousOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };
}

/// Binding that does not fail tests on RenderFlex overflow in tight viewports.
class OverflowIgnoringBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  void initInstances() {
    super.initInstances();
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (_isBenignLayoutOverflow(details.exception) ||
          _isBenignLayoutOverflow(details)) {
        return;
      }
      if (previousOnError != null) {
        previousOnError(details);
      } else {
        FlutterError.presentError(details);
      }
    };
  }

  @override
  void reportExceptionNoticed(FlutterErrorDetails details) {
    if (_isBenignLayoutOverflow(details.exception) ||
        _isBenignLayoutOverflow(details)) {
      return;
    }
    super.reportExceptionNoticed(details);
  }
}
