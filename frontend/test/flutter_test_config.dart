import 'dart:async';

import 'support/ignore_layout_overflow.dart';

/// Runs before every `flutter test` in this package (Flutter 3.44+ stricter asserts).
Future<void> testExecutable(Future<void> Function() testMain) async {
  installLayoutOverflowIgnoreForTests();
  await testMain();
}
