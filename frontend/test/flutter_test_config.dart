import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

import 'support/ignore_layout_overflow.dart';

/// Runs before every `flutter test` in this package (Flutter 3.44+ stricter asserts).
Future<void> testExecutable(Future<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  installLayoutOverflowIgnoreForTests();
  await testMain();
}
