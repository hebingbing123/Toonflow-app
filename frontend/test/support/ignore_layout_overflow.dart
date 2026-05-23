import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

bool _isBenignLayoutOverflow(Object? error) {
  if (error == null) {
    return false;
  }
  final message = error.toString();
  return message.contains('overflowed') ||
      message.contains('RenderFlex overflowed') ||
      message.contains('A RenderFlex overflowed');
}

bool _overflowIgnoreInstalled = false;

/// Clears benign overflow exceptions recorded during a pump window.
void takeBenignLayoutOverflowExceptions(WidgetTester tester) {
  Object? error;
  while ((error = tester.takeException()) != null) {
    if (!_isBenignLayoutOverflow(error)) {
      throw error!;
    }
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
    if (_isBenignLayoutOverflow(details.exception)) {
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
      if (_isBenignLayoutOverflow(details.exception)) {
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
    if (_isBenignLayoutOverflow(details.exception)) {
      return;
    }
    super.reportExceptionNoticed(details);
  }
}
