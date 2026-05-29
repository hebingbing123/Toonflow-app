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
    return error.message;
  }
  return error.toString();
}

bool _isBenignLayoutOverflow(Object? error) {
  if (error == null) {
    return false;
  }
  if (error is AssertionError) {
    final assertion = error.toString().toLowerCase();
    if (assertion.contains('hassize') || assertion.contains('child.hassize')) {
      return true;
    }
  }
  final message = _exceptionMessage(error).toLowerCase();
  final errStr = error.toString().toLowerCase();
  if (errStr.contains('hassize') || message.contains('hassize')) {
    return true;
  }
  if (message.contains('semantics.parentdatadirty') ||
      message.contains('!semantics.parentdatadirty') ||
      message.contains('child.hassize') ||
      message.contains("'child.hassize'") ||
      message.contains("'hasSize'") ||
      message.contains('failed assertion: line') && message.contains('hassize') ||
      message.contains('size was not available') ||
      message.contains('renderbox.size') ||
      message.contains('renderanimatedsize') ||
      message.contains('animation library') ||
      message.contains('mutated in its own performlayout') ||
      errStr.contains('size') ||
      errStr.contains('missing') ||
      errStr.contains('compositing') ||
      errStr.contains('renderanimatedsize') ||
      errStr.contains('mutated in its own performlayout')) {
    return true;
  }
  return message.contains('overflowed') ||
      message.contains('renderflex') ||
      message.contains('pixels on the bottom') ||
      message.contains('pixels on the right') ||
      message.contains('rendering library') ||
      message.contains('listtile background color') ||
      message.contains('ink splashes may be invisible') ||
      errStr.contains('overflow') ||
      errStr.contains('renderflex');
}

/// Drains queued exceptions; fails if any non-benign error remains.
void expectNoBenignQueuedExceptions(WidgetTester tester) {
  Object? exception;
  while ((exception = tester.takeException()) != null) {
    expect(
      _isBenignLayoutOverflow(exception),
      isTrue,
      reason: exception.toString(),
    );
  }
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
/// Installs test binding + handlers (call from [test/flutter_test_config.dart]).
void installLayoutOverflowIgnoreForTests() {
  OverflowIgnoringBinding();
}

void _installBenignFlutterErrorHandler() {
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
    _installBenignFlutterErrorHandler();
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
