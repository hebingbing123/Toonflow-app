import 'package:flutter/widgets.dart';

/// No native OS drop on web; returns [child] unchanged.
Widget studioWrapNativeFileDrop({
  required Widget child,
  required bool enabled,
  required void Function(List<String> paths) onPathsDropped,
}) {
  return child;
}
