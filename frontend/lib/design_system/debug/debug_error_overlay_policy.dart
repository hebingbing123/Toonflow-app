import 'package:flutter/foundation.dart';

/// Whether [details] is a layout overflow that should not drive the debug overlay.
///
/// Reporting these during paint can schedule rebuilds and freeze the web tab.
bool isRenderFlexOverflowError(FlutterErrorDetails details) {
  final message = details.exceptionAsString();
  if (message.contains('RenderFlex overflowed')) {
    return true;
  }
  if (message.contains('overflowed by') && message.contains('pixels')) {
    return true;
  }
  return false;
}
