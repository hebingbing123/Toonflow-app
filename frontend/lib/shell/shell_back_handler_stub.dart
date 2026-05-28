// No-op stub for non-web (native) targets.
// This file is selected by the conditional import in build_product_shell.dart
// when dart:html is NOT available (i.e. on iOS, Android native, macOS, etc.).
//
// Both functions must have the same signatures as shell_back_handler_web.dart
// so the conditional import resolves to a single API surface.

import 'package:flutter/widgets.dart';

/// No-op on native targets. Returns null; the caller may ignore the return value.
// ignore: avoid_returning_null
Object? installPopStateListener(BuildContext context) => null;

/// No-op on native targets.
void removePopStateListener(Object? subscription) {}
